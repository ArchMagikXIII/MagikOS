import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "magikos.system-update"

  property bool updateAvailable: false

  function refresh() {
    if (!updateProc.running) updateProc.running = true
  }

  function clear() { updateAvailable = false }

  function runUpdate() {
    if (root.bar) root.bar.run("magikos-launch-floating-terminal-with-presentation magikos-update")
  }

  visible: updateAvailable
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "magikos.system-update"

    function refresh(): void {
      root.broadcast("refresh")
    }

    function clear(): void {
      root.broadcast("clear")
    }
  }

  Process {
    id: updateProc
    command: ["magikos-update-available"]
    onExited: function(exitCode) {
      root.updateAvailable = exitCode === 0
    }
  }

  Timer {
    interval: 21600000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf021"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: "Pending Magikos Updates"
    onPressed: root.runUpdate()
  }
}
