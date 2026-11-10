import QtQuick
import Quickshell.Services.UPower

BarModule {
    id: root

    readonly property UPowerDevice dev: UPower.displayDevice
    readonly property int pct: Math.round(dev.percentage <= 1 ? dev.percentage * 100 : dev.percentage)
    readonly property bool charging: dev.state === UPowerDeviceState.Charging
    readonly property bool plugged: !UPower.onBattery
    readonly property bool critical: pct <= 15 && !plugged
    property bool showTime: false
    property bool blink: false

    function formatTime(sec) {
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        return `${h} h ${m} min`;
    }

    visible: dev.ready && dev.isPresent

    label: {
        const icon = charging ? Theme.icons.charging
                   : plugged ? Theme.icons.plugged
                   : Theme.pick(Theme.icons.battery, pct);
        const value = showTime ? formatTime(charging ? dev.timeToFull : dev.timeToEmpty) : pct + "%";
        return `${value} <span style="font-size: 18px;">${icon}</span>`;
    }

    bg: critical ? (blink ? Theme.fg : Theme.disconnected)
      : plugged ? Theme.charging
      : Theme.battery
    fg: critical ? (blink ? Theme.dark : Theme.fg)
      : plugged ? Theme.fg
      : Theme.dark

    onClicked: showTime = !showTime

    Timer {
        interval: 500
        running: root.critical
        repeat: true
        onTriggered: root.blink = !root.blink
        onRunningChanged: if (!running) root.blink = false
    }
}
