# action__manage_address_book

Two verbs.

`<upskill>` is the launcher from SKILL.md step 0 - it fetches the current version before running.
Do not run the scripts directly, and do not edit them. `<this-skill>` is the folder holding the
upskill SKILL.md; scripts live under `<this-skill>/actions/action__manage_address_book/scripts/`.

### add an address book

The user gives a git repo of an address book (they may paste a URL). Clone it into the workspace:

`<upskill> create-address-book "<repo-url|local-path>"`

It does NOT switch - tell the user it was added, and that switching is the next step if they want to
work in it now.

### change (switch) address book

The user names another installed team (e.g. "switch to design", or the name the menu printed). Point
the config at it:

`<upskill> switch-address-book "<team-or-address-book-name>"`

Accept `sandbox`, `team__sandbox`, or `upskill__address_book__sandbox` spellings. If the team is not
installed, say so and offer to add it (create). Ask which one if the user has not said.
