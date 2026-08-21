import QtQuick
import Quickshell.Io
import "NightlightModel.js" as NightlightModel

Item {
  id: root

  // Injected by magikos-shell (the first-party service loader).
  property var shell: null

  readonly property int nightTemperature: 4000
  readonly property int dayTemperature: 6500

  property bool stateLoaded: false
  property var temperature: null
  readonly property bool enabled: stateLoaded && NightlightModel.isNightlight(temperature)

  property bool hasPendingTemperature: false
  property int pendingTemperature: 0

  function refresh() {
    if (!statusProbe.running) statusProbe.running = true
  }

  function setNightlight(value) {
    applyTemperature(value ? nightTemperature : dayTemperature)
  }

  function toggle() {
    setNightlight(!enabled)
  }

  function applyTemperature(temp) {
    root.temperature = temp
    root.stateLoaded = true

    if (applyProcess.running) {
      root.pendingTemperature = temp
      root.hasPendingTemperature = true
      return
    }

    runApply(temp)
  }

  function runApply(temp) {
    // For Sway, use hyprsunset directly (compositor-agnostic)
    applyProcess.command = ["bash", "-lc",
      "pgrep -x hyprsunset >/dev/null || { setsid hyprsunset >/dev/null 2>&1 & sleep 1; }; " +
      "hyprsunset -t " + Number(temp)]
    applyProcess.running = true
  }

  Process {
    id: statusProbe
    // Use hyprsunset directly for status query
    command: ["hyprsunset", "--version"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Try to get current temperature
        var tempProbe = Qt.createQmlObject(
          'import Quickshell.Io; Process { command: ["bash", "-c", "hyprsunset -g 2>/dev/null || echo 6500"] }',
          root
        )
        tempProbe.stdout = Qt.createQmlObject(
          'import Quickshell.Io; StdioCollector { waitForEnd: true; onStreamFinished: function(text) { var temp = NightlightModel.temperatureFromOutput(text); root.temperature = temp; root.stateLoaded = true; } }',
          tempProbe
        )
        tempProbe.running = true
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        // hyprsunset not available, use default
        root.temperature = null
        root.stateLoaded = true
      }
    }
  }

  Process {
    id: applyProcess
    onExited: function() {
      if (root.hasPendingTemperature) {
        root.hasPendingTemperature = false
        root.runApply(root.pendingTemperature)
        return
      }

      root.refresh()
    }
  }

  Component.onCompleted: refresh()

  IpcHandler {
    target: "nightlight"

    function status(): string {
      return JSON.stringify({ enabled: root.enabled, temperature: root.temperature })
    }

    function refresh(): void {
      root.refresh()
    }

    function enable(): string {
      root.setNightlight(true)
      return "enabled"
    }

    function disable(): string {
      root.setNightlight(false)
      return "disabled"
    }

    function toggle(): string {
      var enabling = !root.enabled
      root.setNightlight(enabling)
      return enabling ? "enabled" : "disabled"
    }
  }
}
