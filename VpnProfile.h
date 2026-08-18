#pragma once

#include <QString>
#include <QDateTime>


struct VpnProfile
{
    QString serviceName;
    QString displayName;

    QString configPath;

    bool connected = false;

    bool pendingStart = false;
    bool pendingStop = false;

    QString configuredEndpoint;
    QString currentEndpoint;

    qint64 lastHandshakeSeconds = -1;

    QString downloadSpeed = "0 KB/s";
    QString uploadSpeed = "0 KB/s";

    quint64 lastRxBytes = 0;
    quint64 lastTxBytes = 0;

    QDateTime connectedSince;

    QString duration() const {
        if (!connected) { return "00:00:00"; }

        qint64 secs = connectedSince.secsTo(QDateTime::currentDateTime());

        int h = secs / 3600;
        int m = (secs % 3600) / 60;
        int s = secs % 60;

        return QString("%1:%2:%3")
                .arg(h, 2, 10, QChar('0'))
                .arg(m, 2, 10, QChar('0'))
                .arg(s, 2, 10, QChar('0'));
    }
    QString handshakeDuration() const {
        if (lastHandshakeSeconds < 0) { return "Never"; }

		int h = lastHandshakeSeconds / 3600;
		int m = (lastHandshakeSeconds % 3600) / 60;
		int s = lastHandshakeSeconds % 60;

		return QString("%1:%2:%3")
				.arg(h, 2, 10, QChar('0'))
				.arg(m, 2, 10, QChar('0'))
				.arg(s, 2, 10, QChar('0'));
	}
};