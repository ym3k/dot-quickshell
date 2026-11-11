import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

// 再生中のメディア（Sonos / Noson など MPRIS プレイヤー）
ColumnLayout {
    id: root

    required property var panel
    required property MprisPlayer player

    function fmt(sec) {
        const s = Math.max(0, Math.floor(sec));
        return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, "0")}`;
    }

    width: 320
    spacing: 10

    // 再生位置は自動で更新されないので、パネル表示中かつ再生中だけ 1 秒ごとに更新
    Timer {
        running: root.player?.isPlaying ?? false
        interval: 1000
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    component Label: Text {
        Layout.fillWidth: true
        elide: Text.ElideRight
        color: Theme.fg
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    // アルバムアート + 曲情報
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            implicitWidth: 72
            implicitHeight: 72
            radius: Theme.radius
            color: Theme.surface
            clip: true

            Image {
                anchors.fill: parent
                source: root.player?.trackArtUrl ?? ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(144, 144)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label { text: root.player?.trackTitle ?? ""; font.bold: true; font.pixelSize: Theme.fontSize + 1 }
            Label { text: root.player?.trackArtist ?? "" }
            Label { text: root.player?.trackAlbum ?? ""; color: Theme.subtle; font.pixelSize: Theme.fontSize - 1 }
        }
    }

    // 再生位置
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        visible: (root.player?.lengthSupported ?? false) && root.player.length > 0

        Slider {
            Layout.fillWidth: true
            value: root.player && root.player.length > 0 ? root.player.position / root.player.length : 0
            onMoved: v => { if (root.player?.canSeek) root.player.position = v * root.player.length; }
        }
        RowLayout {
            Layout.fillWidth: true
            Label { text: root.fmt(root.player?.position ?? 0); color: Theme.subtle; font.pixelSize: Theme.fontSize - 1 }
            Label {
                text: root.fmt(root.player?.length ?? 0)
                horizontalAlignment: Text.AlignRight
                color: Theme.subtle
                font.pixelSize: Theme.fontSize - 1
            }
        }
    }

    // 操作ボタン
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 16

        IconButton {
            text: Theme.icons.prev
            opacity: root.player?.canGoPrevious ? 1 : 0.4
            onClicked: if (root.player?.canGoPrevious) root.player.previous()
        }
        IconButton {
            implicitWidth: 34
            implicitHeight: 34
            color: Theme.accent
            text: root.player?.isPlaying ? Theme.icons.pause : Theme.icons.play
            onClicked: root.player?.togglePlaying()
        }
        IconButton {
            text: Theme.icons.next
            opacity: root.player?.canGoNext ? 1 : 0.4
            onClicked: if (root.player?.canGoNext) root.player.next()
        }
    }

    // 音量（プレイヤーが対応している時だけ。Sonos ならスピーカーの音量）
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.player?.volumeSupported ?? false

        Text {
            text: Theme.icons.volume[Theme.icons.volume.length - 1]
            color: Theme.fg
            font.family: Theme.iconFontFamily
            font.pixelSize: Theme.fontSize
        }
        Slider {
            Layout.fillWidth: true
            value: root.player?.volume ?? 0
            onMoved: v => { if (root.player) root.player.volume = v; }
        }
        Text {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round((root.player?.volume ?? 0) * 100) + "%"
            color: Theme.fg
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    Label {
        text: root.player?.identity ?? ""
        color: Theme.subtle
        font.pixelSize: Theme.fontSize - 1
    }
}
