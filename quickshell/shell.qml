import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import QtQuick

// Layout (left → right):
//  [clock] [workspaces] [active window]  ···  [cpu/ram] [NOTCH] [music]  ···  [wifi] [bt] [battery]
// Each group is an independent floating pill. The bar itself is transparent.

PanelWindow {
    id: root

    anchors { top: true; left: true; right: true }
    implicitHeight: 40
    color: "transparent"

    // ── Theme ─────────────────────────────────────────────────────────────
    readonly property color colBlue:   "#8fc6f8"
    readonly property color colPink:   "#fbb7d3"
    readonly property color colBg:     Qt.rgba(0.118, 0.118, 0.180, 0.88)
    readonly property color colDiv:    Qt.rgba(0.682, 0.839, 0.945, 0.18)
    readonly property color colFaded:  Qt.rgba(1, 1, 1, 0.45)
    readonly property color colWsAct:  Qt.rgba(0.976, 0.753, 0.796, 0.30)
    readonly property color colWsBase: Qt.rgba(0.682, 0.839, 0.945, 0.12)
    readonly property int   pillH:     32
    readonly property int   pillR:     9
    readonly property int   topPad:    6   // (40 - 28) / 2
    readonly property int   gap:       6   // space between pills
    readonly property int   notchW:    240  // MacBook Pro 14″ notch width (logical px)

    // ── Notch dead-zone ───────────────────────────────────────────────────
    Item {
        id: notch
        width: root.notchW
        anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
    }

    // ── MPRIS reactive tracker ────────────────────────────────────────────
    Item { visible: false; width: 0; height: 0
        Repeater { id: mprisRepeater; model: Mpris.players; delegate: Item {} }
    }

    // ══════════════════════════════════════════════════════════════════════
    // LEFT GROUP  —  clock · workspaces · active window
    // ══════════════════════════════════════════════════════════════════════
    Row {
        id: leftGroup
        anchors { left: parent.left; top: parent.top; leftMargin: 8; topMargin: root.topPad }
        height: root.pillH
        spacing: root.gap
        // cap width so we never overlap the perf pill
        width: Math.min(implicitWidth, perfPill.x - 8 - root.gap)
        clip: true

        // ── Clock pill ────────────────────────────────────────────────────
        Rectangle {
            height: parent.height
            width:  clockLbl.implicitWidth + 22
            radius: root.pillR; color: root.colBg
            Text {
                id: clockLbl
                anchors.centerIn: parent
                color: root.colBlue; font.pixelSize: 12; font.bold: true
                text: Qt.formatDateTime(new Date(), "ddd d MMM  hh:mm")
                Timer { interval: 10000; running: true; repeat: true
                    onTriggered: clockLbl.text = Qt.formatDateTime(new Date(), "ddd d MMM  hh:mm") }
            }
        }

        // ── Workspaces pill ───────────────────────────────────────────────
        Rectangle {
            height: parent.height
            width:  Math.max(wsRow.implicitWidth + 16, 40)
            radius: root.pillR; color: root.colBg
            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        required property var modelData
                        width: wsLbl.implicitWidth + 12; height: 20; radius: height / 2
                        color: modelData.focused ? root.colWsAct
                             : modelData.active  ? root.colWsBase : "transparent"
                        border.color: modelData.urgent  ? root.colPink
                                    : modelData.focused ? root.colPink : root.colBlue
                        border.width: 1
                        Text {
                            id: wsLbl; anchors.centerIn: parent
                            text: modelData.name
                            color: modelData.focused ? root.colPink : root.colBlue
                            font.pixelSize: 11; font.bold: modelData.focused
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: modelData.activate()
                        }
                    }
                }
            }
        }

        // ── Updates pill ──────────────────────────────────────────────────
        Rectangle {
            id: updatesPill
            height: parent.height
            width: updatesRow.implicitWidth + 22
            radius: root.pillR; color: root.colBg
            property int count: 0

            Row {
                id: updatesRow; anchors.centerIn: parent; spacing: 5
                Text {
                    text: "󰅢"; font.pixelSize: 13
                    color: updatesPill.count > 0 ? root.colPink : root.colFaded
                }
                Text {
                    text: updatesPill.count > 0 ? updatesPill.count + " update" + (updatesPill.count === 1 ? "" : "s") : "0"
                    color: updatesPill.count > 0 ? root.colPink : root.colFaded
                    font.pixelSize: 11
                }
            }

            Process {
                id: checkUpdatesProc
                command: ["bash", "-c", "checkupdates 2>/dev/null | wc -l"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: updatesPill.count = parseInt(this.text.trim()) || 0
                }
            }
            // Check on startup and every 5 minutes
            Timer { interval: 300000; running: true; repeat: true; onTriggered: checkUpdatesProc.running = true }

            Process { id: yayProc; command: ["kitty", "sh", "-c", "yay -Syu; read -rsp 'Press any key to close...'"] }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    yayProc.running = true
                    // re-check after a delay so the count refreshes post-update
                    refreshTimer.restart()
                }
            }
            Timer { id: refreshTimer; interval: 120000; onTriggered: checkUpdatesProc.running = true }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // PERF PILL  —  CPU · RAM  (left of notch)
    // ══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: perfPill
        height: root.pillH; radius: root.pillR; color: root.colBg
        width: perfRow.implicitWidth + 22
        anchors { right: parent.horizontalCenter; top: parent.top; rightMargin: root.notchW / 2 + root.gap; topMargin: root.topPad }

        property real cpuPct:   0
        property real prevIdle: 0; property real prevTotal: 0

        Row {
            id: perfRow; anchors.centerIn: parent; spacing: 6
            Text { text: "CPU"; color: root.colPink; font.pixelSize: 10; font.bold: true }
            Text { id: cpuLbl; text: Math.round(perfPill.cpuPct) + "%"; color: root.colBlue; font.pixelSize: 11 }
            Rectangle { width: 1; height: 14; color: root.colDiv }
            Text { text: "RAM"; color: root.colPink; font.pixelSize: 10; font.bold: true }
            Text { id: ramLbl; text: "—"; color: root.colBlue; font.pixelSize: 11 }
        }

        Process {
            id: cpuProc
            command: ["bash", "-c", "awk '/^cpu /{print $2,$3,$4,$5,$6,$7,$8}' /proc/stat"]
            running: true
            stdout: StdioCollector {
                onStreamFinished: {
                    var p = this.text.trim().split(/\s+/).map(Number)
                    var idle  = p[3]
                    var total = p.reduce(function(a,b){ return a+b }, 0)
                    if (perfPill.prevTotal > 0) {
                        var dT = total - perfPill.prevTotal
                        var dI = idle  - perfPill.prevIdle
                        perfPill.cpuPct = dT > 0 ? (1 - dI / dT) * 100 : 0
                    }
                    perfPill.prevIdle = idle; perfPill.prevTotal = total
                }
            }
        }
        Timer { interval: 2000; running: true; repeat: true; onTriggered: cpuProc.running = true }

        Process {
            id: ramProc
            command: ["bash", "-c", "free -g | awk 'NR==2{printf \"%dG/%dG\", $3, $2}'"]
            running: true
            stdout: StdioCollector { onStreamFinished: ramLbl.text = this.text.trim() }
        }
        Timer { interval: 5000; running: true; repeat: true; onTriggered: ramProc.running = true }
    }

    // ══════════════════════════════════════════════════════════════════════
    // MUSIC PILL  —  MPRIS controls  (right of notch)
    // ══════════════════════════════════════════════════════════════════════
    Rectangle {
        id: musicPill
        height: root.pillH; radius: root.pillR; color: root.colBg
        width: musicRow.implicitWidth + 22
        anchors { left: parent.horizontalCenter; top: parent.top; leftMargin: root.notchW / 2 + root.gap; topMargin: root.topPad }
        visible: mprisRepeater.count > 0

        property var player: mprisRepeater.count > 0 ? Mpris.players.values[0] : null

        Row {
            id: musicRow; anchors.centerIn: parent; spacing: 6

            // Prev
            Text {
                text: "⏮"; font.pixelSize: 11
                color: musicPill.player && musicPill.player.canGoPrevious ? root.colBlue : root.colFaded
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (musicPill.player && musicPill.player.canGoPrevious) musicPill.player.previous() } }
            }
            // Play/Pause
            Text {
                text: musicPill.player && musicPill.player.isPlaying ? "⏸" : "▶"
                font.pixelSize: 12; color: root.colPink
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (musicPill.player && musicPill.player.canTogglePlaying) musicPill.player.togglePlaying() } }
            }
            // Track info (single line: artist — title)
            Text {
                width: Math.min(implicitWidth, 160)
                text: {
                    if (!musicPill.player) return "—"
                    var t = musicPill.player.trackTitle   || "Unknown"
                    var a = musicPill.player.trackArtist  || ""
                    return a ? a + "  —  " + t : t
                }
                color: root.colBlue; font.pixelSize: 11
                elide: Text.ElideRight
            }
            // Next
            Text {
                text: "⏭"; font.pixelSize: 11
                color: musicPill.player && musicPill.player.canGoNext ? root.colBlue : root.colFaded
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: { if (musicPill.player && musicPill.player.canGoNext) musicPill.player.next() } }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    // RIGHT GROUP  —  wifi · bluetooth · battery  (right → left order in Row)
    // ══════════════════════════════════════════════════════════════════════
    Row {
        anchors { right: parent.right; top: parent.top; rightMargin: 8; topMargin: root.topPad }
        height: root.pillH
        spacing: root.gap
        layoutDirection: Qt.RightToLeft  // first item = rightmost

        // ── Battery pill (far right) ──────────────────────────────────────
        Rectangle {
            height: parent.height; width: battRow.implicitWidth + 22
            radius: root.pillR; color: root.colBg
            visible: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
            Row {
                id: battRow; anchors.centerIn: parent; spacing: 4
                Text {
                    font.pixelSize: 13
                    color: UPower.displayDevice.percentage * 100 <= 20 ? "#FF6B6B" : root.colPink
                    text: {
                        var pct = UPower.displayDevice.percentage * 100
                        if (UPower.displayDevice.state === UPowerDeviceState.Charging ||
                            UPower.displayDevice.state === UPowerDeviceState.FullyCharged) return "⚡"
                        if (pct > 80) return "󰁹"
                        if (pct > 60) return "󰂁"
                        if (pct > 40) return "󰁾"
                        if (pct > 20) return "󰁼"
                        return "󰁺"
                    }
                }
                Text {
                    text: Math.round(UPower.displayDevice.percentage * 100) + "%"
                    color: UPower.displayDevice.percentage * 100 <= 20 ? "#FF6B6B" : root.colPink
                    font.pixelSize: 12
                }
            }
        }

        // ── Bluetooth pill ────────────────────────────────────────────────
        Rectangle {
            id: btPillRect
            height: parent.height; width: btRow.implicitWidth + 22
            radius: root.pillR; color: root.colBg
            visible: Bluetooth.defaultAdapter !== null
            property int connectedCount: 0
            Row {
                id: btRow; anchors.centerIn: parent; spacing: 5
                Text {
                    text: "󰂯"; font.pixelSize: 13
                    color: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? root.colBlue : root.colDiv
                }
                Text {
                    text: {
                        if (!Bluetooth.defaultAdapter || !Bluetooth.defaultAdapter.enabled) return "Off"
                        var n = btPillRect.connectedCount
                        return n > 0 ? n + (n === 1 ? " device" : " devices") : "On"
                    }
                    color: root.colBlue; font.pixelSize: 11
                }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { if (Bluetooth.defaultAdapter)
                    Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled } }
            Process {
                id: btDevProc
                command: ["bash", "-c", "bluetoothctl devices Connected 2>/dev/null | wc -l"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: btPillRect.connectedCount = parseInt(this.text.trim()) || 0
                }
            }
            Timer { interval: 10000; running: true; repeat: true; onTriggered: btDevProc.running = true }
        }

        // ── WiFi pill ─────────────────────────────────────────────────────
        Rectangle {
            id: wifiPill
            height: parent.height; width: wifiRow.implicitWidth + 22
            radius: root.pillR; color: root.colBg
            property string ssid: "…"
            Row {
                id: wifiRow; anchors.centerIn: parent; spacing: 5
                Text { text: "󰖩"; font.pixelSize: 13; color: root.colBlue }
                Text { text: wifiPill.ssid; color: root.colBlue; font.pixelSize: 11 }
            }
            Process {
                id: wifiLaunchProc
                command: ["kitty", "sh", "-c", "nmtui; read -rsp 'Press any key to close...'"]
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: wifiLaunchProc.running = true }
            Process {
                id: wifiProc
                command: ["bash", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: wifiPill.ssid = this.text.trim() || "—"
                }
            }
            Timer { interval: 15000; running: true; repeat: true; onTriggered: wifiProc.running = true }
        }
    }
}
