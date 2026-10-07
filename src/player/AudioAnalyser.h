#pragma once

#include <QList>
#include <QObject>
#include <QVariantList>
#include <complex>

class QAudioBuffer;
class QAudioBufferOutput;
class QMediaPlayer;
class QTimer;

// Music reactivity for the idle themes. Taps the decoded PCM of the player (QAudioBufferOutput, next to the
// normal audio output) and, about 30 times a second while active, reports the same values the old in-page
// WebAudio analyser did, so ThemeBase and the themes need no changes: bass/mid/treble/level (0..1) and
// 32-band log-spaced spectra (40 Hz..16 kHz) of the mix and of each channel. The spectrum emulates
// AnalyserNode.getByteFrequencyData (fftSize 1024, Blackman window, smoothing 0.5, -90..-8 dB).
class AudioAnalyser : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool active READ active WRITE setActive NOTIFY activeChanged)
    Q_PROPERTY(qreal bass READ bass NOTIFY levelsChanged)
    Q_PROPERTY(qreal mid READ mid NOTIFY levelsChanged)
    Q_PROPERTY(qreal treble READ treble NOTIFY levelsChanged)
    Q_PROPERTY(qreal level READ level NOTIFY levelsChanged)
    Q_PROPERTY(QVariantList bands READ bands NOTIFY bandsChanged)
    Q_PROPERTY(QVariantList bandsL READ bandsL NOTIFY bandsChanged)
    Q_PROPERTY(QVariantList bandsR READ bandsR NOTIFY bandsChanged)

public:
    static constexpr int kFftSize = 1024;
    static constexpr int kBands = 32;

    explicit AudioAnalyser(QMediaPlayer *player, QObject *parent = nullptr);

    bool active() const { return m_active; }
    void setActive(bool on);
    qreal bass() const { return m_bass; }
    qreal mid() const { return m_mid; }
    qreal treble() const { return m_treble; }
    qreal level() const { return m_level; }
    QVariantList bands() const { return m_bands; }
    QVariantList bandsL() const { return m_bandsL; }
    QVariantList bandsR() const { return m_bandsR; }

signals:
    void activeChanged();
    void bandsChanged();  // emitted before levelsChanged: a theme reacts when the level changes
    void levelsChanged();

private:
    struct Channel {
        QList<float> ring = QList<float>(kFftSize, 0.0f);
        QList<double> smoothed = QList<double>(kFftSize / 2, 0.0);
        QList<double> bytes = QList<double>(kFftSize / 2, 0.0);  // 0..255 like getByteFrequencyData
    };

    void onBuffer(const QAudioBuffer &buffer);
    void tick();
    void analyse(Channel &ch);
    QVariantList spectrum(const Channel &ch) const;
    double band(const Channel &ch, double fromHz, double toHz) const;
    int bin(double hz) const;

    QAudioBufferOutput *m_output;
    QTimer *m_timer;
    bool m_active = false;
    bool m_fresh = false;
    int m_sampleRate = 48000;
    int m_write = 0;  // ring write position, shared by the three channels
    Channel m_mix, m_left, m_right;
    QList<float> m_window;
    QList<std::complex<double>> m_fft;

    qreal m_bass = 0, m_mid = 0, m_treble = 0, m_level = 0;
    QVariantList m_bands, m_bandsL, m_bandsR;
};
