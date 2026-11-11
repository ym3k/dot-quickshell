import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string tooltipText: ""
    property bool danger: false
    property bool highlighted: false

    signal clicked()

    Layout.fillWidth: true
    implicitWidth: row.implicitWidth + 20
    implicitHeight: 30
    radius: Theme.radius
    color: highlighted ? Theme.critical
         : mouse.containsMouse ? (danger ? Qt.rgba(235 / 255, 77 / 255, 75 / 255, 0.5) : Theme.surfaceHover)
         : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animMs } }

    Row {
        id: row
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            IconText { anchors.centerIn: parent; text: root.icon }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.width - 46)
            elide: Text.ElideRight
            text: root.label
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Loader {
        active: mouse.containsMouse && root.tooltipText !== ""
        sourceComponent: Tooltip {
            target: root
            text: root.tooltipText
        }
    }
}
