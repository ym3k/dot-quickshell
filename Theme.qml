pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// 配色: Material 3 風のダーク（end_4 風）＋ waybar 時代の legacy。
// ベース色はバーの空き部分の右クリックで切り替え
Singleton {
    id: theme

    // ── ベース色。選択は state ディレクトリに保存 ──
    // c: 一段明るい面 / ch: さらに明るい面（ホバー）/ p: アクセント / op: アクセント上の文字
    // pc・opc: 時計など淡いアクセント / sc・osc: 再生中の曲
    property string base: "lavender"
    readonly property var baseNames: ["teal", "rose", "orange", "lavender", "legacy"]
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
        orange: {
            label: "Orange",
            bar: "#d919120c", c: "#271e18", ch: "#322822", fg: "#f0dfd6", sub: "#d7c3b8", outline: "#52443c",
            p: "#ffb68a", op: "#522300", pc: "#74390f", opc: "#ffdbc8", sc: "#5b4134", osc: "#ffdbc8",
            popup: "#f519120c"
        },
        lavender: {
            label: "Lavender",
            bar: "#d9141318", c: "#211f26", ch: "#2b2930", fg: "#e6e0e9", sub: "#cac4d0", outline: "#49454f",
            p: "#d0bcff", op: "#381e72", pc: "#4f378b", opc: "#eaddff", sc: "#4a4458", osc: "#e8def8",
            popup: "#f5141318"
        },
        // waybar の style.css そのままの配色
        legacy: {
            label: "Legacy",
            bar: "#bf2b303b", c: "#0fffffff", ch: "#24ffffff", fg: "#ffffff", sub: "#9aa5b1", outline: "#8064727d",
            p: "#2980b9", op: "#ffffff", pc: "#64727D", opc: "#ffffff", sc: "transparent", osc: "#ffffff",
            popup: "#f52b303b",
            modules: {
                wsFocused: "#64727D", wsFocusedFg: "#ffffff",
                idle: "#2d3436", idleFg: "#ffffff", idleOn: "#ecf0f1", idleOnFg: "#2d3436",
                muted: "#90b1b1", mutedFg: "#2a5c45",
                battery: "#ffffff", batteryFg: "#000000",
                critical: "#eb4d4b", criticalFg: "#ffffff",
                pulseaudio: "#f1c40f", pulseaudioFg: "#000000", pulseaudioHover: "#a37800",
                network: "#2980b9", networkFg: "#ffffff",
                cpu: "#2ecc71", cpuFg: "#000000",
                memory: "#9b59b6", memoryFg: "#ffffff",
                temperature: "#f0932b", temperatureFg: "#ffffff",
                backlight: "#90b1b1", backlightFg: "#ffffff",
                charging: "#26A65B", chargingFg: "#ffffff",
                powerSaver: "#26A65B", powerSaverFg: "#ffffff",
                sunday: "#f56c6c", saturday: "#5dade2"
            }
        }
    })
    readonly property var b: bases[base] ?? bases.lavender

    // モジュールの色分け（案 D の淡いトーン）。legacy 以外のベースで共通
    readonly property var tints: ({
        critical: "#ffb4ab", criticalFg: "#690005",
        pulseaudio: "#3d3420", pulseaudioFg: "#f5d98a", pulseaudioHover: "#52462b",
        network: "#1f3346", networkFg: "#a8cdf0",
        cpu: "#1e3826", cpuFg: "#a6e3b5",
        memory: "#35263f", memoryFg: "#dcbcf0",
        temperature: "#40291a", temperatureFg: "#f5c08f",
        backlight: "#263534", backlightFg: "#b9d6d4",
        charging: "#1e3826", chargingFg: "#a6e3b5",
        powerSaver: "#1e3826", powerSaverFg: "#a6e3b5",
        sunday: "#ffb4ab", saturday: "#a8cdf0"
    })
    // ベースに modules があればそれを優先、なければ tints
    readonly property var m: Object.assign({}, tints, b.modules ?? {})

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

    readonly property color wsFocused: m.wsFocused ?? b.p
    readonly property color wsFocusedFg: m.wsFocusedFg ?? b.op
    readonly property color clock: b.pc
    readonly property color clockFg: b.opc
    readonly property color media: b.sc
    readonly property color mediaFg: b.osc
    readonly property color tray: b.c
    readonly property color idle: m.idle ?? b.c
    readonly property color idleFg: m.idleFg ?? b.sub
    readonly property color idleOn: m.idleOn ?? b.p
    readonly property color idleOnFg: m.idleOnFg ?? b.op
    readonly property color muted: m.muted ?? b.ch
    readonly property color mutedFg: m.mutedFg ?? b.sub
    readonly property color battery: m.battery ?? b.c
    readonly property color batteryFg: m.batteryFg ?? b.fg

    // ── 警告 ──
    readonly property color critical: m.critical
    readonly property color criticalFg: m.criticalFg
    readonly property color disconnected: critical
    readonly property color performance: critical
    readonly property color performanceFg: criticalFg

    // ── モジュールごとの色分け ──
    readonly property color pulseaudio: m.pulseaudio
    readonly property color pulseaudioFg: m.pulseaudioFg
    readonly property color pulseaudioHover: m.pulseaudioHover
    readonly property color network: m.network
    readonly property color networkFg: m.networkFg
    readonly property color cpu: m.cpu
    readonly property color cpuFg: m.cpuFg
    readonly property color memory: m.memory
    readonly property color memoryFg: m.memoryFg
    readonly property color temperature: m.temperature
    readonly property color temperatureFg: m.temperatureFg
    readonly property color backlight: m.backlight
    readonly property color backlightFg: m.backlightFg
    readonly property color charging: m.charging
    readonly property color chargingFg: m.chargingFg
    readonly property color powerSaver: m.powerSaver
    readonly property color powerSaverFg: m.powerSaverFg

    // カレンダー
    readonly property color sunday: m.sunday
    readonly property color saturday: m.saturday

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
