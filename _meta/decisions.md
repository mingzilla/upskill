# Decisions and WHY

- [Share, Replace] - share replaces the whole folder: `rm -rf "$DEST"` then `cp -R` in `share::copy`. Stale files cannot survive, and a failed run exits before the push, so nothing partial reaches a teammate.
- [Share, Orphans] - a rename leaves the old folder behind. Delete it by hand; a sweep cannot tell an orphan from a skill shared from another machine, because `resolve_src` only sees this project and `private_skills`.
