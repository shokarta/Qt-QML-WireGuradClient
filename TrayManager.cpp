#include "TrayManager.h"

#include <QAction>
#include <QWindow>


TrayManager::TrayManager(QObject *parent) : QObject(parent)
{
    //m_tray.setIcon(QIcon(":/resources/app.ico"));
    m_tray.setIcon(QIcon(":/wireGuardClient/resources/app.ico"));

    QAction *restoreAction = m_menu.addAction("Restore");
    QAction *exitAction = m_menu.addAction("Exit");

    connect(restoreAction, &QAction::triggered, this, &TrayManager::restoreRequested);
    connect(exitAction, &QAction::triggered, this, &TrayManager::exitRequested);

    m_tray.setContextMenu(&m_menu);

    connect(&m_tray, &QSystemTrayIcon::activated, this, [this](QSystemTrayIcon::ActivationReason reason) {
        if (reason == QSystemTrayIcon::Trigger) { emit restoreRequested(); }
    });

    m_tray.hide();
}

void TrayManager::showTray()
{
    m_tray.show();
}

void TrayManager::hideTray()
{
    m_tray.hide();
}

void TrayManager::showMessage(QSystemTrayIcon::MessageIcon icon, const QString &text)
{
    if (!m_tray.isVisible()) { return; }

    m_tray.showMessage("WireGuard Client", text, icon, 3000);
}