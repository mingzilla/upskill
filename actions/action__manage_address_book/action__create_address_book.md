# action__create_address_book

[WHEN] asked to create an upskill address book, [THEN] ask user to provide a list of github repos and convert them into an address book.

## Create Address Book (option 6)

- Ask user to provide a list of repos like `https://github.com/<username>/public_skills.git` and the nickname (name) of the person
- Create a file `<skills_lib_root>/upskill__sandbox/address_book.json`
- Show the user the absolute path of the created file

### Format

```json
{
  "users": {
    "<github_username>__public_skills": {
      "name": "<name>",
      "folder": "<github_username>__public_skills",
      "repo": "https://github.com/<github_username>/public_skills.git"
    }
  }
}
```