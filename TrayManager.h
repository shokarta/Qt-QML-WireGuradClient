#pragma once

#include <QObject>
#include <QSystemTrayIcon>
#include <QMenu>


class TrayManager : public QObject
{
    Q_OBJECT


public:

    explicit TrayManager(QObject *parent = nullptr);
	
    Q_INVOKABLE void showTray();
    Q_INVOKABLE void hideTray();

    Q_INVOKABLE void showMessage(QSystemTrayIcon::MessageIcon icon, const QString &text);


signals:

    void restoreRequested();
    void exitRequested();


private:

    QSystemTrayIcon m_tray;
    QMenu m_menu;
};