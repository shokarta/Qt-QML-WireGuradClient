import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtGraphs

ApplicationWindow {

    visible: true

    width: 400
    height: 700

    title: "Home VPN"

    color: "#FAFAFA"

    property real graphMaxValue: 64

    ListModel {
        id: trafficModel
    }

    Connections {

        target: vpn

        function onTrafficUpdated(rx, tx)
        {
            trafficModel.insert(0, {
                rx: rx,
                tx: tx
            })

            while (trafficModel.count > 60)
            {
                trafficModel.remove(60)
            }

            rebuildGraph()
        }
    }

    function rebuildGraph()
    {
        downloadSeries.clear()
        uploadSeries.clear()

        let maxValue = 64

        for (let i = 0; i < trafficModel.count; ++i)
        {
            let item =
                    trafficModel.get(i)

            let x =
                    59 - i

            downloadSeries.append(
                        x,
                        item.rx)

            uploadSeries.append(
                        x,
                        item.tx)

            maxValue =
                    Math.max(
                        maxValue,
                        item.rx,
                        item.tx)
        }

        graphMaxValue = maxValue
    }

    ColumnLayout {

        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        RowLayout {

            Layout.fillWidth: true

            Switch {

                checked: vpn.connected

                onClicked: {

                    if (checked)
                        vpn.start()
                    else
                        vpn.stop()
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {

                text:
                    vpn.connected
                    ? "CONNECTED"
                    : "DISCONNECTED"

                color:
                    vpn.connected
                    ? "#00AA00"
                    : "#CC0000"

                font.bold: true
                font.pixelSize: 18
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#DDDDDD"
        }

        Text {
            text: "ENDPOINT"
            font.bold: true
        }

        Text {
            Layout.fillWidth: true
            wrapMode: Text.WrapAnywhere
            text: vpn.endpoint
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#DDDDDD"
        }

        Text {
            text: "TRAFFIC"
            font.bold: true
        }

        RowLayout {

            Text {
                text: "DOWNLOAD:"
                font.bold: true
            }

            Text {
                text: vpn.currentDownloadSpeed
                color: "#00AA00"
            }
        }

        RowLayout {

            Text {
                text: "UPLOAD:"
                font.bold: true
            }

            Text {
                text: vpn.currentUploadSpeed
                color: "#4A86FF"
            }
        }

        RowLayout {

            Text {
                text: "DURATION:"
                font.bold: true
            }

            Text {
                text: vpn.duration
            }
        }

        GraphsView {

            Layout.fillWidth: true
            Layout.fillHeight: true

            theme: GraphsTheme {

                grid.mainColor: "#909090"
                grid.mainWidth: 0.5

                backgroundColor: "transparent"
                plotAreaBackgroundColor: "white"
            }

            axisX: ValueAxis {

                id: xAxis

                min: 0
                max: 59

                gridVisible: true
                labelsVisible: true
                lineVisible: false
                visible: false
            }

            axisY: ValueAxis {

                id: yAxis

                min: 0
                max: graphMaxValue * 1.2

                gridVisible: false
                labelsVisible: false
                lineVisible: false
                visible: false
            }

            LineSeries {

                id: downloadSeries

                color: "#00AA00"
                width: 2
            }

            LineSeries {

                id: uploadSeries

                color: "#4A86FF"
                width: 2
            }
        }
    }
}