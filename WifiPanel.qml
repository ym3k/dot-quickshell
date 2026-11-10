import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

// Wi‑Fi パネル（Quickshell.Networking / NetworkManager）
ColumnLayout {
    id: root

    required property var panel
    readonly property var dev: SysStats.wifiDevice
    // 接続中を先頭に、あとは電波の強い順。多すぎると縦に長くなるので 12 件まで
    readonly property var networks: dev
        ? dev.networks.values.slice()
            .sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength))
            .slice(0, 12)
        : []
    readonly property var wiredDevices: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
    property var pskTarget: null    // パスワード入力中のネットワーク
    property string message: ""

    function needsPsk(n) {
        return n.security === WifiSecurityType.WpaPsk
            || n.security === WifiSecurityType.Wpa2Psk
            || n.security === WifiSecurityType.Sae;
    }

    // 有線: 接続中なら切断。未接続なら保存済みの接続で接続（なければ自動接続を許可して NM に任せる）
    function activateWired(d) {
        message = "";
        if (d.connected) {
            d.disconnect();
        } else {
            d.autoconnect = true;
            const n = d.networks.values[0];
            if (n) n.connect();
        }
    }

    function activate(n) {
        message = "";
        if (n.connected) n.disconnect();
        else if (n.known || !needsPsk(n)) n.connect();
        else pskTarget = n;
    }

    width: 300
    spacing: 8

    // パネルを開いている間だけスキャン
    Component.onCompleted: if (dev) dev.scannerEnabled = true
    Component.onDestruction: if (dev) dev.scannerEnabled = false

    component Heading: Text {
        color: Theme.subtle
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize - 1
    }

    // 有線 LAN（デバイスがある時だけ表示）
    Heading { text: "Wired"; visible: root.wiredDevices.length > 0 }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        visible: root.wiredDevices.length > 0

        Repeater {
            model: root.wiredDevices

            delegate: MenuItem {
                required property var modelData
                icon: modelData.connected ? Theme.icons.check : Theme.icons.ethernet
                label: `${modelData.name}   ${modelData.connected ? "Connected" : "Disconnected"}`
                onClicked: root.activateWired(modelData)
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.surfaceHover
        visible: root.wiredDevices.length > 0
    }

    // 見出し + Wi‑Fi のオン/オフ
    RowLayout {
        Layout.fillWidth: true

        Heading { text: "Wi-Fi"; Layout.fillWidth: true }

        Rectangle {
            id: toggle
            readonly property bool on: Networking.wifiEnabled
            implicitWidth: 36
            implicitHeight: 20
            radius: 10
            color: on ? Theme.accent : Theme.surfaceHover
            opacity: Networking.wifiHardwareEnabled ? 1 : 0.4
            Behavior on color { ColorAnimation { duration: Theme.animMs } }

            Rectangle {
                width: 14
                height: 14
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: toggle.on ? parent.width - width - 3 : 3
                color: Theme.fg
                Behavior on x { NumberAnimation { duration: Theme.animMs } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: Networking.wifiHardwareEnabled
                onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }
    }

    // ネットワーク一覧
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        visible: Networking.wifiEnabled

        Repeater {
            model: root.networks

            delegate: MenuItem {
                id: item
                required property var modelData

                icon: modelData.connected ? Theme.icons.check
                    : root.needsPsk(modelData) ? Theme.icons.lock
                    : ""
                label: `${modelData.name}   ${Math.round(modelData.signalStrength * 100)}%`
                       + (modelData.stateChanging ? "   …" : "")
                highlighted: root.pskTarget === modelData
                onClicked: root.activate(modelData)

                Connections {
                    target: item.modelData
                    function onConnectionFailed(reason) {
                        if (reason === ConnectionFailReason.NoSecrets) {
                            root.pskTarget = item.modelData;
                            root.message = "Wrong password";
                        } else {
                            root.message = "Connection failed";
                        }
                    }
                }
            }
        }

        Heading {
            visible: root.networks.length === 0
            text: "Scanning…"
            Layout.leftMargin: 10
            Layout.topMargin: 4
        }
    }

    // パスワード入力
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: root.pskTarget !== null

        Heading { text: `Password for ${root.pskTarget?.name ?? ""}` }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: psk.activeFocus ? Theme.accent : Theme.surfaceHover

            TextInput {
                id: psk
                anchors.fill: parent
                anchors.margins: 8
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                color: Theme.fg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                clip: true

                onVisibleChanged: if (visible) { text = ""; forceActiveFocus(); }
                onAccepted: {
                    if (text !== "" && root.pskTarget) {
                        root.message = "";
                        root.pskTarget.connectWithPsk(text);
                        root.pskTarget = null;
                    }
                }
                Keys.onEscapePressed: root.pskTarget = null
            }
        }
    }

    Heading {
        visible: root.message !== ""
        text: root.message
        color: Theme.critical
    }

    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.surfaceHover }
    MenuItem {
        icon: Theme.icons.settings
        label: "Open nmtui"
        onClicked: {
            Quickshell.execDetached(["kitty", "nmtui"]);
            root.panel.openPopup = "";
        }
    }
}
