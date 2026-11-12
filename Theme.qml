pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// 配色: Material 3 風のダーク（end_4 風）。ベース色はバーの空き部分の右クリックで切り替え
Singleton {
    id: theme

    // ── ベース色（teal / rose / lavender）。選択は state ディレクトリに保存 ──
    property string base: "lavender"
    readonly property var baseNames: ["teal", "rose", "lavender"]
    readonly property var bases: ({
        teal: {
            label: "Teal",
            bar: "#d90e1514", c: "#1a2120", ch: "#252b2a", fg: "#dde4e2", sub: "#bec9c7", outline: "#3f4948",
            p: "#80d5cf", op: "#003735", pc: "#00504c", opc: "#9cf2eb", sc: "#324b49", osc: "#cce8e5",
            popup: "#f50e1514"
        },
        rose: {
            label: "Rose",
            bar: "#d9191113", c: "#261d1f", ch: "#31282a", fg: "#f0dee0", sub: "#d5c2c5", outline: "#524345",
            p: "#ffb1c3", op: "#5e1130", pc: "#7b2946", opc: "#ffd9e0", sc: "#5a3f45", osc: "#ffd9e0",
            popup: "#f5191113"
        },
        lavender: {
            label: "Lavender",
            bar: "#d9141318", c: "#211f26", ch: "#2b2930", fg: "#e6e0e9", sub: "#cac4d0", outline: "#49454f",
            p: "#d0bcff", op: "#381e72", pc: "#4f378b", opc: "#eaddff", sc: "#4a4458", osc: "#e8def8",
            popup: "#f5141318"
        }
    })
    readonly property var b: bases[base] ?? bases.lavender

    function setBase(name) {
        if (!bases[name]) return;
        base = name;
        baseStore.setText(name);
    }

    FileView {
        id: baseStore
        path: Quickshell.statePath("theme-base")
        printErrors: false
        onLoaded: {
            const v = text().trim();
            if (theme.bases[v]) theme.base = v;
        }
    }

    // ── 共通（ベース色から） ──
    readonly property color barBg: b.bar
    readonly property color barBorder: b.outline
    readonly property color fg: b.fg
    readonly property color subtle: b.sub
    readonly property color dark: b.op
    readonly property color surface: b.c
    readonly property color surfaceHover: b.ch
    readonly property color popupBg: b.popup
    readonly property color accent: b.p
    readonly property color onAccent: b.op

    readonly property color wsFocused: b.p
    readonly property color wsFocusedFg: b.op
    readonly property color clock: b.pc
    readonly property color clockFg: b.opc
    readonly property color media: b.sc
    readonly property color mediaFg: b.osc
    readonly property color tray: b.c
    readonly property color idle: b.c
    readonly property color idleFg: b.sub
    readonly property color idleOn: b.p
    readonly property color idleOnFg: b.op
    readonly property color muted: b.ch
    readonly property color mutedFg: b.sub

    // ── 警告（どのベースでも共通） ──
    readonly property color critical: "#ffb4ab"
    readonly property color criticalFg: "#690005"
    readonly property color disconnected: critical
    readonly property color performance: critical
    readonly property color performanceFg: criticalFg

    // ── モジュールごとの色分け（案 D: 淡いトーン、どのベースでも共通） ──
    readonly property color pulseaudio: "#3d3420"
    readonly property color pulseaudioFg: "#f5d98a"
    readonly property color pulseaudioHover: "#52462b"
    readonly property color network: "#1f3346"
    readonly property color networkFg: "#a8cdf0"
    readonly property color cpu: "#1e3826"
    readonly property color cpuFg: "#a6e3b5"
    readonly property color memory: "#35263f"
    readonly property color memoryFg: "#dcbcf0"
    readonly property color temperature: "#40291a"
    readonly property color temperatureFg: "#f5c08f"
    readonly property color backlight: "#263534"
    readonly property color backlightFg: "#b9d6d4"
    readonly property color battery: b.c
    readonly property color batteryFg: b.fg
    readonly property color charging: "#1e3826"
    readonly property color chargingFg: "#a6e3b5"
    readonly property color powerSaver: "#1e3826"
    readonly property color powerSaverFg: "#a6e3b5"

    // カレンダー

    readonly property string fontFamily: "Hack"
    readonly property string iconFontFamily: "Hack Nerd Font Propo"
    readonly property int fontSize: 13

    readonly property int height: 36
    readonly property int spacing: 4
    readonly property int padding: 10

    // デザイン（フローティングバー + 角丸ピル）
    readonly property int barMargin: 6          // 画面端からの余白
    readonly property int radius: 7
    readonly property int pillHeight: 26
    readonly property color sunday: "#f56c6c"
    readonly property color saturday: "#5dade2"
    readonly property int animMs: 150

    // ワークスペース名 → アイコン（waybar config.hyprland と同じ）
    readonly property var workspaceIcons: ({
        "1": "\uf120",
        "2": "\uf268",
        "3": "\uf121",
        "7": "\uf075",
        "8": "\uf003",
        "9": "\uf001",
        "10": "\uf2d2",
        "urgent": "\uf06a",
        "default": "\uf111"
    })

    // 各モジュールのアイコン（waybar config.hyprland と同じ）
    readonly property var icons: ({
        // mpris: 再生中はプレイヤーアイコン、一時停止中はステータスアイコン
        players: { "spotify": "\uf1bc", "mpv": "🎵", "noson": "\udb81\udcc3", "default": "\uf144" },   // noson = Sonos (MDI speaker)
        prev: "\uf048", play: "\uf04b", pause: "\uf04c", next: "\uf051",
        paused: "\uf28b", stopped: "\uf28d",
        idleOn: "\uf06e", idleOff: "\uf070",
        volume: ["\uf027", "\uf028"], volumeMuted: "\uf026",  // Font Awesome: volume-low / high / off
        // device.form-factor ごとのアイコン
        volumeForm: {
            "headphone": "\uf025", "hands-free": "\uf590", "headset": "\uf590",
            "phone": "\uf095", "portable": "\uf095", "car": "\uf1b9"
        },
        bluetooth: "\uf294",
        mic: "\uf130", micMuted: "\uf131",
        clipboard: "\udb80\udd47",
        // Nerd Font (MDI) Wi-Fi signal strength: 1–4 bars
        wifi: ["\udb82\udd1f", "\udb82\udd22", "\udb82\udd25", "\udb82\udd28"], ethernet: "\udb80\ude00",
        cpu: "\uf2db",
        memory: "\uf0c9",
        temperature: ["\uf2cb", "\uf2c9", "\uf2c7"],
        backlight: ["\ue38d", "\ue3d3", "\ue3d1", "\ue3cf", "\ue3ce", "\ue3cd", "\ue3ca", "\ue3c8", "\ue39b"],
        profile: { "performance": "\uf0e7", "balanced": "\uf24e", "low-power": "\uf06c", "default": "\uf0e7" },
        battery: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"],
        charging: "\udb80\udc84", plugged: "\uf1e6",
        check: "\udb80\udd2c", lock: "\udb80\udf3e", settings: "\uf013",   // check / lock は Nerd Font (MDI)
        left: "\uf053", right: "\uf054"
    })

    // 配列アイコンを割合(0-100)で選ぶ（waybar と同じ方式）
    function pick(list, percent) {
        return list[Math.max(0, Math.min(list.length - 1, Math.floor(percent / 100 * list.length)))];
    }
}
