//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property bool idleInhibit: false
    property string submap: ""

    component ClipboardPanel: ColumnLayout {
        id: clipboardPanel

        required property var panel
        property var entries: []
        property string errorMessage: ""
        property bool confirmingClear: false

        width: 340
        spacing: 8

        function reloadHistory() {
            errorMessage = "";
            historyProcess.running = true;
        }

        function clearHistory() {
            errorMessage = "";
            clearProcess.running = true;
        }

        function parseHistory(output) {
            entries = output.split("\n").filter(line => line.length > 0).slice(0, 10).map(line => {
                const separator = line.indexOf("\t");
                return {
                    entry: line,
                    preview: separator < 0 ? line : line.slice(separator + 1)
                };
            });
        }

        function copyEntry(entry) {
            Quickshell.execDetached([
                "sh", "-c",
                "printf '%s\\n' \"$1\" | cliphist -db-path \"$XDG_RUNTIME_DIR/quickshell-clipboard.db\" decode | wl-copy",
                "quickshell-clipboard", entry
            ]);
            panel.openPopup = "";
        }

        Component.onCompleted: reloadHistory()

        Process {
            id: historyProcess
            command: ["sh", "-c",
                "cliphist -db-path \"$XDG_RUNTIME_DIR/quickshell-clipboard.db\" list"]
            stdout: StdioCollector {
                onStreamFinished: clipboardPanel.parseHistory(text)
            }
            stderr: StdioCollector {
                onStreamFinished: clipboardPanel.errorMessage = text.trim()
            }
        }

        Process {
            id: clearProcess
            command: ["sh", "-c",
                "cliphist -db-path \"$XDG_RUNTIME_DIR/quickshell-clipboard.db\" wipe"]
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim() !== "")
                        clipboardPanel.errorMessage = text.trim();
                }
            }
            onExited: (exitCode, exitStatus) => {
                if (exitCode === 0) {
                    clipboardPanel.confirmingClear = false;
                    clipboardPanel.reloadHistory();
                } else if (clipboardPanel.errorMessage === "") {
                    clipboardPanel.errorMessage = `Could not clear clipboard history (exit code ${exitCode}).`;
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Clipboard history"
            color: Theme.subtle
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Text {
            Layout.fillWidth: true
            visible: clipboardPanel.errorMessage !== ""
            text: clipboardPanel.errorMessage
            color: Theme.critical
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        Text {
            Layout.fillWidth: true
            visible: clipboardPanel.entries.length === 0 && clipboardPanel.errorMessage === ""
            text: "No clipboard history"
            color: Theme.subtle
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(contentHeight, 360)
            clip: true
            spacing: 2
            model: clipboardPanel.entries

            delegate: Rectangle {
                id: entryRow
                required property var modelData

                width: ListView.view.width
                implicitHeight: Math.max(Theme.pillHeight, preview.implicitHeight + 12)
                radius: Theme.radius
                color: mouse.containsMouse ? Theme.surfaceHover : "transparent"

                Text {
                    id: preview
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        margins: 8
                    }
                    text: entryRow.modelData.preview || "(空の項目)"
                    textFormat: Text.PlainText
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: clipboardPanel.copyEntry(entryRow.modelData.entry)
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Theme.surfaceHover
        }

        MenuItem {
            label: "Refresh history"
            onClicked: clipboardPanel.reloadHistory()
        }

        MenuItem {
            visible: !clipboardPanel.confirmingClear
            label: "Clear history"
            danger: true
            onClicked: clipboardPanel.confirmingClear = true
        }

        Text {
            Layout.fillWidth: true
            visible: clipboardPanel.confirmingClear
            text: "This permanently deletes all clipboard history. Continue?"
            color: Theme.critical
            wrapMode: Text.Wrap
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize - 1
        }

        RowLayout {
            Layout.fillWidth: true
            visible: clipboardPanel.confirmingClear

            MenuItem {
                label: "Cancel"
                onClicked: clipboardPanel.confirmingClear = false
            }
            MenuItem {
                label: "Delete all"
                danger: true
                onClicked: clipboardPanel.clearHistory()
            }
        }
    }

    Process {
        command: ["wl-paste", "--watch", "sh", "-c",
            "cliphist -db-path \"$XDG_RUNTIME_DIR/quickshell-clipboard.db\" store"]
        running: true
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "submap")
                root.submap = event.data;
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property var modelData
            property string openPopup: ""   // 開いているポップアップ名（1 つだけ）
            property var trayItem: null     // メニューを開いているトレイアイテム
            property Item trayTarget: null  // メニューの表示位置（トレイのアイコン）

            function toggle(name) {
                openPopup = openPopup === name ? "" : name;
            }

            screen: modelData
            anchors { top: true; left: true; right: true }
            implicitHeight: Theme.height + Theme.barMargin
            color: "transparent"

            // waybar の既定と同じ bottom レイヤー（special ワークスペースのウィンドウがバーより前に出る）
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "quickshell-bar"

            IdleInhibitor {
                window: win
                enabled: root.idleInhibit
            }

            Rectangle {
                id: bar
                anchors {
                    fill: parent
                    topMargin: Theme.barMargin
                    leftMargin: Theme.barMargin
                    rightMargin: Theme.barMargin
                }
                radius: Theme.radius + 3
                color: Theme.barBg
                border.width: 1
                border.color: Theme.barBorder

                // 空き部分の右クリックでベース色メニュー（モジュール上のクリックはモジュールが受け取る）
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: e => {
                        themeAnchor.x = e.x;
                        win.toggle("theme");
                    }
                }

                // メニューの表示位置（クリックした場所）
                Item {
                    id: themeAnchor
                    width: 1
                    height: parent.height
                }

                // ── 左 ──
                RowLayout {
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    spacing: Theme.spacing

                    Workspaces {
                        targetScreen: win.modelData
                        submap: root.submap
                    }

                    // mpris（左: パネル、中: 再生/停止、右: Noson の special:sonos を出し入れ、ホイール: 音量）
                    BarModule {
                        id: mediaModule
                        // 再生中 → 曲情報のあるプレイヤー の順で選ぶ
                        // （Sonos が見つからず空のままの Noson が、ほかのプレイヤーを隠さないように）
                        readonly property MprisPlayer player:
                            Mpris.players.values.find(p => p.isPlaying)
                            ?? Mpris.players.values.find(p => p.trackTitle)
                            ?? null
                        readonly property string title:
                            player ? [player.trackTitle, player.trackArtist].filter(s => s).join(" - ") : ""

                        visible: player !== null && title !== ""
                                 && player.playbackState !== MprisPlaybackState.Stopped
                        readonly property string playerIcon: {
                            const id = (player?.identity ?? "").toLowerCase();
                            return Theme.icons.players[id] ?? Theme.icons.players["default"];
                        }
                        label: `${player?.isPlaying ? playerIcon : Theme.icons.paused} ${title}`
                        maxTextWidth: 300
                        bg: Theme.media
                        fg: Theme.mediaFg

                        onClicked: button => {
                            if (!player) return;
                            if (button === Qt.LeftButton) win.toggle("media");
                            // Lua 設定の Hyprland では dispatch に Lua 式を渡す
                            else if (button === Qt.RightButton) Hyprland.dispatch('hl.dsp.workspace.toggle_special("sonos")');
                            else player.togglePlaying();
                        }
                        onScrolled: delta => {
                            if (player?.volumeSupported)
                                player.volume = Math.max(0, Math.min(1, player.volume + (delta > 0 ? 0.05 : -0.05)));
                        }
                    }
                }

                // ── 右 ──
                RowLayout {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    spacing: Theme.spacing

                    // idle_inhibitor
                    BarModule {
                        label: root.idleInhibit ? Theme.icons.idleOn : Theme.icons.idleOff
                        bg: root.idleInhibit ? Theme.idleOn : Theme.idle
                        fg: root.idleInhibit ? Theme.idleOnFg : Theme.idleFg
                        onClicked: root.idleInhibit = !root.idleInhibit
                    }

                    // pulseaudio（左: パネル、右: pavucontrol、中: ミュート、ホイール: 音量）
                    BarModule {
                        id: audioModule

                        readonly property PwNode sink: Pipewire.defaultAudioSink
                        readonly property PwNode source: Pipewire.defaultAudioSource
                        readonly property bool muted: sink?.audio?.muted ?? false
                        readonly property int vol: Math.round((sink?.audio?.volume ?? 0) * 100)
                        readonly property bool micMuted: source?.audio?.muted ?? true
                        readonly property int micVol: Math.round((source?.audio?.volume ?? 0) * 100)
                        readonly property string src: micMuted ? Theme.icons.micMuted : `${micVol}% ${Theme.icons.mic}`

                        readonly property bool bt: (sink?.name ?? "").startsWith("bluez")
                        readonly property string icon:
                            Theme.icons.volumeForm[sink?.properties?.["device.form-factor"] ?? ""]
                            ?? Theme.pick(Theme.icons.volume, vol)

                        // format / format-muted / format-bluetooth / format-bluetooth-muted
                        label: muted ? (bt ? `${Theme.icons.volumeMuted} ${icon}${Theme.icons.bluetooth}\u2009${src}`
                                           : `${Theme.icons.volumeMuted}\u2009${src}`)
                                     : `${vol}% ${icon}${bt ? Theme.icons.bluetooth : ""}\u2009${src}`
                        bg: muted ? Theme.muted : Theme.pulseaudio
                        fg: muted ? Theme.mutedFg : Theme.pulseaudioFg
                        hoverBg: Theme.pulseaudioHover

                        onClicked: button => {
                            if (button === Qt.LeftButton) win.toggle("audio");
                            else if (button === Qt.RightButton) Quickshell.execDetached(["pavucontrol"]);
                            else if (sink?.audio) sink.audio.muted = !sink.audio.muted;
                        }
                        onScrolled: delta => {
                            if (sink?.audio)
                                sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + (delta > 0 ? 0.05 : -0.05)));
                        }
                    }

                    // network（左: Wi‑Fi パネル、右: nmtui）
                    BarModule {
                        id: netModule
                        label: SysStats.netType === "wifi" ? `${SysStats.netName} (${SysStats.netSignal}%) ${Theme.pick(Theme.icons.wifi, SysStats.netSignal)}`
                             : SysStats.netType === "ethernet" ? `${SysStats.netName} ${Theme.icons.ethernet}`
                             : "Disconnected ⚠"
                        bg: SysStats.netType === "" ? Theme.disconnected : Theme.network
                        fg: SysStats.netType === "" ? Theme.criticalFg : Theme.networkFg
                        onClicked: button => {
                            if (button === Qt.RightButton) Quickshell.execDetached(["kitty", "nmtui"]);
                            else win.toggle("wifi");
                        }
                    }

                    // cpu / memory（クリックで btop）
                    BarModule {
                        label: `${SysStats.cpu}% ${Theme.icons.cpu}`
                        bg: SysStats.cpu > 95 ? Theme.critical : Theme.cpu
                        fg: SysStats.cpu > 95 ? Theme.criticalFg : Theme.cpuFg
                        onClicked: Quickshell.execDetached(["kitty", "btop"])
                    }
                    BarModule {
                        label: `${SysStats.memory}% ${Theme.icons.memory}`
                        bg: SysStats.memory > 95 ? Theme.critical : Theme.memory
                        fg: SysStats.memory > 95 ? Theme.criticalFg : Theme.memoryFg
                        onClicked: Quickshell.execDetached(["kitty", "htop"])
                    }

                    // temperature
                    BarModule {
                        readonly property int t: SysStats.temperature
                        readonly property string icon: t < 50 ? Theme.icons.temperature[0]
                            : t < 70 ? Theme.icons.temperature[1] : Theme.icons.temperature[2]
                        label: `${t}°C ${icon}`
                        bg: t >= 80 ? Theme.critical : Theme.temperature
                        fg: t >= 80 ? Theme.criticalFg : Theme.temperatureFg
                    }

                    // backlight（クリックでパネル、ホイールで輝度）
                    BarModule {
                        id: backlightModule
                        visible: SysStats.backlight >= 0
                        label: `${SysStats.backlight}% ${Theme.pick(Theme.icons.backlight, SysStats.backlight)}`
                        bg: Theme.backlight
                        fg: Theme.backlightFg
                        onClicked: button => { if (button === Qt.LeftButton) win.toggle("backlight"); }
                        onScrolled: delta => SysStats.changeBacklight(delta > 0)
                    }

                    // custom/power-profile（/sys/firmware/acpi/platform_profile）
                    BarModule {
                        readonly property string p: SysStats.platformProfile
                        visible: p !== ""
                        label: Theme.icons.profile[p] ?? Theme.icons.profile["default"]
                        bg: p === "performance" ? Theme.performance
                          : p === "low-power" ? Theme.powerSaver
                          : "transparent"
                        fg: p === "performance" ? Theme.performanceFg
                          : p === "low-power" ? Theme.powerSaverFg
                          : Theme.fg
                    }

                    Battery {}

                    // clock（クリックでカレンダー）
                    BarModule {
                        id: clockModule
                        label: Qt.formatDateTime(clock.date, "yyyy-MM-dd\u2009hh:mm")
                        bg: Theme.clock
                        fg: Theme.clockFg
                        onClicked: win.toggle("calendar")
                    }

                    BarModule {
                        id: clipboardModule
                        label: Theme.icons.clipboard
                        bg: win.openPopup === "clipboard" ? Theme.accent : Theme.surface
                        fg: win.openPopup === "clipboard" ? Theme.onAccent : Theme.fg
                        onClicked: win.toggle("clipboard")
                    }

                    Tray { panel: win }
                }
            }

            // ── ポップアップ（開いた時だけ生成） ──
            LazyLoader {
                active: win.openPopup === "tray" && win.trayItem !== null && win.trayTarget !== null
                Popup {
                    target: win.trayTarget
                    panel: win
                    TrayMenu { panel: win; menu: win.trayItem.menu }
                }
            }

            LazyLoader {
                active: win.openPopup === "theme"
                Popup {
                    target: themeAnchor
                    panel: win
                    ThemePicker { panel: win }
                }
            }

            LazyLoader {
                active: win.openPopup === "media" && mediaModule.player !== null
                Popup {
                    target: mediaModule
                    panel: win
                    MediaPanel { panel: win; player: mediaModule.player }
                }
            }

            LazyLoader {
                active: mediaModule.hovered && mediaModule.textTruncated && win.openPopup === ""
                Tooltip {
                    target: mediaModule
                    text: mediaModule.title
                }
            }

            LazyLoader {
                active: win.openPopup === "audio"
                Popup {
                    target: audioModule
                    panel: win
                    AudioPanel { panel: win }
                }
            }

            LazyLoader {
                active: win.openPopup === "backlight" && backlightModule.visible
                Popup {
                    target: backlightModule
                    panel: win
                    ColumnLayout {
                        width: 300
                        spacing: 8

                        Text {
                            text: "Brightness"
                            color: Theme.subtle
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            IconText {
                                text: Theme.pick(Theme.icons.backlight, SysStats.backlight)
                            }
                            Slider {
                                Layout.fillWidth: true
                                value: SysStats.backlight / 100
                                onMoved: v => SysStats.setBacklight(v * 100)
                            }
                            Text {
                                Layout.preferredWidth: 38
                                horizontalAlignment: Text.AlignRight
                                text: SysStats.backlight + "%"
                                color: Theme.fg
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSize
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: SysStats.backlightError !== ""
                            text: SysStats.backlightError
                            color: Theme.critical
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }

            // ネットワークのツールチップ（IP アドレス）
            LazyLoader {
                active: netModule.hovered && win.openPopup === ""
                onActiveChanged: if (active) SysStats.refreshIp()
                Tooltip {
                    target: netModule
                    text: SysStats.netIface === "" ? "Disconnected"
                        : `${SysStats.netIface}: ${SysStats.netIp || "(no IP)"}`
                          + (SysStats.netGateway ? `\nvia ${SysStats.netGateway}` : "")
                }
            }

            LazyLoader {
                active: win.openPopup === "wifi"
                Popup {
                    target: netModule
                    panel: win
                    WifiPanel { panel: win }
                }
            }

            LazyLoader {
                active: win.openPopup === "calendar"
                Popup {
                    target: clockModule
                    panel: win
                    CalendarView {}
                }
            }

            LazyLoader {
                active: win.openPopup === "clipboard"
                Popup {
                    target: clipboardModule
                    panel: win
                    ClipboardPanel { panel: win }
                }
            }
        }
    }
}
