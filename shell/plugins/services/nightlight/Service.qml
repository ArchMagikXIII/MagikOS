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
    // wlsunset speaks the standard wlr gamma protocol, so this works on any
    // compositor. Equal low/high temps pin a constant value immediately;
    // killing the daemon restores native daylight.
    var cmd = "pkill -x wlsunset 2>/dev/null; "
    if (Number(temp) < dayTemperature) {
      cmd += "sleep 0.3; setsid wlsunset -t " + Number(temp) + " -T " + Number(temp) + " >/dev/null 2>&1 &"
    }
    applyProcess.command = ["bash", "-c", cmd]
    applyProcess.running = true
  }

  Process {
    id: statusProbe
    // The daemon's arguments are the only source of truth: wlsunset cannot be
    // queried live. No output means nothing is running (daylight).
    command: ["bash", "-c", "pgrep -ax wlsunset | head -n1 | awk '{for(i=2;i<NF;i++) if($i==\"-t\"){print $(i+1); exit}}'"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: function(text) {
        root.temperature = NightlightModel.temperatureFromOutput(text)
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
