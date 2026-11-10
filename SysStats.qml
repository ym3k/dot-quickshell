pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// CPU / メモリ / 温度 / 画面輝度 / ネットワーク
Singleton {
    id: root

    property int cpu: 0
    property int memory: 0
    property int temperature: 0
    property int backlight: -1        // -1 = バックライトなし
    // ネットワーク（NetworkManager の D-Bus イベントで自動更新）
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var activeWifi: wifiDevice?.networks.values.find(n => n.connected) ?? null
    readonly property string netType: wiredDevice ? "ethernet" : activeWifi ? "wifi" : ""   // "wifi" | "ethernet" | ""
    readonly property string netName: wiredDevice ? wiredDevice.name : activeWifi?.name ?? ""
    readonly property int netSignal: Math.round((activeWifi?.signalStrength ?? 0) * 100)
    readonly property string netIface: wiredDevice ? wiredDevice.name : activeWifi ? wifiDevice.name : ""

    // IP アドレスとゲートウェイ（Networking モジュールにはないので ip コマンドで取得）。
    // ツールチップを出す時だけ呼ぶ
    property string netIp: ""
    property string netGateway: ""
    function refreshIp() {
        if (netIface === "") {
            netIp = "";
            netGateway = "";
            return;
        }
        ipProc.running = true;
    }

    Process {
        id: ipProc
        command: ["sh", "-c",
            "ip -4 -o addr show dev \"$1\" | awk '{print $4}' | head -n1; ip route show default dev \"$1\" | awk '{print $3; exit}'",
            "sh", root.netIface]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                root.netIp = (l[0] ?? "").trim();
                root.netGateway = (l[1] ?? "").trim();
            }
        }
    }
    property string platformProfile: ""   // low-power | balanced | performance など

    property var lastCpu: null

    // 輝度変更（brightnessctl が必要）。表示は先に更新し、次のポーリングで補正
    function changeBacklight(up) {
        if (backlight < 0) return;
        Quickshell.execDetached(["brightnessctl", "set", up ? "5%+" : "5%-"]);
        backlight = Math.max(0, Math.min(100, backlight + (up ? 5 : -5)));
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                if (dt > 0)
                    root.cpu = Math.round(100 * (1 - (idle - root.lastCpu.idle) / dt));
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const get = k => Number(t.match(new RegExp(k + ":\\s+(\\d+)"))[1]);
            const total = get("MemTotal");
            root.memory = Math.round(100 * (total - get("MemAvailable")) / total);
        }
    }

    FileView {
        id: thermal
        path: "/sys/class/thermal/thermal_zone0/temp"   // 必要なら zone を変更
        onLoaded: root.temperature = Math.round(Number(text()) / 1000)
    }

    // 元の power-profile.sh と同じファイルを読む
    FileView {
        id: platformProfileFile
        path: "/sys/firmware/acpi/platform_profile"
        onLoaded: root.platformProfile = text().trim()
    }

    // バックライト: デバイス名を起動時に 1 回だけ調べ、あとは sysfs を直接読む
    property string backlightDir: ""
    property int backlightMax: 0

    Process {
        running: true
        command: ["sh", "-c", "ls /sys/class/backlight | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dev = text.trim();
                if (dev !== "") root.backlightDir = "/sys/class/backlight/" + dev;
            }
        }
    }

    FileView {
        id: backlightMaxFile
        path: root.backlightDir ? root.backlightDir + "/max_brightness" : ""
        onLoaded: root.backlightMax = Number(text())
    }

    FileView {
        id: backlightFile
        path: root.backlightDir ? root.backlightDir + "/actual_brightness" : ""
        onLoaded: {
            if (root.backlightMax > 0)
                root.backlight = Math.round(100 * Number(text()) / root.backlightMax);
        }
    }

    // CPU・メモリ・温度・電源プロファイル（waybar の既定より短めの 5 秒）
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            thermal.reload();
            platformProfileFile.reload();
        }
    }

    // 輝度（ファイルを読むだけなので軽い。キー操作が早めに反映されるよう 2 秒）
    Timer {
        interval: 2000
        running: root.backlightDir !== ""
        repeat: true
        onTriggered: backlightFile.reload()
    }
}
