#!/usr/bin/env bash
# Links crew's skills, agents and CLI into your Claude Code and PATH. Safe to run again.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p ~/.claude/skills ~/.claude/agents ~/.local/bin
link() {
  if [[ -e $2 && ! -L $2 ]]; then echo "skip $2 (exists and is not a link)"; return; fi
  ln -sfn "$1" "$2"; echo "link $2"
}
for d in "$here"/skills/*/; do link "${d%/}" ~/.claude/skills/"$(basename "$d")"; done
for f in "$here"/agents/*.md; do link "$f" ~/.claude/agents/"$(basename "$f")"; done
link "$here/bin/crew" ~/.local/bin/crew
chmod +x "$here"/bin/crew "$here"/hooks/*.sh
command -v jq >/dev/null || echo "warning: jq is required"
command -v herdr >/dev/null || echo "warning: herdr is required"
echo "next: open your project in a Herdr pane, run 'crew init', then start claude and say: use crew"
