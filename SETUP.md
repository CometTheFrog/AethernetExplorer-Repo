# Aethernet Explorer Auto-Update Setup

This bundle contains files for two repositories.

## 1. Bootstrap the distribution repository

Copy the contents of `DistributionRepo` into your local clone of:

`https://github.com/CometTheFrog/AethernetExplorer-Repo`

Then run:

```powershell
git add .
git commit -m "Initialize Dalamud custom repository"
git push origin main
```

The public feed URL will be:

`https://raw.githubusercontent.com/CometTheFrog/AethernetExplorer-Repo/main/pluginmaster.json`

## 2. Add the release pipeline to the development repository

Copy the contents of `DevelopmentRepo` into the root of the main
AethernetExplorer development repository.

Commit and push:

```powershell
git add .github tools
git commit -m "Add automated alpha release pipeline"
git push origin master
```

Use `main` instead of `master` if that is your development branch.

## 3. Create the cross-repository token

On GitHub:

1. Open Settings.
2. Open Developer settings.
3. Open Personal access tokens.
4. Choose Fine-grained tokens.
5. Create a token named `Aethernet Explorer Publisher`.
6. Set the resource owner to `CometTheFrog`.
7. Select only `AethernetExplorer-Repo`.
8. Give Repository permissions → Contents: Read and write.
9. Generate and copy the token.

Do not put the token in a file or commit it.

## 4. Add the token as an Actions secret

In the main development repository:

1. Open Settings.
2. Open Secrets and variables → Actions.
3. Create a new repository secret.
4. Name it exactly:

`AETHERNET_REPO_TOKEN`

5. Paste the fine-grained token.

## 5. Publish the first alpha

From a clean development repository:

```powershell
.\tools\Publish-Alpha.ps1 -Version 0.9.0.1
```

That command updates the source version, commits it, creates the tag, and
pushes it. GitHub Actions then:

1. Builds the complete Windows package.
2. Creates `AethernetExplorer.zip`.
3. Creates a prerelease in `AethernetExplorer-Repo`.
4. Updates `pluginmaster.json`.
5. Makes the update visible to Dalamud.

## 6. Add the repository in Dalamud

Testers add this URL under Dalamud custom plugin repositories:

`https://raw.githubusercontent.com/CometTheFrog/AethernetExplorer-Repo/main/pluginmaster.json`

After saving and refreshing plugin listings, Aethernet Explorer should appear.

## Version rule

Always use a higher four-part version:

- `0.9.0.1`
- `0.9.0.2`
- `0.9.0.3`

Never reuse a published version.
