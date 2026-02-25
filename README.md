# Simplified testing of Sitecore package installations

Have you ever found the setup of Sitecore module packages to be time consuming and a pain to automate? Did you know that modules can be converted from the standard module zip to a web deployment version?

The following repo provides some details about how you can get started.

## Setup

1. Clone this repo
2. From an **elevated** prompt run `init.ps1` with the path to the license file. An elevated prompt is required for this step to install the TLS certificate into the system trust store.

```powershell
.\init.ps1 [-LicenseXmlPath "C:\License\license.xml"] [-HostName "dev.local"] [-SitecoreAdminPassword "Password12345"] [-SqlSaPassword "Password12345"]
```

`init.ps1` is **idempotent** — re-running it on an existing environment preserves already-generated secrets (Telerik key, ID secret, media request secret) so running containers are not broken.

3. Build the Docker images and start the environment.

```powershell
.\up.ps1 [-SkipBuild] [-IncludeSpe] [-IncludeSxa] [-IncludePackages] [-ForceConvert]
```

4. Authenticate the Sitecore CLI (opens a browser login).

```powershell
.\login.ps1
```

5. *(First time only)* Populate the Solr schema, publish content, and rebuild indexes.

```powershell
.\maintenance.ps1
```

6. Tear down when done.

```powershell
.\down.ps1 [-IncludeSpe] [-IncludeSxa] [-Cleanup]
```

> **Important:** pass the same `-IncludeSpe` / `-IncludeSxa` flags to `down.ps1` that were used with `up.ps1` so all overlay services are properly stopped.

---

### Package / Code Deployment

Packages and code can be delivered to the running environment in three ways depending on when you need them applied:

| Location | When applied | Use case |
|---|---|---|
| `.\docker\build\packages\` | Baked into the image at build time | Packages that must be present before Sitecore first starts |
| `.\docker\releases\` | Deployed by scripts when containers start | Packages to install on each fresh environment |
| `.\docker\deploy\` | Hot-deployed via volume mount at any time | Fastest path for iterating on code changes |

---

### Scripts

| Script | Description |
|---|---|
| `init.ps1` | **One-time setup** (elevated): generates TLS certificates, populates `.env`. Safe to re-run — existing secrets are preserved. |
| `cert.ps1` | Creates or renews the Traefik TLS development certificate. Called automatically by `init.ps1`. Pass `-Renew` for annual renewal. |
| `up.ps1` | Converts any new packages to WDP format, builds images (unless `-SkipBuild`), starts containers, and waits for CM to become healthy. |
| `login.ps1` | Restores the Sitecore CLI and authenticates against the running Identity Server. Re-run any time the CLI session expires. |
| `maintenance.ps1` | Populates the Solr managed schema, publishes content, and rebuilds search indexes. Individual steps can be skipped with `-SkipSchemaPopulate`, `-SkipPublish`, or `-SkipIndexRebuild`. |
| `deploy.ps1` | Installs packages from `.\docker\releases\` into running containers via `docker compose exec`. Run after containers are up whenever new packages are added. |
| `status.ps1` | Displays a colour-coded per-container health table. Use `-Watch` to poll continuously until all containers are healthy. |
| `down.ps1` | Stops containers. Pass `-IncludeSpe` / `-IncludeSxa` to match the flags used with `up.ps1`. Use `-Cleanup` to also clear data volumes and build artefacts. |
| `build.ps1` | Builds Docker images. Called by `up.ps1` but can be run standalone to rebuild without restarting containers. |
| `clean.ps1` | Removes data volumes and build artefacts. Called by `down.ps1 -Cleanup`. |

---

## Testing

- Run `up.ps1`, then `login.ps1`

## Demo

![Test-Sitecore-Packages-720](https://user-images.githubusercontent.com/933163/81630806-287b4480-93cc-11ea-9fd1-025dd24e9891.gif)
