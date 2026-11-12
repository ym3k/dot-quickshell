import QtQuick
import QtQuick.Layouts

// ベース色の選択メニュー（バーの空き部分を右クリック）
ColumnLayout {
    id: root

    required property var panel

    width: 180
    spacing: 2

    Text {
        text: "Base color"
        color: Theme.subtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
        Layout.leftMargin: 4
        Layout.bottomMargin: 2
    }

    Repeater {
        model: Theme.baseNames

        delegate: Rectangle {
            id: row
            required property string modelData
            readonly property var pal: Theme.bases[modelData]
            readonly property bool current: Theme.base === modelData

            Layout.fillWidth: true
            implicitHeight: 30
            radius: Theme.radius
            color: mouse.containsMouse || current ? Theme.surfaceHover : "transparent"
            Behavior on color { ColorAnimation { duration: Theme.animMs } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 10

                // 色見本（アクセント / 背景）
                Row {
                    spacing: -4
                    Rectangle { width: 14; height: 14; radius: 7; color: row.pal.p; border.width: 1; border.color: Theme.barBorder }
                    Rectangle { width: 14; height: 14; radius: 7; color: row.pal.pc; border.width: 1; border.color: Theme.barBorder }
                }

                Text {
                    Layout.fillWidth: true
                    text: row.pal.label
                    color: Theme.fg
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize
                }

                Text {
                    visible: row.current
                    text: Theme.icons.check
                    color: Theme.accent
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Theme.setBase(row.modelData);
                    root.panel.openPopup = "";
                }
            }
        }
    }
}
