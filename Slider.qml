import QtQuick

// 0〜1 のスライダー。ドラッグ・クリック・ホイールで操作
Item {
    id: root

    property real value: 0
    property bool dim: false
    signal moved(real value)

    function clamp(v) { return Math.max(0, Math.min(1, v)); }

    implicitWidth: 180
    implicitHeight: 18

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Theme.surfaceHover

        Rectangle {
            width: parent.width * root.clamp(root.value)
            height: parent.height
            radius: 2
            color: root.dim ? Theme.subtle : Theme.accent
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: root.clamp(root.value) * (root.width - width)
        width: 12
        height: 12
        radius: 6
        color: Theme.fg
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function set(x) { root.moved(root.clamp(x / width)); }
        onPressed: e => set(e.x)
        onPositionChanged: e => { if (pressed) set(e.x); }
        onWheel: e => root.moved(root.clamp(root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05)))
    }
}
