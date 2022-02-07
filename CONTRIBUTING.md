# Contributing

`main` branch is protected from direct pushes.

Based on the commit messages, increment the version from the latest release.
- If the string "BREAKING CHANGE", "major" or the Attention pattern refactor!: drop support for Node 6 is found anywhere in any of the commit messages or descriptions the major version will be incremented.
- If a commit message begins with the string "feat" or includes "minor" then the minor version will be increased. This works for most common commit metadata for feature additions: "feat: new API" and "feature: new API".
- If a commit message contains the word "pre-alpha" or "pre-beta" or "pre-rc" then the pre-release version will be increased (for example specifying pre-alpha: 1.6.0-alpha.1 -> 1.6.0-alpha.2 or, specifying pre-beta: 1.6.0-alpha.1 -> 1.6.0-beta.0)
- All other changes will increment the patch version.

NOTE: message can be picked up either from commit or pull request message.
NOTE: branch cannot be protected in GitHub.
