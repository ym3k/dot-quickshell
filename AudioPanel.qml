import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// 音量・マイク・出力先の切り替え
ColumnLayout {
    id: root

    required property var panel
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    property var profileCards: []
    property string profileError: ""

    width: 300
    spacing: 8

    // 出力先の詳細（properties）を読むため、パネル表示中だけ出力先を追跡する
    PwObjectTracker { objects: root.sinks }

    // ツールチップの内容: どのカードのどの出力（ポート）か
    function sinkInfo(n) {
        const p = n.properties ?? {};
        const lines = [n.description || n.nickname || n.name];
        if (p["device.profile.description"]) lines.push(`Port: ${p["device.profile.description"]}`);
        const card = p["alsa.card_name"] ?? p["alsa.long_card_name"];
        if (card) lines.push(`Card: ${card}` + (p["api.alsa.path"] ? `  (${p["api.alsa.path"]})` : ""));
        if (p["api.bluez5.address"]) lines.push(`Bluetooth: ${p["api.bluez5.address"]}`);
        if (p["audio.channels"]) lines.push(`Channels: ${p["audio.channels"]}` + (p["audio.position"] ? `  (${p["audio.position"]})` : ""));
        return lines.join("\n");
    }

    function reloadProfiles() {
        profileError = "";
        cardsProcess.running = true;
    }

    function parseProfiles(output) {
        try {
            const cards = JSON.parse(output);
            profileCards = cards.filter(card => card.profiles && Object.keys(card.profiles).length > 0);
        } catch (error) {
            profileCards = [];
            profileError = `Could not read audio profiles: ${error}`;
        }
    }

    function selectProfile(cardName, profileName) {
        if (profileProcess.running) return;
        profileError = "";
        profileProcess.command = ["pactl", "set-card-profile", cardName, profileName];
        profileProcess.running = true;
    }

    Component.onCompleted: reloadProfiles()

    Process {
        id: cardsProcess
        command: ["pactl", "-f", "json", "list", "cards"]
        stdout: StdioCollector {
            onStreamFinished: root.parseProfiles(text)
        }
        stderr: StdioCollector {
            id: cardsStderr
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.profileError = cardsStderr.text.trim() || `Could not read audio profiles (exit code ${exitCode}).`;
            }
        }
    }

    Process {
        id: profileProcess
        command: []
        stderr: StdioCollector {
            id: profileStderr
        }
        onExited: (exitCode, exitStatus) => {
            let errorMessage = "";
            if (exitCode !== 0) {
                errorMessage = profileStderr.text.trim() || `Could not change audio profile (exit code ${exitCode}).`;
            }
            root.reloadProfiles();
            root.profileError = errorMessage;
        }
    }

    component Heading: Text {
        color: Theme.subtle
        font.family: Theme.fontFamily
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
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }
    }

    Heading { text: "Volume" }
    VolumeRow { node: root.sink; icon: Theme.icons.volume[1]; mutedIcon: Theme.icons.volumeMuted }
    VolumeRow { node: root.source; icon: Theme.icons.mic; mutedIcon: Theme.icons.micMuted }

    Heading { text: "Output"; Layout.topMargin: 4 }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: root.sinks
            delegate: MenuItem {
                id: sinkItem
                required property PwNode modelData
                icon: modelData === root.sink ? Theme.icons.check : ""
                label: modelData.description || modelData.nickname || modelData.name
                onClicked: Pipewire.preferredDefaultAudioSink = modelData

                // ホバーで詳細（パネルの右側に表示）
                LazyLoader {
                    active: sinkItem.hovered
                    Tooltip {
                        target: sinkItem
                        text: root.sinkInfo(sinkItem.modelData)
                        anchor.rect.width: sinkItem.width + 8
                        anchor.rect.height: sinkItem.height
                        anchor.edges: Edges.Right
                        anchor.gravity: Edges.Right
                    }
                }
            }
        }
    }

    Heading { text: "Profile"; Layout.topMargin: 4 }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: root.profileCards
            delegate: ColumnLayout {
                required property var modelData
                readonly property var card: modelData

                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: card.properties["device.description"] || card.name
                    color: Theme.subtle
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 1
                }
                Repeater {
                    model: Object.keys(card.profiles).filter(name =>
                        card.profiles[name].available || name === card.active_profile)
                    delegate: MenuItem {
                        required property string modelData
                        icon: modelData === card.active_profile ? Theme.icons.check : ""
                        label: card.profiles[modelData].description || modelData
                        tooltipText: label
                        onClicked: root.selectProfile(card.name, modelData)
                    }
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: root.profileCards.length === 0 && root.profileError === ""
        text: "No audio profiles available"
        color: Theme.subtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }
    Text {
        Layout.fillWidth: true
        visible: root.profileError !== ""
        text: root.profileError
        color: Theme.critical
        wrapMode: Text.Wrap
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
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
