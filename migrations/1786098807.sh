echo "Relink agent skill symlinks to default/agents/skills/magikos"

mkdir -p ~/.agents/skills ~/.claude/skills ~/.codex/skills ~/.pi/agent/skills
ln -sfn "$MAGIKOS_PATH/default/agents/skills/magikos" ~/.agents/skills/magikos
ln -sfn "$MAGIKOS_PATH/default/agents/skills/magikos" ~/.claude/skills/magikos
ln -sfn "$MAGIKOS_PATH/default/agents/skills/magikos" ~/.codex/skills/magikos
ln -sfn "$MAGIKOS_PATH/default/agents/skills/magikos" ~/.pi/agent/skills/magikos
