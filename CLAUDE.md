# Unity AI Studio kit — maintainer notes

This repo is the **Unity AI Studio kit**, Sefa Mehmet Yıldız's personal kit
and his alone. Do not add any company, studio, team or client name to it, or
the name of a project that uses it. The kit is a Claude Code plugin and
marketplace that installs a ready-made AI game-dev environment into
any Unity project. The environment is Claude Code Game Studios (CCGS) wired to
the gamedev skills and Unity's official plugin, CLI and Editor MCP. Users
install it with `setup-machine.ps1` once per machine, then `/studio:add` per
project. See `README.md` (user docs) and `BASLANGIC.md` (beginner guide).

**Talk to the user in Turkish.** Code, comments, commit messages and script
output stay in English.

## Shipped content is not instructions for this repo

`payload/` is what gets copied into users' Unity projects. Its `CLAUDE.md`
files (`payload/CLAUDE.md`, `payload/docs/CLAUDE.md`,
`payload/design/CLAUDE.md`) and everything under `payload/.claude/` (rules,
agents, skills, hooks) are **product content**. Claude Code may load a nested
`CLAUDE.md` when you read files under `payload/`. Do not follow its rules here.
That includes the "May I write…" protocol, the engine setup and the code-root
tables. Only this file governs work in this repo.

## Layout

```
.claude-plugin/plugin.json       plugin "studio"  (repo root = plugin root)
.claude-plugin/marketplace.json  marketplace "unity-ai-studio", source "./"
skills/{add,doctor,update}/SKILL.md   /studio:add, /studio:doctor, /studio:update
setup-machine.ps1                one-time machine setup (self-contained)
scripts/common.ps1               shared helpers (dot-sourced)
scripts/add-to-project.ps1       install / -Update into a Unity project
scripts/doctor.ps1               machine + project + live Editor checks
templates/unity.gitignore        base Unity .gitignore (used when a project has none)
templates/studio.gitignore       kit block, between >>> / <<< unity-ai-studio markers
templates/studio.gitattributes   kit block, same markers
payload/                         files copied into the project root (651 files)
VERSION                          kit version
README.md, BASLANGIC.md, THIRD_PARTY.md, LICENSE
```

The installed copy lives at `~/.claude/plugins/cache/unity-ai-studio/studio/<version>/`.
Skills find it through `${CLAUDE_PLUGIN_ROOT}`, which is expanded in skill
text. This was verified: it resolves to that cache path. Each skill also gives
a fallback, "two folders above the skill's base directory".

## Hard rules (each one broke something before)

1. **Scripts must be pure ASCII.** Windows PowerShell 5.1 reads a BOM-less
   `.ps1` as the ANSI code page, so Turkish characters get garbled. Check with
   `LC_ALL=C grep -n '[^ -~	]' scripts/*.ps1 setup-machine.ps1`. It must print nothing.
2. **Target Windows PowerShell 5.1**, not only pwsh 7. Do not use `??`, `?.`,
   the ternary operator, `&&`/`||` or `ConvertFrom-Json -AsHashtable`. Test
   with `powershell.exe`.
3. **Never parse Claude Code's own JSON with `ConvertFrom-Json`.**
   `~/.claude.json` can contain keys that differ only by case (project paths),
   and PS 5.1 then fails. When that happened the doctor reported a configured
   MCP as missing. Use `Read-JsonDict` + `Get-JsonPath` (common.ps1); they use
   a case-sensitive JavaScriptSerializer. `setup-machine.ps1` has its own
   copies of these helpers.
4. **`setup-machine.ps1` must stay self-contained.** It runs as
   `irm .../setup-machine.ps1 | iex`. There, `$PSScriptRoot` is empty and
   nothing can be dot-sourced. A bare `exit` would close the user's shell, so
   it only exits when `$PSCommandPath` is set. It must stay idempotent: skip
   anything already installed.
5. **Project-owned files are never overwritten.** `Test-FrameworkFile`
   (common.ps1) decides what `-Update` overwrites:
   - Framework: `.claude/**`, except `.claude/docs/technical-preferences.md`
     and `.claude/agent-memory/`.
   - Framework: `docs/engine-reference/**`, except `*/VERSION.md`.
   - Framework: `docs/CLAUDE.md`, `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`,
     `design/CLAUDE.md`, `.worktreeinclude`.
   - Everything else is a seed. Seeds are copied only when missing.
     `CLAUDE.md` and `project.yaml` are seeds because CCGS's `/setup-engine`
     edits them.

   Changing this function changes what users lose on update. Document it in
   the update skill and in the README.
6. **Install never overwrites anything.** Only `-Update` overwrites, and only
   framework files. It backs them up to `.studio-backup/<time>/` first.
   Framework files that were in the old stamp's `files` list but are gone from
   the payload are moved to that backup.
7. **Git config is merged, never replaced.** Only the marked block in
   `.gitignore` / `.gitattributes` is inserted or replaced (`Set-ManagedBlock`).
8. **Bump the version in three places together**: `VERSION`,
   `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`. Users only
   receive a change after a bump and push, then
   `claude plugin marketplace update unity-ai-studio` and
   `claude plugin update studio@unity-ai-studio`.
9. **Never commit or push without the user's explicit OK.**

## add-to-project.ps1 contract

- Flags: `-ProjectPath` (default: current folder), `-Update`, `-Force` (also
  install into a non-Unity folder), `-SkipPackage`, `-DryRun`.
- Exit codes: `0` ok, `2` not a Unity project, `3` already installed (use
  `-Update`).
- A Unity project is a folder with `Assets/` and
  `ProjectSettings/ProjectVersion.txt`.
- Writes `.claude/studio-kit.json`: kit name, version, installedAt, updatedAt
  and the payload `files` list.
- Adds `com.unity.pipeline` with `unity pipeline install --project-path`.

## Payload origin

`payload/` is **CCGS 1.3.0** (https://github.com/Donchitos/Claude-Code-Game-Studios,
commit `abc0de7`, MIT, see `payload/.claude/CCGS-LICENSE`). The template's
`src/`, `studio-tests/` and repo meta files are left out. It has these local
changes:

- `skills:` frontmatter lines in 9 agents:
  - `unity-specialist`, `gameplay-programmer`, `ai-programmer`,
    `ui-programmer`, `unity-ui-specialist`
  - `unity-shader-specialist`, `technical-artist`, `performance-analyst`,
    `prototyper`

  The table in `payload/.claude/rules/plugin-integration.md` is the source of
  truth for these lines.
- `payload/.claude/rules/plugin-integration.md`: routing between CCGS,
  gamedev and Unity skills, the "Editor first" rule, the version check,
  overlaps and the subagent preload table.
- `payload/.claude/settings.json`: `extraKnownMarketplaces` + `enabledPlugins`
  for the three plugins. Teammates who open a project are offered them.
- `production/.gitkeep`.
- `.gitattributes` moved out of the payload into `templates/studio.gitattributes`.

**Upgrading CCGS:**
1. Clone the new release.
2. Diff it against `payload/`.
3. Copy the upstream files over.
4. Re-apply the local changes above.
5. Update `THIRD_PARTY.md`.
6. Bump the kit version.

Plugin-namespaced names in agent `skills:` frontmatter work: preloading was
verified by having an agent quote the skill headings.

## External pieces setup-machine.ps1 relies on

| Piece | How it is installed |
|---|---|
| Claude Code | `irm https://claude.ai/install.ps1 \| iex`, installs to `~/.local/bin`, which the script adds to the user PATH |
| Unity CLI | `$env:UNITY_CLI_CHANNEL='beta'; irm https://public-cdn.cloud.unity3d.com/hub/prod/cli/install.ps1 \| iex`, installs to `%LOCALAPPDATA%\Unity\bin` |
| `gamedev@awesome-gamedev-agent-skills` | `claude plugin marketplace add gamedev-skills/awesome-gamedev-agent-skills` + `claude plugin install ... --scope user` |
| `unity@unity-agent-plugin` + Unity CLI skills in `~/.claude/skills` | `unity setup claude -y` |
| MCP `unity-editor-mcp` | `unity mcp configure claude -y --replace-legacy`, fallback `claude mcp add --scope user unity-editor-mcp -- <unity.exe> mcp --tool-groups` |
| `studio@unity-ai-studio` | `claude plugin marketplace add sefamehmetyildiz/unity-ai-studio` (falls back to the local clone) + install |

`claude plugin marketplace add` and `plugin install` are idempotent: both
succeed when the item is already present. Useful Unity CLI calls for the
doctor:
- `unity --json status`: `data.instances[].projectPath/state/port`.
- `unity --json command console status --project-path <p>`:
  `groundTruth.compilationFailed/consoleErrors`.
- `unity recompile --project-path <p>`.

## How to test a change

Run this before every commit that touches scripts or the payload.

1. **Parse check** in PS 5.1: run `powershell.exe -NoProfile -File <script>`,
   or use `[System.Management.Automation.Language.Parser]::ParseFile` on each
   `.ps1`.
2. **Scratch Unity project.** Create it in a temp/scratchpad folder, never
   inside this repo:
   - `ProjectSettings/` copied from any real Unity project.
   - `Packages/manifest.json` with `com.unity.pipeline` removed (edit it with
     node/JSON, not with grep, which leaves a trailing comma).
   - An empty `Assets/`.
   - Optionally a `.gitignore` of its own, to test the merge.
3. **Run the sequence:**
   1. `add-to-project.ps1 -DryRun`
   2. A real install.
   3. A second install, which must exit 3.
   4. Tamper with the project:
      - delete a `skills:` line in an agent
      - delete `plugin-integration.md`
      - append to `project.yaml` and `technical-preferences.md`
      - add an obsolete file to the stamp's `files` list
   5. `-Update`. Framework files must be restored, owned files kept, the
      obsolete file moved to backup and the gitignore block present once.
   6. `doctor.ps1 -NoEditor`.
4. **Live Editor check:** run `doctor.ps1 -ProjectPath <a project open in
   Unity>`. Editor connected, compile and console checks should pass.
5. **Plugin manifest:** `claude plugin validate .` must pass. The README
   warning is gone; a missing icon is only a warning.
6. **`setup-machine.ps1 -DryRun`.** To test the `iex` path without changing
   the machine, pipe a copy whose `$DryRun` switch defaults to `$true` into
   `Invoke-Expression`.

Note: in auto mode, Claude is not allowed to run `irm <remote> | iex` itself.
Run the local file instead, or let the user run the one-liner.

## Known gaps / ideas

- Windows only. There is no macOS/Linux `setup-machine.sh` yet.
- No plugin icon (`.claude-plugin/icon.png`, 512–2048 px square PNG).
- The gamedev skills and CCGS engine docs target Unity 6.3 LTS. The doctor
  warns on older editors.
- `/studio:*` skill runs are verified only manually, not with `claude plugin eval`.
