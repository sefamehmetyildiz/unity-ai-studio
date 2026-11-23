#!/usr/bin/env bash
# Shared helpers for the Unity AI Studio kit's bash scripts (macOS / Linux).
# Mirrors scripts/common.ps1; keep the two in step.
#
# Portability: bash 3.2 (macOS default) and BSD userland. No associative
# arrays, no sed -i, no readlink -f, no GNU-only flags.

# An exported CDPATH makes `cd` print the folder, which corrupts $(cd X && pwd).
unset CDPATH
KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD_ROOT="$KIT_ROOT/payload"
TEMPLATE_ROOT="$KIT_ROOT/templates"
KIT_STAMP_REL='.claude/studio-kit.json'

# Agents that get plugin skills preloaded through `skills:` frontmatter.
BRIDGED_AGENTS="unity-specialist gameplay-programmer ai-programmer ui-programmer unity-ui-specialist unity-shader-specialist technical-artist performance-analyst prototyper"

# Plugins the kit depends on.
REQUIRED_PLUGINS="gamedev@awesome-gamedev-agent-skills unity@unity-agent-plugin studio@unity-ai-studio"

if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_FAIL=$'\033[31m'; C_DO=$'\033[36m'; C_DIM=$'\033[90m'; C_B=$'\033[1m'; C_RST=$'\033[0m'
else
  C_OK=''; C_WARN=''; C_FAIL=''; C_DO=''; C_DIM=''; C_B=''; C_RST=''
fi

# Kit version from the VERSION file.
kit_version() {
  if [ -f "$KIT_ROOT/VERSION" ]; then head -n 1 "$KIT_ROOT/VERSION" | tr -d ' \r\n'; else echo '0.0.0'; fi
}

# Status line: OK / WARN / MISSING / FAIL / INFO / DO.
write_status() {
  local col="$C_RST"
  case "$1" in
    OK) col="$C_OK" ;; WARN|MISSING) col="$C_WARN" ;; FAIL) col="$C_FAIL" ;; DO) col="$C_DO" ;; INFO) col="$C_DIM" ;;
  esac
  printf '  %s[%-7s]%s %s\n' "$col" "$1" "$C_RST" "$2"
}

write_section() { printf '\n%s== %s ==%s\n' "$C_B" "$1" "$C_RST"; }

# Claude Code CLI path, or empty.
find_claude() {
  local p
  for p in "$HOME/.local/bin/claude" "$HOME/.local/bin/claude.exe"; do
    if [ -x "$p" ]; then echo "$p"; return 0; fi
  done
  command -v claude 2>/dev/null
}

# Unity CLI path, or empty. ~/.unity/bin is the macOS default, ~/.local/bin Linux.
find_unity() {
  local p
  for p in "$HOME/.unity/bin/unity" "$HOME/.local/bin/unity" "${LOCALAPPDATA:-/nonexistent}/Unity/bin/unity.exe"; do
    if [ -x "$p" ]; then echo "$p"; return 0; fi
  done
  command -v unity 2>/dev/null
}

# True when the folder looks like a Unity project.
is_unity_project() { [ -f "$1/ProjectSettings/ProjectVersion.txt" ] && [ -d "$1/Assets" ]; }

# Unity editor version from ProjectSettings/ProjectVersion.txt.
project_unity_version() {
  sed -n 's/^m_EditorVersion:[[:space:]]*\([^[:space:]]*\).*/\1/p' "$1/ProjectSettings/ProjectVersion.txt" 2>/dev/null | head -n 1 | tr -d '\r'
}

# Kit "framework" files are overwritten on update; everything else in the
# payload is a seed file, copied only when missing. Mirrors Test-FrameworkFile.
is_framework_file() {
  case "$1" in
    .claude/docs/technical-preferences.md) return 1 ;;
    .claude/agent-memory/*) return 1 ;;
    "$KIT_STAMP_REL") return 1 ;;
    .claude/*) return 0 ;;
    docs/engine-reference/*/VERSION.md) return 1 ;;
    docs/engine-reference/*) return 0 ;;
    docs/CLAUDE.md|docs/COLLABORATIVE-DESIGN-PRINCIPLE.md|design/CLAUDE.md|.worktreeinclude) return 0 ;;
  esac
  return 1
}

# Payload files, relative to the payload root, one per line.
# Finder metadata (.DS_Store, ._*) is never part of the payload.
payload_files() { (cd "$PAYLOAD_ROOT" && find . -type f ! -name .DS_Store ! -name '._*' | sed 's#^\./##' | LC_ALL=C sort); }

# True when two files have the same content, ignoring CRLF vs LF.
same_content() { cmp -s <(tr -d '\r' < "$1") <(tr -d '\r' < "$2"); }

# Value of a top-level string field in a kit stamp (or any simple JSON).
json_string_field() {
  tr -d '\r\n' < "$1" 2>/dev/null | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p"
}

# The "files" array of a kit stamp, one path per line. Works for the
# PowerShell writer's layout too (any whitespace/newlines between items).
stamp_files() {
  tr -d '\r\n' < "$1" 2>/dev/null \
    | sed -n 's/.*"files"[[:space:]]*:[[:space:]]*\[\([^]]*\)].*/\1/p' \
    | tr ',' '\n' \
    | sed -n 's/^[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' \
    | awk 'NF'   # every line newline-terminated, so `while read` never drops the last one
}

# Insert or replace the kit's managed block (between the >>> / <<< marker
# lines) in a text file such as .gitignore. Prints created / updated /
# unchanged / appended. Args: target block_file base_file_if_missing dry_run(0|1)
set_managed_block() {
  local target="$1" block="$2" base="$3" dry="$4" tmp
  tmp="$(mktemp "${TMPDIR:-/tmp}/studio-block.XXXXXX")"
  if [ ! -f "$target" ]; then
    { if [ -n "$base" ] && [ -f "$base" ]; then tr -d '\r' < "$base"; echo; fi; tr -d '\r' < "$block"; } > "$tmp"
    if [ "$dry" != 1 ]; then cp "$tmp" "$target"; fi
    rm -f "$tmp"; echo created; return
  fi
  # Replace only when both markers are present; with a lone start marker the
  # awk below would drop every following line. Otherwise append (as .ps1 does).
  if grep -q '^# >>> unity-ai-studio >>>' "$target" && grep -q '^# <<< unity-ai-studio <<<' "$target"; then
    tr -d '\r' < "$target" | awk -v blockfile="$block" '
      BEGIN { while ((getline line < blockfile) > 0) { sub(/\r$/, "", line); blk = blk line "\n" } }
      /^# >>> unity-ai-studio >>>/ { printf "%s", blk; skip = 1; next }
      skip && /^# <<< unity-ai-studio <<</ { skip = 0; next }
      !skip { print }
    ' > "$tmp"
    if cmp -s "$tmp" <(tr -d '\r' < "$target"); then rm -f "$tmp"; echo unchanged; return; fi
    if [ "$dry" != 1 ]; then cp "$tmp" "$target"; fi
    rm -f "$tmp"; echo updated; return
  fi
  { tr -d '\r' < "$target"; echo; tr -d '\r' < "$block"; } > "$tmp"
  if [ "$dry" != 1 ]; then cp "$tmp" "$target"; fi
  rm -f "$tmp"; echo appended
}
