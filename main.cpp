#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "ServiceController.h"
#include "VpnProfilesModel.h"


int main(int argc,char *argv[])
{
    QGuiApplication app(argc,argv);

    QQmlApplicationEngine engine;

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

	return app.exec();
}