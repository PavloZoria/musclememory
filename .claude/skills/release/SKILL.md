---
name: release
description: Version, build and publish one Muscle Memory plugin as a GitHub release with its installable package attached. Use when asked to release, publish, ship or cut a version of a plugin, e.g. "release intellij/vscode", "publish 0.0.2 of the VS Code extension", "/release intellij/vscode minor".
argument-hint: <ide>/<editor> [patch|minor|major|x.y.z]
---

# Release a plugin

Publishes `<ide>/<editor>/` (for example `intellij/vscode/`) as a GitHub release tagged `<ide>-<editor>-v<version>`, with the plugin's installable package attached so people can download it instead of building it.

## Rules

- **No credentials.** Never read, print, write or pass tokens, keys or passwords. Rely on the existing `gh` login and git's credential helper. If authentication fails, tell the user what to run (`gh auth login`, `gh auth switch`) and stop.
- **Ask before anything public.** Pushing, tagging and creating the release need the user's explicit go-ahead in step 7. Everything before that is local and can be undone.
- **Never force-push and never rewrite published history.** Release tags point at commits on `main`.
- **One plugin per run.** Only files inside the plugin folder, its changelog and the README status rows (step 5) change.
- If any step fails, stop, report the output, and leave the working tree as it is so the user can inspect it.

## Inputs

- `<ide>/<editor>`: the plugin folder relative to the repository root. If missing, list the folders that match `*/*/` with a manifest from the host table and ask.
- Version: `patch` (default), `minor`, `major` or an exact `x.y.z`.

## Host table

How each kind of plugin is versioned, built and installed. Pick the row by the **editor** folder name (the second level). If there is no row for the plugin's editor, stop and ask the user to add one here first.

| Editor folder | Manifest (version lives here) | Set version | Build (run inside the plugin folder) | Artifact | Install steps for the release notes |
|---|---|---|---|---|---|
| `vscode` | `package.json` (+ `package-lock.json`) | `npm version <x.y.z> --no-git-tag-version` | `npm ci` when `node_modules/` is missing, then `npm run package` (lint, tests, package) | `dist/<name>-<x.y.z>.vsix` | Command Palette → **Extensions: Install from VSIX…** → pick the file, or `code --install-extension <file>` |
| `xcode` | `VERSION` | `printf '%s\n' <x.y.z> > VERSION` | `make package` (lint, tests, check against the installed Xcode, package) | `dist/musclememory-xcode-<x.y.z>.zip` | Quit Xcode, unzip the file and run `musclememory-xcode-<x.y.z>/install.sh` (`uninstall.sh` next to it removes it again) |
| `intellij` (planned, confirm against the plugin's build when it exists) | `gradle.properties` → `pluginVersion` | edit `pluginVersion` | `./gradlew buildPlugin` (runs tests via `check` if configured) | `build/distributions/<name>-<x.y.z>.zip` | Settings → Plugins → ⚙ → **Install Plugin from Disk…** → pick the file |

## Steps

### 1. Preflight

Run from the repository root (`git rev-parse --show-toplevel`):

- `git status --porcelain` is empty, otherwise ask the user to commit or stash first.
- The current branch is `main`. `git fetch origin` and confirm `main` is not behind `origin/main`.
- The plugin folder exists and has the manifest from the host table.
- Find the repository and your access: `gh repo view --json nameWithOwner,owner,viewerPermission`. Releasing needs `WRITE`, `MAINTAIN` or `ADMIN`.
  - If the permission is `READ` and `gh auth status` shows a logged-in account named like the owner, tell the user you will run `gh auth switch --user <owner>` for the publish steps and switch back afterwards. Note the previously active account so step 9 can restore it.
  - If no logged-in account has write access, stop and ask the user to log in with one (`gh auth login`).
- Pushing goes through git's credential helper. If `git remote get-url origin` is SSH and the SSH key belongs to a different account than the owner, pushing will fail: suggest switching the remote to HTTPS (`git remote set-url origin https://github.com/<owner>/<repo>.git`) so the `gh` credential helper serves the active account.

### 2. Versions

- Current version: from the manifest.
- Tag prefix: `<ide>-<editor>-v`. Previous release: `git tag -l '<prefix>*' --sort=-v:refname | head -1`.
- **First release** (no previous tag): release the manifest's current version as it is; skip the bump in step 4.
- Otherwise compute the new version from the argument (`patch` when none was given) and make sure the tag `<prefix><new>` does not exist locally or on GitHub (`gh release view <tag>` fails).
- Tell the user: plugin, current version → new version, tag name.

### 3. Changelog

- Changes since the previous release: `git log <previous-tag>..HEAD --format='- %s' -- <ide>/<editor>` (all history for a first release).
- Draft a `## <new>` section at the top of `<ide>/<editor>/CHANGELOG.md`, written for people who use the plugin: what they can now do or what was fixed, not file or function names. Group related commits; drop purely internal ones (refactors, test-only, docs typos).
- Show the draft to the user and apply their edits.

### 4. Bump the version

Use the "Set version" command from the host table. Check that every place holding the version agrees (for `vscode`: `package.json` and both `version` fields at the top of `package-lock.json`; for `xcode`: `VERSION` is the only one).

### 5. Update the README status rows

The `Status` column for this plugin in the root `README.md` "Plugins" table and in `<ide>/README.md` shows the latest released version. Set both to `<new>`.

### 6. Build and verify

Delegate to the `plugin-builder` agent with the plugin folder and the expected version. It builds, runs the tests, checks the package and scans it for secrets, and returns the artifact path, size and SHA-256.

- If it reports a failure or any finding, stop and show it to the user. Do not publish a package with findings.
- Keep the artifact path and SHA-256 for steps 8 and 9.

### 7. Commit and confirm

- Commit only the plugin's manifest/lockfile, its `CHANGELOG.md` and the two README status rows: `Release <ide>/<editor> <new>` with a body listing the changelog bullets.
- Show the user a summary and **wait for explicit approval**:
  - repository and branch to push to
  - tag `<prefix><new>` on commit `<short sha>`
  - release title `<IDE> → <Editor> <new>`, public
  - attached file name, size and SHA-256
  - the release notes from step 8

### 8. Publish

1. Switch the `gh` account if step 1 said so.
2. `git push origin main`.
3. Write the release notes to a temporary file outside the repository, from [release-notes-template.md](release-notes-template.md): the install steps from the host table, the changelog section from step 3, and links to the plugin README on `main`.
4. `gh release create <prefix><new> <artifact> --target <commit sha> --title "<IDE> → <Editor> <new>" --notes-file <notes file>`. This creates the tag on GitHub; then `git fetch --tags origin` so the local tag exists too.

### 9. Verify and clean up

- `gh release view <tag> --json url,isDraft,assets`: not a draft, exactly one asset with the expected name.
- Download the asset (`gh release download <tag> --dir <temp dir>`) and compare its SHA-256 with the one from step 6. They must match.
- Switch the `gh` account back if it was switched. Delete the temporary notes file and download.
- Report to the user: the release URL, the direct download URL (`https://github.com/<owner>/<repo>/releases/download/<tag>/<file>`), the version and the SHA-256.
