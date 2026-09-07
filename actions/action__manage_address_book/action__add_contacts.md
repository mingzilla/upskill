# action__add_contacts

One verb: add people to the address book you are already using.

`<upskill>` is the launcher from SKILL.md. Do not run the script directly, and do not edit it.

## Add contacts to your address book (option 6)

Ask the user for each person's name and repo. One person is enough - always pass a list:

`<upskill> add-contacts "<name>" "<repo url>" ["<name>" "<repo url>" ...]`

Writes into the active address book - the one the menu shows. On a matching key the new entry
replaces the existing one.

| Case | What happens |
|---|---|
| A new person | Added |
| Someone already in your book (same repo) | Replaced, and reported as Updated - the newest entry wins |
| An entry is not a valid `https` repo url | the script says which one and stops |

Print the output verbatim.
