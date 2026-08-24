#include "TrayManager.h"

#include <QAction>
#include <QWindow>
#include <QStyle>
#include <QApplication>


TrayManager::TrayManager(QObject *parent) : QObject(parent)
{
    m_tray.setIcon(QIcon(":/wireGuardClient/resources/app.ico"));
    m_tray.setToolTip("WireGuard Client");

    QAction *restoreAction = m_menu.addAction(QApplication::style()->standardIcon(QStyle::SP_TitleBarNormalButton), "Restore");                 restoreAction->setEnabled(true);
    QAction *moveAction = m_menu.addAction("Move");                                                                                             moveAction->setEnabled(false);
    QAction *sizeAction = m_menu.addAction("Size");                                                                                             sizeAction->setEnabled(false);
    QAction *maximalizeAction = m_menu.addAction(QApplication::style()->standardIcon(QStyle::SP_TitleBarMinButton), "Minimalize");              maximalizeAction->setEnabled(false);
    QAction *minimalizeAction = m_menu.addAction(QApplication::style()->standardIcon(QStyle::SP_TitleBarMaxButton), "Maximalize");              minimalizeAction->setEnabled(false);
    m_menu.addSeparator();
    QAction *exitAction = m_menu.addAction(QApplication::style()->standardIcon(QStyle::SP_TitleBarCloseButton), "Exit");                        exitAction->setEnabled(true);

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