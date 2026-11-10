pragma Singleton
import QtQuick
import Quickshell

// Waybar の style.css に合わせた色・フォント
Singleton {
    readonly property color barBg: Qt.rgba(43 / 255, 48 / 255, 59 / 255, 0.75)
    readonly property color barBorder: Qt.rgba(100 / 255, 114 / 255, 125 / 255, 0.5)
    readonly property color fg: "#ffffff"
    readonly property color dark: "#000000"

    readonly property color clock: "#64727D"
    readonly property color cpu: "#2ecc71"
    readonly property color memory: "#9b59b6"
    readonly property color temperature: "#f0932b"
    readonly property color critical: "#eb4d4b"
    readonly property color backlight: "#90b1b1"
    readonly property color network: "#2980b9"
    readonly property color disconnected: "#f53c3c"
    readonly property color pulseaudio: "#f1c40f"
    readonly property color pulseaudioHover: "#a37800"
    readonly property color muted: "#90b1b1"
    readonly property color mutedFg: "#2a5c45"
    readonly property color tray: "#2980b9"
    readonly property color idle: "#2d3436"
    readonly property color idleOn: "#ecf0f1"
    readonly property color battery: "#ffffff"
    readonly property color charging: "#26A65B"
    readonly property color performance: "#f53c3c"
    readonly property color powerSaver: "#26A65B"

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
    readonly property color surface: Qt.rgba(1, 1, 1, 0.06)
    readonly property color surfaceHover: Qt.rgba(1, 1, 1, 0.14)
    readonly property color popupBg: Qt.rgba(43 / 255, 48 / 255, 59 / 255, 0.96)
    readonly property color accent: "#2980b9"
    readonly property color subtle: "#9aa5b1"
    readonly property color wsFocused: "#64727D"
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
        players: { "spotify": "\uf1bc", "mpv": "🎵", "default": "\uf144" },
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
