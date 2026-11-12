import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// トレイアイコンのメニュー（アプリのネイティブメニューの代わりにテーマに合わせて描く）
// サブメニューは中に入って表示し、「Back」で戻る
ColumnLayout {
    id: root

    required property var panel
    required property var menu

    // 開いているサブメニューの項目（親から順に）
    property var stack: []

    // 階層ごとにメニューを開いたままにしておく。
    // 1 つの opener を使い回すと、親メニューが閉じてサブメニューの項目ごと消えてしまう（Slack など）
    QsMenuOpener { id: o0; menu: root.menu }
    QsMenuOpener { id: o1; menu: root.stack.length > 0 ? root.stack[0] : null }
    QsMenuOpener { id: o2; menu: root.stack.length > 1 ? root.stack[1] : null }
    QsMenuOpener { id: o3; menu: root.stack.length > 2 ? root.stack[2] : null }
    readonly property var openers: [o0, o1, o2, o3]
    readonly property var current: openers[Math.min(stack.length, openers.length - 1)]

    // "_Open" のようなアクセラレータ記号を取り除く
    function cleanText(t) {
        return (t ?? "").replace(/__/g, "\u0000").replace(/_/g, "").replace(/\u0000/g, "_");
    }

    width: 240
    spacing: 0

    MenuItem {
        visible: root.stack.length > 0
        icon: Theme.icons.left
        label: "Back"
        onClicked: root.stack = root.stack.slice(0, -1)
    }

    Repeater {
        model: root.current.children

        delegate: Item {
            id: entry

            required property QsMenuEntry modelData
            readonly property bool isRadio: modelData.buttonType === QsMenuButtonType.RadioButton
            readonly property bool isCheck: modelData.buttonType === QsMenuButtonType.CheckBox
            readonly property bool checked: modelData.checkState === Qt.Checked
            readonly property bool hasIcon: (modelData.icon ?? "") !== ""

            Layout.fillWidth: true
            implicitHeight: modelData.isSeparator ? 9 : 30

            // 区切り線
            Rectangle {
                visible: entry.modelData.isSeparator
                anchors.centerIn: parent
                width: parent.width - 8
                height: 1
                color: Theme.surfaceHover
            }

            // 通常の項目
            Rectangle {
                visible: !entry.modelData.isSeparator
                anchors.fill: parent
                radius: Theme.radius
                opacity: entry.modelData.enabled ? 1 : 0.4
                color: mouse.containsMouse && entry.modelData.enabled ? Theme.surfaceHover : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.animMs } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    // ラジオボタン（丸）: 未選択は枠だけ、選択中は中を塗る
                    Rectangle {
                        visible: entry.isRadio
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 7
                        color: "transparent"
                        border.width: 1.5
                        border.color: entry.checked ? Theme.accent : Theme.subtle

                        Rectangle {
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.accent
                            visible: entry.checked
                        }
                    }

                    // チェックボックス（角丸の四角）
                    Rectangle {
                        visible: entry.isCheck
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 3
                        color: entry.checked ? Theme.accent : "transparent"
                        border.width: 1.5
                        border.color: entry.checked ? Theme.accent : Theme.subtle

                        Text {
                            anchors.centerIn: parent
                            visible: entry.checked
                            text: Theme.icons.check
                            color: Theme.onAccent
                            font.family: Theme.iconFontFamily
                            font.pixelSize: 11
                        }
                    }

                    // 項目のアイコン（ラジオ・チェックと併用できる）
                    IconImage {
                        visible: entry.hasIcon
                        implicitWidth: 16
                        implicitHeight: 16
                        source: entry.modelData.icon
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.cleanText(entry.modelData.text)
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }

                    Text {
                        visible: entry.modelData.hasChildren
                        text: Theme.icons.right
                        color: Theme.subtle
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize - 2
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: entry.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (entry.modelData.hasChildren) {
                            if (root.stack.length < root.openers.length - 1)
                                root.stack = root.stack.concat([entry.modelData]);
                        } else {
                            entry.modelData.triggered();
                            root.panel.openPopup = "";
                        }
                    }
                }
            }
        }
    }
}
