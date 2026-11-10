import QtQuick
import Quickshell
import Quickshell.Hyprland

// バーのモジュールの下に出るポップアップ。外側クリックで閉じる
PopupWindow {
    id: root

    required property Item target
    required property var panel
    default property alias content: inner.data

    anchor.item: target
    anchor.rect.width: target.width
    anchor.rect.height: target.height + 8
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom

    implicitWidth: bg.implicitWidth
    implicitHeight: bg.implicitHeight
    color: "transparent"
    visible: true

    HyprlandFocusGrab {
        windows: [root, root.panel]
        active: root.visible
        onCleared: root.panel.openPopup = ""
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        implicitWidth: inner.width + 24
        implicitHeight: inner.height + 24
        radius: Theme.radius + 4
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.barBorder

        opacity: 0
        Component.onCompleted: opacity = 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Item {
            id: inner
            x: 12
            y: 12
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
