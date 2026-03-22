# AGENTS.md — Rules for all AI assistants on this host

This file defines mandatory behavior for **any AI** running on this machine
(Claude, opencode, Cursor, Aider, Continue, etc.). Read this before doing
anything else.

---

## 1. Startup behavior (MUST DO — before any user prompt)

At the start of every session, **before responding to the user**, check the
Obsidian vault at `~/Obsidian/`:

| Folder | What to check | What to do |
|--------|---------------|------------|
| `01-Inbox` | New notes, raw captures | Process into Pending/Research/Ideas/Log |
| `02-Pending/Pending.md` | Open tasks, `#now` items | Report what's pending; prioritize for the session |
| `03-Log/` | Recent log entries (last 2 days) | Understand what broke/fixed recently |
| `04-Research/` | Active research notes | Carry context into current work |
| `05-Ideas/` | Active ideas | Reference if relevant to user's request |
| `06-AI-Chat-Logs/` | Previous session logs (last 2 days) | Understand what was done, what's carry-forward |
| `07-Templates/` | Available templates | Use when creating new vault files |

After reviewing, greet the user with:
1. A brief summary of pending work
2. Any carry-forward items from previous sessions
3. Then proceed with their request

---

## 2. Obsidian vault access rules

- **All AIs have full read/write access** to `~/Obsidian/` — no permission needed.
- When creating new vault files, **use templates** from `07-Templates/`.
- If no template fits the task, **create a new template** in `07-Templates/`.
- Log every significant session to `06-AI-Chat-Logs/YYYY-MM-DD.md` using
  the session template.
- Log errors, fixes, and system changes to `03-Log/` using the log template.
- Move completed items in `02-Pending/Pending.md` to `#completed` with date.

---

## 3. Vault folder structure

```
~/Obsidian/
├── 01-Inbox/           Raw captures, unprocessed notes
├── 02-Pending/         Active tasks and project tracking (Pending.md)
├── 03-Log/             Error logs, fix logs, system change logs
├── 04-Research/        Investigation notes (Research template)
├── 05-Ideas/           Concept development (Idea template)
├── 06-AI-Chat-Logs/    Daily session logs (Session template)
└── 07-Templates/       Templates for all file types
```

### File naming conventions
- Logs: `YYYY-MM-DD-title-slug.md`
- Research: `YYYY-MM-DD-topic-slug.md`
- Ideas: `short-descriptive-name.md`
- Session logs: `YYYY-MM-DD.md` (multiple sessions per file)

---

## 4. Templates (in `07-Templates/`)

| Template | Use for |
|----------|---------|
| `Session.md` | AI session logs (in `06-AI-Chat-Logs/`) |
| `Log-Entry.md` | Error/fix logs (in `03-Log/`) |
| `Research.md` | Investigation notes (in `04-Research/`) |
| `Idea.md` | Concept notes (in `05-Ideas/`) |

When creating a file, copy the template and replace `{{date}}`, `{{time}}`,
`{{title}}` placeholders with actual values.

---

## 5. NixOS config access rules

- The nixos-config repo at `~/nixos-config/` is the working directory.
- All AIs may read, edit, create, and delete files as needed.
- **Do NOT commit** unless explicitly asked by the user.
- **Do NOT run `nixos-rebuild`** unless explicitly asked.
- Run lint/typecheck after code changes if commands are known.
- Follow existing code conventions (check neighboring files first).

---

## 6. Workflow rules

1. Check vault at startup (section 1).
2. When the user describes work to do, check `02-Pending` first —
   it may already be tracked.
3. If the work is new, add it to `02-Pending/Pending.md` under `#now`.
4. Log the session to `06-AI-Chat-Logs/` when significant work is done.
5. Log errors/fixes to `03-Log/` when issues are resolved.
6. Update `02-Pending/Pending.md` when tasks are completed (move to `#completed`).
7. Carry-forward notes go at the bottom of session logs under "Notes / carry-forward".
