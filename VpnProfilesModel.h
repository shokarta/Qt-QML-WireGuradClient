#pragma once

#include <QAbstractListModel>
#include <QList>

#include "VpnProfile.h"


class VpnProfilesModel : public QAbstractListModel
{
    Q_OBJECT


public:

	// MODEL ROLES
    enum Roles {
        NameRole = Qt::UserRole + 1,

        ServiceRole,

        ConnectedRole,

        PendingStartRole,
        PendingStopRole,

        ConfiguredEndpointRole,
        CurrentEndpointRole,

        PingRole,
        PingHistoryRole,

        HandshakeRole,

        DownloadRole,
        UploadRole,

        DurationRole
    };

	// CONSTRUCTOR
    explicit VpnProfilesModel(QObject *parent = nullptr);

	// QAbstractListModel Overrides
    int rowCount(const QModelIndex &parent = QModelIndex()) const override;
    QVariant data(const QModelIndex &index, int role = Qt::DisplayRole) const override;
    QHash<int, QByteArray> roleNames() const override;

	// PROFILE COLLECTION
    void setProfiles(const QList<VpnProfile> &profiles);
    QList<VpnProfile> &profiles();
    const QList<VpnProfile> &profiles() const;

	// UI Refresh
    void refreshRow(int row);


private:

	// MODEL DATA
    QList<VpnProfile> m_profiles;
};