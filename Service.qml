import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import "Security.js" as Security

Item {
    id: root
    property var state: ({today: 0, total: 0, interval: 60, suggested: 20, paused: false, due: false, remaining: 3600, canUndo: false, history: []})
    property double now: Date.now()
    property double sampledAt: Date.now()
    readonly property int remainingSeconds: state.paused ? state.remaining
        : Math.max(0, Math.ceil(state.remaining - (now - sampledAt) / 1000))
    property bool ready: false
    property bool failed: false
    property var queue: []
    readonly property bool busy: worker.running || queue.length > 0
    readonly property string helper: String(Qt.resolvedUrl("store.py")).replace(/^file:\/\//, "")

    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

    function request(action, values) {
        if (action === "tick" && busy) return
        if (queue.length >= 20) return
        queue = queue.concat([[action].concat(values || [])])
        drain()
    }
    function drain() {
        if (worker.running || queue.length === 0) return
        var next = queue[0]
        queue = queue.slice(1)
        worker.command = ["python3", helper].concat(next)
        worker.running = true
    }
    function notify() {
        if (notice.running) return
        notice.command = ["omarchy", "notification", "send", "--app-name", "Squat Break", "-u", "normal", "-t", "15000",
            Security.plain(strings.t("alert.title")),
            Security.plain(strings.tn("alert.body", state.suggested).arg(Commons.I18n.formatNumber(state.suggested))),
            "--exec", "omarchy-shell", "shell", "summon", "b1k.squats", "{}"]
        notice.running = true
    }
    // Update only the display each second; persistence still polls every 15s.
    Timer { interval: 1000; repeat: true; running: root.ready && !root.state.paused; onTriggered: root.now = Date.now() }
    Component.onCompleted: request("tick")
    Timer { interval: 15000; repeat: true; running: true; onTriggered: root.request("tick") }
    Process {
        id: worker
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                try {
                    var result = JSON.parse(text)
                    if (result.error) { root.failed = true; return }
                    root.now = Date.now()
                    root.sampledAt = root.now
                    root.state = result
                    root.failed = false
                    root.ready = true
                    if (result.alert) root.notify()
                } catch (error) { root.failed = true; console.warn("Squat ledger returned invalid JSON") }
            }
        }
        onExited: function(code) {
            if (code !== 0) root.failed = true
            Qt.callLater(root.drain)
        }
    }
    Process { id: notice }
    Commons.ShellIpc {
        target: "b1k.squats"
        function status(): string { return JSON.stringify(Object.assign({}, root.state, {remaining: root.remainingSeconds})) }
        function testAlert(): void { root.notify() }
        function refresh(): void { root.request("tick") }
        function add(count: int): void { root.request("add", [String(count)]) }
        function undo(): void { root.request("undo") }
        function pause(): void { root.request("pause") }
        function resume(): void { root.request("resume") }
        function snooze(): void { root.request("snooze") }
    }
}
