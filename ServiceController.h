#pragma once

#include <QObject>
#include <QSettings>
#include <QProcess>
#include <QFileInfo>
#include <QRegularExpression>
#include <QTimer>
#include <QVariantMap>
#include <QFile>
#include <QTextStream>
#include <QtConcurrent>
#include <QFutureWatcher>

#include "VpnProfilesModel.h"


struct ProfileRuntimeData
{
    QString serviceName;

    bool connected = false;

    QString currentEndpoint;

    int currentPingMs = -1;

    qint64 lastHandshakeSeconds = -1;

    QString downloadSpeed = "0 KB/s";
    QString uploadSpeed = "0 KB/s";

    quint64 rx = 0;
    quint64 tx = 0;
};
struct SaveProfileResult
{
    bool success = false;
    QString error;
};


class ServiceController : public QObject
{
    Q_OBJECT


    Q_PROPERTY(VpnProfilesModel *profilesModel READ profilesModel CONSTANT)
    Q_PROPERTY(bool wireGuardInstalled READ wireGuardInstalled NOTIFY wireGuardInstalledChanged)
    Q_PROPERTY(QString wireGuardPath READ wireGuardPath NOTIFY wireGuardInstalledChanged)
    Q_PROPERTY(QString wireGuardExe READ wireGuardExe NOTIFY wireGuardInstalledChanged)
    Q_PROPERTY(QString wireGuardError READ wireGuardError NOTIFY wireGuardInstalledChanged)
    Q_PROPERTY(bool allowMultipleConnections READ allowMultipleConnections WRITE setAllowMultipleConnections NOTIFY allowMultipleConnectionsChanged)
    Q_PROPERTY(bool anyProfileConnected READ anyProfileConnected NOTIFY anyProfileConnectedChanged)
    Q_PROPERTY(bool askDisconnectOnExit READ askDisconnectOnExit WRITE setAskDisconnectOnExit NOTIFY askDisconnectOnExitChanged)


public:

	// CONSTRUCTOR
    explicit ServiceController(QObject *parent = nullptr);

    // UTILITY HELPERS
    static int pingHost(const QString &host);
    static quint64 parseSize(QString text);
    static QString formatSpeed(quint64 bytesPerSecond);

	// MODEL ACCESS
    VpnProfilesModel *profilesModel() { return &m_profilesModel; }

	// GETTERS
	bool wireGuardInstalled() const { return m_wireGuardInstalled; }
	QString wireGuardPath() const { return m_wireGuardPath; }
    QString wireGuardExe() const { return m_wireGuardPath + "/wg.exe"; }
    QString wireGuardError() const { return m_wireGuardError; }

    bool allowMultipleConnections() const { return m_allowMultipleConnections; }
    bool anyProfileConnected() const {
		const auto &profiles = m_profilesModel.profiles();
		for (const auto &profile : profiles) { if (profile.connected) { return true; } }
		return false;
	}
    bool askDisconnectOnExit() const { return m_askDisconnectOnExit; }

	// SETTERS
    void setAllowMultipleConnections(bool value);
    void setAskDisconnectOnExit(bool value);
	
	// PROFILE ADD
	Q_INVOKABLE bool addProfile(const QVariantMap &config);
	
	// PROFILE EDIT
	Q_INVOKABLE QVariantMap loadProfileConfig(int row);
    Q_INVOKABLE bool saveProfileConfig(int row, const QVariantMap &config);
	
	// PROFILE DELETE
    Q_INVOKABLE bool deleteProfile(int row, bool deleteConfigFile = false);

	// PROFILE DISCOVERY
	Q_INVOKABLE void refreshProfiles();
	
	// PROFILE CONNECTION CONTROL
	Q_INVOKABLE void startProfile(int row);
    Q_INVOKABLE void stopProfile(int row);
	Q_INVOKABLE void disconnectAllProfiles();

	// WIREGUARD CONFIGURATION
	Q_INVOKABLE bool setWireGuardFolder(const QString &folder);


signals:

    void wireGuardInstalledChanged();
    void allowMultipleConnectionsChanged();
    void anyProfileConnectedChanged();
    void askDisconnectOnExitChanged();


private:

	// WIREGUARD DETECTION
    bool validateWireGuardFolder(const QString &path);
    void detectWireGuard();

	// PROFILE DISCOVERY
    void discoverProfiles();
    QList<VpnProfile> discoverProfilesWorker();

	// RUNTIME MONITORING
    void updateProfiles();
    static QList<ProfileRuntimeData> collectRuntimeDataWorker(const QStringList &serviceNames, const QString &wireGuardExe);
    void applyRuntimeData(const QList<ProfileRuntimeData> &runtimeData);

    // PROFILE SAVE
	SaveProfileResult saveProfileConfigWorker(QString configPath, QString wireGuardPath, QString serviceName, QVariantMap config);
	void applySaveProfileResult(int row, const SaveProfileResult &result);


private:

	// MODELS
    VpnProfilesModel m_profilesModel;

	// WIREGUARD STATE
    QString m_wireGuardPath;
    QString m_wireGuardError;
	bool m_wireGuardInstalled = false;

	// USER SETTINGS
    bool m_allowMultipleConnections = false;
	bool m_askDisconnectOnExit = true;
	
	// TIMERS
    QTimer m_updateTimer;

    // CONCURRENT WATCHERS
	QFutureWatcher<QList<VpnProfile>> m_discoverWatcher;
	QFutureWatcher<QList<ProfileRuntimeData>> m_runtimeWatcher;
	QFutureWatcher<SaveProfileResult> m_saveProfileWatcher;
};