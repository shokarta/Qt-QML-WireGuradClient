#pragma once

#include <QObject>
#include <QProcess>
#include <QTimer>
#include <QDateTime>
#include <QRegularExpression>

class ServiceController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString currentDownloadSpeed READ currentDownloadSpeed NOTIFY statsChanged)
    Q_PROPERTY(QString currentUploadSpeed READ currentUploadSpeed NOTIFY statsChanged)
    Q_PROPERTY(QString endpoint READ endpoint NOTIFY statsChanged)
    Q_PROPERTY(QString duration READ duration NOTIFY statsChanged)

public:

    explicit ServiceController(QObject* parent = nullptr)
        : QObject(parent)
    {
        connect(
            &m_timer,
            &QTimer::timeout,
            this,
            &ServiceController::updateStats);

        m_timer.start(1000);
    }

    bool connected() const
    {
        return m_connected;
    }

    QString currentDownloadSpeed() const
    {
        return m_currentDownloadSpeed;
    }

    QString currentUploadSpeed() const
    {
        return m_currentUploadSpeed;
    }

    QString endpoint() const
    {
        return m_endpoint;
    }

    QString duration() const
    {
        if (!m_connected)
            return "00:00:00";

        qint64 secs =
                m_connectedSince.secsTo(
                    QDateTime::currentDateTime());

        int h = secs / 3600;
        int m = (secs % 3600) / 60;
        int s = secs % 60;

        return QString("%1:%2:%3")
                .arg(h,2,10,QChar('0'))
                .arg(m,2,10,QChar('0'))
                .arg(s,2,10,QChar('0'));
    }

    Q_INVOKABLE void start()
    {
        QProcess::startDetached(
            "sc",
            {
                "start",
                "WireGuardTunnel$homevpn"
            });
    }

    Q_INVOKABLE void stop()
    {
        QProcess::startDetached(
            "sc",
            {
                "stop",
                "WireGuardTunnel$homevpn"
            });
    }

signals:

    void connectedChanged();
    void statsChanged();

    void trafficUpdated(
        double rxKBps,
        double txKBps);

private:

    static quint64 parseSize(QString text)
    {
        text.remove("received");
        text.remove("sent");

        QRegularExpression re(
            R"(([0-9.]+)\s*(B|KiB|MiB|GiB))");

        auto match = re.match(text);

        if (!match.hasMatch())
            return 0;

        double value =
                match.captured(1).toDouble();

        QString unit =
                match.captured(2);

        if (unit == "KiB")
            value *= 1024.0;
        else if (unit == "MiB")
            value *= 1024.0 * 1024.0;
        else if (unit == "GiB")
            value *= 1024.0 * 1024.0 * 1024.0;

        return static_cast<quint64>(value);
    }

    static QString formatSpeed(quint64 bytesPerSecond)
    {
        double value = bytesPerSecond;

        if (value >= 1024.0 * 1024.0)
            return QString::number(
                       value / (1024.0 * 1024.0),
                       'f',
                       2) + " MB/s";

        if (value >= 1024.0)
            return QString::number(
                       value / 1024.0,
                       'f',
                       2) + " KB/s";

        return QString::number(
                   value,
                   'f',
                   0) + " B/s";
    }

    void updateStats()
    {
        QProcess service;

        service.start(
            "powershell",
            {
                "-Command",
                "Get-Service *WireGuardTunnel* | Select-Object -ExpandProperty Status"
            });

        service.waitForFinished();

        bool state =
                QString::fromUtf8(
                    service.readAllStandardOutput())
                .contains("Running");

        if (state != m_connected)
        {
            m_connected = state;

            if (state)
            {
                m_connectedSince =
                        QDateTime::currentDateTime();
            }

            emit connectedChanged();
        }

        if (!state)
            return;

        QProcess wg;

        wg.start(
            R"(C:\Program Files\WireGuard\wg.exe)",
            { "show" });

        wg.waitForFinished();

        QString output =
                QString::fromUtf8(
                    wg.readAllStandardOutput());

        quint64 rxBytes = 0;
        quint64 txBytes = 0;

        const QStringList lines =
                output.split('\n');

        for (const QString &line : lines)
        {
            QString trimmed =
                    line.trimmed();

            if (trimmed.startsWith("endpoint:"))
            {
                m_endpoint =
                        trimmed.section(':',1).trimmed();
            }

            if (trimmed.contains("transfer:"))
            {
                QStringList parts =
                        trimmed.mid(
                            trimmed.indexOf("transfer:")
                            + 9).split(',');

                if (parts.size() >= 2)
                {
                    rxBytes =
                        parseSize(parts[0]);

                    txBytes =
                        parseSize(parts[1]);
                }
            }
        }

        if (m_lastRxBytes)
        {
            quint64 rxSpeed =
                    rxBytes - m_lastRxBytes;

            quint64 txSpeed =
                    txBytes - m_lastTxBytes;

            m_currentDownloadSpeed =
                    formatSpeed(rxSpeed);

            m_currentUploadSpeed =
                    formatSpeed(txSpeed);

            double rx =
                    rxSpeed / 1024.0;

            double tx =
                    txSpeed / 1024.0;

            // Exponential Moving Average
            m_rxAvg =
                    (m_rxAvg * 0.75)
                    + (rx * 0.25);

            m_txAvg =
                    (m_txAvg * 0.75)
                    + (tx * 0.25);

            emit trafficUpdated(
                m_rxAvg,
                m_txAvg);
        }

        m_lastRxBytes = rxBytes;
        m_lastTxBytes = txBytes;

        emit statsChanged();
    }

private:

    QTimer m_timer;

    bool m_connected = false;

    QString m_currentDownloadSpeed = "0 KB/s";
    QString m_currentUploadSpeed = "0 KB/s";

    QString m_endpoint;

    quint64 m_lastRxBytes = 0;
    quint64 m_lastTxBytes = 0;

    QDateTime m_connectedSince;

    double m_rxAvg = 0.0;
    double m_txAvg = 0.0;
};