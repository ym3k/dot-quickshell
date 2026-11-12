import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Rectangle {
    id: root

    required property var targetScreen
    property string submap: ""
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(targetScreen)

    component WorkspaceButton: BarModule {
        required property HyprlandWorkspace workspace
        readonly property bool special: workspace.name.startsWith("special:")
        readonly property string name: special ? workspace.name.slice(8) : workspace.name

        implicitHeight: Theme.pillHeight - 4
        padding: 7
        label: `${name} ${workspace.urgent ? Theme.workspaceIcons["urgent"]
                           : Theme.workspaceIcons[name] ?? Theme.workspaceIcons["default"]}`
        italic: special
        bg: workspace.urgent ? Theme.critical
          : workspace.focused ? Theme.wsFocused
          : workspace.active ? Theme.surface
          : "transparent"
        fg: workspace.urgent ? Theme.criticalFg
          : workspace.focused ? Theme.wsFocusedFg
          : workspace.active ? Theme.fg
          : Theme.subtle

        // special は表示のみ
        onClicked: if (!special) workspace.activate()
    }

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

            delegate: WorkspaceButton {
                required property HyprlandWorkspace modelData
                workspace: modelData
                // special:sonos（Noson の隠し場所）はバーに出さない
                visible: modelData.monitor === root.monitor && modelData.name !== "special:magic" && modelData.name !== "special:sonos"
            }
        }

        Repeater {
            model: Hyprland.workspaces

            delegate: WorkspaceButton {
                required property HyprlandWorkspace modelData
                workspace: modelData
                visible: modelData.monitor === root.monitor && modelData.name === "special:magic"
            }
        }

        BarModule {
            visible: root.submap !== ""
            label: root.submap
            italic: true
            bg: Theme.critical
            fg: Theme.criticalFg
        }
    }
}
