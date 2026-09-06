# action__manage_address_book

One verb: import people into the address book you are already using.

`<upskill>` is the launcher from SKILL.md. Do not run the script directly, and do not edit it.

## Import contacts (option 5)

The user gives a link to someone's `address_book.json` - usually one of the books in
`https://github.com/mingzilla/upskill__setup/tree/main/address_books`. A `blob`/`tree` github link
works; it is converted to the raw one.

`<upskill> import "<url|path>"`

| Case | What happens |
|---|---|
| New person | Added |
| Already in your book | Left exactly as it is, and reported - an import never rewrites where your skills come from |
| Two people, one display name | Both kept, the clash is reported - say which key you mean when using it |

Print the output verbatim.
