import QtQuick

Rectangle {
    id: root

    property string text: ""
    signal clicked()

    implicitWidth: 26
    implicitHeight: 26
    radius: Theme.radius
    color: mouse.containsMouse ? Theme.surfaceHover : "transparent"
    Behavior on color { ColorAnimation { duration: Theme.animMs } }

    Text {
        anchors.centerIn: parent
        text: root.text
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
