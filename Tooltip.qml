import QtQuick
import Quickshell

// バーのモジュールの下に出る小さなツールチップ（0.4 秒ホバーで表示）
PopupWindow {
    id: root

    required property Item target
    property string text: ""

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 6
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12
    color: "transparent"
    visible: false

    Timer {
        running: true
        interval: 400
        onTriggered: root.visible = true
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.barBorder

        Text {
            id: label
            anchors.centerIn: parent
            text: root.text
            color: Theme.fg
            font.family: Theme.fontFamilies
            font.pixelSize: Theme.fontSize
        }
    }
}
