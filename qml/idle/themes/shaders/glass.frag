#version 440

// Liquid Glass material.
// The glass is a union of rounded rectangles described by a signed distance field.
// Its rim is a convex squircle bevel: the backdrop is refracted through it with
// Snell's law (per-channel IOR for dispersion), the flat centre stays undistorted.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;       // effect item size, px
    vec4 srcMap;         // xy: effect origin in source px, zw: source size px
    vec2 srcScale;       // effect px -> source px
    vec4 shape0;         // x, y, w, h in effect px
    vec4 shape1;
    vec4 shape2;
    vec4 shape3;
    vec4 radii;
    float shapeCount;
    float smoothing;     // smooth-union radius, px
    float bezel;         // width of the curved rim, px
    float thickness;     // optical depth of the glass, px
    float ior;
    float dispersion;
    float magnify;
    float frost;         // 0 = sharp backdrop, 1 = blurred backdrop
    float clearRim;      // how much of the frost the rim drops (1 = a clear rim)
    vec4 tint;           // premultiplied
    float saturation;
    float brightness;
    float rimLight;
    float lightAngle;    // radians, screen space
    float shadowOpacity;
    float shadowRadius;
    float shadowOffset;
    vec2 glowPos;
    float glow;
    float glowRadius;
};

layout(binding = 1) uniform sampler2D source;
layout(binding = 2) uniform sampler2D sourceBlur;

float sdRoundRect(vec2 p, vec4 r, float rad)
{
    vec2 h = r.zw * 0.5;
    vec2 q = abs(p - r.xy - h) - h + rad;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
}

float smin(float a, float b, float k)
{
    if (k <= 0.0)
        return min(a, b);
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float sceneSdf(vec2 p)
{
    float d = sdRoundRect(p, shape0, radii.x);
    if (shapeCount > 1.5)
        d = smin(d, sdRoundRect(p, shape1, radii.y), smoothing);
    if (shapeCount > 2.5)
        d = smin(d, sdRoundRect(p, shape2, radii.z), smoothing);
    if (shapeCount > 3.5)
        d = smin(d, sdRoundRect(p, shape3, radii.w), smoothing);
    return d;
}

vec4 backdrop(vec2 p, float f)
{
    vec2 uv = (srcMap.xy + p * srcScale) / srcMap.zw;
    vec4 s = texture(source, uv);
    if (f > 0.0)
        s = mix(s, texture(sourceBlur, uv), f);
    return s;
}

vec2 refractOffset(vec3 n, float eta)
{
    vec3 r = refract(vec3(0.0, 0.0, -1.0), n, 1.0 / eta);
    return r.xy / max(-r.z, 0.15) * thickness;
}

void main()
{
    vec2 p = qt_TexCoord0 * itemSize;
    float d = sceneSdf(p);
    float mask = clamp(0.5 - d, 0.0, 1.0);

    float shadow = 0.0;
    if (shadowOpacity > 0.0 && mask < 1.0) {
        float ds = max(sceneSdf(p - vec2(0.0, shadowOffset)) + 2.0, 0.0);
        float s = exp(-3.0 * ds / shadowRadius);
        shadow = shadowOpacity * s * (1.0 - smoothstep(0.6, 1.0, ds / shadowRadius));
    }
    vec4 outside = vec4(0.0, 0.0, 0.0, shadow);

    if (mask <= 0.0) {
        fragColor = outside * qt_Opacity;
        return;
    }

    vec2 e = vec2(0.5, 0.0);
    vec2 grad = vec2(sceneSdf(p + e.xy) - sceneSdf(p - e.xy),
                     sceneSdf(p + e.yx) - sceneSdf(p - e.yx));
    float gl = length(grad);
    vec2 n2 = gl > 1e-5 ? grad / gl : vec2(0.0);

    // Convex squircle rim profile h(t) = (1 - (1 - t)^4)^(1/4), slope = h'(t).
    float inner = max(-d, 0.0);
    float t = clamp(inner / bezel, 0.0, 1.0);
    float u = 1.0 - t;
    float slope = u * u * u / pow(max(1.0 - u * u * u * u, 1e-3), 0.75);
    vec3 n = normalize(vec3(n2 * slope, 1.0));

    vec2 c = shape0.xy + shape0.zw * 0.5;
    vec2 base = c + (p - c) / magnify;

    // frosted in the middle, clear on the rim, so the bent backdrop shows where the glass curves
    float f = frost * mix(1.0 - clearRim, 1.0, smoothstep(0.0, bezel * 1.6, inner));

    vec4 col;
    if (dispersion > 0.0) {
        vec4 g = backdrop(base + refractOffset(n, ior), f);
        col = vec4(backdrop(base + refractOffset(n, ior - dispersion), f).r,
                   g.g,
                   backdrop(base + refractOffset(n, ior + dispersion), f).b,
                   g.a);
    } else {
        col = backdrop(base + refractOffset(n, ior), f);
    }

    vec3 rgb = col.a > 0.0 ? col.rgb / col.a : vec3(0.0);
    float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    rgb = max(mix(vec3(luma), rgb, saturation), 0.0) * brightness;
    col = vec4(rgb * col.a, col.a);
    // the tint thins out toward a clear rim as well
    float k = mix(1.0 - 0.4 * clearRim, 1.0, smoothstep(0.0, bezel * 1.6, inner));
    col = col * (1.0 - k * tint.a) + k * tint;

    // Specular rim: lit from lightAngle, with a weaker internal reflection on the opposite side.
    vec2 L = vec2(cos(lightAngle), sin(lightAngle));
    float facing = dot(n2, L);
    float dirTerm = max(pow(max(facing, 0.0), 2.0), 0.7 * pow(max(-facing, 0.0), 2.0));
    float rim = 1.0 - smoothstep(0.0, 1.5, inner);
    float bevel = pow(u, 6.0);
    float spec = rimLight * (rim * (0.28 + 0.72 * dirTerm) + bevel * 0.32 * dirTerm);
    col = mix(col, vec4(1.0), clamp(spec, 0.0, 1.0));

    if (glow > 0.0) {
        vec2 dg = p - glowPos;
        col = mix(col, vec4(1.0), glow * exp(-dot(dg, dg) / (glowRadius * glowRadius)));
    }

    fragColor = (col * mask + outside * (1.0 - mask)) * qt_Opacity;
}
