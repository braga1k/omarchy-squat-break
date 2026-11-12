import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "Security.js" as Security

Ui.BarWidget {
    id: root
    moduleName: "b1k.squats"
    readonly property var service: bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
    readonly property var state: service ? service.state : null
    property bool opened: false
    property bool popoutSwitchClosing: false
    property int count: state ? state.suggested : 20
    property int intervalDraft: state ? state.interval : 60
    property int suggestedDraft: state ? state.suggested : 20
    readonly property string minutes: state ? Commons.I18n.formatNumber(Math.ceil(service.remainingSeconds / 60)) : "—"
    readonly property string countdown: {
        if (!service || !service.ready) return "--:--"
        var seconds = service.remainingSeconds
        var mins = Math.floor(seconds / 60)
        var secs = seconds % 60
        var zero = Commons.I18n.formatNumber(0)
        return (mins < 10 ? zero : "") + Commons.I18n.formatNumber(mins)
            + ":" + (secs < 10 ? zero : "") + Commons.I18n.formatNumber(secs)
    }
    readonly property string statusText: service && service.failed ? strings.t("error")
        : !service || !service.ready ? strings.t("loading")
        : state.paused ? strings.t("paused")
        : state.due ? strings.t("due") : strings.t("next").arg(minutes)

    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
    function open() {
        if (state) {
            count = state.suggested
            intervalDraft = state.interval
            suggestedDraft = state.suggested
        }
        popoutSwitchClosing = false
        opened = true
    }
    function close() { opened = false }
    function closeForPopoutSwitch() { popoutSwitchClosing = true; close() }
    function act(action, args) { if (service) service.request(action, args || []) }
    function number(value) { return Commons.I18n.formatNumber(value || 0) }
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    Ui.WidgetButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰒡 " + root.number(root.state ? root.state.today : 0) + (root.vertical ? "\n" : " - ") + root.countdown
        active: root.state && root.state.due && !root.state.paused
        dimmed: root.state && root.state.paused
        tooltipText: Security.plain(strings.t("tooltip").arg(root.number(root.state ? root.state.today : 0)).arg(root.number(root.state ? root.state.total : 0)).arg(root.statusText))
        onPressed: function(b) { if (b === Qt.RightButton) root.act(root.state && root.state.paused ? "resume" : "pause"); else root.opened ? root.close() : root.open() }
    }

    Ui.KeyboardPanel {
        id: panel
        anchorItem: button
        bar: root.bar
        owner: root
        open: root.opened
        contentWidth: fittedContentWidth(Commons.Style.space(350))
        contentHeight: fittedContentHeight(column.implicitHeight)
        focusTarget: column
        Column {
            id: column
            width: parent.width
            spacing: Commons.Style.space(12)
            focus: true
            Keys.onEscapePressed: root.close()

            PlainText { text: strings.t("title"); font.pixelSize: Commons.Style.font.subtitle; font.bold: true }
            PlainText { width: parent.width; text: root.statusText; wrapMode: Text.WordWrap; color: Commons.Color.accent }
            Row {
                width: parent.width
                Column {
                    width: parent.width / 2
                    PlainText { text: strings.t("today"); opacity: 0.65 }
                    PlainText { text: root.number(root.state ? root.state.today : 0); font.pixelSize: Commons.Style.font.displayLarge; font.bold: true }
                }
                Column {
                    width: parent.width / 2
                    PlainText { text: strings.t("total"); opacity: 0.65 }
                    PlainText { text: root.number(root.state ? root.state.total : 0); font.pixelSize: Commons.Style.font.displayLarge; font.bold: true }
                }
            }
            Ui.PanelSeparator { width: parent.width }
            Ui.NumberField {
                id: countField
                label: strings.t("done")
                value: root.count
                from: 1; to: 1000
                fieldWidth: column.width
                onModified: function(value) { root.count = value }
            }
            Ui.Button {
                width: parent.width
                text: Security.plain(strings.tn("record", root.count).arg(root.number(root.count)))
                selected: true
                focusable: true
                enabled: !!root.service && root.service.ready && !root.service.failed && !root.service.busy
                onClicked: { countField.field.focus = false; root.act("add", [String(root.count)]) }
            }
            Row {
                width: parent.width
                spacing: Commons.Style.space(6)
                Ui.Button {
                    width: (column.width - parent.spacing) / 2
                    text: Security.plain(strings.t("undo")); focusable: true
                    enabled: !!root.state && root.state.canUndo && !root.service.busy && !root.service.failed
                    onClicked: root.act("undo")
                }
                Ui.Button {
                    width: (column.width - parent.spacing) / 2
                    text: Security.plain(strings.t("snooze")); focusable: true
                    enabled: !!root.service && root.service.ready && !root.service.busy && !root.service.failed
                    onClicked: root.act("snooze")
                }
            }
            Ui.PanelSeparator { width: parent.width }
            Row {
                width: parent.width
                spacing: Commons.Style.space(12)
                Ui.NumberField {
                    label: strings.t("interval")
                    value: root.intervalDraft; from: 1; to: 1440
                    fieldWidth: (column.width - parent.spacing) / 2
                    onModified: function(value) { root.intervalDraft = value }
                }
                Ui.NumberField {
                    label: strings.t("suggested")
                    value: root.suggestedDraft; from: 1; to: 1000
                    fieldWidth: (column.width - parent.spacing) / 2
                    onModified: function(value) { root.suggestedDraft = value }
                }
            }
            Row {
                width: parent.width
                spacing: Commons.Style.space(6)
                Ui.Button {
                    width: (column.width - parent.spacing) / 2
                    text: Security.plain(strings.t("save")); focusable: true
                    enabled: !!root.service && root.service.ready && !root.service.busy && !root.service.failed
                    onClicked: root.act("settings", [String(root.intervalDraft), String(root.suggestedDraft)])
                }
                Ui.Button {
                    width: (column.width - parent.spacing) / 2
                    text: Security.plain(strings.t(root.state && root.state.paused ? "resume" : "pause")); focusable: true
                    enabled: !!root.service && root.service.ready && !root.service.busy && !root.service.failed
                    onClicked: root.act(root.state && root.state.paused ? "resume" : "pause")
                }
            }

        }
    }
}
