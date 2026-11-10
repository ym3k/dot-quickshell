import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

Rectangle {
    id: root

    required property var panel

    visible: SystemTray.items.values.length > 0
    Layout.alignment: Qt.AlignVCenter
    implicitWidth: row.implicitWidth + Theme.padding * 2
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    color: "transparent"

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Repeater {
            model: SystemTray.items

            delegate: MouseArea {
                id: item

                required property SystemTrayItem modelData

                width: 16
                height: 16
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: e => {
                    if (e.button === Qt.LeftButton && !modelData.onlyMenu) {
                        modelData.activate();
                    } else if (e.button === Qt.MiddleButton) {
                        modelData.secondaryActivate();
                    } else if (modelData.hasMenu) {
                        const p = item.mapToItem(null, 0, item.height);
                        modelData.display(root.panel, p.x, p.y);
                    }
                }

                IconImage {
                    anchors.fill: parent
                    source: item.modelData.icon
                }
            }
        }
    }
}
