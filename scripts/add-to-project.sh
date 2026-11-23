#!/usr/bin/env bash
# Installs (or updates) the Unity AI Studio kit into a Unity project.
# macOS / Linux counterpart of add-to-project.ps1: same behaviour, same exit codes.
#
# Install mode copies files that are missing and never overwrites existing ones.
# --update also overwrites the kit's framework files (.claude/..., engine
# reference docs) after backing up the old copies to .studio-backup/<time>/.
# Project-owned files are never overwritten: CLAUDE.md, project.yaml, design/,
# production/, docs/architecture/, .claude/docs/technical-preferences.md.
#
# Usage: bash add-to-project.sh [--project-path P] [--update] [--force] [--skip-package] [--dry-run]
# Exit codes: 0 ok, 2 not a Unity project, 3 already installed (use --update).

set -u
unset CDPATH
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

PROJECT_PATH="$(pwd)"; UPDATE=0; FORCE=0; SKIP_PACKAGE=0; DRY_RUN=0
while [ $# -gt 0 ]; do
  case "$1" in
    --project-path|-ProjectPath)
      [ $# -ge 2 ] || { echo "Missing value for $1" >&2; exit 64; }
      shift; PROJECT_PATH="$1" ;;
    --update|-Update) UPDATE=1 ;;
    --force|-Force) FORCE=1 ;;
    --skip-package|-SkipPackage) SKIP_PACKAGE=1 ;;
    --dry-run|-DryRun) DRY_RUN=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 64 ;;
  esac
  shift
done

if ! abs="$(cd "$PROJECT_PATH" 2>/dev/null && pwd)"; then
  write_status FAIL "Folder not found: $PROJECT_PATH"; exit 2
fi
PROJECT_PATH="$abs"
KIT_VERSION="$(kit_version)"
MODE=Install; [ "$UPDATE" = 1 ] && MODE=Update
TAG=''; [ "$DRY_RUN" = 1 ] && TAG=' (dry run: nothing is written)'
printf '%sUnity AI Studio kit v%s -> %s  [%s]%s%s\n' "$C_B" "$KIT_VERSION" "$PROJECT_PATH" "$MODE" "$TAG" "$C_RST"

# --- 1. Target checks --------------------------------------------------------
if ! is_unity_project "$PROJECT_PATH"; then
  if [ "$FORCE" != 1 ]; then
    write_status FAIL 'Not a Unity project (needs Assets/ and ProjectSettings/ProjectVersion.txt). Use --force to install anyway.'
    exit 2
  fi
  write_status WARN 'Not a Unity project; continuing because of --force.'
fi

STAMP="$PROJECT_PATH/$KIT_STAMP_REL"
if [ "$UPDATE" != 1 ] && { [ -f "$STAMP" ] || [ -d "$PROJECT_PATH/.claude/agents" ]; }; then
  v='unknown (installed by hand)'
  [ -f "$STAMP" ] && v="$(json_string_field "$STAMP" version)"
  write_status FAIL "The studio is already in this project (version $v). Run again with --update to refresh it."
  exit 3
fi

# --- 2. Payload files --------------------------------------------------------
write_section 'Files'
TIME_TAG="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$PROJECT_PATH/.studio-backup/$TIME_TAG"
LIST="$(mktemp "${TMPDIR:-/tmp}/studio-files.XXXXXX")"
KEPT="$(mktemp "${TMPDIR:-/tmp}/studio-kept.XXXXXX")"
payload_files > "$LIST"
added=0; updated=0; same=0; removed=0; failed=0

# Every write is checked: a failed copy is reported, never counted as done,
# and stops the stamp from being written (the .ps1 aborts on any error too).
fail_write() { write_status FAIL "Could not write $1"; failed=$((failed + 1)); }

backup_file() {
  [ "$DRY_RUN" = 1 ] && return 0
  mkdir -p "$(dirname "$BACKUP_ROOT/$1")" && cp -p "$PROJECT_PATH/$1" "$BACKUP_ROOT/$1"
}

while IFS= read -r rel; do
  [ -z "$rel" ] && continue
  src="$PAYLOAD_ROOT/$rel"; dst="$PROJECT_PATH/$rel"
  if [ ! -e "$dst" ]; then
    if [ "$DRY_RUN" != 1 ] && ! { mkdir -p "$(dirname "$dst")" && cp "$src" "$dst"; }; then
      fail_write "$rel"; continue
    fi
    added=$((added + 1)); continue
  fi
  if same_content "$src" "$dst"; then same=$((same + 1)); continue; fi
  if [ "$UPDATE" = 1 ] && is_framework_file "$rel"; then
    if ! backup_file "$rel"; then fail_write "$rel (backup)"; continue; fi
    if [ "$DRY_RUN" != 1 ] && ! cp -f "$src" "$dst"; then fail_write "$rel"; continue; fi
    updated=$((updated + 1))
  else
    echo "$rel" >> "$KEPT"
  fi
done < "$LIST"

# Framework files the previous kit version shipped and this one no longer does.
if [ "$UPDATE" = 1 ] && [ -f "$STAMP" ]; then
  while IFS= read -r old; do
    [ -z "$old" ] && continue
    if grep -qxF "$old" "$LIST" || ! is_framework_file "$old"; then continue; fi
    if [ -e "$PROJECT_PATH/$old" ]; then
      if ! backup_file "$old"; then fail_write "$old (backup)"; continue; fi
      if [ "$DRY_RUN" != 1 ] && ! rm -f "$PROJECT_PATH/$old"; then fail_write "$old"; continue; fi
      removed=$((removed + 1))
    fi
  done <<EOF
$(stamp_files "$STAMP")
EOF
fi

write_status OK "$added added, $updated updated, $same already current, $removed removed (obsolete)"
if [ "$failed" -gt 0 ]; then
  write_status FAIL "$failed file(s) could not be written. Nothing was stamped; fix the permissions and run again."
  rm -f "$LIST" "$KEPT"
  exit 1
fi
if [ $((updated + removed)) -gt 0 ]; then
  if [ "$DRY_RUN" = 1 ]; then write_status INFO "Previous copies would be backed up to .studio-backup/$TIME_TAG"
  else write_status INFO "Previous copies backed up to .studio-backup/$TIME_TAG"; fi
fi
kept_count="$(wc -l < "$KEPT" | tr -d ' ')"
if [ "$kept_count" -gt 0 ]; then
  write_status INFO "$kept_count file(s) differ from the kit and were kept as the project's own:"
  head -n 15 "$KEPT" | sed 's/^/            /'
  if [ "$kept_count" -gt 15 ]; then echo "            ... and $((kept_count - 15)) more"; fi
fi

# --- 3. .gitignore / .gitattributes blocks ------------------------------------
write_section 'Git config'
r="$(set_managed_block "$PROJECT_PATH/.gitignore" "$TEMPLATE_ROOT/studio.gitignore" "$TEMPLATE_ROOT/unity.gitignore" "$DRY_RUN")"
write_status OK ".gitignore: $r"
r="$(set_managed_block "$PROJECT_PATH/.gitattributes" "$TEMPLATE_ROOT/studio.gitattributes" '' "$DRY_RUN")"
write_status OK ".gitattributes: $r"

# --- 4. Unity package --------------------------------------------------------
write_section 'Unity package'
MANIFEST="$PROJECT_PATH/Packages/manifest.json"
if [ "$SKIP_PACKAGE" = 1 ]; then
  write_status INFO 'Skipped (--skip-package).'
elif [ ! -f "$MANIFEST" ]; then
  write_status WARN 'Packages/manifest.json not found; com.unity.pipeline not added.'
elif grep -q '"com\.unity\.pipeline"' "$MANIFEST"; then
  write_status OK 'com.unity.pipeline already in Packages/manifest.json'
else
  UNITY="$(find_unity)"
  if [ -z "$UNITY" ]; then
    write_status WARN 'Unity CLI not found. Run setup-machine.sh, then: unity pipeline install --project-path <project>'
  elif [ "$DRY_RUN" = 1 ]; then
    write_status DO 'Would run: unity pipeline install'
  else
    if "$UNITY" --no-banner pipeline install --project-path "$PROJECT_PATH" </dev/null; then write_status OK 'com.unity.pipeline added'
    else write_status WARN 'unity pipeline install failed; add it later with the same command.'; fi
  fi
fi

# --- 5. Stamp ----------------------------------------------------------------
# Same fields as the PowerShell writer, so either OS can read the other's stamp.
if [ "$DRY_RUN" != 1 ]; then
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  installed_at="$now"
  if [ -f "$STAMP" ]; then
    prev="$(json_string_field "$STAMP" installedAt)"
    [ -n "$prev" ] && installed_at="$prev"
  fi
  mkdir -p "$(dirname "$STAMP")"
  {
    printf '{\n  "kit": "unity-ai-studio",\n  "version": "%s",\n  "installedAt": "%s",\n  "updatedAt": "%s",\n  "files": [\n' "$KIT_VERSION" "$installed_at" "$now"
    awk 'NR > 1 { printf ",\n" } { printf "    \"%s\"", $0 } END { printf "\n" }' "$LIST"
    printf '  ]\n}\n'
  } > "$STAMP.tmp" && mv "$STAMP.tmp" "$STAMP"
fi
rm -f "$LIST" "$KEPT"

# --- 6. Next steps -----------------------------------------------------------
write_section 'Next'
if [ "$MODE" = Install ]; then
  write_status DO 'Open the project in Unity (it downloads com.unity.pipeline on first load).'
  write_status DO 'Start Claude Code in the project folder and run: /setup-engine unity'
  write_status DO 'Then: /studio:doctor   (checks everything)   and   /start or "make me a game ..."'
else
  write_status DO 'Restart Claude Code in this project so the updated agents, skills and hooks load.'
  write_status DO 'Then run /studio:doctor'
fi
exit 0
