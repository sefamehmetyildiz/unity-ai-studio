---
name: doctor
description: Checks the Unity AI Studio setup on this machine, in a Unity project and in the open Unity Editor (CLIs, plugins, MCP, kit files, agent skill bridge, engine config, com.unity.pipeline, compile and console), and says how to fix each gap. Use when the user asks if the studio or system is ready, set up correctly, or why Claude cannot reach Unity.
argument-hint: "[unity-project-path | --machine]"
---

# Studio doctor

The kit root is `${CLAUDE_PLUGIN_ROOT}`. If that text appears literally (not
expanded), the kit root is two folders above this skill's base directory.
Below, `<kit>` means that folder.

## Steps

1. **Pick the scope.** Argument `--machine`, or a current folder that is not a
   Unity project (no `Assets/` + `ProjectSettings/ProjectVersion.txt`), means
   machine only. Otherwise the target is the argument path or the current folder.

2. **Run** (machine only adds `-MachineOnly`):

   ```
   powershell -NoProfile -ExecutionPolicy Bypass -File "<kit>/scripts/doctor.ps1" -ProjectPath "<target>"
   ```

   It prints one line per check: `OK`, `WARN`, `MISSING` or `FAIL`, each with
   the fix. It changes nothing except asking a connected Editor to recompile.

3. **Report** as a short table: what is ready, then each gap with its fix.
   Give a one-line verdict: ready / ready with warnings / not ready.

4. **Offer the fixes** you can run here and run them only on the user's yes:
   - kit files, rules, agent bridge, `.gitignore`: `/studio:update`
   - package: `unity pipeline install --project-path "<target>"`
   - MCP: `unity mcp configure claude -y`
   - plugins / CLIs: `powershell -NoProfile -ExecutionPolicy Bypass -File "<kit>/setup-machine.ps1"`
   - engine not set: the user runs `/setup-engine unity` (it asks them questions)

   Some fixes are the user's own: opening the project in Unity, upgrading the
   Editor in Unity Hub, fixing compile errors they wrote. Say so plainly.
