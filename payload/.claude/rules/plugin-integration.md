# Plugin Integration — CCGS + gamedev + Unity

This project runs three layers together. This file says which one owns what, so
a task goes to the right skill instead of three overlapping ones.

> Installed by the **Unity AI Studio kit** (`studio@unity-ai-studio`),
> not part of the CCGS framework. The kit version is in `.claude/studio-kit.json`.
> A raw CCGS upgrade that overwrites `.claude/agents/` drops the `skills:` lines
> added to the Unity-facing agents — run `/studio:update` instead, or re-add them
> from the table at the bottom.

## Studio kit commands

| Command | Does |
|---|---|
| `/studio:doctor` | Checks the machine (CLIs, plugins, MCP), this project (kit files, package, engine config) and the open Editor (connection, compile, console). Run it first when something seems off. |
| `/studio:update` | Applies the kit's current framework files to this project. Never touches `CLAUDE.md`, `project.yaml`, `design/`, `production/` or `docs/architecture/`. |
| `/studio:add` | Installs the kit into another Unity project. |

## Who owns what

| Layer | Owns | Entry points |
|---|---|---|
| **CCGS** (this `.claude/`) | The **process**: idea → brief → GDD → architecture/ADR → epics → stories → sprint → QA → release. Documents, gates, reviews. | `/start`, `/next-step`, `/prototype`, `/design-system`, `/create-stories`, `/sprint-plan`, `/gate-check` |
| **gamedev** plugin | **How-to knowledge**, engine-neutral and per-engine: genre design, game feel, AI, saves, audio, cameras, performance. | `gamedev:router` when unsure; else the named skill |
| **Unity official** (`unity:` plugin + Unity CLI user skills) | **Unity specifics and the Editor itself**: UI Toolkit/uGUI, URP, tilemaps, sprites, packages, IAP, multiplayer, live control of the open Editor. | `unity-cli`, `unity-pipeline`, `unity:ui`, … |

**Rule of thumb:** CCGS decides *what* and *when*; gamedev decides *how it should
work and feel*; Unity skills decide *how Unity does it* and **do** it in the Editor.

## Routing by CCGS phase

| CCGS phase / skill | Also load |
|---|---|
| `/brainstorm`, `/prototype` (concept) | `gamedev:<genre>` (`platformer`, `roguelike`, `puzzle`, `card-game`, …), `gamedev:prototype-fast`, `gamedev:game-jam` for time-boxed work |
| First playable / "feels flat" | `craft-game-floors`, `gamedev:game-feel`, `gamedev:camera-systems` |
| `/design-system`, `/quick-design` | the genre skill + the discipline skill for that system (`gamedev:save-systems`, `gamedev:game-ai`, `gamedev:dialogue-systems`, `gamedev:input-systems`, `gamedev:audio-design`, `gamedev:level-design`, `gamedev:rpg` for stats/economy) |
| `/create-architecture`, `/architecture-decision` | `gamedev:unity-scriptableobjects` (data/decoupling), `gamedev:unity-build-pipeline` |
| Story implementation (C#) | `gamedev:unity-csharp-scripting` + the subsystem skill (`gamedev:unity-input-system`, `gamedev:unity-physics` / `create-2d-physics`, `gamedev:unity-animation`, `gamedev:unity-navmesh`, `gamedev:unity-tilemap-2d`) |
| Scenes, prefabs, GameObjects | `unity-cli` + `unity-pipeline` — see "Editor first" below |
| UI / HUD (`/team-ui`, `/ux-design`) | `unity:ui` (routes to `ui-uitk` / `ui-ugui`) + `gamedev:game-ui-ux` |
| Art / VFX / shaders | `gamedev:create-game-assets`, `unity:manage-sprite-atlas`, `unity:sprite-editor`, `unity:urp-postprocessing`, `unity:shader-graph-create-custom-node`, `gamedev:shader-programming` |
| Audio (`/team-audio`) | `gamedev:audio-design`, `unity:audio-setup-mixers`, `unity:optimize-audio` |
| `/localize` | `localize-unity-project` |
| `/perf-profile`, `/team-polish` | `gamedev:performance-optimization`, `project-auditor-fixes`, `gamedev:unity-build-size` |
| `/test-setup`, `/smoke-check` | `unity-pipeline` (compile, run tests, Play Mode, screenshots) |
| `/release-checklist`, `/team-release` | `gamedev:unity-build-pipeline`, `gamedev:steam-publish` / `gamedev:itch-publish`, `manage-cloud-build` |
| Online play, live-ops | `build-multiplayer-game`, `unity:build-live-game`, `unity:implement-in-app-purchases` |

## Editor first

Before creating or editing a scene, prefab, GameObject or asset, check for a
connected Editor: `unity status` (CLI at `%LOCALAPPDATA%\Unity\bin\unity.exe`) or
the `unity-editor-mcp` MCP tools. If an Editor is connected, drive it — do not
hand-edit `.unity` / `.prefab` / `.asset` YAML. Hand-editing is the fallback when
no Editor is reachable, and then say so. Requires the `com.unity.pipeline`
package (already in `Packages/manifest.json`).

After any C# change, compile through the Editor (`unity-pipeline`) and read the
console before reporting the story done. Compile errors put the Editor in Safe
Mode, which cuts the CLI/MCP connection — fix them first.

## Version check

`ProjectSettings/ProjectVersion.txt` is the truth for the Unity version. The
gamedev Unity skills and `docs/engine-reference/unity/` target **Unity 6.3 LTS**.
If the project is on an older editor, check any API a skill suggests against
that version before using it.

## Overlaps — which one wins

| Overlap | Use |
|---|---|
| Unity CLI user skills (v1.0.1) vs `unity:` plugin (v0.1.6-beta) | The CLI user skills are newer: `fix-3d-physics-collisions` over `unity:physics-3d-collision`, `localize-unity-project` over `unity:localization`, `create-tile-palette-or-rule-tiles` over `unity:tilemap-*` |
| `/prototype` vs `gamedev:prototype-fast` | `/prototype` runs the flow (brief → build → proceed/pivot/kill); load `gamedev:prototype-fast` inside it for scoping |
| `/perf-profile` vs `gamedev:performance-optimization` | `/perf-profile` owns the report; the gamedev skill supplies the method |
| `/code-review` | This is CCGS's architecture/standards review. It shadows Claude Code's built-in bug-hunting `/code-review` in this project |
| `unity-developer` user skill | Generic; prefer the specific skills above |

## Subagents

CCGS subagents have no Skill tool and no MCP tools. The Unity-facing ones get
their core skills **preloaded** through `skills:` in their frontmatter (table
below) and reach the Editor through the `unity` CLI with Bash. When an
orchestrating skill (`/team-*`, `/create-stories` follow-up) briefs a subagent
on something outside its preloaded set — a genre or a discipline skill — name
the skill in the brief and paste the relevant rules from it, since the
subagent cannot load it itself.

| Agent | Preloaded skills |
|---|---|
| `unity-specialist` | `gamedev:unity-csharp-scripting`, `gamedev:unity-scriptableobjects`, `unity:unity-package-management`, `unity-pipeline` |
| `gameplay-programmer` | `gamedev:unity-csharp-scripting`, `gamedev:unity-input-system`, `gamedev:unity-physics`, `unity-pipeline` |
| `ai-programmer` | `gamedev:game-ai`, `gamedev:unity-navmesh` |
| `ui-programmer`, `unity-ui-specialist` | `unity:ui`, `gamedev:game-ui-ux` |
| `unity-shader-specialist` | `unity:urp-postprocessing`, `unity:shader-graph-create-custom-node`, `gamedev:shader-programming` |
| `technical-artist` | `gamedev:create-game-assets`, `unity:manage-sprite-atlas` |
| `performance-analyst` | `gamedev:performance-optimization`, `gamedev:unity-build-size`, `project-auditor-fixes` |
| `prototyper` | `gamedev:prototype-fast`, `craft-game-floors`, `unity-pipeline` |
