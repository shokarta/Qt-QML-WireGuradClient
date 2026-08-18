#include "ServiceController.h"
#include <QFile>
#include <QTextStream>


ServiceController::ServiceController(QObject *parent) : QObject(parent)
{
	QSettings settings;

	m_allowMultipleConnections = settings.value("AllowMultipleConnections",false).toBool();

	m_askDisconnectOnExit = settings.value("AskDisconnectOnExit", true).toBool();

	detectWireGuard();

	discoverProfiles();

	connect(&m_updateTimer, &QTimer::timeout, this, &ServiceController::updateProfiles);

	m_updateTimer.start(1000);
}

quint64 ServiceController::parseSize(QString text)
{
	text.remove("received");
	text.remove("sent");

	QRegularExpression re(R"(([0-9.]+)\s*(B|KiB|MiB|GiB))");

	auto match = re.match(text);

	if (!match.hasMatch()) { return 0; }

	double value = match.captured(1).toDouble();

	QString unit = match.captured(2);

	if (unit == "KiB") { value *= 1024.0; }
	else if (unit == "MiB") { value *= 1024.0 * 1024.0; }
	else if (unit == "GiB") { value *= 1024.0 * 1024.0 * 1024.0; }

	return static_cast<quint64>(value);
}

QString ServiceController::formatSpeed(quint64 bytesPerSecond)
{
	double value = bytesPerSecond;

	if (value >= 1024.0 * 1024.0) { return QString::number(value / (1024.0 * 1024.0), 'f', 2) + " MB/s"; }
	if (value >= 1024.0) { return QString::number(value / 1024.0, 'f', 2) + " KB/s"; }

	return QString::number(value, 'f', 0) + " B/s";
}

void ServiceController::setAllowMultipleConnections(bool value)
{
	if (m_allowMultipleConnections == value) { return; }

	m_allowMultipleConnections = value;

	QSettings settings;
		settings.setValue("AllowMultipleConnections", value);

	emit allowMultipleConnectionsChanged();
}

bool ServiceController::anyProfileConnected() const
{
	const auto &profiles = m_profilesModel.profiles();

	for (const auto &profile : profiles) {
		if (profile.connected) { return true; }
	}

	return false;
}

void ServiceController::setAskDisconnectOnExit(bool value)
{
	if (m_askDisconnectOnExit == value) { return; }

	m_askDisconnectOnExit = value;

	QSettings settings;

	settings.setValue("AskDisconnectOnExit", value);

	emit askDisconnectOnExitChanged();
}

bool ServiceController::validateWireGuardFolder(const QString &path)
{
	QFileInfo wg(path + "/wg.exe");
	QFileInfo wireguard(path + "/wireguard.exe");

	return wg.exists() && wireguard.exists();
}

bool ServiceController::setWireGuardFolder(const QString &folder)
{
	if (!validateWireGuardFolder(folder)) {
		m_wireGuardInstalled = false;

		m_wireGuardPath.clear();

		m_wireGuardError = "Wrong WireGuard path";

		emit wireGuardInstalledChanged();

		return false;
	}

	m_wireGuardPath = folder;

	m_wireGuardInstalled = true;

	m_wireGuardError.clear();

	QSettings settings;
		settings.setValue("WireGuardPath", folder);

	emit wireGuardInstalledChanged();

	return true;
}

void ServiceController::detectWireGuard()
{
	QSettings settings;

	QString savedPath = settings.value("WireGuardPath").toString();

	if (!savedPath.isEmpty() && validateWireGuardFolder(savedPath)) {
		m_wireGuardPath = savedPath;
		m_wireGuardInstalled = true;

		m_wireGuardError.clear();

		emit wireGuardInstalledChanged();

		return;
	}

	QString defaultPath = R"(C:\Program Files\WireGuard)";

	if (validateWireGuardFolder(defaultPath)) {
		m_wireGuardPath = defaultPath;

		m_wireGuardInstalled = true;

		settings.setValue("WireGuardPath", defaultPath);

		emit wireGuardInstalledChanged();

		return;
	}

	QProcess process;

	process.start("where", { "wg.exe" });

	if (!process.waitForFinished(5000)) {
		process.kill();

		m_wireGuardInstalled = false;

		m_wireGuardError = "WireGuard not installed";

		emit wireGuardInstalledChanged();

		return;
	}

	QString fullPath = QString::fromUtf8(process.readAllStandardOutput()).split('\n').value(0).trimmed();

	if (!fullPath.isEmpty()) {
		QFileInfo info(fullPath);

		QString folder = info.absolutePath();

		if (validateWireGuardFolder(folder)) {
			m_wireGuardPath = folder;

			m_wireGuardInstalled = true;

			settings.setValue("WireGuardPath", folder);

			emit wireGuardInstalledChanged();

			return;
		}
	}

	m_wireGuardInstalled = false;

	m_wireGuardError = "WireGuard not installed";

	emit wireGuardInstalledChanged();
}

void ServiceController::discoverProfiles()
{
	QList<VpnProfile> profiles;

	QProcess process;

	process.start(
		"powershell",
		{
			"-Command",
			"Get-Service *WireGuardTunnel* | Select-Object Name,DisplayName"
		});

	if (!process.waitForFinished(5000)) {
		process.kill();
		return;
	}

	QString output = QString::fromUtf8(process.readAllStandardOutput());

	const QStringList lines = output.split('\n');

	for (const QString &line : lines) {
		QString trimmed = line.trimmed();

		if (!trimmed.startsWith("WireGuardTunnel$")) { continue; }

		QStringList parts = trimmed.split(QRegularExpression("\\s+"), Qt::SkipEmptyParts);

		if (parts.size() < 2) { continue; }

		VpnProfile profile;

		profile.serviceName = parts[0];

		profile.displayName = parts.mid(1).join(' ');

		profile.displayName.remove("WireGuard Tunnel: ");

		// Get config path from service
		QProcess qc;
		qc.start(
			"sc",
			{
				"qc",
				profile.serviceName
			});

		if (qc.waitForFinished(3000)) {
			QString qcOutput = QString::fromUtf8(qc.readAllStandardOutput());

			QRegularExpression pathRegex(R"(/tunnelservice\s+([^\r\n]+\.conf))", QRegularExpression::CaseInsensitiveOption);

			QRegularExpressionMatch match = pathRegex.match(qcOutput);

			if (match.hasMatch()) {
				QString configPath = match.captured(1).trimmed();

				profile.configPath = configPath;

				QFile configFile(configPath);

				if (configFile.open(QIODevice::ReadOnly | QIODevice::Text)) {
					QTextStream stream(&configFile);

					while (!stream.atEnd()) {
						QString configLine = stream.readLine().trimmed();

						if (configLine.startsWith("Endpoint", Qt::CaseInsensitive)) {
							profile.configuredEndpoint = configLine.section('=', 1).trimmed();
							break;
						}
					}

					configFile.close();
				}
			}
		}

		profiles.append(profile);
	}

	m_profilesModel.setProfiles(profiles);
}

void ServiceController::disconnectAllProfiles()
{
	auto &profiles = m_profilesModel.profiles();

	for (int i = 0; i < profiles.size(); i++) {
		QProcess::startDetached(
			"sc",
			{
				"stop",
				profiles[i].serviceName
			});
	}
}

void ServiceController::startProfile(int row)
{
	auto &profiles = m_profilesModel.profiles();

	if (row < 0 || row >= profiles.size()) { return; }

	if (!m_allowMultipleConnections) {
		for (int i = 0; i < profiles.size(); i++) {
			if (i == row) { continue; }

			profiles[row].pendingStart = false;
			profiles[row].pendingStop = true;

			m_profilesModel.refreshRow(row);

			QProcess::startDetached(
				"sc",
				{
					"stop",
					profiles[i].serviceName
				});
		}
	}

	profiles[row].pendingStart = true;
	profiles[row].pendingStop = false;

	m_profilesModel.refreshRow(row);

	QProcess::startDetached(
		"sc",
		{
			"start",
			profiles[row].serviceName
		});
}

void ServiceController::stopProfile(int row)
{
	auto &profiles = m_profilesModel.profiles();

	if (row < 0 || row >= profiles.size()) { return; }

	profiles[row].pendingStop = true;
	profiles[row].pendingStart = false;

	m_profilesModel.refreshRow(row);

	QProcess::startDetached(
		"sc",
		{
			"stop",
			profiles[row].serviceName
		});
}

void ServiceController::refreshProfiles()
{
	discoverProfiles();
}

void ServiceController::updateProfiles()
{
	auto &profiles = m_profilesModel.profiles();

	bool wasAnyConnected = anyProfileConnected();

	// Query running services
	for (int row = 0; row < profiles.size(); row++) {
		VpnProfile &profile = profiles[row];

		QProcess service;

		service.start(
			"sc",
			{
				"query",
				profile.serviceName
			});

		if (!service.waitForFinished(3000)) {
			service.kill();
			continue;
		}

		QString serviceOutput = QString::fromUtf8(service.readAllStandardOutput());

		bool connected = serviceOutput.contains("RUNNING");

		if (connected != profile.connected) {
			profile.connected = connected;

			if (connected) {
				profile.pendingStart = false;
				profile.connectedSince = QDateTime::currentDateTime();
			}

			if (!connected) { profile.pendingStop = false; }
		}

		if (!connected) {
			profile.currentEndpoint.clear();

			profile.lastHandshakeSeconds = -1;

			profile.downloadSpeed = "0 KB/s";
			profile.uploadSpeed = "0 KB/s";

			profile.lastRxBytes = 0;
			profile.lastTxBytes = 0;

			m_profilesModel.refreshRow(row);

			continue;
		}
	}

	// Query WireGuard
	QProcess wg;
	wg.start(
		wireGuardExe(),
		{ "show" });

	if (!wg.waitForFinished(3000)) {
		wg.kill();
		return;
	}

	QString output = QString::fromUtf8(wg.readAllStandardOutput());

	QStringList interfaces = output.split("interface:");

	for (QString interfaceBlock : interfaces) {
		interfaceBlock = interfaceBlock.trimmed();

		if (interfaceBlock.isEmpty()) { continue; }

		QString interfaceName = interfaceBlock.section('\n', 0, 0).trimmed();

		for (int row = 0; row < profiles.size(); row++) {
			VpnProfile &profile = profiles[row];

			QString tunnelName = profile.serviceName;

			tunnelName.remove("WireGuardTunnel$");

			if (tunnelName != interfaceName) { continue; }

			const QStringList lines = interfaceBlock.split('\n');

			for (const QString &line : lines) {
				QString trimmed = line.trimmed();

				// endpoint
				if (trimmed.startsWith("endpoint:")) { profile.currentEndpoint = trimmed.section(':', 1) .trimmed(); }

				// handshake
				if (trimmed.startsWith("latest handshake:")) {
					QString handshakeText = trimmed.section(':', 1).trimmed();

					qint64 seconds = 0;

					QRegularExpression hoursRe(R"((\d+)\s+hour)");
					QRegularExpression minutesRe(R"((\d+)\s+minute)");
					QRegularExpression secondsRe(R"((\d+)\s+second)");

					auto h = hoursRe.match(handshakeText);

					auto m = minutesRe.match(handshakeText);

					auto s = secondsRe.match(handshakeText);

					if (h.hasMatch()) { seconds += h.captured(1).toLongLong() * 3600; }

					if (m.hasMatch()) {
						seconds += m.captured(1).toLongLong() * 60; }

					if (s.hasMatch()) { seconds += s.captured(1).toLongLong(); }

					profile.lastHandshakeSeconds = seconds;
				}

				// transfer
				if (trimmed.startsWith("transfer:")) {
					QStringList parts = trimmed.mid(QString("transfer:").length()).split(',');

					if (parts.size() >= 2) {
						quint64 rx = parseSize(parts[0]);
						quint64 tx = parseSize(parts[1]);

						if (profile.lastRxBytes) {
							profile.downloadSpeed = formatSpeed(rx - profile.lastRxBytes);
							profile.uploadSpeed = formatSpeed(tx - profile.lastTxBytes);
						}

						profile.lastRxBytes = rx;
						profile.lastTxBytes = tx;
					}
				}
			}

			m_profilesModel.refreshRow(row);
		}
	}

	bool nowAnyConnected = anyProfileConnected();

	if (wasAnyConnected != nowAnyConnected) { emit anyProfileConnectedChanged(); }
}

bool ServiceController::addProfile(const QVariantMap &config)
{
	QString profileName = config.value("ProfileName").toString().trimmed();

	if (profileName.isEmpty()) { return false; }

	QString configPath = config.value("ConfigPath").toString().trimmed();

	if (configPath.isEmpty()) { return false; }

	QFile file(configPath);

	if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) { return false; }

	QTextStream stream(&file);

	stream
		<< "[Interface]\n"
		<< "PrivateKey = "
		<< config.value("PrivateKey").toString()
		<< "\n"

		<< "Address = "
		<< config.value("Address").toString()
		<< "\n";

	if (!config.value("DNS").toString().isEmpty()) {
		stream
			<< "DNS = "
			<< config.value("DNS").toString()
			<< "\n";
	}

	if (!config.value("ListenPort").toString().isEmpty()) {
		stream
			<< "ListenPort = "
			<< config.value("ListenPort").toString()
			<< "\n";
	}

	stream
		<< "\n[Peer]\n"

		<< "PublicKey = "
		<< config.value("PublicKey").toString()
		<< "\n"

		<< "Endpoint = "
		<< config.value("Endpoint").toString()
		<< "\n"

		<< "AllowedIPs = "
		<< config.value("AllowedIPs").toString()
		<< "\n";

	if (!config.value("PresharedKey").toString().isEmpty()) {
		stream
			<< "PresharedKey = "
			<< config.value("PresharedKey").toString()
			<< "\n";
	}

	QString keepalive = config.value("PersistentKeepalive").toString();

	if (!keepalive.isEmpty() && keepalive != "0") {
		stream
			<< "PersistentKeepalive = "
			<< keepalive
			<< "\n";
	}

	file.close();

	QProcess install;

	install.start(
		m_wireGuardPath +
		"/wireguard.exe",
		{
			"/installtunnelservice",
			configPath
		});

	if (!install.waitForFinished(15000)) {
		install.kill();
		return false;
	}

	discoverProfiles();

	return true;
}


QVariantMap ServiceController::loadProfileConfig(int row)
{
	QVariantMap result;

	auto &profiles = m_profilesModel.profiles();

	if (row < 0 || row >= profiles.size()) { return result; }

	QFile file(profiles[row].configPath);

	if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) { return result; }

	QTextStream stream(&file);

	while (!stream.atEnd()) {
		QString line = stream.readLine().trimmed();

		int pos = line.indexOf('=');

		if (pos < 0) { continue; }

		QString key = line.left(pos).trimmed();

		QString value = line.mid(pos + 1).trimmed();

		result[key] = value;
	}

	return result;
}

static void setOrInsertInSection(QStringList &lines, const QString &section, const QString &key, const QString &value)
{
	bool inSection = false;

	for (QString &line : lines) {
		QString trimmed = line.trimmed();

		if (trimmed.compare("[" + section + "]", Qt::CaseInsensitive) == 0) {
			inSection = true;
			continue;
		}

		if (inSection && trimmed.startsWith('[')) { inSection = false; }

		if (!inSection) { continue; }

		if (trimmed.startsWith(key + " ", Qt::CaseInsensitive) || trimmed.startsWith(key + "=", Qt::CaseInsensitive)) {
			line = key + " = " + value;
			return;
		}
	}

	// Not found -> insert into section
	for (int i = 0; i < lines.size(); i++) {
		QString trimmed = lines[i].trimmed();

		if (trimmed.compare("[" + section + "]", Qt::CaseInsensitive) == 0) {
			int insertPos = i + 1;

			while (insertPos < lines.size()) {
				QString current = lines[insertPos].trimmed();

				if (current.startsWith('[')) { break; }

				insertPos++;
			}

			lines.insert(insertPos, key + " = " + value);

			return;
		}
	}
}
static void removeKey(QStringList &lines, const QString &key)
{
	for (int i = 0; i < lines.size(); i++) {
		QString trimmed = lines[i].trimmed();

		if (trimmed.startsWith(key + " ", Qt::CaseInsensitive) || trimmed.startsWith(key + "=", Qt::CaseInsensitive)) {
			lines.removeAt(i);
			return;
		}
	}
}
bool ServiceController::saveProfileConfig(int row, const QVariantMap &config)
{
	auto &profiles = m_profilesModel.profiles();

	if (row < 0 || row >= profiles.size()) { return false; }

	VpnProfile &profile = profiles[row];

	// Stop service
	QProcess stop;
	stop.start(
		"sc",
		{
			"stop",
			profile.serviceName
		});

	stop.waitForFinished(10000);

	// Read config
	QFile file(profile.configPath);

	if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) { return false; }

	QString content = QString::fromUtf8(file.readAll());

	file.close();

	// Backup
	QFile::remove(profile.configPath + ".bak");

	QFile::copy(profile.configPath, profile.configPath + ".bak");

	QStringList lines = content.split('\n');

	// Required Interface
	setOrInsertInSection(lines, "Interface", "PrivateKey", config.value("PrivateKey").toString());

	setOrInsertInSection(lines, "Interface", "Address", config.value( "Address").toString());

	// Optional Interface
	QString dns = config.value("DNS").toString();

	if (dns.isEmpty()) { removeKey(lines, "DNS"); }
	else { setOrInsertInSection(lines, "Interface", "DNS", dns); }

	QString listenPort = config.value("ListenPort").toString();

	if (listenPort.isEmpty()) { removeKey(lines, "ListenPort"); }
	else { setOrInsertInSection(lines, "Interface", "ListenPort", listenPort); }

	// Required Peer
	setOrInsertInSection(lines, "Peer", "PublicKey", config.value( "PublicKey").toString());

	setOrInsertInSection(lines, "Peer", "Endpoint", config.value("Endpoint").toString());

	setOrInsertInSection(lines, "Peer", "AllowedIPs", config.value("AllowedIPs").toString());

	// Optional Peer
	QString presharedKey = config.value("PresharedKey").toString();

	if (presharedKey.isEmpty()) { removeKey(lines, "PresharedKey"); }
	else { setOrInsertInSection(lines, "Peer", "PresharedKey", presharedKey); }

	QString keepalive = config.value("PersistentKeepalive").toString();

	if (keepalive.isEmpty() || keepalive == "0") { removeKey(lines, "PersistentKeepalive"); }
	else { setOrInsertInSection(lines, "Peer", "PersistentKeepalive", keepalive); }

	// Save file
	if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) { return false; }

	QTextStream stream(&file);

	stream << lines.join('\n');

	file.close();

	// Uninstall service
	QProcess uninstall;
	uninstall.start(
		m_wireGuardPath +
		"/wireguard.exe",
		{
			"/uninstalltunnelservice",
			profile.configPath
		});

	if (!uninstall.waitForFinished(15000)) {
		uninstall.kill();
		return false;
	}

	// Install service
	QProcess install;
	install.start(
		m_wireGuardPath +
		"/wireguard.exe",
		{
			"/installtunnelservice",
			profile.configPath
		});

	if (!install.waitForFinished(15000)) {
		install.kill();
		return false;
	}

	// Refresh UI
	discoverProfiles();

	return true;
}

bool ServiceController::deleteProfile(int row, bool deleteConfigFile)
{
	auto &profiles = m_profilesModel.profiles();

	if (row < 0 || row >= profiles.size()) { return false; }

	const VpnProfile &profile = profiles[row];

	// Stop service if running
	QProcess stop;
	stop.start(
		"sc",
		{
			"stop",
			profile.serviceName
		});

	stop.waitForFinished(5000);

	// Uninstall tunnel service
	QProcess uninstall;
	uninstall.start(
		m_wireGuardPath + "/wireguard.exe",
		{
			"/uninstalltunnelservice",
			profile.configPath
		});

	if (!uninstall.waitForFinished(10000)) {
		uninstall.kill();
		return false;
	}

	// optionally delete conf file
	if (deleteConfigFile) { QFile::remove(profile.configPath); }

	// refresh model
	discoverProfiles();

	return true;
}