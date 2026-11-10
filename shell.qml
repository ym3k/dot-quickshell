//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris

ShellRoot {
    id: root

    property bool idleInhibit: false
    property string submap: ""

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

                // ── 左 ──
                RowLayout {
                    anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
                    spacing: Theme.spacing

                    Workspaces { targetScreen: win.modelData }

                    // mpris（左: 再生/停止、右: 次、中: 前）
                    BarModule {
                        readonly property MprisPlayer player:
                            Mpris.players.values.find(p => p.isPlaying) ?? Mpris.players.values[0] ?? null
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

                        onClicked: button => {
                            if (!player) return;
                            if (button === Qt.LeftButton) player.togglePlaying();
                            else if (button === Qt.RightButton) player.next();
                            else player.previous();
                        }
                    }
                }

                // ── 中央：submap ──
                BarModule {
                    anchors.centerIn: parent
                    visible: root.submap !== ""
                    label: root.submap
                    italic: true
                    bg: Theme.critical
                }

                // ── 右 ──
                RowLayout {
                    anchors { right: parent.right; rightMargin: 4; verticalCenter: parent.verticalCenter }
                    spacing: Theme.spacing

                    // idle_inhibitor
                    BarModule {
                        label: root.idleInhibit ? Theme.icons.idleOn : Theme.icons.idleOff
                        bg: root.idleInhibit ? Theme.idleOn : Theme.idle
                        fg: root.idleInhibit ? Theme.idle : Theme.fg
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
                        fg: muted ? Theme.mutedFg : Theme.dark
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
                        onClicked: button => {
                            if (button === Qt.RightButton) Quickshell.execDetached(["kitty", "nmtui"]);
                            else win.toggle("wifi");
                        }
                    }

                    // cpu / memory（クリックで btop）
                    BarModule {
                        label: `${SysStats.cpu}% ${Theme.icons.cpu}`
                        bg: Theme.cpu
                        fg: Theme.dark
                        onClicked: Quickshell.execDetached(["kitty", "htop"])
                    }
                    BarModule {
                        label: `${SysStats.memory}% ${Theme.icons.memory}`
                        bg: Theme.memory
                        onClicked: Quickshell.execDetached(["kitty", "htop"])
                    }

                    // temperature
                    BarModule {
                        readonly property int t: SysStats.temperature
                        label: `${t}°C ${Theme.pick(Theme.icons.temperature, t)}`
                        bg: t >= 80 ? Theme.critical : Theme.temperature
                    }

                    // backlight（ホイールで輝度）
                    BarModule {
                        visible: SysStats.backlight >= 0
                        label: `${SysStats.backlight}% ${Theme.pick(Theme.icons.backlight, SysStats.backlight)}`
                        bg: Theme.backlight
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
                    }

                    Battery {}

                    // clock（クリックでカレンダー）
                    BarModule {
                        id: clockModule
                        label: Qt.formatDateTime(clock.date, "yyyy-MM-dd\u2009hh:mm")
                        bg: Theme.clock
                        onClicked: win.toggle("calendar")
                    }

                    Tray { panel: win }
                }
            }

            // ── ポップアップ（開いた時だけ生成） ──
            LazyLoader {
                active: win.openPopup === "audio"
                Popup {
                    target: audioModule
                    panel: win
                    AudioPanel { panel: win }
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
        }
    }
}
