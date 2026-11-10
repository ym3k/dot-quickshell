import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

// 音量・マイク・出力先の切り替え
ColumnLayout {
    id: root

    required property var panel
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)

    width: 300
    spacing: 8

    component Heading: Text {
        color: Theme.subtle
        font.family: Theme.fontFamilies
        font.pixelSize: Theme.fontSize - 1
    }

    component VolumeRow: RowLayout {
        id: vr
        required property PwNode node
        required property string icon
        required property string mutedIcon
        readonly property bool muted: node?.audio?.muted ?? false

        Layout.fillWidth: true
        spacing: 8

        IconButton {
            text: vr.muted ? vr.mutedIcon : vr.icon
            onClicked: if (vr.node?.audio) vr.node.audio.muted = !vr.node.audio.muted
        }
        Slider {
            Layout.fillWidth: true
            value: vr.node?.audio?.volume ?? 0
            dim: vr.muted
            onMoved: v => { if (vr.node?.audio) vr.node.audio.volume = v; }
        }
        Text {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            text: Math.round((vr.node?.audio?.volume ?? 0) * 100) + "%"
            color: Theme.fg
            font.family: Theme.fontFamilies
            font.pixelSize: Theme.fontSize
        }
    }

    Heading { text: "Volume" }
    VolumeRow { node: root.sink; icon: Theme.icons.volume[2]; mutedIcon: Theme.icons.volumeMuted }
    VolumeRow { node: root.source; icon: Theme.icons.mic; mutedIcon: Theme.icons.micMuted }

    Heading { text: "Output"; Layout.topMargin: 4 }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: root.sinks
            delegate: MenuItem {
                required property PwNode modelData
                icon: modelData === root.sink ? Theme.icons.check : ""
                label: modelData.description || modelData.nickname || modelData.name
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surfaceHover }
    MenuItem {
        icon: Theme.icons.settings
        label: "Open pavucontrol"
        onClicked: {
            Quickshell.execDetached(["pavucontrol"]);
            root.panel.openPopup = "";
        }
    }
}
