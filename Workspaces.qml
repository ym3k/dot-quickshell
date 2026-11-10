import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: root

    required property var targetScreen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(targetScreen)

    Layout.alignment: Qt.AlignVCenter
    implicitWidth: row.implicitWidth + 4
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    color: Theme.surface

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: Hyprland.workspaces

            delegate: BarModule {
                id: ws

                required property HyprlandWorkspace modelData
                readonly property bool special: modelData.name.startsWith("special:")
                readonly property string name: special ? modelData.name.slice(8) : modelData.name

                visible: modelData.monitor === root.monitor
                implicitHeight: Theme.pillHeight - 4
                padding: 7
                label: `${name} ${modelData.urgent ? Theme.workspaceIcons["urgent"]
                                   : Theme.workspaceIcons[name] ?? Theme.workspaceIcons["default"]}`
                italic: special
                bg: modelData.urgent ? Theme.critical
                  : modelData.focused ? Theme.wsFocused
                  : modelData.active ? Theme.surface
                  : "transparent"
                fg: modelData.focused || modelData.active || modelData.urgent ? Theme.fg : Theme.subtle

                // special は表示のみ
                onClicked: if (!special) modelData.activate()
            }
        }
    }
}
