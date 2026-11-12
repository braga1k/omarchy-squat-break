import QtQuick
import Quickshell
import "plugin" as Squats
import "plugin/Security.js" as Security
ShellRoot {
    Squats.Service { id: service }
    Timer {
        interval: 100; repeat: true; running: true
        onTriggered: {
            if (service.failed) { console.error("SQUAT_TEST_FAILED ledger"); Qt.quit(); return }
            if (!service.ready) return
            var malicious = '<img src="https://example.invalid/tracker">&<b>squats</b>'
            var cleaned = Security.plain(malicious)
            if (/[<>&]/.test(cleaned) || Security.plain('x'.repeat(5000)).length > 1024) {
                console.error("SQUAT_TEST_FAILED markup"); Qt.quit(); return
            }
            console.log("SQUAT_TEST_PASSED", JSON.stringify(service.state))
            Qt.quit()
        }
    }
    Timer { interval: 10000; running: true; onTriggered: { console.error("SQUAT_TEST_FAILED timeout"); Qt.quit() } }
}
