import QtQuick
import QtQuick.Layouts

// カレンダー。ホイールで月送り、見出しクリックで今月に戻る
ColumnLayout {
    id: root

    readonly property var now: new Date()
    property int year: now.getFullYear()
    property int month: now.getMonth()
    readonly property int firstDow: new Date(year, month, 1).getDay()

    function shift(n) {
        const d = new Date(year, month + n, 1);
        year = d.getFullYear();
        month = d.getMonth();
    }

    spacing: 8

    WheelHandler {
        onWheel: e => root.shift(e.angleDelta.y > 0 ? -1 : 1)
    }

    RowLayout {
        Layout.fillWidth: true

        IconButton { text: Theme.icons.left; onClicked: root.shift(-1) }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: `${["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][root.month]} ${root.year}`
            color: Theme.fg
            font.family: Theme.fontFamilies
            font.pixelSize: Theme.fontSize + 1
            font.bold: true
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.year = root.now.getFullYear(); root.month = root.now.getMonth(); }
            }
        }
        IconButton { text: Theme.icons.right; onClicked: root.shift(1) }
    }

    Grid {
        columns: 7
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            delegate: Text {
                required property string modelData
                required property int index
                width: 32
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: index === 0 ? Theme.sunday : index === 6 ? Theme.saturday : Theme.subtle
                font.family: Theme.fontFamilies
                font.pixelSize: Theme.fontSize - 1
            }
        }

        Repeater {
            model: 42
            delegate: Rectangle {
                required property int index
                readonly property var d: new Date(root.year, root.month, 1 - root.firstDow + index)
                readonly property bool inMonth: d.getMonth() === root.month
                readonly property bool isToday: d.toDateString() === root.now.toDateString()

                width: 32
                height: 26
                radius: Theme.radius
                color: isToday ? Theme.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.d.getDate()
                    opacity: parent.inMonth ? 1 : 0.35
                    color: parent.isToday ? Theme.fg
                         : parent.index % 7 === 0 ? Theme.sunday
                         : parent.index % 7 === 6 ? Theme.saturday
                         : Theme.fg
                    font.family: Theme.fontFamilies
                    font.pixelSize: Theme.fontSize
                    font.bold: parent.isToday
                }
            }
        }
    }
}
