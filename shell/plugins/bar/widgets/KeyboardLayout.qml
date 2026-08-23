import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "KeyboardLayoutModel.js" as KeyboardLayoutModel

BarWidget {
  id: root
  moduleName: "magikos.keyboard-layout"

  property string layoutFull: ""
  property string keyboardIdentifier: ""
  property int keyboardCount: 0
  property bool multipleLayouts: false
  property var layoutBriefs: ({})
  readonly property string layoutLabel: KeyboardLayoutModel.shortLabel(layoutFull, layoutBriefs)

  property bool refreshPending: false

  function refresh() {
    if (queryProc.running) {
      refreshPending = true
      return
    }
    refreshPending = false
    queryProc.running = true
  }

  function typedKeyboards(keyboards) {
    return keyboards.filter(k => k.type === "keyboard" && KeyboardLayoutModel.isTypedKeyboard(k.name))
  }

  function selectKeyboard(typed) {
    // Select the first keyboard with multiple layouts
    for (var i = 0; i < typed.length; i++) {
      if (typed[i].xkb_layout_names && typed[i].xkb_layout_names.length > 1) {
        return typed[i]
      }
    }
    return typed.length > 0 ? typed[0] : null
  }

  function cycleLayout() {
    if (!root.keyboardIdentifier || !root.bar) return
    // Use swaymsg input command to cycle layout
    root.bar.run("swaymsg input " + Util.shellQuote(root.keyboardIdentifier) + " xkb_switch_layout next")
    refreshTimer.restart()
  }

  Component.onCompleted: {
    briefsProc.running = true
    refresh()
  }

  // Sway offers no raw layout-change events, so we poll periodically
  // The keyboard layout changes are detected via the query

  Process {
    id: queryProc
    command: ["swaymsg", "-t", "get_inputs"]
    onRunningChanged: {
      if (running) {
        stallTimer.restart()
        return
      }
      stallTimer.stop()
      if (root.refreshPending) root.refresh()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        let inputs
        try {
          inputs = JSON.parse(text || "[]")
        } catch (e) {
          return
        }

        if (!Array.isArray(inputs)) return

        const typed = root.typedKeyboards(inputs)
        const kb = root.selectKeyboard(typed)
        if (!kb || !kb.xkb_active_layout_name) {
          root.keyboardCount = typed.length
          if (typed.length === 0) {
            root.layoutFull = ""
            root.keyboardIdentifier = ""
          }
          return
        }

        root.keyboardCount = typed.length
        root.keyboardIdentifier = kb.identifier
        root.multipleLayouts = kb.xkb_layout_names && kb.xkb_layout_names.length > 1
        root.layoutFull = kb.xkb_active_layout_name
      }
    }
  }

  Process {
    id: briefsProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutBriefs = KeyboardLayoutModel.layoutBriefs(text)
    }
  }

  Timer {
    id: refreshTimer
    interval: 600
    onTriggered: root.refresh()
  }

  Timer {
    id: stallTimer
    interval: 5000
    onTriggered: {
      queryProc.running = false
      refreshTimer.restart()
    }
  }

  Timer {
    interval: 10000
    running: !root.keyboardIdentifier || root.keyboardCount > 1
    repeat: true
    onTriggered: root.refresh()
  }

  visible: layoutLabel !== "" && multipleLayouts
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.layoutLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.layoutFull
    onPressed: function() { root.cycleLayout() }
  }
}
