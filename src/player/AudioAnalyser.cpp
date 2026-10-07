#include "player/AudioAnalyser.h"

#include <QAudioBuffer>
#include <QAudioBufferOutput>
#include <QMediaPlayer>
#include <QTimer>
#include <cmath>
#include <numbers>

static constexpr double kMinDb = -90.0;
static constexpr double kMaxDb = -8.0;
static constexpr double kSmoothing = 0.5;

AudioAnalyser::AudioAnalyser(QMediaPlayer *player, QObject *parent)
    : QObject(parent), m_timer(new QTimer(this))
{
    QAudioFormat format;
    format.setSampleFormat(QAudioFormat::Float);
    format.setChannelCount(2);
    format.setSampleRate(48000);
    m_output = new QAudioBufferOutput(format, this);
    player->setAudioBufferOutput(m_output);
    connect(m_output, &QAudioBufferOutput::audioBufferReceived, this, &AudioAnalyser::onBuffer);

    m_window.resize(kFftSize);
    for (int i = 0; i < kFftSize; ++i) {
        const double x = 2 * std::numbers::pi * i / kFftSize;
        m_window[i] = float(0.42 - 0.5 * std::cos(x) + 0.08 * std::cos(2 * x));  // Blackman, like WebAudio
    }
    m_fft.resize(kFftSize);

    m_timer->setInterval(33);
    connect(m_timer, &QTimer::timeout, this, &AudioAnalyser::tick);
}

void AudioAnalyser::setActive(bool on)
{
    if (on == m_active)
        return;
    m_active = on;
    if (on) {
        m_mix = m_left = m_right = Channel();
        m_write = 0;
        m_fresh = false;
        m_timer->start();
    } else {
        m_timer->stop();
    }
    emit activeChanged();
}

void AudioAnalyser::onBuffer(const QAudioBuffer &buffer)
{
    if (!m_active || !buffer.isValid())
        return;
    const QAudioFormat fmt = buffer.format();
    const int channels = fmt.channelCount();
    const int bytesPerSample = fmt.bytesPerSample();
    if (channels < 1 || bytesPerSample < 1)
        return;
    m_sampleRate = fmt.sampleRate() > 0 ? fmt.sampleRate() : m_sampleRate;
    const char *data = buffer.constData<char>();
    const qsizetype frames = buffer.frameCount();
    const bool isFloat = fmt.sampleFormat() == QAudioFormat::Float;
    // the requested float format is what the FFmpeg backend normally delivers; anything else is normalised
    auto sample = [&](qsizetype frame, int channel) -> float {
        const char *p = data + (frame * channels + channel) * bytesPerSample;
        return isFloat ? *reinterpret_cast<const float *>(p) : fmt.normalizedSampleValue(p);
    };
    for (qsizetype f = 0; f < frames; ++f) {
        const float l = sample(f, 0);
        const float r = channels > 1 ? sample(f, 1) : l;
        m_left.ring[m_write] = l;
        m_right.ring[m_write] = r;
        m_mix.ring[m_write] = 0.5f * (l + r);  // WebAudio's stereo -> mono down-mix
        m_write = (m_write + 1) % kFftSize;
    }
    m_fresh = frames > 0;
}

static void fft(QList<std::complex<double>> &a)
{
    const qsizetype n = a.size();
    for (qsizetype i = 1, j = 0; i < n; ++i) {
        qsizetype bit = n >> 1;
        for (; j & bit; bit >>= 1)
            j ^= bit;
        j ^= bit;
        if (i < j)
            std::swap(a[i], a[j]);
    }
    for (qsizetype len = 2; len <= n; len <<= 1) {
        const double ang = -2 * std::numbers::pi / double(len);
        const std::complex<double> wl(std::cos(ang), std::sin(ang));
        for (qsizetype i = 0; i < n; i += len) {
            std::complex<double> w(1);
            for (qsizetype k = 0; k < len / 2; ++k) {
                const auto u = a[i + k];
                const auto v = a[i + k + len / 2] * w;
                a[i + k] = u + v;
                a[i + k + len / 2] = u - v;
                w *= wl;
            }
        }
    }
}

void AudioAnalyser::analyse(Channel &ch)
{
    for (int i = 0; i < kFftSize; ++i)
        m_fft[i] = std::complex<double>(ch.ring[(m_write + i) % kFftSize] * m_window[i], 0.0);
    fft(m_fft);
    for (int k = 0; k < kFftSize / 2; ++k) {
        const double magnitude = std::abs(m_fft[k]) / kFftSize;
        ch.smoothed[k] = kSmoothing * ch.smoothed[k] + (1 - kSmoothing) * magnitude;
        const double db = ch.smoothed[k] > 0 ? 20 * std::log10(ch.smoothed[k]) : kMinDb;
        ch.bytes[k] = std::clamp(255.0 * (db - kMinDb) / (kMaxDb - kMinDb), 0.0, 255.0);
    }
}

int AudioAnalyser::bin(double hz) const
{
    const double binHz = double(m_sampleRate) / kFftSize;
    return std::clamp(int(std::lround(hz / binHz)), 0, kFftSize / 2 - 1);
}

double AudioAnalyser::band(const Channel &ch, double fromHz, double toHz) const
{
    const int from = bin(fromHz);
    int to = bin(toHz);
    if (to <= from)
        to = from + 1;
    double sum = 0;
    for (int i = from; i < to; ++i)
        sum += ch.bytes[i];
    return sum / ((to - from) * 255.0);
}

QVariantList AudioAnalyser::spectrum(const Channel &ch) const
{
    QVariantList out;
    out.reserve(kBands);
    for (int i = 0; i < kBands; ++i) {
        const double lo = 40 * std::pow(16000.0 / 40, double(i) / kBands);
        const double hi = 40 * std::pow(16000.0 / 40, double(i + 1) / kBands);
        out.append(band(ch, lo, hi));
    }
    return out;
}

void AudioAnalyser::tick()
{
    // nothing new (paused, between tracks): stay quiet, the themes decay on their own
    if (!m_fresh)
        return;
    m_fresh = false;
    analyse(m_mix);
    analyse(m_left);
    analyse(m_right);
    m_bands = spectrum(m_mix);
    m_bandsL = spectrum(m_left);
    m_bandsR = spectrum(m_right);
    emit bandsChanged();
    m_bass = band(m_mix, 20, 300);
    m_mid = band(m_mix, 300, 2500);
    m_treble = band(m_mix, 2500, 11000);
    m_level = band(m_mix, 20, 11000);
    emit levelsChanged();
}
