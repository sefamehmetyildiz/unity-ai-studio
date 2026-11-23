#!/usr/bin/env bash
# One-time machine setup for the Unity AI Studio kit on macOS (and Linux).
# Windows uses setup-machine.ps1 instead.
#
# Installs or verifies, and skips anything already in place:
#   1. Git (Xcode Command Line Tools on macOS; bash runs the Game Studios hooks)
#   2. Claude Code CLI
#   3. Unity CLI (beta channel by default)
#   4. Plugin gamedev@awesome-gamedev-agent-skills
#   5. Plugin unity@unity-agent-plugin + Unity CLI skills  (via: unity setup claude)
#   6. MCP server unity-editor-mcp
#   7. Plugin studio@unity-ai-studio (this kit: /studio:add, /studio:doctor, /studio:update)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/sefamehmetyildiz/unity-ai-studio/main/setup-machine.sh | bash
#   bash setup-machine.sh [--dry-run] [--kit-marketplace owner/repo|path] [--unity-cli-channel beta]
#
# Portability: bash 3.2 (macOS default) and BSD tools. No associative arrays,
# no sed -i, no GNU-only flags. Everything runs inside main() so that
# `curl | bash` has read the whole script before anything executes.

usage() {
  cat <<'USAGE'
Unity AI Studio - one-time machine setup for macOS / Linux.

  curl -fsSL https://raw.githubusercontent.com/sefamehmetyildiz/unity-ai-studio/main/setup-machine.sh | bash
  bash setup-machine.sh [--dry-run] [--kit-marketplace owner/repo|path] [--unity-cli-channel beta]

Installs or verifies Git, Claude Code, the Unity CLI, the gamedev and unity
plugins, the Unity CLI skills, the unity-editor-mcp server and the studio
plugin. Anything already installed is skipped.
USAGE
}

main() {
  unset CDPATH
  local DRY_RUN=0
  local KIT_MARKETPLACE="sefamehmetyildiz/unity-ai-studio"
  local UNITY_CLI_CHANNEL_ARG="beta"
  local failures=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --kit-marketplace|--unity-cli-channel)
        [ $# -ge 2 ] || { echo "Missing value for $1" >&2; return 64; }
        if [ "$1" = --kit-marketplace ]; then KIT_MARKETPLACE="$2"; else UNITY_CLI_CHANNEL_ARG="$2"; fi
        shift ;;
      -h|--help) usage; return 0 ;;
      *) echo "Unknown option: $1" >&2; return 2 ;;
    esac
    shift
  done

  local C_OK='' C_DO='' C_WARN='' C_FAIL='' C_RST='' C_B=''
  if [ -t 1 ]; then
    C_OK=$'\033[32m'; C_DO=$'\033[36m'; C_WARN=$'\033[33m'; C_FAIL=$'\033[31m'; C_RST=$'\033[0m'; C_B=$'\033[1m'
  fi
  say() {
    local col="$C_RST"
    case "$1" in OK) col="$C_OK" ;; DO) col="$C_DO" ;; WARN) col="$C_WARN" ;; FAIL) col="$C_FAIL" ;; esac
    printf '  %s[%-4s]%s %s\n' "$col" "$1" "$C_RST" "$2"
    if [ "$1" = "FAIL" ]; then failures=$((failures + 1)); fi
  }
  step() { printf '\n%s== %s ==%s\n' "$C_B" "$1" "$C_RST"; }

  # Put a folder on PATH for new terminals too, not just for this process
  # (the parity of setup-machine.ps1's user-PATH write). zsh is the macOS
  # default shell; ~/.bash_profile is touched only if it already exists.
  persist_path() {
    local dir="$1" rel rc
    rel="\$HOME${dir#"$HOME"}"
    for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
      if [ "$rc" = "$HOME/.bash_profile" ] && [ ! -f "$rc" ]; then continue; fi
      if grep -qsF "$dir" "$rc" || grep -qsF "$rel" "$rc"; then continue; fi
      if [ "$DRY_RUN" = 1 ]; then say DO "Would add $dir to PATH in $rc"; continue; fi
      printf '\n# Added by Unity AI Studio setup\nexport PATH="%s:$PATH"\n' "$rel" >> "$rc"
      say OK "Added $dir to PATH in $rc (new terminals see it)"
    done
  }

  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*)
      if [ "${STUDIO_FORCE_POSIX:-}" != "1" ]; then
        echo "This is Windows: run setup-machine.ps1 instead (see README)." >&2
        return 2
      fi ;;
  esac

  local tag=''
  if [ "$DRY_RUN" = 1 ]; then tag='  (dry run: nothing is changed)'; fi
  printf '%sUnity AI Studio - machine setup%s%s\n' "$C_B" "$tag" "$C_RST"

  local installed_json="$HOME/.claude/plugins/installed_plugins.json"
  plugin_installed() { [ -f "$installed_json" ] && grep -q "\"$1\"" "$installed_json"; }

  # --- 1. Git -----------------------------------------------------------------
  step 'Git'
  # On macOS /usr/bin/git is a stub until the Command Line Tools are installed
  # (running it opens the install dialog), and xcode-select -p can point at a
  # stale folder after an OS upgrade. Only trust git if it really runs.
  local have_git=0 gv='' dev=''
  if [ "$(uname -s)" = "Darwin" ]; then
    dev="$(xcode-select -p 2>/dev/null)"
    if [ -n "$dev" ] && [ -x "$dev/usr/bin/git" ] && gv="$(git --version 2>/dev/null)"; then have_git=1; fi
  elif command -v git >/dev/null 2>&1 && gv="$(git --version 2>/dev/null)"; then
    have_git=1
  fi
  if [ "$have_git" = 1 ]; then
    say OK "$gv"
  elif [ "$DRY_RUN" = 1 ]; then
    say DO 'Would install Git (macOS: xcode-select --install)'
  elif [ "$(uname -s)" = "Darwin" ] && [ -n "$dev" ] && [ -x "$dev/usr/bin/git" ]; then
    say FAIL "Git is installed but does not run (Xcode licence not accepted?). Run: sudo xcodebuild -license accept, then run this script again."
  elif [ "$(uname -s)" = "Darwin" ]; then
    say DO 'Opening the Xcode Command Line Tools installer (it includes Git)...'
    xcode-select --install >/dev/null 2>&1 || true
    say FAIL 'Finish the Command Line Tools install in the dialog, then run this script again.'
  else
    say FAIL 'Git not found. Install it with your package manager (e.g. sudo apt install git), then run this script again.'
  fi

  # --- 2. Claude Code CLI -------------------------------------------------------
  step 'Claude Code CLI'
  local claude=''
  if [ -x "$HOME/.local/bin/claude" ]; then claude="$HOME/.local/bin/claude"
  elif command -v claude >/dev/null 2>&1; then claude="$(command -v claude)"
  fi
  if [ -n "$claude" ]; then
    say OK "Claude Code $("$claude" --version 2>/dev/null | head -n 1)"
  elif [ "$DRY_RUN" = 1 ]; then
    say DO 'Would install Claude Code (curl -fsSL https://claude.ai/install.sh | bash)'
  else
    say DO 'Installing Claude Code...'
    curl -fsSL https://claude.ai/install.sh | bash
    if [ -x "$HOME/.local/bin/claude" ]; then claude="$HOME/.local/bin/claude"; say OK 'Claude Code installed'
    else say FAIL 'Claude Code install failed. See https://docs.claude.com/en/docs/claude-code/setup'
    fi
  fi
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH"; export PATH ;; esac
  if [ -n "$claude" ] || [ "$DRY_RUN" = 1 ]; then persist_path "$HOME/.local/bin"; fi

  # --- 3. Unity CLI ---------------------------------------------------------------
  step 'Unity CLI'
  find_unity() {
    local p
    for p in "$HOME/.unity/bin/unity" "$HOME/.local/bin/unity"; do
      if [ -x "$p" ]; then echo "$p"; return 0; fi
    done
    command -v unity 2>/dev/null
  }
  local unity
  unity="$(find_unity)"
  if [ -n "$unity" ]; then
    say OK "Unity CLI $("$unity" --version 2>/dev/null | head -n 1)"
  elif [ "$DRY_RUN" = 1 ]; then
    say DO "Would install Unity CLI ($UNITY_CLI_CHANNEL_ARG channel)"
  else
    say DO "Installing Unity CLI ($UNITY_CLI_CHANNEL_ARG channel)..."
    curl -fsSL https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.sh | UNITY_CLI_CHANNEL="$UNITY_CLI_CHANNEL_ARG" bash
    unity="$(find_unity)"
    if [ -n "$unity" ]; then say OK 'Unity CLI installed'; else say FAIL 'Unity CLI install failed.'; fi
  fi
  if [ -n "$unity" ]; then
    local ubin; ubin="$(dirname "$unity")"
    case ":$PATH:" in *":$ubin:"*) ;; *) PATH="$ubin:$PATH"; export PATH ;; esac
    persist_path "$ubin"
  fi

  # --- 4. gamedev plugin ----------------------------------------------------------
  step 'Plugin: gamedev'
  local id='gamedev@awesome-gamedev-agent-skills'
  if plugin_installed "$id"; then say OK "$id"
  elif [ -z "$claude" ]; then say FAIL "$id skipped: Claude Code missing"
  elif [ "$DRY_RUN" = 1 ]; then say DO "Would install $id"
  else
    "$claude" plugin marketplace add gamedev-skills/awesome-gamedev-agent-skills </dev/null
    "$claude" plugin install "$id" --scope user </dev/null
    if plugin_installed "$id"; then say OK "$id"; else say FAIL "$id install failed"; fi
  fi

  # --- 5. Unity plugin + Unity CLI skills ------------------------------------------
  step 'Plugin: unity + Unity CLI skills'
  id='unity@unity-agent-plugin'
  if plugin_installed "$id" && [ -f "$HOME/.claude/skills/unity-pipeline/SKILL.md" ]; then say OK "$id + Unity CLI skills"
  elif [ -z "$claude" ] || [ -z "$unity" ]; then say FAIL "$id skipped: Claude Code or Unity CLI missing"
  elif [ "$DRY_RUN" = 1 ]; then say DO 'Would run: unity setup claude -y'
  else
    "$unity" --no-banner setup claude -y </dev/null
    if plugin_installed "$id"; then say OK "$id"; else say FAIL "$id install failed (try: unity setup claude)"; fi
  fi

  # --- 6. Unity Editor MCP ---------------------------------------------------------
  step 'MCP: unity-editor-mcp'
  mcp_ok() { [ -n "$claude" ] && "$claude" mcp get unity-editor-mcp >/dev/null 2>&1 </dev/null; }
  if mcp_ok; then say OK 'unity-editor-mcp'
  elif [ -z "$claude" ] || [ -z "$unity" ]; then say FAIL 'MCP skipped: Claude Code or Unity CLI missing'
  elif [ "$DRY_RUN" = 1 ]; then say DO 'Would run: unity mcp configure claude -y --replace-legacy'
  else
    "$unity" --no-banner mcp configure claude -y --replace-legacy </dev/null
    if ! mcp_ok; then "$claude" mcp add --scope user unity-editor-mcp -- "$unity" mcp --tool-groups </dev/null; fi
    if mcp_ok; then say OK 'unity-editor-mcp'; else say FAIL 'MCP setup failed'; fi
  fi

  # --- 7. Studio kit plugin --------------------------------------------------------
  step 'Plugin: studio (this kit)'
  id='studio@unity-ai-studio'
  local here=''
  # Under `curl | bash`, BASH_SOURCE[0] is "main", not a file of ours.
  if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != main ] && [ -f "${BASH_SOURCE[0]}" ]; then
    here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi
  if plugin_installed "$id"; then say OK "$id"
  elif [ -z "$claude" ]; then say FAIL "$id skipped: Claude Code missing"
  elif [ "$DRY_RUN" = 1 ]; then say DO "Would add marketplace $KIT_MARKETPLACE and install $id"
  else
    if ! "$claude" plugin marketplace add "$KIT_MARKETPLACE" </dev/null; then
      if [ -n "$here" ] && [ -f "$here/.claude-plugin/marketplace.json" ]; then
        say WARN "Could not reach $KIT_MARKETPLACE; using this local copy instead: $here"
        "$claude" plugin marketplace add "$here" </dev/null
      fi
    fi
    "$claude" plugin install "$id" --scope user </dev/null
    if plugin_installed "$id"; then say OK "$id"; else say FAIL "$id install failed"; fi
  fi

  # --- Done ------------------------------------------------------------------------
  echo
  if [ "$failures" -gt 0 ]; then
    printf '%sFinished with %s problem(s) - see [FAIL] lines above.%s\n' "$C_FAIL" "$failures" "$C_RST"
    return 1
  fi
  printf '%sMachine ready.%s\n' "$C_OK" "$C_RST"
  printf '%s  Next: open a NEW terminal window, cd into a Unity project, run "claude", then type /studio:add%s\n' "$C_DO" "$C_RST"
  return 0
}

main "$@"
