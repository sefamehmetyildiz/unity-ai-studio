---
name: update
description: Updates the Unity AI Studio files in a Unity project to the kit's current version, or adopts a project where Game Studios was installed by hand, keeping the project's own design docs and config. Use when the user wants to update or repair the studio, restore lost agent skill lines after a Game Studios upgrade, or after /studio:doctor reports an outdated kit.
argument-hint: "[unity-project-path]"
---

# Update the studio in a project

The kit root is `${CLAUDE_PLUGIN_ROOT}`. If that text appears literally (not
expanded), the kit root is two folders above this skill's base directory.
Below, `<kit>` means that folder.

## What an update touches

- **Overwritten** (old copies backed up to `.studio-backup/<time>/`): the kit's
  framework files — everything under `.claude/` except
  `.claude/docs/technical-preferences.md` and agent memory, the engine reference
  docs except their `VERSION.md`, `docs/CLAUDE.md`, `design/CLAUDE.md`,
  `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`, `.worktreeinclude`.
- **Never overwritten:** `CLAUDE.md`, `project.yaml`, `design/`, `production/`,
  `docs/architecture/`, everything in `Assets/`.
- The kit's block in `.gitignore` / `.gitattributes` is replaced; the rest of
  those files is left alone.
- Local edits to framework files are replaced too (they are in the backup).

## Steps

1. **Get the newest kit first.** Run `claude plugin marketplace update unity-ai-studio`
   then `claude plugin update studio@unity-ai-studio`. If the plugin itself was
   updated, tell the user to restart Claude Code and run `/studio:update` again
   (this session still runs the old kit files).

2. **Dry run.** Target is the argument or the current folder:

   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "<kit>/scripts/add-to-project.ps1" -ProjectPath "<target>" -Update -DryRun
   ```

   Summarize: files added / updated / removed, files kept as the project's own.
   If framework files the user may have edited on purpose will be replaced,
   name them.

3. **Ask, then update.** Ask "May I update the studio in `<target>`?" and wait
   for a yes. Run the same command without `-DryRun`.

4. **Finish.** Run `/studio:doctor` for the target. Tell the user to restart
   Claude Code in the project so the new agents, hooks and rules load. Do not
   commit; mention that `.studio-backup/` is gitignored and can be deleted once
   they are happy.
