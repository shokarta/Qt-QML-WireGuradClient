#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QWindow>
#include <QDebug>

#include "TrayManager.h"
#include "ServiceController.h"


int main(int argc,char *argv[])
{
	QApplication app(argc,argv);

    QQmlApplicationEngine engine;

	// VPN(s) Controller
	auto serviceController = new ServiceController(&app);			engine.rootContext()->setContextProperty("serviceController", serviceController);

	// Minimize to Tray
	auto trayManager = new TrayManager(&app);						engine.rootContext()->setContextProperty("trayManager", trayManager);
	bool startMinimized = app.arguments().contains("-minimized", Qt::CaseInsensitive);
	engine.rootContext()->setContextProperty("startMinimized", startMinimized);


	const QUrl url("qrc:/wireGuardClient/Main.qml");
	QObject::connect(
		&engine,
		&QQmlApplicationEngine::objectCreationFailed,
		&app,
		[]() { QCoreApplication::exit(-1); },
		Qt::QueuedConnection);
	//engine.loadFromModule("wireGuardClient", "Main");
	engine.load(url);
	

	if (engine.rootObjects().isEmpty()) { return -1; }
	auto *window = qobject_cast<QWindow*>(engine.rootObjects().constFirst());
	if (startMinimized) {
		trayManager->showTray();
		window->hide();
	}


	QObject::connect(trayManager, &TrayManager::restoreRequested, &app, [&window, &trayManager, &startMinimized](){
		trayManager->hideTray();
		window->showNormal();
        window->raise();
        window->requestActivate();
    });
	
	QObject::connect(trayManager, &TrayManager::exitRequested, &app, [&app](){
        app.quit();
    });

	return app.exec();
}