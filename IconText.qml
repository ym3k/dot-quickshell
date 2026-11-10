import QtQuick

// 文字とアイコンを 1 つの Text で描く。
// フォントは waybar の style.css と同じ順でフォールバックする
Text {
    id: root

    property int pixelSize: Theme.fontSize
    property bool italic: false
    property bool bold: false
    property int maxTextWidth: 0

    width: maxTextWidth > 0 ? Math.min(implicitWidth, maxTextWidth) : implicitWidth
    elide: Text.ElideRight
    color: Theme.fg
    font.family: Theme.iconFontFamily
    font.pixelSize: pixelSize
    font.italic: italic
    font.bold: bold
}
