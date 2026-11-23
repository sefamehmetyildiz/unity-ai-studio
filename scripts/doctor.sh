#!/usr/bin/env bash
# Checks that the Unity AI Studio environment is set up: machine, project, Editor.
# macOS / Linux counterpart of doctor.ps1: same checks, same wording.
#
# Prints one line per check with OK / WARN / MISSING / FAIL and the fix.
# Changes nothing (it does ask a connected Editor to recompile scripts).
#
# Usage: bash doctor.sh [--project-path P] [--machine-only] [--no-editor]
# Exit code: 1 when any check FAILs, else 0.

set -u
unset CDPATH
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

PROJECT_PATH="$(pwd)"; MACHINE_ONLY=0; NO_EDITOR=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project-path|-ProjectPath)
      [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 64; }
      shift; PROJECT_PATH="$1" ;;
    --machine-only|-MachineOnly) MACHINE_ONLY=1 ;;
    --no-editor|-NoEditor) NO_EDITOR=1 ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 64 ;;
  esac
  shift
done

fails=0; warns=0
report() {
  write_status "$1" "$2"
  case "$1" in FAIL) fails=$((fails + 1)) ;; WARN|MISSING) warns=$((warns + 1)) ;; esac
}
finish() {
  echo
  echo "Result: $fails fail, $warns warning"
  if [ "$fails" -gt 0 ]; then exit 1; fi
  exit 0
}

KIT_VERSION="$(kit_version)"
printf '%sUnity AI Studio doctor (kit v%s)%s\n' "$C_B" "$KIT_VERSION" "$C_RST"

# --- Machine -----------------------------------------------------------------
write_section 'Machine'

CLAUDE="$(find_claude)"
if [ -n "$CLAUDE" ]; then
  report OK "Claude Code CLI $("$CLAUDE" --version 2>/dev/null | head -n 1)"
  if ! command -v claude >/dev/null 2>&1; then
    report WARN "$(dirname "$CLAUDE") is not on PATH (typing 'claude' in a new terminal fails). Open a new terminal, or re-run setup-machine.sh."
  fi
else
  report FAIL 'Claude Code CLI not found -> run setup-machine.sh'
fi

# On macOS without the Command Line Tools, /usr/bin/git is a stub: running it
# opens the install dialog. Only run git once xcode-select points at a real one.
git_ok=0; gv=''
if [ "$(uname -s)" = Darwin ]; then
  dev="$(xcode-select -p 2>/dev/null)"
  if [ -n "$dev" ] && [ -x "$dev/usr/bin/git" ] && gv="$(git --version 2>/dev/null)"; then git_ok=1; fi
elif command -v git >/dev/null 2>&1 && gv="$(git --version 2>/dev/null)"; then
  git_ok=1
fi
if [ "$git_ok" = 1 ] && command -v bash >/dev/null 2>&1; then
  report OK "git + bash ($gv) - Game Studios hooks run through bash"
else
  report FAIL 'git or bash not found - Game Studios hooks need them -> macOS: xcode-select --install'
fi

UNITY="$(find_unity)"
if [ -n "$UNITY" ]; then report OK "Unity CLI $("$UNITY" --version 2>/dev/null | head -n 1)"
else report FAIL 'Unity CLI not found -> run setup-machine.sh'; fi

INSTALLED="$HOME/.claude/plugins/installed_plugins.json"
USER_SETTINGS="$HOME/.claude/settings.json"
for id in $REQUIRED_PLUGINS; do
  if ! { [ -f "$INSTALLED" ] && grep -q "\"$id\"" "$INSTALLED"; }; then
    report MISSING "Plugin $id not installed -> run setup-machine.sh"
  elif [ -f "$USER_SETTINGS" ] && tr -d '\r\n' < "$USER_SETTINGS" | grep -q "\"$id\"[[:space:]]*:[[:space:]]*false"; then
    report WARN "Plugin $id is installed but disabled -> claude plugin enable $id"
  else
    report OK "Plugin $id"
  fi
done

missing_skills=''
for s in unity-pipeline craft-game-floors create-2d-physics project-auditor-fixes; do
  [ -f "$HOME/.claude/skills/$s/SKILL.md" ] || missing_skills="$missing_skills $s"
done
if [ -z "$missing_skills" ]; then report OK 'Unity CLI skills (unity-pipeline, craft-game-floors, ...)'
else report MISSING "Unity CLI skills missing:$missing_skills -> unity setup claude -y"; fi

if [ -n "$CLAUDE" ] && "$CLAUDE" mcp get unity-editor-mcp >/dev/null 2>&1 </dev/null; then
  report OK 'MCP server unity-editor-mcp'
else
  report MISSING 'MCP server unity-editor-mcp not configured -> unity mcp configure claude -y'
fi
if [ -n "$CLAUDE" ] && "$CLAUDE" mcp get unity-mcp >/dev/null 2>&1 </dev/null; then
  report WARN 'Legacy MCP server unity-mcp (old AI Assistant relay) still configured -> claude mcp remove unity-mcp -s user'
fi

[ "$MACHINE_ONLY" = 1 ] && finish

# --- Project -----------------------------------------------------------------
if ! abs="$(cd "$PROJECT_PATH" 2>/dev/null && pwd -P)"; then
  report FAIL "Folder not found: $PROJECT_PATH"; finish
fi
PROJECT_PATH="$abs"
write_section "Project  $PROJECT_PATH"

if ! is_unity_project "$PROJECT_PATH"; then
  report FAIL 'Not a Unity project (no Assets/ + ProjectSettings/ProjectVersion.txt). Pass --project-path or --machine-only.'
  finish
fi

UV="$(project_unity_version "$PROJECT_PATH")"
minor="$(echo "$UV" | sed -n 's/^6000\.\([0-9]*\)\..*/\1/p')"
if [ -n "$minor" ] && [ "$minor" -ge 3 ]; then report OK "Unity $UV"
else report WARN "Unity $UV - the gamedev skills and Game Studios engine docs target Unity 6.3 LTS; check suggested APIs against your version or upgrade via Unity Hub."; fi

STAMP="$PROJECT_PATH/$KIT_STAMP_REL"
if [ -f "$STAMP" ]; then
  sv="$(json_string_field "$STAMP" version)"
  if [ "$sv" = "$KIT_VERSION" ]; then report OK "Studio kit v$sv"
  else report WARN "Studio kit v$sv installed, v$KIT_VERSION available -> /studio:update"; fi
elif [ -d "$PROJECT_PATH/.claude/agents" ]; then
  report WARN 'Game Studios present but not installed by the kit (no .claude/studio-kit.json) -> /studio:update adopts it'
else
  report MISSING 'Studio kit not installed in this project -> /studio:add'
fi

if [ -f "$PROJECT_PATH/CLAUDE.md" ] && grep -q 'Game Studio' "$PROJECT_PATH/CLAUDE.md"; then report OK 'CLAUDE.md (Game Studios)'
elif [ -f "$PROJECT_PATH/CLAUDE.md" ]; then report WARN 'CLAUDE.md exists but is not the Game Studios one (the kit kept your file). Merge payload/CLAUDE.md into it by hand.'
else report MISSING 'CLAUDE.md missing -> /studio:update'; fi

if [ -f "$PROJECT_PATH/.claude/rules/plugin-integration.md" ]; then report OK 'Routing rules (.claude/rules/plugin-integration.md)'
else report MISSING 'Routing rules missing -> /studio:update'; fi

no_bridge=''; n=0
for a in $BRIDGED_AGENTS; do
  n=$((n + 1))
  f="$PROJECT_PATH/.claude/agents/$a.md"
  if [ ! -f "$f" ] || ! grep -q '^skills:' "$f"; then no_bridge="$no_bridge $a"; fi
done
if [ -z "$no_bridge" ]; then report OK "Agent skill bridge ($n agents)"
else report MISSING "Agents without preloaded skills:$no_bridge -> /studio:update"; fi

engine=''
if [ -f "$PROJECT_PATH/project.yaml" ]; then
  engine="$(tr -d '\r' < "$PROJECT_PATH/project.yaml" | awk '
    /^engine:[[:space:]]*$/ { inside = 1; next }
    inside && /^[^[:space:]]/ { exit }
    inside && /^[[:space:]]+name:/ {
      v = $0; sub(/^[[:space:]]+name:[[:space:]]*/, "", v); sub(/[[:space:]]*#.*$/, "", v); sub(/[[:space:]]+$/, "", v); gsub(/"/, "", v)
      print v; exit
    }')"
fi
if [ "$engine" = "Unity" ]; then report OK 'Game Studios engine: Unity (project.yaml)'
elif [ -n "$engine" ]; then report WARN "Game Studios engine is '$engine', not Unity -> /setup-engine unity"
else report MISSING 'Game Studios engine not set -> run /setup-engine unity in Claude Code'; fi

if [ -f "$PROJECT_PATH/Packages/manifest.json" ] && grep -q '"com\.unity\.pipeline"' "$PROJECT_PATH/Packages/manifest.json"; then
  report OK 'Package com.unity.pipeline (manifest)'
else
  report MISSING 'Package com.unity.pipeline not in manifest -> unity pipeline install'
fi

GI="$PROJECT_PATH/.gitignore"
if [ -f "$GI" ] && grep -q 'ibrary/' "$GI"; then
  if grep -qE '>>> unity-ai-studio >>>|production/session-logs' "$GI"; then report OK '.gitignore (Unity + studio entries)'
  else report WARN '.gitignore lacks the studio block (session logs, local config would be committed) -> /studio:update'; fi
else
  report WARN '.gitignore missing or does not ignore Library/ -> /studio:update'
fi

# --- Editor ------------------------------------------------------------------
if [ "$NO_EDITOR" != 1 ] && [ -n "$UNITY" ]; then
  write_section 'Editor'
  # Lower-case a path, except on Linux where file systems are case-sensitive.
  lc() { if [ "$(uname -s)" = Linux ]; then printf '%s' "$1"; else printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; fi; }
  # One instance object per line; pick the one whose projectPath is this project.
  inst="$("$UNITY" --no-banner --json status 2>/dev/null </dev/null | tr -d '\r\n' \
    | sed 's/"items".*//' | tr '{' '\n' | grep '"projectPath"' \
    | while IFS= read -r obj; do
        p="$(echo "$obj" | sed -n 's/.*"projectPath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | sed 's#\\\\#/#g')"
        rp="$(cd "$p" 2>/dev/null && pwd -P)"
        # macOS volumes are case-insensitive and pwd -P keeps the typed case,
        # so compare ignoring case there (doctor.ps1's -eq ignores case too).
        if [ -n "$rp" ] && { [ "$rp" = "$PROJECT_PATH" ] || [ "$(lc "$rp")" = "$(lc "$PROJECT_PATH")" ]; }; then echo "$obj"; break; fi
      done)"
  if [ -z "$inst" ]; then
    report WARN 'No connected Editor for this project. Open it in Unity (a first open downloads com.unity.pipeline), then re-run.'
  else
    field() { echo "$inst" | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\",}]*\)\"\{0,1\}.*/\1/p"; }
    report OK "Editor connected: Unity $(field version), port $(field port), state $(field state)"
    "$UNITY" --no-banner recompile --project-path "$PROJECT_PATH" --timeout 180 >/dev/null 2>&1 </dev/null
    con="$("$UNITY" --no-banner --json command console status --project-path "$PROJECT_PATH" 2>/dev/null </dev/null | tr -d '\r\n')"
    if echo "$con" | grep -q '"groundTruth"'; then
      if echo "$con" | grep -q '"compilationFailed"[[:space:]]*:[[:space:]]*true'; then
        report FAIL 'Scripts do not compile - fix errors first (compile errors put the Editor in Safe Mode and cut the connection)'
      else
        report OK 'Scripts compile'
      fi
      ce="$(echo "$con" | sed -n 's/.*"consoleErrors"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')"
      cw="$(echo "$con" | sed -n 's/.*"consoleWarnings"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p')"
      if [ "${ce:-0}" -gt 0 ]; then report WARN "Console: $ce error(s), ${cw:-0} warning(s)"
      else report OK "Console: 0 errors, ${cw:-0} warning(s)"; fi
    else
      report WARN 'Could not read the Editor console.'
    fi
  fi
fi

finish
