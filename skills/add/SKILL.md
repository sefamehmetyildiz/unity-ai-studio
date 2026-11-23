---
name: add
description: Installs the Unity AI Studio (Claude Code Game Studios + gamedev skills + Unity official plugin wiring) into a Unity project. Use when the user wants to add the studio, Game Studios or this AI setup to a Unity project, or to set up a new or existing Unity project for Claude.
argument-hint: "[unity-project-path]"
---

# Add the studio to a Unity project

The kit root is `${CLAUDE_PLUGIN_ROOT}`. If that text appears literally (not
expanded), the kit root is two folders above this skill's base directory.
Below, `<kit>` means that folder.

**Pick the script for this OS.** On Windows use the PowerShell script; on macOS
or Linux use the bash script. They take the same options and return the same
exit codes:

| | Windows | macOS / Linux |
|---|---|---|
| Install | `powershell -NoProfile -ExecutionPolicy Bypass -File "<kit>/scripts/add-to-project.ps1" -ProjectPath "<target>"` | `bash "<kit>/scripts/add-to-project.sh" --project-path "<target>"` |
| Dry run | add `-DryRun` | add `--dry-run` |
| Force | add `-Force` | add `--force` |

## Steps

1. **Pick the target.** Use the argument if one was given, else the current
   working directory. It must be a Unity project: it has `Assets/` and
   `ProjectSettings/ProjectVersion.txt`. If not, say so and ask for the path.
   Do not use the force option unless the user asks for it.

2. **Dry run and show.** Run the install command for this OS with the dry-run
   option.

   Exit code 3 means the studio is already in that project: stop and offer
   `/studio:update` instead. Exit code 2 means it is not a Unity project.
   Otherwise summarize for the user: how many files are added, which existing
   files are kept as the project's own, the `.gitignore` / `.gitattributes`
   change and whether `com.unity.pipeline` is added.

3. **Ask, then install.** Ask "May I install the studio into `<target>`?" and
   wait for a yes. Then run the same command without the dry-run option.

4. **Check.** Run `/studio:doctor` for the target (the doctor skill's command
   for this OS with the target path). Report what is OK and what is left.

5. **Hand over the next steps** in this order:
   - If any existing `CLAUDE.md` was kept as the project's own, it must be merged
     with `<kit>/payload/CLAUDE.md` or Game Studios will not load its rules.
     Offer to do the merge.
   - Open the project in Unity once (it downloads `com.unity.pipeline`).
   - Restart Claude Code **in the project folder**: agents, hooks, rules and
     `CLAUDE.md` load only at session start.
   - In the new session: `/setup-engine unity`, then `/start` (guided) or
     `/prototype` ("make me a game ...").

Do not commit anything. The user decides when to commit.
