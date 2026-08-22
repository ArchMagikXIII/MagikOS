import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "magikos.workspaces"

  property var swayService: null

  readonly property var wsColors: [
    "#4d9fff",
    "#3ddc84",
    "#ff5fd7",
    "#22e0cd",
    "#ffd75e"
  ]

  Component.onCompleted: {
    var svc = root.bar && root.bar.shell && root.bar.shell.firstPartyServiceFor
      ? root.bar.shell.firstPartyServiceFor("magikos.sway") : null
    if (svc) {
      root.swayService = svc
      swayServiceRetry.running = false
    }
  }

  Timer {
    id: swayServiceRetry
    interval: 500
    repeat: true
    running: root.swayService === null
    onTriggered: {
      var svc = root.bar && root.bar.shell && root.bar.shell.firstPartyServiceFor
        ? root.bar.shell.firstPartyServiceFor("magikos.sway") : null
      if (svc) {
        root.swayService = svc
        running = false
      }
    }
  }

  function workspaceById(id) {
    if (!swayService) return null
    return swayService.getWorkspaceById(id)
  }

  function workspaceIds() {
    if (!swayService) return [1, 2, 3, 4, 5]
    return swayService.getWorkspaceIds()
  }

  function focusWorkspace(id) {
    if (!swayService) return
    swayService.switchWorkspace(id)
  }

  function wsColor(index) {
    var ci = (index - 1) % wsColors.length
    return wsColors[ci < 0 ? 0 : ci]
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.windowCount > 0
        readonly property bool focused: swayService && swayService.focusedWorkspaceId === modelData
        readonly property color wsCol: wsColor(modelData)

        bar: root.bar
        text: focused ? "\uDB85\uDCFB" : (modelData === 1 ? "󰙯" : modelData === 2 ? "󰅴" : modelData === 3 ? "󰖟" : modelData === 4 ? "󰘐" : modelData === 5 ? "\uF1B6" : modelData === 10 ? "0" : String(modelData))
        foreground: focused ? wsCol : (occupied ? Color.muted : Color.foreground)
        useActiveColor: false
        opacity: 1
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
      }
    }
  }
}
