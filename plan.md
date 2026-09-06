# upskill - rebuild plan

Rebuild from `usage.md`. Bash only; `.ps1` mirroring is a separate pass at the end.
Salvage from `upskill__bk/` where the old code still fits, rewrite where the model changed.

## Target tree

```text
upskill/                              <- the git repo, symlinked from ~/.claude/skills/upskill
├── SKILL.md                          router: menu + 5 options
├── usage.md                          the spec this plan implements
├── plan.md                           this file
├── upskill__user_config.json         gitignored, per machine
├── upskill__user_config.example.json
├── scripts/
│   ├── upskill__lib.sh               config + address book + shared helpers
│   └── upskill__run.sh               launcher: self-update, then dispatch
├── actions/
│   ├── action__show_menu/            option 0
│   ├── action__receive_skills/       options 1, 2
│   ├── action__provide_skills/       options 3, 4 (+ secret scan)
│   └── action__manage_address_book/  option 5 (import only)
└── .install/
    ├── upskill__install.sh           builds the skills_lib tree, clones this repo
    ├── install/custom/*.md           per-team one-liners
    ├── guide__create_public_skills/
    └── guide__import_address_book/
```

## Ground rules

| Rule | |
|---|---|
| Config | `{"skills_lib_root": "<abs>", "address_book": "./upskill__address_book/<file>.json"}` |
| Self-update | on `prod`: `git fetch origin prod && git reset --hard origin/prod && git clean -fd`; any other branch: skip |
| Address book keys | `<owner>__<repo>`; `name` is a display alias only; one clone per repo |
| Menu | zero network - names only, never skill counts |
| Output | every script's stdout is printed verbatim as the whole reply |
| Failure | print the error and stop; never improvise git, never edit a script to work around it |

---

## Phase 0 - installer

Source: `upskill__management/upskill__install.sh` (workspace model - rewrite, do not copy).

- [x] `.install/upskill__install.sh` - accepts `UP_SKILL_ADDRESS_BOOK` = a **raw json URL** in `mingzilla/upskill__setup`, e.g.
      `https://raw.githubusercontent.com/mingzilla/upskill__setup/main/address_books/address_book__ken.json`
- [x] Fix `install/custom/action__install__sandbox__linux.md` - both URLs in it are stale:
      installer is now `https://raw.githubusercontent.com/mingzilla/upskill/prod/.install/upskill__install.sh`,
      address book now comes from `upskill__setup`, not `upskill/.install/guide__import_address_book/`
- [ ] Retire `upskill/.install/guide__import_address_book/address_book.json` - `upskill__setup` is the source of truth now
- [x] Prompt for skills_lib root; offer platform defaults (`E:\code\upskill__skills_lib`, `~/code/upskill__skills_lib`), allow free text
- [x] Create the tree: `private_files/ private_skills/ public_skills/ upskill__address_book/ upskill__sandbox/`
- [x] `upskill__sandbox/.claude/skills/` created eagerly so "add here" works on day one
- [x] Clone `upskill` repo at `prod` into `<root>/upskill`, symlink `~/.claude/skills/upskill` -> it
- [x] Ask for the user's `public_skills` repo URL, clone it to `<root>/public_skills` (guide: `.install/guide__create_public_skills/README.md`)
- [x] Fetch the address book json into `<root>/upskill__address_book/address_book.json`
- [x] Write `upskill__user_config.json`
- [x] Preflight before writing anything: git present, address book reachable, repo URL valid
- [x] Re-run is safe: existing dirs are kept, only config + symlink are rewritten
- [x] `.install/uninstall/upskill__uninstall.sh` - remove symlink, tell the user where the tree is; never delete their skills

**Settled:** the installer refuses when the user's entry (and so their `public_skills` url) is not in the address book. The guide asks people to create `public_skills` + `private_skills` up front; `private_skills` is cloned when it exists and skipped without failing when it does not.

---

## Phase 1 - foundation

- [ ] `scripts/upskill__lib.sh` - salvage from `upskill__bk/scripts/upskill__lib.sh`
  - keep: `us::require`, `us::jget`, `us::validate_skill`, `us::skill_names`, `us::safe_name`
  - rewrite: `us::init` / `us::load_config` -> read `skills_lib_root` + `address_book`, drop `US_TEAM`/workspace walk-up
  - rewrite: `us::members` -> emit `key<TAB>name<TAB>repo` from the new schema
  - add: `us::pool_dir <key>` -> `<root>/upskill__address_book/<key>`
  - add: `us::sync_repo <key>` -> clone if absent, else pull (import rule: existing = pull, never re-clone)
  - add: `us::my_repo` -> `<root>/public_skills` (identity = its `origin`, no `user` field in config)
- [ ] `scripts/upskill__run.sh` - salvage the dispatch table only; replace the whole workspace/self-update body with the branch rule above
- [ ] `SKILL.md` - retarget the routing table (option 5 is now Import contacts), drop the `.ps1` column until the mirror pass

---

## Phase 2 - menu (usage.md "Default")

- [ ] `actions/action__show_menu/` - salvage, strip counts
- [ ] Prints: book name, member display names, the 4 + 1 options - no network, no `(cached)` markers

---

## Phase 3 - show a member's skills (option 1)

- [ ] `actions/action__receive_skills/scripts/upskill__list.sh` - salvage
- [ ] Resolve display name -> key; sync that one repo; list skill folders numbered
- [ ] Ends with the "Where would you like to add this?" prompt shape from usage.md
- [ ] Ambiguous display name (two repos, same `name`) -> report the clash, do not guess

---

## Phase 4 - add a member's skill (option 2)

- [ ] `actions/action__receive_skills/scripts/upskill__add.sh` - salvage
- [ ] Targets: `1. upskill__sandbox (Recommended)` / `2. current project` / `3. a path`
- [ ] No `--project` given -> exit 2 + print the numbered target menu
- [ ] Already present in target -> overwrite and say "updated", not "added"
- [ ] Keep the sandbox/permission message for Codex

---

## Phase 5 - share a skill (option 3)

- [ ] `actions/action__provide_skills/scripts/upskill__share.sh` - salvage, retarget `US_ME_DIR` -> `<root>/public_skills`
- [ ] `upskill__scan_secrets.sh` - **already written**, keep as is
- [ ] Scan source before copy; scan whole repo before commit; roll back on hit
- [ ] After push, refresh the pool clone of my own repo, or "show my skills" shows a stale list
- [ ] Confirm the destination URL with the user before the first push

---

## Phase 6 - remove a shared skill (option 4)

- [ ] `actions/action__provide_skills/scripts/upskill__remove.sh` - salvage
- [ ] Bare `remove` -> numbered list of my own shared skills
- [ ] Only ever touches `<root>/public_skills`

---

## Phase 7 - import contacts (option 5)

- [ ] `actions/action__manage_address_book/scripts/upskill__import_contacts.sh` - new; the old create/switch scripts are deleted, do not restore them
- [ ] Input: a URL to an `address_book.json`, normally one of `mingzilla/upskill__setup/address_books/*.json`
- [ ] Accept `github.com/.../blob/...` and `/tree/...` URLs, convert to `raw.githubusercontent.com`
- [ ] Merge into the active book by key; existing key -> keep the entry, `git pull` the pool clone; never re-clone
- [ ] Report `Imported: <names>` and, separately, any key already present
- [ ] Duplicate display `name` across two keys -> report the clash, import anyway

---

## Phase 8 - .ps1 mirror

- [ ] Only after phases 0-7 are working. One `.ps1` per `.sh`, same args, same exit codes
- [ ] `upskill__scan_secrets.ps1` already exists - re-verify, its in-process call is untested

---

## Open decisions

| # | Question | Blocks |
|---|---|---|
| 1 | ~~public_skills fallback~~ **settled**: refuse, point at the guide | - |
| 2 | ~~address book source~~ **settled**: raw json URL from the public `upskill__setup` repo | - |
| 3 | ~~private_skills~~ **settled**: its own repo, cloned at install; scanned like any other source | - |
| 4 | ~~private_files guard~~ **settled**: installer appends `private_files/` to the root `.gitignore` | - |
