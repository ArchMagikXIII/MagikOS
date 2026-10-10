#!/usr/bin/env bash
# Workaround: Qt 6.12 adds a `Color` singleton to the `QtQuick` import that
# shadows the magikos shell's `qs.Commons.Color` singleton (same name), making
# every theme color undefined (solid black bar).
# Fix: rename the magikos singleton Color -> Colors and rewrite `Color.` ->
# `Colors.` in all shell + user-plugin QML/JS.
# Idempotent. Run:  sudo bash /tmp/opencode/magikos-color-fix.sh

set -euo pipefail

SHELL_DIR=/usr/share/magikos/shell
PLUGIN_DIR=/home/magikxiii/.config/magikos/plugins
QM=Commons/qmldir
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP=/root/magikos-color-fix-backup-$STAMP
mkdir -p "$BACKUP"

echo "==> backing up to $BACKUP"
tar -C "$(dirname "$SHELL_DIR")" -cf "$BACKUP/shell.tar" "$(basename "$SHELL_DIR")"
[ -d "$PLUGIN_DIR" ] && tar -C "$(dirname "$PLUGIN_DIR")" -cf "$BACKUP/plugins.tar" "$(basename "$PLUGIN_DIR")"

# 1) rename the singleton (once)
if [ -f "$SHELL_DIR/$QM" ] && grep -q 'singleton Color 1.0 Color.qml' "$SHELL_DIR/$QM" && [ ! -f "$SHELL_DIR/Commons/Colors.qml" ]; then
  echo "==> renaming Commons/Color.qml -> Commons/Colors.qml"
  mv -f "$SHELL_DIR/Commons/Color.qml" "$SHELL_DIR/Commons/Colors.qml"
  sed -i 's/singleton Color 1.0 Color\.qml/singleton Colors 1.0 Colors.qml/' "$SHELL_DIR/$QM"
fi

# 2) rewrite Color. -> Colors. everywhere it still appears
echo "==> rewriting Color. -> Colors. in shell + user plugins"
for root in "$SHELL_DIR" "$PLUGIN_DIR"; do
  [ -d "$root" ] || continue
  while IFS= read -r -d '' f; do
    sed -i 's/Color\./Colors./g' "$f"
  done < <(find "$root" -type f \( -name '*.qml' -o -name '*.js' \) -exec grep -lq 'Color\.' {} \; -print0)
done

# 3) report
echo "==> remaining 'Color.' references (should be 0):"
find "$SHELL_DIR" "$PLUGIN_DIR" -type f \( -name '*.qml' -o -name '*.js' \) -exec grep -l 'Color\.' {} + 2>/dev/null || echo "none"
echo "==> qmldir now:"
grep -n 'singleton Colors' "$SHELL_DIR/Commons/qmldir" || true
echo "==> done. restart the shell with:  pkill -f quickshell; swaymsg reload"