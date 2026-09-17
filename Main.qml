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
        height: Math.min(root.height * 0.9, 800)
        title: "Add New VPN Profile"
        property bool addressValid: /^.+\/\d+$/.test(newAddressField.text.trim())
        property bool endpointValid: newEndpointField.text.trim().length > 3 && newEndpointField.text.includes(":")
        property bool allowedIpsValid: newAllowedIpsField.text.trim().length > 0

        function isValid() { return newProfileNameField.text.trim().length > 0 && newConfigPathField.text.trim().length > 0 && newPrivateKeyField.text.trim().length > 0 && newPublicKeyField.text.trim().length > 0 && addressValid && endpointValid && allowedIpsValid; }

        background: Rectangle {
            color: "white"
            radius: 12
            border.color: root.borderColor
        }

        ScrollView {
            anchors.fill: parent

            ColumnLayout {
                width: addProfileDialog.width - 50
                spacing: 10

                Label {
                    text: "Profile"
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: newProfileNameField
                    Layout.fillWidth: true
                    placeholderText: "Profile Name"
                }

                RowLayout {
                    Layout.fillWidth: true

                    TextField {
                        id: newConfigPathField
                        Layout.fillWidth: true
                        placeholderText: "C:\\VPN\\MyVPN.conf"
                    }

                    Button {
                        text: "Browse..."
                        onClicked: addProfileFileDialog.open()
                    }
                }

                Label {
                    text: "Interface"
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: newAddressField
                    Layout.fillWidth: true
                    placeholderText: "Address"
                    palette.base: addProfileDialog.addressValid ? "white" : "#FFEAEA"
                }

                TextField {
                    id: newDnsField
                    Layout.fillWidth: true
                    placeholderText: "DNS"
                }

                TextField {
                    id: newListenPortField
                    Layout.fillWidth: true
                    placeholderText: "ListenPort"
                }

                TextArea {
                    id: newPrivateKeyField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    wrapMode: Text.WrapAnywhere
                    placeholderText: "PrivateKey"
                    palette.base: newPrivateKeyField.text.trim().length > 0 ? "white" : "#FFEAEA"
                }

                Label {
                    text: "Peer"
                    font.weight: Font.DemiBold
                }

                TextArea {
                    id: newPublicKeyField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    wrapMode: Text.WrapAnywhere
                    placeholderText: "PublicKey"
                    palette.base: newPublicKeyField.text.trim().length > 0 ? "white" : "#FFEAEA"
                }

                TextArea {
                    id: newPresharedKeyField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    wrapMode: Text.WrapAnywhere
                    placeholderText: "PresharedKey"
                }

                TextField {
                    id: newEndpointField
                    Layout.fillWidth: true
                    placeholderText: "Endpoint"
                    palette.base: addProfileDialog.endpointValid ? "white" : "#FFEAEA"
                }

                TextField {
                    id: newAllowedIpsField
                    Layout.fillWidth: true
                    placeholderText: "AllowedIPs"
                    palette.base: addProfileDialog.allowedIpsValid ? "white" : "#FFEAEA"
                }

                RowLayout {

                    Label {
                        text: "Persistent Keepalive"
                    }

                    SpinBox {
                        id: newKeepaliveField
                        from: 0
                        to: 300
                        value: 25
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        text: " Cancel "
                        onClicked: addProfileDialog.close()
                    }

                    Button {
                        text: " Create "
                        enabled: addProfileDialog.isValid()
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
        title: "Edit VPN Profile"

        property bool addressValid: /^.+\/\d+$/.test(addressField.text.trim())
        property bool endpointValid: endpointField.text.includes(":")
        property bool allowedIpsValid: allowedIpsField.text.trim().length > 0

        function isValid() { return privateKeyField.text.trim().length > 0 && publicKeyField.text.trim().length > 0 && addressValid && endpointValid && allowedIpsValid;  }
        property color invalidColor: "#CC0000"

        background: Rectangle {
            color: "white"
            radius: 12
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

        ScrollView {
            anchors.fill: parent

            ColumnLayout {
                id: editFormLayouut
                width: profileEditorDialog.width - 50

                spacing: 10

                // Interface
                Label {
                    text: "Interface"
                    font.weight: Font.DemiBold
                }

                TextField {
                    id: addressField
                    Layout.fillWidth: true
                    placeholderText: "Address"
                    palette.base: profileEditorDialog.addressValid ? "white" : "#FFEAEA"
                }

                TextField {
                    id: dnsField
                    Layout.fillWidth: true
                    placeholderText: "DNS"
                }

                TextField {
                    id: listenPortField
                    Layout.fillWidth: true
                    placeholderText: "ListenPort"
                }

                TextArea {
                    id: privateKeyField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    wrapMode: Text.WrapAnywhere
                    placeholderText: "PrivateKey"
                    palette.base: privateKeyField.text.trim().length > 0 ? "#C0C0C0" : "red"
                }

                // Peer
                Label {
                    text: "Peer"
                    font.weight: Font.DemiBold
                }

                TextArea {
                    id: publicKeyField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    wrapMode: Text.WrapAnywhere
                    placeholderText: "PublicKey"
                    palette.base: publicKeyField.text.trim().length > 0 ? "#C0C0C0" : "red"
                }

                TextArea {
                    id: presharedKeyField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    wrapMode: Text.WrapAnywhere
                    placeholderText: "PresharedKey"
                }

                TextField {
                    id: endpointField
                    Layout.fillWidth: true
                    placeholderText: "Endpoint"
                    palette.base: profileEditorDialog.endpointValid ? "white" : "#FFEAEA"
                }

                TextField {
                    id: allowedIpsField
                    Layout.fillWidth: true
                    placeholderText: "AllowedIPs"
                    palette.base: profileEditorDialog.allowedIpsValid ? "white" : "#FFEAEA"
                }

                RowLayout {

                    Label {
                        text: "Persistent Keepalive"
                    }

                    SpinBox {
                        id: keepaliveField
                        from: 0
                        to: 300
                        value: 25
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                RowLayout {
                    Layout.fillWidth: true

                    Button {
                        text: " Delete "
                        onClicked: {
                            deleteProfileDialog.profileIndex = profileEditorDialog.profileIndex;
                            deleteProfileDialog.open();
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Button {
                        text: " Cancel "
                        onClicked: profileEditorDialog.close()
                    }

                    Button {
                        text: " Save "
                        enabled: profileEditorDialog.isValid()
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
            }
        }
    }

    Dialog {
        id: deleteProfileDialog
        anchors.centerIn: parent
        modal: true
        width: 225
        height: 150
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property int profileIndex: -1
        title: "Delete Profile"

        background: Rectangle {
            color: "white"
            radius: 12
            border.color: root.borderColor
        }

        ColumnLayout {
            id: deleteFormLayout

            Text {
                text: "Really delete this VPN profile?"
            }

            CheckBox {
                id: deleteConfigCheckBox
                text: "Delete configuration file too"
            }

            RowLayout {

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: " Cancel "
                    onClicked: deleteProfileDialog.close()
                }

                Button {
                    text: " Delete "
                    highlighted: true
                    onClicked: {
                        serviceController.deleteProfile(deleteProfileDialog.profileIndex, deleteConfigCheckBox.checked);
                        deleteProfileDialog.close();
                        profileEditorDialog.close();
                    }
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
        title: "Exit Application"

        background: Rectangle {
            color: "white"
            radius: 12
            border.color: root.borderColor
        }

        ColumnLayout {
            spacing: 10

            Text {
                text: "Disconnect all VPN connections before exiting?"
            }

            CheckBox {
                id: doNotAskAgainCheck
                text: "Do not ask again"
            }

            RowLayout {

                Button {
                    text: "Cancel"
                    onClicked: exitDialog.close()
                }

                Item {
                    Layout.fillWidth: true
                }

                Button {
                    text: " Exit "
                    onClicked: {
                        if (doNotAskAgainCheck.checked) { serviceController.askDisconnectOnExit = false; }
                        root.reallyClosing = true;
                        root.close();
                    }
                }

                Button {
                    text: "Disconnect && Exit"
                    highlighted: true
                    onClicked: {
                        if (doNotAskAgainCheck.checked) { serviceController.askDisconnectOnExit = false; }
                        serviceController.disconnectAllProfiles();
                        root.reallyClosing = true;
                        root.close();
                    }
                }
            }
        }
    }
}