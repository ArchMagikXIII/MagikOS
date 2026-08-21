import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "magikos.menu"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\ue900"
    fontFamily: "magikos"
    horizontalMargin: 7.5
    onPressed: function(button) {
      if (!root.bar) return
      if (button === Qt.RightButton) root.bar.run("xdg-terminal-exec")
      else root.bar.run("magikos-shell shell toggle magikos.menu '{\"menu\":\"root\"}'")
    }
  }
}
