import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property string magikosPath: Quickshell.env("MAGIKOS_PATH")

  property var workspaces: []
  property var outputs: []
  property int focusedWorkspaceId: -1
  property string focusedOutputName: ""

  readonly property string swaySock: Quickshell.env("SWAYSOCK")
  readonly property string swayCmdPrefix: "SWAYSOCK=" + swaySock + " "

  signal workspacesUpdated()
  signal outputsUpdated()

  Process {
    id: workspaceQuery
    command: ["sh", "-c", root.swayCmdPrefix + "swaymsg -t get_workspaces | jq -c ."]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var trimmed = String(line).trim()
        if (trimmed.length === 0) return
        try {
          var data = JSON.parse(trimmed)
          var newWorkspaces = []
          var newFocusedId = -1
          for (var i = 0; i < data.length; i++) {
            var ws = data[i]
            newWorkspaces.push({
              id: ws.num,
              name: ws.name,
              focused: ws.focused,
              visible: ws.visible,
              urgent: ws.urgent,
              output: ws.output,
              windowCount: countWindows(ws)
            })
            if (ws.focused) {
              newFocusedId = ws.num
            }
          }
          root.workspaces = newWorkspaces
          root.focusedWorkspaceId = newFocusedId
          root.workspacesUpdated()
        } catch (e) {
          console.warn("Sway workspace parse failed:", e, trimmed.substring(0, 100))
        }
      }
    }
  }

  Process {
    id: outputQuery
    command: ["sh", "-c", root.swayCmdPrefix + "swaymsg -t get_outputs | jq -c ."]
    running: false
    stdout: SplitParser {
      onRead: function(line) {
        var trimmed = String(line).trim()
        if (trimmed.length === 0) return
        try {
          var data = JSON.parse(trimmed)
          var newOutputs = []
          var newFocusedOutput = ""
          for (var i = 0; i < data.length; i++) {
            var out = data[i]
            newOutputs.push({
              name: out.name,
              active: out.active,
              focused: out.focused,
              rect: out.rect
            })
            if (out.focused) {
              newFocusedOutput = out.name
            }
          }
          root.outputs = newOutputs
          root.focusedOutputName = newFocusedOutput
          root.outputsUpdated()
        } catch (e) {
          console.warn("Sway output parse failed:", e, trimmed.substring(0, 100))
        }
      }
    }
  }

  // Sway emits one JSON line per state change on this subscription. Reacting
  // to events keeps the bar's workspace highlight in step with the switch
  // itself instead of up to a poll interval behind it, and replaces the two
  // process spawns a fast poll would need every tick.
  Process {
    id: eventStream
    command: ["sh", "-c", root.swayCmdPrefix + "swaymsg -m -t subscribe '[\"workspace\",\"output\"]'"]
    stdout: SplitParser {
      onRead: function(line) { root.handleEventLine(line) }
    }
    // A compositor reload or crash ends the stream; revive it promptly.
    onExited: eventStreamRestart.restart()
  }

  Timer {
    id: eventStreamRestart
    interval: 1000
    onTriggered: if (!eventStream.running) eventStream.running = true
  }

  function handleEventLine(line) {
    var trimmed = String(line).trim()
    if (trimmed.length === 0) return
    var evt
    try { evt = JSON.parse(trimmed) } catch (e) { return }
    if (evt.output !== undefined && evt.change !== undefined) {
      root.refreshOutputs()
      return
    }
    // A focus event already names the newly focused workspace, so the
    // highlight moves immediately; the follow-up query refreshes window
    // counts and visibility with authoritative state.
    if (evt.current !== undefined) {
      if (evt.change === "focus" && evt.current.num > 0) root.focusedWorkspaceId = evt.current.num
      root.refreshWorkspaces()
    }
  }

  // Safety net: catches state the event stream missed (a dropped connection
  // between exit and revival) and revives the subscription after failures.
  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.refreshWorkspaces()
      root.refreshOutputs()
      if (!eventStream.running) eventStream.running = true
    }
  }

  function refreshWorkspaces() {
    if (!workspaceQuery.running) {
      workspaceQuery.running = true
    }
  }

  function refreshOutputs() {
    if (!outputQuery.running) {
      outputQuery.running = true
    }
  }

  function switchWorkspace(id) {
    var wsName = String(id)
    for (var i = 0; i < root.workspaces.length; i++) {
      if (root.workspaces[i].id === id) {
        wsName = root.workspaces[i].name
        break
      }
    }
    Quickshell.execDetached(["sh", "-c", root.swayCmdPrefix + "swaymsg workspace " + wsName])
  }

  function focusOutput(name) {
    Quickshell.execDetached(["sh", "-c", root.swayCmdPrefix + "swaymsg output " + name + " focus"])
  }

  function countWindows(workspace) {
    var count = 0
    if (workspace.nodes) count += workspace.nodes.length
    if (workspace.floating_nodes) count += workspace.floating_nodes.length
    return count
  }

  function getWorkspaceById(id) {
    for (var i = 0; i < root.workspaces.length; i++) {
      if (root.workspaces[i].id === id) return root.workspaces[i]
    }
    return null
  }

  function getFocusedWorkspace() {
    return getWorkspaceById(root.focusedWorkspaceId)
  }

  function getWorkspaceIds() {
    var ids = [1, 2, 3, 4, 5]
    for (var i = 0; i < root.workspaces.length; i++) {
      var id = root.workspaces[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) {
        ids.push(id)
      }
    }
    ids.sort(function(left, right) { return left - right })
    return ids
  }
}
