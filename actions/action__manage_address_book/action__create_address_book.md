# action__create_address_book

One verb: make an address book from a list of people and their public repos.

`<upskill>` is the launcher from SKILL.md. Do not run the script directly, and do not edit it.

## Create address book (option 7)

Ask the user for each person's name and repo. One person is enough - always pass a list:

`<upskill> create "<name>" "<repo url>" ["<name>" "<repo url>" ...]`

The draft is written to `<skills_lib_root>/upskill__sandbox/address_book.json` - the active address
book is never touched.

| Case | What happens |
|---|---|
| No draft in the sandbox yet | a fresh address book is written |
| A draft is already there | you are told up front, and the new entries are merged in - on a matching key the new entry replaces the existing one |
| An entry is not a valid `https` repo url | the script says which one and stops |

Print the output verbatim.
