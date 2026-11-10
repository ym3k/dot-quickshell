import QtQuick
import QtQuick.Layouts

// バーのピル型モジュール。文字とアイコンは 1 つのラベル（waybar と同じ）
Rectangle {
    id: root

    property string label: ""
    property color fg: Theme.fg
    property color bg: "transparent"
    property color hoverBg: bg.a === 0 ? Theme.surfaceHover : Qt.lighter(bg, 1.15)
    property bool italic: false
    property int maxTextWidth: 0
    property int padding: Theme.padding
    readonly property alias hovered: mouse.containsMouse

    signal clicked(int button)
    signal scrolled(int delta)

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: text.width + padding * 2
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    color: hovered ? hoverBg : bg
    Behavior on color { ColorAnimation { duration: Theme.animMs } }

    Text {
        id: text
        anchors.centerIn: parent
        width: root.maxTextWidth > 0 ? Math.min(implicitWidth, root.maxTextWidth) : implicitWidth
        elide: Text.ElideRight
        text: root.label
        color: root.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        font.italic: root.italic
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: e => root.clicked(e.button)
        onWheel: e => root.scrolled(e.angleDelta.y)
    }
}
