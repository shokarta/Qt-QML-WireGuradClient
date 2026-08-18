#pragma once

#include <QObject>
#include <QSettings>
#include <QProcess>
#include <QFileInfo>
#include <QRegularExpression>
#include <QTimer>
#include <QVariantMap>

#include "VpnProfilesModel.h"


class ServiceController : public QObject
{
    Q_OBJECT


    Q_PROPERTY(VpnProfilesModel* profilesModel READ profilesModel CONSTANT)
    Q_PROPERTY(bool wireGuardInstalled READ wireGuardInstalled NOTIFY wireGuardInstalledChanged)
    Q_PROPERTY(QString wireGuardPath READ wireGuardPath NOTIFY wireGuardInstalledChanged)
    Q_PROPERTY(QString wireGuardExe READ wireGuardExe NOTIFY wireGuardInstalledChanged)
    Q_PROPERTY(QString wireGuardError READ wireGuardError NOTIFY wireGuardInstalledChanged)
    Q_PROPERTY(bool allowMultipleConnections READ allowMultipleConnections WRITE setAllowMultipleConnections NOTIFY allowMultipleConnectionsChanged)
    Q_PROPERTY(bool anyProfileConnected READ anyProfileConnected NOTIFY anyProfileConnectedChanged)
    Q_PROPERTY(bool askDisconnectOnExit READ askDisconnectOnExit WRITE setAskDisconnectOnExit NOTIFY askDisconnectOnExitChanged)


public:

    explicit ServiceController(QObject *parent = nullptr);

    VpnProfilesModel *profilesModel() { return &m_profilesModel; }

    Q_INVOKABLE bool addProfile(const QVariantMap &config);

    Q_INVOKABLE QVariantMap loadProfileConfig(int row);

    Q_INVOKABLE bool saveProfileConfig(int row, const QVariantMap &config);

    Q_INVOKABLE bool deleteProfile(int row, bool deleteConfigFile = false);

    bool wireGuardInstalled() const { return m_wireGuardInstalled; }

    QString wireGuardPath() const { return m_wireGuardPath; }

    QString wireGuardExe() const { return m_wireGuardPath + "/wg.exe"; }

    QString wireGuardError() const { return m_wireGuardError; }

    bool allowMultipleConnections() const { return m_allowMultipleConnections; }

    bool anyProfileConnected() const;

    bool askDisconnectOnExit() const { return m_askDisconnectOnExit; }

    void setAllowMultipleConnections(bool value);

    void setAskDisconnectOnExit(bool value);

    Q_INVOKABLE bool setWireGuardFolder(const QString &folder);

    Q_INVOKABLE void disconnectAllProfiles();

    Q_INVOKABLE void startProfile(int row);

    Q_INVOKABLE void stopProfile(int row);

    Q_INVOKABLE void refreshProfiles();

    static quint64 parseSize(QString text);

    static QString formatSpeed(quint64 bytesPerSecond);


signals:

    void wireGuardInstalledChanged();

    void allowMultipleConnectionsChanged();

    void anyProfileConnectedChanged();

    void askDisconnectOnExitChanged();


private:

    bool validateWireGuardFolder(const QString &path);

    void detectWireGuard();

    void discoverProfiles();

    void updateProfiles();


private:

    VpnProfilesModel m_profilesModel;

    QString m_wireGuardPath;
    QString m_wireGuardError;

    bool m_wireGuardInstalled = false;

    bool m_allowMultipleConnections = false;

    QTimer m_updateTimer;

    bool m_askDisconnectOnExit = true;
};