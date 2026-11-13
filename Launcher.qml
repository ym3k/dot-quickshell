import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets

// ランチャー（wofi の代わり）
//   apps  : アプリ起動（drun 相当）        qs ipc call launcher toggle apps
//   emoji : 絵文字を選んでコピー           qs ipc call launcher toggle emoji
//   run   : kitty + fish でコマンド実行    qs ipc call launcher toggle run
// 操作: 入力で絞り込み / ↑↓（絵文字は ←→ も）で選択 / Enter で決定 / Tab でモード切替 / Esc か外側クリックで閉じる
PanelWindow {
    id: root

    property string mode: "apps"
    property string query: ""
    property int current: 0
    property var targetScreen: Quickshell.screens[0]

    readonly property var modes: ["apps", "emoji", "run"]

    function openMode(m) {
        targetScreen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
        mode = m;
        input.text = "";
        query = "";
        current = m === "run" ? -1 : 0;
        visible = true;
        input.forceActiveFocus();
    }

    function close() {
        visible = false;
    }

    function toggle(m) {
        if (visible && mode === m) close();
        else openMode(m);
    }

    // hyprland から呼ぶ: qs ipc call launcher toggle apps
    IpcHandler {
        target: "launcher"
        function toggle(mode: string): void { root.toggle(mode || "apps"); }
        function open(mode: string): void { root.openMode(mode || "apps"); }
        function close(): void { root.close(); }
    }

    visible: false
    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell-launcher"

    // ───────────── アプリ ─────────────
    readonly property var apps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
    // 使用回数（モード別）。よく使うものほど上に出す
    property var usage: ({ apps: {}, emoji: {}, run: {} })

    FileView {
        id: usageFile
        path: Quickshell.statePath("launcher-usage.json")
        printErrors: false
        onLoaded: {
            try {
                const u = JSON.parse(text());
                // 旧形式（アプリだけの記録）からの移行
                root.usage = u.apps ? Object.assign({ apps: {}, emoji: {}, run: {} }, u) : { apps: u, emoji: {}, run: {} };
            } catch (e) {
                root.usage = { apps: {}, emoji: {}, run: {} };
            }
        }
    }

    function uses(kind, key) {
        return usage[kind]?.[key] ?? 0;
    }

    // モードごとに覚える件数の上限。超えたら回数の少ないもの（同数なら古いもの）から消す
    readonly property var usageLimit: ({ apps: 300, emoji: 300, run: 200 })

    function bump(kind, key) {
        const u = JSON.parse(JSON.stringify(usage));
        const m = u[kind] = u[kind] ?? {};
        m[key] = (m[key] ?? 0) + 1;

        const keys = Object.keys(m);   // 追加した順（古い順）
        const over = keys.length - (usageLimit[kind] ?? 200);
        if (over > 0) {
            keys.filter(k => k !== key)                 // 今使ったものは消さない
                .map((k, i) => ({ k: k, i: i, n: m[k] }))
                .sort((a, b) => a.n - b.n || a.i - b.i)
                .slice(0, over)
                .forEach(o => delete m[o.k]);
        }

        usage = u;
        usageFile.setText(JSON.stringify(u));
    }

    // 回数の多い順（同数なら元の順番のまま）に並べ替える
    function byUsage(list, kind, keyOf) {
        return list.map((x, i) => ({ x: x, i: i, n: uses(kind, keyOf(x)) }))
            .sort((a, b) => b.n - a.n || a.i - b.i)
            .map(o => o.x);
    }

    function appScore(e, q) {
        const n = (e.name ?? "").toLowerCase();
        if (n === q) return 100;
        if (n.startsWith(q)) return 80;
        if (n.split(/[\s\-_.]+/).some(w => w.startsWith(q))) return 60;
        if (n.includes(q)) return 40;
        const extra = [e.genericName ?? "", e.comment ?? "", Array.prototype.join.call(e.keywords ?? [], " ")]
            .join(" ").toLowerCase();
        if (extra.includes(q)) return 20;
        let i = 0;                       // 飛び飛びの一致（例: "ffx" → firefox）
        for (const ch of n) if (ch === q[i]) i++;
        return i === q.length ? 10 : 0;
    }

    readonly property var appResults: {
        if (mode !== "apps") return [];
        const q = query.trim().toLowerCase();
        const use = id => uses("apps", id);
        if (q === "")
            return apps.slice().sort((a, b) => use(b.id) - use(a.id) || a.name.localeCompare(b.name)).slice(0, 60);
        return apps.map(e => ({ e: e, s: appScore(e, q) }))
            .filter(x => x.s > 0)
            .sort((a, b) => b.s - a.s || use(b.e.id) - use(a.e.id))
            .map(x => x.e)
            .slice(0, 60);
    }

    function launchApp(e) {
        if (!e) return;
        e.execute();
        bump("apps", e.id);
        close();
    }

    // ───────────── 絵文字 ─────────────
    // unicode-emoji パッケージのデータを使う（肌の色違いは省略）
    property var emojis: []

    FileView {
        id: emojiFile
        path: root.mode === "emoji" || root.emojis.length > 0 ? "/usr/share/unicode/emoji/emoji-test.txt" : ""
        printErrors: false
        onLoaded: {
            if (root.emojis.length > 0) return;
            const out = [];
            for (const line of text().split("\n")) {
                if (!line.includes("; fully-qualified")) continue;
                const m = line.match(/#\s*(\S+)\s+E[\d.]+\s+(.+)$/);
                if (m && !m[2].includes("skin tone")) out.push({ c: m[1], n: m[2] });
            }
            root.emojis = out;
        }
    }

    readonly property var emojiResults: {
        if (mode !== "emoji") return [];
        const words = query.trim().toLowerCase().split(/\s+/).filter(w => w);
        const list = words.length === 0 ? emojis : emojis.filter(x => words.every(w => x.n.includes(w)));
        return byUsage(list, "emoji", x => x.c);
    }

    function pickEmoji(x) {
        if (!x) return;
        Quickshell.execDetached(["wl-copy", x.c]);
        bump("emoji", x.c);
        close();
    }

    // ───────────── コマンド実行 ─────────────
    // 候補はランチャーから実行したコマンド（回数の多い順）だけ。fish の履歴は読まない
    readonly property var runResults: {
        if (mode !== "run") return [];
        const q = query.trim().toLowerCase();
        const used = usage.run ?? {};
        return Object.keys(used)
            .filter(c => q === "" || c.toLowerCase().includes(q))
            .sort((a, b) => used[b] - used[a])
            .slice(0, 8);
    }

    // keepOpen が true なら実行後も fish を残す（既定はコマンドが終わったら kitty も閉じる）
    function runCommand(cmd, keepOpen) {
        if (!cmd || cmd.trim() === "") return;
        // -C: 実行したあと fish をそのまま使える / -c: 実行したら終了（kitty も閉じる）
        Quickshell.execDetached(["kitty", "fish", keepOpen ? "-C" : "-c", cmd]);
        bump("run", cmd.trim());
        close();
    }

    // ───────────── 電卓（Apps モードで数式を入力すると先頭に答えを出す） ─────────────
    // eval は使わず、四則演算・累乗・関数だけを解釈する小さなパーサーで計算する
    readonly property var calcFuncs: ({
        sqrt: Math.sqrt, abs: Math.abs, round: Math.round, floor: Math.floor, ceil: Math.ceil,
        sin: Math.sin, cos: Math.cos, tan: Math.tan, asin: Math.asin, acos: Math.acos, atan: Math.atan,
        log: Math.log10, ln: Math.log, exp: Math.exp
    })
    readonly property var calcConsts: ({ pi: Math.PI, e: Math.E })

    function calc(src) {
        const text = src.trim().toLowerCase().replace(/×/g, "*").replace(/÷/g, "/").replace(/\*\*/g, "^");
        // 数式らしいものだけ（数字と、演算子か関数を含む）。ただの数字やアプリ名では出さない
        if (!/[0-9]/.test(text) && !/\b(pi|e)\b/.test(text)) return null;
        if (!/[-+*/%^()]/.test(text)) return null;

        const tokens = text.match(/\d+\.?\d*|\.\d+|[a-z]+|[-+*/%^()]|\S/g) ?? [];
        let pos = 0;
        const peek = () => tokens[pos];
        const next = () => tokens[pos++];

        function expr() {                       // 足し算・引き算
            let v = term();
            while (peek() === "+" || peek() === "-") v = next() === "+" ? v + term() : v - term();
            return v;
        }
        function term() {                       // 掛け算・割り算・余り
            let v = power();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = next(), r = power();
                v = op === "*" ? v * r : op === "/" ? v / r : v % r;
            }
            return v;
        }
        function power() {                      // 累乗（右から計算）
            const b = unary();
            if (peek() === "^") { next(); return Math.pow(b, power()); }
            return b;
        }
        function unary() {
            if (peek() === "-") { next(); return -unary(); }
            if (peek() === "+") { next(); return unary(); }
            return primary();
        }
        function primary() {
            const t = next();
            if (t === undefined) throw "end";
            if (t === "(") { const v = expr(); if (next() !== ")") throw "paren"; return v; }
            if (/^[\d.]/.test(t)) return parseFloat(t);
            if (root.calcConsts[t] !== undefined) return root.calcConsts[t];
            if (root.calcFuncs[t]) {
                if (next() !== "(") throw "func";
                const v = expr();
                if (next() !== ")") throw "paren";
                return root.calcFuncs[t](v);
            }
            throw "token";
        }

        try {
            const v = expr();
            if (pos !== tokens.length || !isFinite(v)) return null;
            return String(Number(v.toPrecision(12)));   // 浮動小数の誤差（0.1+0.2 など）を丸める
        } catch (e) {
            return null;
        }
    }

    readonly property var calcResult: mode === "apps" ? calc(query) : null

    function copyCalc() {
        if (calcResult === null) return;
        Quickshell.execDetached(["wl-copy", calcResult]);
        close();
    }

    // ───────────── 共通 ─────────────
    readonly property int count: mode === "apps" ? appResults.length
                               : mode === "emoji" ? emojiResults.length
                               : runResults.length

    function move(d) {
        const min = mode === "run" || (mode === "apps" && calcResult !== null) ? -1 : 0;
        current = Math.max(min, Math.min(count - 1, current + d));
    }

    function activate(shift) {
        if (mode === "apps" && current < 0) copyCalc();
        else if (mode === "apps") launchApp(appResults[current]);
        else if (mode === "emoji") pickEmoji(emojiResults[current]);
        else runCommand(current >= 0 ? runResults[current] : input.text, shift);
    }

    // 背景（外側クリックで閉じる）
    Rectangle {
        anchors.fill: parent
        color: "#59000000"
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(40, (parent.height - 480) / 2)
        width: 600
        height: content.implicitHeight + 24
        radius: Theme.radius + 4
        color: Theme.popupBg
        border.width: 1
        border.color: Theme.barBorder

        MouseArea { anchors.fill: parent }   // 枠内のクリックで閉じないように

        ColumnLayout {
            id: content
            x: 12
            y: 12
            width: parent.width - 24
            spacing: 10

            // モード切り替え
            RowLayout {
                spacing: 4
                Repeater {
                    model: [["apps", "Apps"], ["emoji", "Emoji"], ["run", "Run"]]
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: root.mode === modelData[0]
                        implicitWidth: label.implicitWidth + 20
                        implicitHeight: 24
                        radius: Theme.radius
                        color: on ? Theme.accent : (tabMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
                        Behavior on color { ColorAnimation { duration: Theme.animMs } }

                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: parent.modelData[1]
                            color: parent.on ? Theme.onAccent : Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                        MouseArea {
                            id: tabMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openMode(parent.modelData[0])
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                Text {
                    text: "Tab: switch   Esc: close"
                    color: Theme.subtle
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize - 2
                }
            }

            // 入力欄
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 38
                radius: Theme.radius
                color: Theme.surface
                border.width: 1
                border.color: Theme.accent

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.mode === "run" ? "\uf120" : "\uf002"
                    color: Theme.subtle
                    font.family: Theme.iconFontFamily
                    font.pixelSize: Theme.fontSize
                }

                TextInput {
                    id: input
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.fg
                    selectionColor: Theme.accent
                    selectedTextColor: Theme.onAccent
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize + 2
                    clip: true

                    onTextChanged: {
                        root.query = text;
                        root.current = root.mode === "run" || (root.mode === "apps" && root.calcResult !== null) ? -1 : 0;
                    }

                    Keys.onPressed: e => {
                        const cols = emojiGrid.columns;
                        if (e.key === Qt.Key_Escape) root.close();
                        else if (e.key === Qt.Key_Tab) root.openMode(root.modes[(root.modes.indexOf(root.mode) + 1) % root.modes.length]);
                        else if (e.key === Qt.Key_Down) root.move(root.mode === "emoji" ? cols : 1);
                        else if (e.key === Qt.Key_Up) root.move(root.mode === "emoji" ? -cols : -1);
                        else if (root.mode === "emoji" && e.key === Qt.Key_Right) root.move(1);
                        else if (root.mode === "emoji" && e.key === Qt.Key_Left) root.move(-1);
                        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.activate(e.modifiers & Qt.ShiftModifier);
                        else return;
                        e.accepted = true;
                    }

                    Text {
                        visible: input.text === ""
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.mode === "apps" ? "Search apps…  or calculate (12*34, sqrt(2)^3)"
                            : root.mode === "emoji" ? "Search emoji (english)…"
                            : "Run in kitty + fish…   (Shift+Enter: keep open)"
                        color: Theme.subtle
                        font: input.font
                    }
                }
            }

            // ── 電卓の答え ──
            Rectangle {
                visible: root.calcResult !== null
                Layout.fillWidth: true
                implicitHeight: 48
                radius: Theme.radius
                color: root.current < 0 ? Theme.surfaceHover : "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 12

                    Text {
                        Layout.preferredWidth: 26
                        horizontalAlignment: Text.AlignHCenter
                        text: "\uf1ec"    // 電卓
                        color: Theme.accent
                        font.family: Theme.iconFontFamily
                        font.pixelSize: Theme.fontSize + 6
                    }
                    Text {
                        text: "= " + (root.calcResult ?? "")
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize + 6
                        font.bold: true
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: "Enter: copy"
                        color: Theme.subtle
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize - 1
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.current = -1
                    onClicked: root.copyCalc()
                }
            }

            // ── アプリ一覧 ──
            ListView {
                id: appList
                visible: root.mode === "apps"
                Layout.fillWidth: true
                implicitHeight: Math.min(contentHeight, 40 * 9)
                clip: true
                model: root.appResults
                currentIndex: root.current
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: appRow
                    required property var modelData
                    required property int index
                    width: appList.width
                    height: 40
                    radius: Theme.radius
                    color: index === root.current ? Theme.surfaceHover : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 10
                        spacing: 12

                        IconImage {
                            implicitSize: 26
                            source: Quickshell.iconPath(appRow.modelData.icon, "application-x-executable")
                            asynchronous: true
                        }
                        Text {
                            text: appRow.modelData.name
                            color: Theme.fg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize + 1
                        }
                        Text {
                            Layout.fillWidth: true
                            text: appRow.modelData.genericName ?? ""
                            elide: Text.ElideRight
                            color: Theme.subtle
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize - 1
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.current = appRow.index
                        onClicked: root.launchApp(appRow.modelData)
                    }
                }
            }

            // ── 絵文字 ──
            GridView {
                id: emojiGrid
                readonly property int columns: Math.max(1, Math.floor(width / cellWidth))
                visible: root.mode === "emoji"
                Layout.fillWidth: true
                implicitHeight: 46 * 7
                clip: true
                cellWidth: 48
                cellHeight: 46
                model: root.emojiResults
                currentIndex: root.current
                onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: cell
                    required property var modelData
                    required property int index
                    width: 44
                    height: 42
                    radius: Theme.radius
                    color: index === root.current ? Theme.surfaceHover : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData.c
                        font.pixelSize: 24
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.current = cell.index
                        onClicked: root.pickEmoji(cell.modelData)
                    }
                }
            }

            Text {
                visible: root.mode === "emoji"
                Layout.fillWidth: true
                text: root.emojis.length === 0 ? "emoji-test.txt not found (pacman -S unicode-emoji)"
                    : (root.emojiResults[root.current]?.n ?? "") + "   — Enter: copy"
                elide: Text.ElideRight
                color: Theme.subtle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize - 1
            }

            // ── コマンド（ランチャーで実行した履歴） ──
            ListView {
                id: runList
                visible: root.mode === "run" && count > 0
                Layout.fillWidth: true
                implicitHeight: contentHeight
                interactive: false
                model: root.runResults
                currentIndex: root.current

                delegate: Rectangle {
                    id: runRow
                    required property var modelData
                    required property int index
                    width: runList.width
                    height: 32
                    radius: Theme.radius
                    color: index === root.current ? Theme.surfaceHover : "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 12
                        width: parent.width - 24
                        text: runRow.modelData
                        elide: Text.ElideRight
                        color: Theme.fg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: root.current = runRow.index
                        acceptedButtons: Qt.LeftButton
                        onClicked: e => root.runCommand(runRow.modelData, e.modifiers & Qt.ShiftModifier)
                    }
                }
            }
        }
    }
}
