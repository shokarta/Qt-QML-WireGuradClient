import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Effects
import QtQuick.Layouts
import QtGraphs


ApplicationWindow {
    id: root
    width: 400
    height: 700
    visible: true
    title: "WireGuard Client"
    color: bgColor

    property color bgColor: "#F5F7FA"
    property color cardColor: "#FFFFFF"
    property color cardColorConnected: "#EEFFF0"
    property color primaryColor: "#2563EB"
    property color successColor: "#22C55E"
    property color textColor: "#111827"
    property color secondaryText: "#6B7280"
    property color borderColor: "#E5E7EB"
    property color popupColor: "#F5F7F9"
    property color buttonColor: "#E8EAF3"

    font.family: "Inter"

    property color downloadColor: "#00AA00"
    property color uploadColor: "#4A86FF"

    property bool reallyClosing: false
    onClosing: function(close) {
        if (reallyClosing) { return; }
        if (!serviceController.askDisconnectOnExit) { return; }
        if (!serviceController.anyProfileConnected) { return; }

        close.accepted = false;
        exitDialog.open();
    }

    property bool minimizeToTray: true
    onVisibilityChanged: function() {
        if (!root.minimizeToTray) { return; }

        if (visibility === Window.Minimized) {
            trayManager.showTray();
            root.hide();
            //root.visibility = Window.Hidden;
            trayManager.showMessage(1, "Application has been minimized to tray.");
        }
    }


    FolderDialog {
        id: wireGuardFolderDialog
        title: "Select WireGuard folder"
        onAccepted: {
            let folder = selectedFolder.toString().replace("file:///", "").replace(/\//g, "\\");
            serviceController.setWireGuardFolder(folder);
        }
    }


    ColumnLayout {
        id: mainContent
        anchors.top: parent.top;            anchors.topMargin: 15
        anchors.left: parent.left;          anchors.leftMargin: 15
        anchors.right: parent.right;        anchors.rightMargin: 15
        spacing: 15

        Text {
            font.weight: Font.DemiBold
            font.pixelSize: 18
            text: "WIREGUARD PROFILES"
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: errorLayout.height * 1.5
            border.width: 2
            border.color: "darkred"
            radius: height / 5
            color: "#FF9C9C"
            visible: !serviceController.wireGuardInstalled

            RowLayout {
                id: errorLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: 15
                spacing: 0

                Text {
                    font.bold: false
                    font.pixelSize: 18
                    text: serviceController.wireGuardError
                    color: "darkred"
                }

                Item { Layout.fillWidth: true }        // Extra Space

                Text {
                    font.weight: Font.DemiBold
                    font.pixelSize: 18
                    //color: root.duarationColor
                    text: "📁"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: wireGuardFolderDialog.open()
                    }
                }
            }
        }


        Repeater {
            model: serviceController.profilesModel

            delegate: Item {
                Layout.fillWidth: true
                Layout.preferredHeight: delegateLayout.height

                // SHADOW
                MultiEffect {
                    source: card
                    anchors.fill: card
                    shadowEnabled: true
                    shadowColor: "black"
                    shadowOpacity: 0.3
                    shadowBlur: 1.0
                    shadowVerticalOffset: 3
                }

                Rectangle {
                    id: card
                    anchors.fill: parent
                    color: connected ? root.cardColorConnected : root.cardColor
                    radius: 12
                    border.color: root.borderColor
                    border.width: 1
                }

                ColumnLayout {
                    id: delegateLayout
                    anchors.top: parent.top;            anchors.topMargin: 15
                    anchors.left: parent.left;          anchors.leftMargin: 15
                    anchors.right: parent.right;        anchors.rightMargin: 15
                    spacing: 15

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Item {
                            Layout.fillHeight: true
                            Layout.preferredWidth: switchIndicator.width

                            Switch {
                                id: switchIndicator
                                anchors.centerIn: parent
                                width: height * 1.75
                                height: parent.height / 1.5
                                checked: serviceController.wireGuardInstalled
                                checkable: false
                                opacity: connectingIndicator.visible ? 0.05 : 1
                                property bool active: serviceController.wireGuardInstalled

                                indicator: Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: if (!switchIndicator.active) { return root.secondaryText; }
                                           else if (connected || pendingStart) { return root.primaryColor; }
                                           else { return root.secondaryText; }

                                    Rectangle {
                                        height: parent.height
                                        width: height
                                        radius: height / 2
                                        x: connected || pendingStart ? parent.width - width : 0
                                        color: "white"
                                        border.width: height / 15
                                        border.color: parent.color
                                    }
                                }
                            }
                            BusyIndicator {
                                id: connectingIndicator
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.height
                                running: visible
                                visible: pendingStart || pendingStop
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: if (!switchIndicator.active) { return false; }
                                         else if (connectingIndicator.visible) { return false; }
                                         else { return true; }
                                onClicked: {
                                    if (connected) { serviceController.stopProfile(index); }
                                    else { serviceController.startProfile(index); }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 4

                            Text {
                                font.weight: Font.DemiBold
                                font.pixelSize: 14
                                color: root.textColor
                                text: name
                            }
                            Text {
                                color: root.secondaryText
                                text: currentEndpoint.length > 0 ? currentEndpoint : configuredEndpoint
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Image {
                            //height: parent.height * 0.6
                            Layout.preferredHeight: parent.height * 0.6
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectFit
                            source: "resources/images/i_modify.svg"
                            visible: !connected

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    profileEditorDialog.loadProfile(index);
                                    profileEditorDialog.open()
                                }
                            }
                        }

                        RowLayout {
                            spacing: 10
                            visible: connected

                            Text {
                                id: pingData
                                Layout.alignment: Qt.AlignBottom
                                color: pingGraph.getColor(ping)
                                text: ping >= 0 ? (ping + " ms") : "-- ms"
                                visible: connected
                            }
                            Row {
                                id: pingGraph
                                Layout.preferredHeight: barWidth * maxHeightMultiplier
                                Layout.alignment: Qt.AlignBottom
                                spacing: 1
                                visible: connected
                                property int maxLength: 8
                                property int maxPing: 200
                                property real barWidth: 8
                                property real maxHeightMultiplier: 3

                                function getColor(value) {
                                    if (value === null) { return "transparent"; }

                                    value = Math.min(Math.max(value, 0), pingGraph.maxPing);

                                    let t = value / pingGraph.maxPing;
                                    let r, g, b;

                                    if (t < 0.5) {      // green -> yellow
                                        let x = t * 2;
                                            r = Math.round(0 + (255 - 0) * x);
                                            g = Math.round(192 + (192 - 192) * x);
                                            b = Math.round(0 + (0 - 0) * x);
                                    }
                                    else {              // yellow -> red
                                        let x = (t - 0.5) * 2;
                                            r = Math.round(255 + (208 - 255) * x);
                                            g = Math.round(192 + (0 - 192) * x);
                                            b = 0;
                                    }

                                    return Qt.rgba(r/255, g/255, b/255, 1);
                                }

                                Repeater {
                                    model: {
                                        let values = pingHistory.slice(Math.max(0, pingHistory.length - pingGraph.maxLength));
                                        while (values.length < pingGraph.maxLength) { values.unshift(null); }
                                        return values;
                                    }
                                    delegate: Rectangle {
                                        required property var modelData
                                        anchors.bottom: parent.bottom
                                        width: pingGraph.barWidth
                                        height: modelData === null ? 1 : (width * pingGraph.maxHeightMultiplier * Math.min(modelData, pingGraph.maxPing) / pingGraph.maxPing);
                                        color: pingGraph.getColor(modelData)
                                    }
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true; Layout.preferredHeight: 1; visible: !connected }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: root.borderColor
                        visible: connected
                    }

                    Row {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 0
                        visible: connected

                        Item {
                            width: parent.width/4
                            height: parent.height

                            RowLayout {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3

                                Image {
                                    Layout.preferredHeight: textDownload.height
                                    sourceSize.height: height
                                    fillMode: Image.PreserveAspectFit
                                    source: "resources/images/i_arrowDown.svg"
                                }
                                Text {
                                    id: textDownload
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 12
                                    color: root.textColor
                                    text: downloadSpeed
                                }
                            }
                        }

                        Item {
                            width: parent.width/4
                            height: parent.height

                            RowLayout {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 3

                                Image {
                                    Layout.preferredHeight: textUpload.height
                                    sourceSize.height: height
                                    fillMode: Image.PreserveAspectFit
                                    source: "resources/images/i_arrowUp.svg"
                                }
                                Text {
                                    id: textUpload
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 12
                                    color: root.textColor
                                    text: uploadSpeed
                                }
                            }
                        }

                        Item {
                            width: parent.width/4
                            height: parent.height

                            RowLayout {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 5

                                Image {
                                    Layout.preferredHeight: textDuration.height
                                    sourceSize.height: height
                                    fillMode: Image.PreserveAspectFit
                                    source: "resources/images/i_clock.svg"
                                }
                                Text {
                                    id: textDuration
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 12
                                    color: root.textColor
                                    text: duration
                                }
                            }
                        }

                        Item {
                            width: parent.width/4
                            height: parent.height

                            RowLayout {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 5

                                Image {
                                    Layout.preferredHeight: textHandshake.height
                                    sourceSize.height: height
                                    fillMode: Image.PreserveAspectFit
                                    source: "resources/images/i_shield.svg"
                                }
                                Text {
                                    id: textHandshake
                                    horizontalAlignment: Text.AlignHCenter
                                    font.pixelSize: 12
                                    color: root.textColor
                                    text: lastHandshake
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true; Layout.preferredHeight: 1 }
                }
            }
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: addProfileText.height + 25
            Layout.preferredWidth: addProfileText.width + 40
            color: root.primaryColor
            radius: height / 5

            Text {
                id: addProfileText
                anchors.centerIn: parent
                font.pixelSize: 16
                font.weight: Font.DemiBold
                color: "white"
                text: "+ Add New Profile"
            }
            MouseArea {
                anchors.fill: parent
                onClicked: addProfileDialog.open()
            }
        }
    }




    // NETWORK STATE
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 80

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: root.borderColor
        }
        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left;          anchors.leftMargin: parent.width * 0.4
            width: 1
            color: root.borderColor
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Item {
                Layout.preferredWidth: parent.width * 0.4
                Layout.fillHeight: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Image {
                        Layout.preferredHeight: parent.height * 0.6
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        source: "resources/images/i_lan.svg"
                    }

                    ColumnLayout {
                        Layout.fillHeight: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: root.textColor
                            text: "LAN"
                        }
                        Text {
                            Layout.fillWidth: true
                            font.pixelSize: 12
                            font.bold: false
                            color: root.secondaryText
                            text: serviceController.lanConnected ? "Connected" : "Disconnected"
                        }
                    }
                }
            }

            Item {
                Layout.preferredWidth: parent.width * 0.6
                Layout.fillHeight: true

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10

                    Image {
                        Layout.preferredHeight: parent.height * 0.6
                        sourceSize.height: height
                        fillMode: Image.PreserveAspectFit
                        source: "resources/images/i_wifi.svg"
                    }

                    ColumnLayout {
                        Layout.fillHeight: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: root.textColor
                            text: "Wi-Fi"
                        }
                        Text {
                            Layout.fillWidth: true
                            font.pixelSize: 12
                            font.bold: false
                            color: root.secondaryText
                            text: "2.4GHz: " + (serviceController.wifi24Ssid.length > 0 ? serviceController.wifi24Ssid : "-----") + (serviceController.wifi24Signal >= 0 ? " (" + serviceController.wifi24Signal + "%)" : "")
                        }
                        Text {
                            Layout.fillWidth: true
                            font.pixelSize: 12
                            font.bold: false
                            color: root.secondaryText
                            text: "5GHz: " + (serviceController.wifi5Ssid.length > 0 ? serviceController.wifi5Ssid : "-----") + (serviceController.wifi5Signal >= 0 ? " (" + serviceController.wifi5Signal + "%)" : "")
                        }
                    }
                }
            }
        }
    }





    Dialog {
        id: addProfileDialog
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(root.width * 0.9, 700)
        height: Math.min(root.height * 0.85, 750)

        property bool addressValid: /^.+\/\d+$/.test(newAddressField.text.trim())
        property bool endpointValid: newEndpointField.text.trim().length > 3 && newEndpointField.text.includes(":")
        property bool allowedIpsValid: newAllowedIpsField.text.trim().length > 0

        function isValid() { return newProfileNameField.text.trim().length > 0 && newConfigPathField.text.trim().length > 0 && newPrivateKeyField.text.trim().length > 0 && newPublicKeyField.text.trim().length > 0 && addressValid && endpointValid && allowedIpsValid; }

        background: Rectangle {
            color: root.popupColor
            radius: 15
            border.color: root.borderColor
        }

        Flickable {
            anchors.fill: parent
            contentHeight: addFormLayouut.height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            clip: true
        //    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        //    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: addFormLayouut
                anchors.top: parent.top;            //anchors.topMargin: 15
                anchors.left: parent.left;          anchors.leftMargin: 20
                anchors.right: parent.right;        anchors.rightMargin: 20
                spacing: 0

                Image {
                    Layout.alignment: Qt.AlignRight
                    //height: 20
                    Layout.preferredHeight: 20
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    source: "resources/images/i_cross.svg"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: addProfileDialog.close()
                    }
                }

                // Rectangle {
                //     Layout.alignment: Qt.AlignHCenter
                //     Layout.preferredHeight: 80
                //     Layout.preferredWidth: 80
                //     color: "#F7E2E1"
                //     radius: width

                //        Text {
                //            anchors.centerIn: parent
                //            color: "#ED1A2B"
                //            font.pixelSize: parent.height / 1.5
                //            font.weight: Font.Black
                //            text: "!"
                //        }
                // }

                Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

                // Profile
                Text {
                    text: "PROFILE"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: newProfileNameField
                    Layout.fillWidth: true
                    placeholderText: "Profile Name"
                    palette.base: addProfileDialog.addressValid ? "white" : "#FFEAEA"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newProfileNameField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    TextField {
                        id: newConfigPathField
                        Layout.fillWidth: true
                        placeholderText: "Configuration File"
                        background: Rectangle {
                            implicitWidth: parent.width
                            implicitHeight: 40
                            color: root.cardColor
                            radius: height / 7.5
                            border.width: 1
                            border.color: newConfigPathField.activeFocus ? root.primaryColor : root.borderColor
                        }

                        Text {
                            anchors.top: parent.top;            anchors.topMargin: 1
                            anchors.right: parent.right;        anchors.rightMargin: 8
                            text: parent.placeholderText
                            font.pixelSize: 10
                            color: parent.placeholderTextColor
                            visible: parent.text.trim().length > 0
                        }
                    }

                    Rectangle {
                        Layout.fillHeight: true
                        Layout.preferredWidth: browseButtonText.width + 25
                        color: root.primaryColor
                        radius: height / 5

                        Text {
                            id: browseButtonText
                            anchors.centerIn: parent
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            color: "white"
                            text: "Browse..."
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: addProfileFileDialog.open()
                        }
                    }
                }

                Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

                // Interface
                Text {
                    text: "INTERFACE"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: newAddressField
                    Layout.fillWidth: true
                    placeholderText: "Address"
                    palette.base: addProfileDialog.addressValid ? "white" : "#FFEAEA"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newAddressField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: newDnsField
                    Layout.fillWidth: true
                    placeholderText: "DNS"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newDnsField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: newListenPortField
                    Layout.fillWidth: true
                    placeholderText: "ListenPort"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newListenPortField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: newPrivateKeyField
                    Layout.fillWidth: true
                    placeholderText: "PrivateKey"
                    wrapMode: Text.WrapAnywhere
                    palette.base: newPrivateKeyField.text.trim().length > 0 ? "white" : "#FFEAEA"
                    font.pixelSize: 11
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newPrivateKeyField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 12; Layout.fillWidth: true; }     // Space

                // Peer
                Text {
                    text: "PEER"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: newPublicKeyField
                    Layout.fillWidth: true
                    placeholderText: "PublicKey"
                    wrapMode: Text.WrapAnywhere
                    palette.base: newPublicKeyField.text.trim().length > 0 ? "white" : "#FFEAEA"
                    font.pixelSize: 11
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newPublicKeyField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: newPresharedKeyField
                    Layout.fillWidth: true
                    placeholderText: "PresharedKey"
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: 11
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newPresharedKeyField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: newEndpointField
                    Layout.fillWidth: true
                    placeholderText: "Endpoint"
                    palette.base: addProfileDialog.endpointValid ? "white" : "#FFEAEA"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newEndpointField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: newAllowedIpsField
                    Layout.fillWidth: true
                    placeholderText: "AllowedIPs"
                    palette.base: addProfileDialog.allowedIpsValid ? "white" : "#FFEAEA"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: newAllowedIpsField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

                RowLayout {
                    spacing: 12

                    Text {
                        text: "Persistent Keepalive"
                    }

                    SpinBox {
                        id: newKeepaliveField
                        from: 0
                        to: 300
                        value: 25
                    }
                }

                Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: profileAddCreateText.height + 25
                    Layout.fillWidth: true
                    color: root.primaryColor
                    radius: height / 5

                    Text {
                        id: profileAddCreateText
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: "white"
                        text: "Create"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!addProfileDialog.isValid()) { return; }

                            if (serviceController.addProfile({
                                "ProfileName": newProfileNameField.text,
                                "ConfigPath": newConfigPathField.text,
                                "PrivateKey": newPrivateKeyField.text,
                                "Address": newAddressField.text,
                                "DNS": newDnsField.text,
                                "ListenPort": newListenPortField.text,
                                "PublicKey": newPublicKeyField.text,
                                "PresharedKey": newPresharedKeyField.text,
                                "Endpoint": newEndpointField.text,
                                "AllowedIPs": newAllowedIpsField.text,
                                "PersistentKeepalive": newKeepaliveField.value
                            })) { addProfileDialog.close(); }
                        }
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: profileAddCancelText.height + 25
                    Layout.fillWidth: true
                    color: root.buttonColor
                    radius: height / 5

                    Text {
                        id: profileAddCancelText
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: root.textColor
                        text: "Cancel"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: addProfileDialog.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: profileEditorDialog
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(root.width * 0.9, 700)
        height: Math.min(root.height * 0.85, 750)
        property int profileIndex: -1

        property bool addressValid: /^.+\/\d+$/.test(addressField.text.trim())
        property bool endpointValid: endpointField.text.includes(":")
        property bool allowedIpsValid: allowedIpsField.text.trim().length > 0

        function isValid() { return privateKeyField.text.trim().length > 0 && publicKeyField.text.trim().length > 0 && addressValid && endpointValid && allowedIpsValid; }
        property color invalidColor: "#CC0000"

        background: Rectangle {
            color: root.popupColor
            radius: 15
            border.color: root.borderColor
        }

        function loadProfile(row) {
            profileIndex = row;
            let cfg = serviceController.loadProfileConfig(row);

            privateKeyField.text = cfg["PrivateKey"] || "";
            addressField.text = cfg["Address"] || "";
            dnsField.text = cfg["DNS"] || "";
            listenPortField.text = cfg["ListenPort"] || "";
            publicKeyField.text = cfg["PublicKey"] || "";
            presharedKeyField.text = cfg["PresharedKey"] || "";
            endpointField.text = cfg["Endpoint"] || "";
            allowedIpsField.text = cfg["AllowedIPs"] || "";
            keepaliveField.value = Number(cfg["PersistentKeepalive"] || 0);
        }

        Flickable {
            anchors.fill: parent
            contentHeight: editFormLayouut.height
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            clip: true
        //    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        //    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: editFormLayouut
                anchors.top: parent.top;            //anchors.topMargin: 15
                anchors.left: parent.left;          anchors.leftMargin: 20
                anchors.right: parent.right;        anchors.rightMargin: 20
                spacing: 0

                Image {
                    Layout.alignment: Qt.AlignRight
                    //height: 20
                    Layout.preferredHeight: 20
                    sourceSize.height: height
                    fillMode: Image.PreserveAspectFit
                    source: "resources/images/i_cross.svg"

                    MouseArea {
                        anchors.fill: parent
                        onClicked: profileEditorDialog.close()
                    }
                }

                // Rectangle {
                //     Layout.alignment: Qt.AlignHCenter
                //     Layout.preferredHeight: 80
                //     Layout.preferredWidth: 80
                //     color: "#F7E2E1"
                //     radius: width

                //        Text {
                //            anchors.centerIn: parent
                //            color: "#ED1A2B"
                //            font.pixelSize: parent.height / 1.5
                //            font.weight: Font.Black
                //            text: "!"
                //        }
                // }

                Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

                // Interface
                Text {
                    text: "INTERFACE"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: addressField
                    Layout.fillWidth: true
                    placeholderText: "Address"
                    palette.base: profileEditorDialog.addressValid ? "white" : "#FFEAEA"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: addressField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: dnsField
                    Layout.fillWidth: true
                    placeholderText: "DNS"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: dnsField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: listenPortField
                    Layout.fillWidth: true
                    placeholderText: "ListenPort"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: listenPortField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: privateKeyField
                    Layout.fillWidth: true
                    placeholderText: "PrivateKey"
                    wrapMode: Text.WrapAnywhere
                    palette.base: privateKeyField.text.trim().length > 0 ? "#C0C0C0" : "red"
                    font.pixelSize: 11
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: privateKeyField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 12; Layout.fillWidth: true; }     // Space

                // Peer
                Text {
                    text: "PEER"
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: publicKeyField
                    Layout.fillWidth: true
                    placeholderText: "PublicKey"
                    wrapMode: Text.WrapAnywhere
                    palette.base: publicKeyField.text.trim().length > 0 ? "#C0C0C0" : "red"
                    font.pixelSize: 11
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: publicKeyField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: presharedKeyField
                    Layout.fillWidth: true
                    placeholderText: "PresharedKey"
                    wrapMode: Text.WrapAnywhere
                    font.pixelSize: 11
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: presharedKeyField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: endpointField
                    Layout.fillWidth: true
                    placeholderText: "Endpoint"
                    palette.base: profileEditorDialog.endpointValid ? "white" : "#FFEAEA"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: endpointField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                TextField {
                    id: allowedIpsField
                    Layout.fillWidth: true
                    placeholderText: "AllowedIPs"
                    palette.base: profileEditorDialog.allowedIpsValid ? "white" : "#FFEAEA"
                    background: Rectangle {
                        implicitWidth: parent.width
                        implicitHeight: 40
                        color: root.cardColor
                        radius: height / 7.5
                        border.width: 1
                        border.color: allowedIpsField.activeFocus ? root.primaryColor : root.borderColor
                    }

                    Text {
                        anchors.top: parent.top;            anchors.topMargin: 1
                        anchors.right: parent.right;        anchors.rightMargin: 8
                        text: parent.placeholderText
                        font.pixelSize: 10
                        color: parent.placeholderTextColor
                        visible: parent.text.trim().length > 0
                    }
                }

                Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

                RowLayout {
                    spacing: 12

                    Text {
                        text: "Persistent Keepalive"
                    }

                    SpinBox {
                        id: keepaliveField
                        from: 0
                        to: 300
                        value: 25
                    }
                }

                Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: profileEditSaveText.height + 25
                    Layout.fillWidth: true
                    color: root.primaryColor
                    radius: height / 5

                    Text {
                        id: profileEditSaveText
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: "white"
                        text: "Save"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!profileEditorDialog.isValid()) { return; }

                            if (serviceController.saveProfileConfig(profileEditorDialog.profileIndex, {
                                "PrivateKey": privateKeyField.text,
                                "Address": addressField.text,
                                "DNS": dnsField.text,
                                "ListenPort": listenPortField.text,

                                "PublicKey": publicKeyField.text,
                                "PresharedKey": presharedKeyField.text,

                                "Endpoint": endpointField.text,
                                "AllowedIPs": allowedIpsField.text,

                                "PersistentKeepalive": keepaliveField.value
                            })) { profileEditorDialog.close(); }
                        }
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: profileEditCancelText.height + 25
                    Layout.fillWidth: true
                    color: root.buttonColor
                    radius: height / 5

                    Text {
                        id: profileEditCancelText
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: root.textColor
                        text: "Cancel"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: profileEditorDialog.close()
                    }
                }

                Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: profileEditDeleteText.height + 25
                    Layout.fillWidth: true
                    color: root.buttonColor
                    radius: height / 5

                    Text {
                        id: profileEditDeleteText
                        anchors.centerIn: parent
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        color: root.textColor
                        text: "Delete"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            deleteProfileDialog.profileIndex = profileEditorDialog.profileIndex;
                            deleteProfileDialog.open();
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: deleteProfileDialog
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(root.width * 0.7, 700)
        //height: 150
        property int profileIndex: -1

        background: Rectangle {
            color: root.popupColor
            radius: 15
            border.color: root.borderColor
        }

        ColumnLayout {
            id: deleteFormLayout
            anchors.top: parent.top;            //anchors.topMargin: 15
            anchors.left: parent.left;          //anchors.leftMargin: 20
            anchors.right: parent.right;        //anchors.rightMargin: 20
            spacing: 0

            Image {
                Layout.alignment: Qt.AlignRight
                //height: 20
                Layout.preferredHeight: 20
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                source: "resources/images/i_cross.svg"

                MouseArea {
                    anchors.fill: parent
                    onClicked: deleteProfileDialog.close()
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 80
                Layout.preferredWidth: 80
                color: "#F7E2E1"
                radius: width

                Text {
                    anchors.centerIn: parent
                    color: "#ED1A2B"
                    font.pixelSize: parent.height / 1.5
                    font.weight: Font.Black
                    text: "!"
                }
            }

            Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: parent.width * 0.95
                text: "Really delete this VPN profile?"
                color: root.textColor
                font.pixelSize: 20
                font.weight: Font.ExtraBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

            Item {
                id: deleteConfigCheckBox
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                property real space: 10
                property bool checked: false

                Rectangle {
                    id: deteleCheckboxBox
                    width: height
                    height: parent.height
                    color: "white"
                    radius: height / 6
                    border.width: 1
                    border.color: "#3E649C"

                    Text {
                        anchors.centerIn: parent
                        text: "✔"
                        font.pixelSize: parent.height * 0.8
                        color: root.textColor
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.Wrap
                        visible: deleteConfigCheckBox.checked
                    }
                }
                Text {
                    id: deleteCheckboxText
                    anchors.verticalCenter: deteleCheckboxBox.verticalCenter
                    anchors.left: deteleCheckboxBox.right;        anchors.leftMargin: deleteConfigCheckBox.space
                    text: "Delete configuration file too"
                    font.pixelSize: deteleCheckboxBox.height * 0.8
                    color: root.textColor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: parent.checked = !parent.checked
                }
            }

            Item { Layout.preferredHeight: 12; Layout.fillWidth: true; }     // Space

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: deleteFormLayoutDeleteText.height + 25
                Layout.fillWidth: true
                color: root.primaryColor
                radius: height / 5

                Text {
                    id: deleteFormLayoutDeleteText
                    anchors.centerIn: parent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: "white"
                    text: "Delete"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        serviceController.deleteProfile(deleteProfileDialog.profileIndex, deleteConfigCheckBox.checked);
                        deleteProfileDialog.close();
                        profileEditorDialog.close();
                    }
                }
            }

            Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: deleteFormLayoutCancelText.height + 25
                Layout.fillWidth: true
                color: root.buttonColor
                radius: height / 5

                Text {
                    id: deleteFormLayoutCancelText
                    anchors.centerIn: parent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: root.textColor
                    text: "Cancel"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: deleteProfileDialog.close()
                }
            }
        }
    }


    FileDialog {
        id: addProfileFileDialog
        title: "Create WireGuard configuration"
        fileMode: FileDialog.SaveFile
        nameFilters: [ "WireGuard (*.conf)" ]
        onAccepted: {
            let path = selectedFile.toString().replace("file:///", "").replace(/\//g, "\\");
            if (!path.toLowerCase().endsWith(".conf")) { path += ".conf"; }
            newConfigPathField.text = path;
        }
    }


    Dialog {
        id: exitDialog
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: Math.min(root.width * 0.8, 700)
        //height: Math.min(root.height * 0.85, 750)

        background: Rectangle {
            color: root.popupColor
            radius: 15
            border.color: root.borderColor
        }

        ColumnLayout {
            id: exitFormLayouut
            anchors.top: parent.top;            //anchors.topMargin: 15
            anchors.left: parent.left;          //anchors.leftMargin: 20
            anchors.right: parent.right;        //anchors.rightMargin: 20
            spacing: 0

            Image {
                Layout.alignment: Qt.AlignRight
                //height: 20
                Layout.preferredHeight: 20
                sourceSize.height: height
                fillMode: Image.PreserveAspectFit
                source: "resources/images/i_cross.svg"

                MouseArea {
                    anchors.fill: parent
                    onClicked: exitDialog.close()
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: 80
                Layout.preferredWidth: 80
                color: "#F7E2E1"
                radius: width

                Text {
                    anchors.centerIn: parent
                    color: "#ED1A2B"
                    font.pixelSize: parent.height / 1.5
                    font.weight: Font.Black
                    text: "!"
                }
            }

            Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: parent.width * 0.95
                text: "Disconnect VPN First?"
                color: root.textColor
                font.pixelSize: 20
                font.weight: Font.ExtraBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: parent.width * 0.95
                text: "An active VPN connection is running."
                color: root.secondaryText
                font.pixelSize: 16
                //font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Item { Layout.preferredHeight: 10; Layout.fillWidth: true; }     // Space

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: parent.width * 0.95
                text: "Disconnecting before exit helps prevent accidental traffic leaks."
                color: root.secondaryText
                font.pixelSize: 16
                //font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Item { Layout.preferredHeight: 12; Layout.fillWidth: true; }     // Space

            Item {
                id: doNotAskAgainCheck
                Layout.alignment: Qt.AlignLeft
                Layout.leftMargin: 20
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                property real space: 10
                property bool checked: false

                Rectangle {
                    id: checkboxBox
                    width: height
                    height: parent.height
                    color: "white"
                    radius: height / 6
                    border.width: 1
                    border.color: "#3E649C"

                    Text {
                        anchors.centerIn: parent
                        text: "✔"
                        font.pixelSize: parent.height * 0.8
                        color: root.textColor
                        visible: doNotAskAgainCheck.checked
                    }
                }
                Text {
                    id: checkboxText
                    anchors.verticalCenter: checkboxBox.verticalCenter
                    anchors.left: checkboxBox.right;        anchors.leftMargin: doNotAskAgainCheck.space
                    text: "Don't show again"
                    font.pixelSize: checkboxBox.height * 0.8
                    color: root.textColor
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: parent.checked = !parent.checked
                }
            }

            Item { Layout.preferredHeight: 12; Layout.fillWidth: true; }     // Space

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: disconnetAndExitText.height + 25
                Layout.fillWidth: true
                color: root.primaryColor
                radius: height / 5

                Text {
                    id: disconnetAndExitText
                    anchors.centerIn: parent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: "white"
                    text: "Disconnect & Exit"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (doNotAskAgainCheck.checked) { serviceController.askDisconnectOnExit = false; }
                        serviceController.disconnectAllProfiles();
                        root.reallyClosing = true;
                        root.close();
                    }
                }
            }

            Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: exitAnywayText.height + 25
                Layout.fillWidth: true
                color: root.buttonColor
                radius: height / 5

                Text {
                    id: exitAnywayText
                    anchors.centerIn: parent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: root.textColor
                    text: "Exit Anyway"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (doNotAskAgainCheck.checked) { serviceController.askDisconnectOnExit = false; }
                        root.reallyClosing = true;
                        root.close();
                    }
                }
            }

            Item { Layout.preferredHeight: 6; Layout.fillWidth: true; }     // Space

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: cancelText.height + 25
                Layout.fillWidth: true
                color: root.buttonColor
                radius: height / 5

                Text {
                    id: cancelText
                    anchors.centerIn: parent
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    color: root.textColor
                    text: "Cancel"
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: exitDialog.close()
                }
            }


        }
    }
}