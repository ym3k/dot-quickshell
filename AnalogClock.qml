import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

// 秒針付きのアナログ時計。Hyprland では普通のウィンドウとして開くので、
// window rule（title: Analog Clock）で float にする
// 左クリック: ローカル時刻 ⇔ UTC、右クリック: メニュー（Close）
FloatingWindow {
    id: win

    title: "Analog Clock"
    implicitWidth: 220
    implicitHeight: 220
    color: "transparent"

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // UTC 表示の切り替え（既定は PC のタイムゾーン = Asia/Tokyo）
    property bool utc: false

    readonly property int h: utc ? clock.date.getUTCHours() : clock.hours
    readonly property int mi: utc ? clock.date.getUTCMinutes() : clock.minutes
    readonly property int s: clock.seconds

    // 左クリック: UTC 切り替え、右クリック: メニュー
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => {
            // メニューが開いていたら、どこを押してもまずメニューを閉じるだけ
            if (menu.visible) {
                menu.visible = false;
                return;
            }
            if (e.button === Qt.RightButton) {
                menu.anchor.rect.x = e.x;
                menu.anchor.rect.y = e.y;
                menu.visible = true;
            } else {
                win.utc = !win.utc;
            }
        }
    }

    PopupWindow {
        id: menu

        anchor.window: win
        implicitWidth: menuBox.implicitWidth
        implicitHeight: menuBox.implicitHeight
        color: "transparent"
        visible: false

        // メニューの外をクリックしたら閉じる
        HyprlandFocusGrab {
            windows: [menu]
            active: menu.visible
            onCleared: menu.visible = false
        }

        Rectangle {
            id: menuBox
            anchors.fill: parent
            implicitWidth: menuCol.width + 12
            implicitHeight: menuCol.height + 12
            radius: Theme.radius + 4
            color: Theme.popupBg
            border.width: 1
            border.color: Theme.barBorder

            ColumnLayout {
                id: menuCol
                x: 6
                y: 6
                width: 150
                spacing: 0

                MenuItem {
                    icon: "\udb80\udd56"   // Nerd Font (MDI) close
                    label: "Close"
                    onClicked: {
                        menu.visible = false;
                        win.visible = false;
                    }
                }
            }
        }
    }

    // 文字盤（ウィンドウの短い辺に合わせて拡大縮小）
    Rectangle {
        id: face
        readonly property real size: Math.min(win.width, win.height) - 8
        readonly property real r: size / 2

        anchors.centerIn: parent
        width: size
        height: size
        radius: r
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.barBorder
        antialiasing: true

        // 目盛り（5 分ごとは太く長く）
        Repeater {
            model: 60
            delegate: Item {
                required property int index
                readonly property bool major: index % 5 === 0
                anchors.fill: parent
                rotation: index * 6

                Rectangle {
                    x: face.r - width / 2
                    y: face.r * 0.06
                    width: parent.major ? 3 : 1
                    height: parent.major ? face.r * 0.12 : face.r * 0.05
                    radius: width / 2
                    color: parent.major ? Theme.fg : Theme.subtle
                    opacity: parent.major ? 1 : 0.6
                    antialiasing: true
                }
            }
        }

        // 12 / 3 / 6 / 9
        Repeater {
            model: [12, 3, 6, 9]
            delegate: Text {
                required property int modelData
                required property int index
                readonly property real a: index * Math.PI / 2
                readonly property real dist: face.r * 0.66
                x: face.r + Math.sin(a) * dist - width / 2
                y: face.r - Math.cos(a) * dist - height / 2
                text: modelData
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Math.max(10, face.r * 0.16)
            }
        }

        // AM / PM（中心の上）
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: face.r * 0.62 - height / 2
            text: win.h < 12 ? "AM" : "PM"
            color: Theme.subtle
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, face.r * 0.12)
        }

        // タイムゾーン（中心の下）。ローカルは PC のタイムゾーンの略称（JST など）、UTC 表示中は UTC
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            y: face.r * 1.3
            text: win.utc ? "UTC" : Qt.formatDateTime(clock.date, "t")
            color: win.utc ? Theme.accent : Theme.subtle
            font.family: Theme.fontFamily
            font.pixelSize: Math.max(9, face.r * 0.13)
            font.bold: true
        }

        // 針（中心を軸に回転。tail は中心から反対側へ出る長さ）
        component Hand: Rectangle {
            id: hand
            property real angle: 0
            property real length: face.r * 0.5
            property real tail: 0

            x: face.r - width / 2
            y: face.r - length
            height: length + tail
            radius: width / 2
            antialiasing: true
            transform: Rotation {
                origin.x: hand.width / 2
                origin.y: hand.length
                angle: hand.angle
            }
        }

        Hand {   // 時針
            width: Math.max(4, face.r * 0.05)
            length: face.r * 0.5
            color: Theme.fg
            angle: (win.h % 12) * 30 + win.mi * 0.5
        }
        Hand {   // 分針
            width: Math.max(3, face.r * 0.035)
            length: face.r * 0.74
            color: Theme.fg
            angle: win.mi * 6 + win.s * 0.1
        }
        Hand {   // 秒針（アクセント色）
            width: 2
            length: face.r * 0.82
            tail: face.r * 0.16
            color: Theme.accent
            angle: win.s * 6
        }

        // 中心のキャップ
        Rectangle {
            anchors.centerIn: parent
            width: Math.max(8, face.r * 0.08)
            height: width
            radius: width / 2
            color: Theme.accent
            antialiasing: true
        }
    }
}
