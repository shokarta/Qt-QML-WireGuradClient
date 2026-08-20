#include "ServiceController.h"


// CONSTRUCTOR
ServiceController::ServiceController(QObject *parent) : QObject(parent)
{
	QSettings settings;

	m_allowMultipleConnections = settings.value("AllowMultipleConnections",false).toBool();
	m_askDisconnectOnExit = settings.value("AskDisconnectOnExit", true).toBool();

	detectWireGuard();
	discoverProfiles();

	connect(&m_updateTimer, &QTimer::timeout, this, &ServiceController::updateProfiles);

	m_updateTimer.start(1000);

	updateNetworkState();
}


// UTILITY HELPERS
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


// SETTERS
void ServiceController::setAllowMultipleConnections(bool value)
{
	if (m_allowMultipleConnections == value) { return; }

	m_allowMultipleConnections = value;

	QSettings settings;
		settings.setValue("AllowMultipleConnections", value);

	emit allowMultipleConnectionsChanged();
}
void ServiceController::setAskDisconnectOnExit(bool value)
{
	if (m_askDisconnectOnExit == value) { return; }

	m_askDisconnectOnExit = value;

	QSettings settings;

	settings.setValue("AskDisconnectOnExit", value);

	emit askDisconnectOnExitChanged();
}


// PROFILE ADD
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


// PROFILE EDIT
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
bool ServiceController::saveProfileConfig(int row, const QVariantMap &config)
{
	auto &profiles = m_profilesModel.profiles();

	if (row < 0 || row >= profiles.size()) { return false; }

	if (m_saveProfileWatcher.isRunning()) { return false; }

	VpnProfile &profile = profiles[row];

	QString configPath = profile.configPath;

	QString wireGuardPath = m_wireGuardPath;

	QString serviceName = profile.serviceName;


	QFuture<SaveProfileResult> future = QtConcurrent::run([this, configPath, wireGuardPath, serviceName, config]() {
		return saveProfileConfigWorker(configPath, wireGuardPath, serviceName, config);
	});


	connect(&m_saveProfileWatcher, &QFutureWatcher<SaveProfileResult>::finished, this, [this, row]() {
			SaveProfileResult result = m_saveProfileWatcher.result();
			applySaveProfileResult(row, result);
		},
		Qt::SingleShotConnection);

	m_saveProfileWatcher.setFuture(future);

	return true;
}


// PROFILE DELETE
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


// PROFILE DISCOVERY
void ServiceController::refreshProfiles()
{
	discoverProfiles();
}


// PROFILE CONNECTION CONTROL
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


// WIREGUARD CONFIGURATION
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


// UTILITY HELPERS
int ServiceController::pingHost(const QString &host)
{
	QProcess ping;
	ping.start(
		"ping",
		{
			"-n",
			"1",
			host
		});

	if (!ping.waitForFinished(3000)) {
		ping.kill();
		ping.waitForFinished();
		return -1;
	}

	QString output = QString::fromUtf8(ping.readAllStandardOutput());

	QRegularExpression re(R"((\d+)\s*ms)", QRegularExpression::CaseInsensitiveOption);
	auto match = re.match(output);
	if (!match.hasMatch()) { return -1; }

	return match.captured(1).toInt();
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


// WIREGUARD DETECTION
bool ServiceController::validateWireGuardFolder(const QString &path)
{
	QFileInfo wg(path + "/wg.exe");
	QFileInfo wireguard(path + "/wireguard.exe");

	return wg.exists() && wireguard.exists();
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


// PROFILE DISCOVERY
void ServiceController::discoverProfiles()
{
	// Do not start another discovery while one is already running.
	if (m_discoverWatcher.isRunning()) { return; }

	QFuture<QList<VpnProfile>> future = QtConcurrent::run([this]() { return discoverProfilesWorker(); });

	connect(&m_discoverWatcher, &QFutureWatcher<QList<VpnProfile>>::finished, this, [this]() {
		QList<VpnProfile> profiles = m_discoverWatcher.result();
		m_profilesModel.setProfiles(profiles);
	},
	Qt::SingleShotConnection);

	m_discoverWatcher.setFuture(future);
}
QList<VpnProfile> ServiceController::discoverProfilesWorker()
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
		return profiles;
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

	return profiles;
}


// RUNTIME MONITORING
void ServiceController::updateProfiles()
{
	if (m_runtimeWatcher.isRunning()) { return; }

	// NETWORK MONITORING
	static int networkCounter = 0;
	if (++networkCounter >= 5) {		// every 5 seconds run network state update
		networkCounter = 0;
		updateNetworkState();
	}


	QStringList serviceNames;
	const auto &profiles = m_profilesModel.profiles();
	for (const VpnProfile &profile : profiles) { serviceNames.append(profile.serviceName); }

	QString wireGuardExePath = wireGuardExe();
	QFuture<QList<ProfileRuntimeData>> future = QtConcurrent::run([serviceNames, wireGuardExePath]() {
		return collectRuntimeDataWorker(serviceNames, wireGuardExePath);
	});

	connect(&m_runtimeWatcher, &QFutureWatcher<QList<ProfileRuntimeData>>::finished, this, [this]() {
			QList<ProfileRuntimeData> runtimeData = m_runtimeWatcher.result();
			applyRuntimeData(runtimeData);
		},
		Qt::SingleShotConnection);

	m_runtimeWatcher.setFuture(future);
}
QList<ProfileRuntimeData>ServiceController::collectRuntimeDataWorker(const QStringList &serviceNames, const QString &wireGuardExe)
{
	QList<ProfileRuntimeData> result;

	// 1. Query service state
	for (const QString &serviceName : serviceNames) {
		ProfileRuntimeData data;
			data.serviceName = serviceName;

		QProcess service;
		service.start(
			"sc",
			{
				"query",
				serviceName
			});

		if (!service.waitForFinished(3000)) {
			service.kill();
			result.append(data);
			continue;
		}

		QString serviceOutput = QString::fromUtf8(service.readAllStandardOutput());

		data.connected = serviceOutput.contains("RUNNING");

		result.append(data);
	}


	// 2. If no profile is connected, we're done
	bool anyConnected = false;
	for (const auto &data : result) {
		if (data.connected) {
			anyConnected = true;
			break;
		}
	}

	if (!anyConnected) { return result; }


	// 3. Query WireGuard
	QProcess wg;
	wg.start(
		wireGuardExe,
		{
			"show"
		});

	if (!wg.waitForFinished(3000)) {
		wg.kill();
		return result;
	}

	QString output = QString::fromUtf8(wg.readAllStandardOutput());
	QStringList interfaces = output.split("interface:");


	// 4. Parse interfaces
	for (QString interfaceBlock : interfaces) {
		interfaceBlock = interfaceBlock.trimmed();

		if (interfaceBlock.isEmpty()) { continue; }

		QString interfaceName = interfaceBlock.section('\n', 0, 0).trimmed();

		// Find matching result
		ProfileRuntimeData *data = nullptr;
		for (auto &item : result) {
			QString tunnelName = item.serviceName;
			tunnelName.remove("WireGuardTunnel$");

			if (tunnelName == interfaceName) {
				data = &item;
				break;
			}
		}

		if (!data || !data->connected) { continue; }


		// Parse WireGuard information
		const QStringList lines = interfaceBlock.split('\n');

		QString handshakeText;

		QString transferText;

		for (const QString &line : lines) {
			QString trimmed = line.trimmed();

			// endpoint
			if (trimmed.startsWith("endpoint:")) { data->currentEndpoint = trimmed.section(':', 1).trimmed(); }

			// handshake
			if (trimmed.startsWith("latest handshake:")) { handshakeText = trimmed.section(':', 1).trimmed(); }

			// transfer
			if (trimmed.startsWith("transfer:")) { transferText = trimmed.mid(QString("transfer:").length()).trimmed();}
		}

		// Parse handshake
		if (!handshakeText.isEmpty()) {
			qint64 seconds = 0;

			QRegularExpression hoursRe(R"((\d+)\s+hour)");
			QRegularExpression minutesRe(R"((\d+)\s+minute)");
			QRegularExpression secondsRe(R"((\d+)\s+second)");

			auto h = hoursRe.match(handshakeText);
			auto m = minutesRe.match(handshakeText);
			auto s = secondsRe.match(handshakeText);


			if (h.hasMatch()) { seconds += h.captured(1).toLongLong() * 3600; }
			if (m.hasMatch()) { seconds += m.captured(1).toLongLong() * 60; }
			if (s.hasMatch()) { seconds += s.captured(1).toLongLong(); }

			data->lastHandshakeSeconds = seconds;
		}

		// Parse transfer
		if (!transferText.isEmpty()) {

			QStringList parts = transferText.split(',');

			if (parts.size() >= 2) {
				data->rx = ServiceController::parseSize(parts[0]);
				data->tx = ServiceController::parseSize(parts[1]);
			}
		}

		// Ping
		if (!data->currentEndpoint.isEmpty()) {
			QString host = data->currentEndpoint.section(':', 0, 0).trimmed();
			if (!host.isEmpty()) { data->currentPingMs = ServiceController::pingHost(host); }
		}
	}

	return result;
}
void ServiceController::applyRuntimeData(const QList<ProfileRuntimeData> &runtimeData)
{
	auto &profiles = m_profilesModel.profiles();

	bool wasAnyConnected = anyProfileConnected();

	for (int row = 0; row < profiles.size(); row++) {
		VpnProfile &profile = profiles[row];

		// Find corresponding runtime data
		const ProfileRuntimeData *data = nullptr;

		for (const auto &item : runtimeData) {
			if (item.serviceName == profile.serviceName) {
				data = &item;
				break;
			}
		}

		if (!data) { continue; }

		// Connection state
		if (data->connected != profile.connected) {
			profile.connected = data->connected;

			if (data->connected) {
				profile.pendingStart = false;
				profile.connectedSince = QDateTime::currentDateTime();
			}
			else {
				profile.pendingStop = false;
				profile.currentEndpoint.clear();

				profile.lastHandshakeSeconds = -1;

				profile.downloadSpeed = "0 KB/s";
				profile.uploadSpeed = "0 KB/s";

				profile.lastRxBytes = 0;
				profile.lastTxBytes = 0;
			}
		}

		if (!data->connected) {
			m_profilesModel.refreshRow(row);
			continue;
		}

		// Endpoint
		profile.currentEndpoint = data->currentEndpoint;

		// Ping
		profile.currentPingMs = data->currentPingMs;

		if (data->currentPingMs >= 0) {
			if (!profile.lastHistoryPingUpdate.isValid() || profile.lastHistoryPingUpdate.secsTo(QDateTime::currentDateTime()) >= 5 ) {
				profile.pingHistory.append(data->currentPingMs);

				while (profile.pingHistory.size() > 30 ) { profile.pingHistory.removeFirst(); }

				profile.lastHistoryPingUpdate = QDateTime::currentDateTime();
			}
		}

		// Handshake
		profile.lastHandshakeSeconds = data->lastHandshakeSeconds;

		// Transfer
		if (profile.lastRxBytes) {
			if (data->rx >= profile.lastRxBytes) { profile.downloadSpeed = formatSpeed(data->rx - profile.lastRxBytes); }
			if (data->tx >= profile.lastTxBytes) { profile.uploadSpeed = formatSpeed(data->tx - profile.lastTxBytes); }
		}

		profile.lastRxBytes = data->rx;
		profile.lastTxBytes = data->tx;

		// Notify QML
		m_profilesModel.refreshRow(row);
	}

	bool nowAnyConnected = anyProfileConnected();

	if (wasAnyConnected != nowAnyConnected) { emit anyProfileConnectedChanged(); }
}


// PROFILE SAVE
SaveProfileResult ServiceController::saveProfileConfigWorker(QString configPath, QString wireGuardPath, QString serviceName, QVariantMap config)
{
	SaveProfileResult result;

	// Stop service
	QProcess stop;
	stop.start(
		"sc",
		{
			"stop",
			serviceName
		});

	if (!stop.waitForFinished(10000)) {
		stop.kill();
		stop.waitForFinished();

		result.error = "Failed to stop WireGuard service";
		return result;
	}

	// Read config
	QFile file(configPath);
	if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
		result.error = "Failed to open configuration file";
		return result;
	}

	QString content = QString::fromUtf8(file.readAll());
	file.close();


	// Backup
	QFile::remove(configPath + ".bak");
	QFile::copy(configPath, configPath + ".bak");

	QStringList lines = content.split('\n');

	// Interface
	setOrInsertInSection(lines, "Interface", "PrivateKey", config.value("PrivateKey").toString());
	setOrInsertInSection(lines, "Interface", "Address", config.value("Address").toString());

	QString dns = config.value("DNS").toString();
		if (dns.isEmpty()) { removeKey(lines, "DNS"); }
		else { setOrInsertInSection(lines, "Interface", "DNS", dns); }

	QString listenPort = config.value("ListenPort").toString();
		if (listenPort.isEmpty()) { removeKey(lines, "ListenPort"); }
		else { setOrInsertInSection(lines, "Interface", "ListenPort", listenPort); }

	// Peer
	setOrInsertInSection(lines, "Peer", "PublicKey", config.value("PublicKey").toString());
	setOrInsertInSection(lines, "Peer", "Endpoint", config.value("Endpoint").toString());
	setOrInsertInSection(lines, "Peer", "AllowedIPs", config.value("AllowedIPs").toString());

	QString presharedKey = config.value("PresharedKey").toString();
		if (presharedKey.isEmpty()) { removeKey(lines, "PresharedKey"); }
		else { setOrInsertInSection(lines, "Peer", "PresharedKey", presharedKey); }

	QString keepalive = config.value("PersistentKeepalive").toString();
		if (keepalive.isEmpty() || keepalive == "0") { removeKey(lines, "PersistentKeepalive"); }
		else { setOrInsertInSection(lines, "Peer", "PersistentKeepalive", keepalive); }

	// Save config
	if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
		result.error = "Failed to write configuration file";
		return result;
	}

	QTextStream stream(&file);
		stream << lines.join('\n');
	file.close();

	// Uninstall service
	QProcess uninstall;
	uninstall.start(
		wireGuardPath +
		"/wireguard.exe",
		{
			"/uninstalltunnelservice",
			configPath
		});

	if (!uninstall.waitForFinished(15000)) {
		uninstall.kill();
		uninstall.waitForFinished();

		result.error = "Failed to uninstall WireGuard service";
		return result;
	}

	// Install service
	QProcess install;
	install.start(
		wireGuardPath +
		"/wireguard.exe",
		{
			"/installtunnelservice",
			configPath
		});

	if (!install.waitForFinished(15000)) {
		install.kill();
		install.waitForFinished();

		result.error = "Failed to install WireGuard service";
		return result;
	}

	result.success = true;
	return result;
}
void ServiceController::applySaveProfileResult(int row, const SaveProfileResult &result)
{
	if (!result.success) {
		qWarning() << "Failed to save profile:" << result.error;
		return;
	}

	discoverProfiles();
}

// NETWORK MONITORING
void ServiceController::updateNetworkState()
{
	if (m_networkWatcher.isRunning()) { return; }

	QFuture<NetworkStateData> future = QtConcurrent::run([]() {
		return collectNetworkStateWorker();
	});

	connect(&m_networkWatcher, &QFutureWatcher<NetworkStateData>::finished, this, [this]() {
			applyNetworkState(m_networkWatcher.result());
		},
		Qt::SingleShotConnection);

	m_networkWatcher.setFuture(future);
}
NetworkStateData ServiceController::collectNetworkStateWorker()
{
	NetworkStateData result;

	// LAN
	QProcess lan;
	lan.start(
		"powershell",
		{
			"-Command",
			"Get-NetAdapter "
			"| Where-Object {$_.Status -eq 'Up'} "
			"| Select-Object Name,InterfaceDescription"
		});

	if (!lan.waitForFinished(3000)) {
		lan.kill();
		lan.waitForFinished();
	}
	else {
		QString output = QString::fromUtf8(lan.readAllStandardOutput());
		result.lanConnected = output.contains("Ethernet", Qt::CaseInsensitive);
	}

	// WIFI
	QProcess wifi;
	wifi.start(
		"netsh",
		{
			"wlan",
			"show",
			"interfaces"
		});

	if (!wifi.waitForFinished(3000)) {
		wifi.kill();
		wifi.waitForFinished();
	}
	else {
		QString output = QString::fromUtf8(wifi.readAllStandardOutput());

		if (output.contains("connected", Qt::CaseInsensitive)) {
			QRegularExpression ssidRe(R"(SSID\s*:\s*(.+))");
			QRegularExpression radioRe(R"(Radio type\s*:\s*(.+))");

			auto ssidMatch = ssidRe.match(output);
			auto radioMatch = radioRe.match(output);

			QString ssid;
			QString radio;

			if (ssidMatch.hasMatch()) { ssid = ssidMatch.captured(1).trimmed(); }

			if (radioMatch.hasMatch()) { radio = radioMatch.captured(1).trimmed(); }

			if (!ssid.isEmpty()) {
				if (radio.contains("802.11a", Qt::CaseInsensitive) || radio.contains("802.11ac", Qt::CaseInsensitive) || radio.contains("802.11ax", Qt::CaseInsensitive)) { result.wifi5Ssid = ssid; }
				else { result.wifi24Ssid = ssid; }
			}
		}
	}

	return result;
}
void ServiceController::applyNetworkState(const NetworkStateData &state)
{
	bool changed = state.lanConnected != m_lanConnected || state.wifi24Ssid != m_wifi24Ssid || state.wifi5Ssid != m_wifi5Ssid;

	m_lanConnected = state.lanConnected;

	m_wifi24Ssid = state.wifi24Ssid;
	m_wifi5Ssid = state.wifi5Ssid;

	if (changed) { emit networkStateChanged(); }
}