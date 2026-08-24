#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QWindow>

#include "TrayManager.h"
#include "ServiceController.h"


int main(int argc,char *argv[])
{
	QApplication app(argc,argv);

    QQmlApplicationEngine engine;

	auto trayManager = new TrayManager(&app);						engine.rootContext()->setContextProperty("trayManager", trayManager);
	
	auto serviceController = new ServiceController(&app);			engine.rootContext()->setContextProperty("serviceController", serviceController);

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
	bool startMinimized = app.arguments().contains("-minimized", Qt::CaseInsensitive);

	QObject::connect(trayManager, &TrayManager::restoreRequested, &app, [&window, &trayManager, &startMinimized](){
		trayManager->hideTray();
		if (startMinimized) { trayManager->showTray(); }
		else { window->show(); }
        window->raise();
        window->requestActivate();
    });
	
	QObject::connect(trayManager, &TrayManager::exitRequested, &app, [&app](){
        app.quit();
    });

	return app.exec();
}