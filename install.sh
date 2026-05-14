#!/bin/bash
# WAVE Skill Installer — Mac/Linux

DEST="$HOME/.claude/plugins/wave-skill"

echo "Installing WAVE skill to $DEST..."

rm -rf "$DEST"
mkdir -p "$DEST"
cp -r ./skills "$DEST/"
cp -r ./.claude-plugin "$DEST/"

echo "WAVE skill installed."
echo "Restart Claude Code to activate."
