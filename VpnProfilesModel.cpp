#include "VpnProfilesModel.h"


VpnProfilesModel::VpnProfilesModel(QObject *parent) : QAbstractListModel(parent)
{
}

int VpnProfilesModel::rowCount(const QModelIndex &parent) const
{
    if (parent.isValid()) { return 0; }

    return m_profiles.count();
}

QVariant VpnProfilesModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid()) { return {}; }

    if (index.row() < 0 || index.row() >= m_profiles.size()) { return {}; }

    const VpnProfile &profile = m_profiles[index.row()];

    switch (role) {
        case NameRole:
            return profile.displayName;

        case ServiceRole:
            return profile.serviceName;

        case ConnectedRole:
            return profile.connected;

        case PendingStartRole:
            return profile.pendingStart;

        case PendingStopRole:
            return profile.pendingStop;

        case ConfiguredEndpointRole:
            return profile.configuredEndpoint;

        case CurrentEndpointRole:
            return profile.currentEndpoint;

        case HandshakeRole:
            return profile.handshakeDuration();

        case DownloadRole:
            return profile.downloadSpeed;

        case UploadRole:
            return profile.uploadSpeed;

        case DurationRole:
            return profile.duration();

        default:
            return {};
    }
}

QHash<int, QByteArray>VpnProfilesModel::roleNames() const
{
    return {
        { NameRole, "name" },
        { ServiceRole, "serviceName" },

        { ConnectedRole, "connected" },

        { PendingStartRole, "pendingStart" },
        { PendingStopRole, "pendingStop" },

        { ConfiguredEndpointRole, "configuredEndpoint" },
        { CurrentEndpointRole, "currentEndpoint" },

        { HandshakeRole, "lastHandshake" },

        { DownloadRole, "downloadSpeed" },
        { UploadRole, "uploadSpeed" },

        { DurationRole, "duration" }
    };
}

void VpnProfilesModel::setProfiles(const QList<VpnProfile> &profiles)
{
    beginResetModel();

    m_profiles = profiles;

    endResetModel();
}

QList<VpnProfile>&VpnProfilesModel::profiles()
{
    return m_profiles;
}

const QList<VpnProfile>&VpnProfilesModel::profiles() const
{
    return m_profiles;
}

void VpnProfilesModel::refreshRow(int row)
{
    if (row < 0 || row >= m_profiles.size()) { return; }

    emit dataChanged(index(row), index(row));
}