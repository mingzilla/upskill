# action__import_contacts

One verb: import people into the address book you are already using.

`<upskill>` is the launcher from SKILL.md. Do not run the script directly, and do not edit it.

## Import contacts (option 5)

The script takes a **url or a file path** - never raw json, which no command line survives intact.

| The user gives you | Do |
|---|---|
| a link, usually one of the books in `https://github.com/mingzilla/upskill/tree/main/.install/install` | pass it straight through - a `blob`/`tree` github link is converted to the raw one |
| a path to a `.json` file | pass it straight through |
| **the json text itself, pasted into the chat** | save it to a file first, then import that file |

For pasted text: write it verbatim to a temporary `.json` file - do not reformat it, re-key it, or
fill in anything that looks missing - then run import on that path. If it turns out not to be an
address book the script says so; that is the check, not your reading of it.

`<upskill> import "<url|path>"`

| Case | What happens |
|---|---|
| New person | Added |
| Already in your book | Left exactly as it is, and reported - an import never rewrites where your skills come from |
| Two people, one display name | Both kept, the clash is reported - say which key you mean when using it |

Print the output verbatim.
