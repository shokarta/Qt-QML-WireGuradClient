#pragma once

#include <QAbstractListModel>
#include <QList>

#include "VpnProfile.h"


class VpnProfilesModel : public QAbstractListModel
{
    Q_OBJECT

public:

    enum Roles {
        NameRole = Qt::UserRole + 1,

        ServiceRole,

        ConnectedRole,

        PendingStartRole,
        PendingStopRole,

        ConfiguredEndpointRole,
        CurrentEndpointRole,

        HandshakeRole,

        DownloadRole,
        UploadRole,

        DurationRole
    };

    explicit VpnProfilesModel(QObject *parent = nullptr);

    int rowCount(
        const QModelIndex &parent = QModelIndex()) const override;

    QVariant data(
        const QModelIndex &index,
        int role = Qt::DisplayRole) const override;

    QHash<int, QByteArray> roleNames() const override;

    void setProfiles(
        const QList<VpnProfile> &profiles);

    QList<VpnProfile>& profiles();

    const QList<VpnProfile>& profiles() const;

    void refreshRow(int row);

private:

    QList<VpnProfile> m_profiles;
};