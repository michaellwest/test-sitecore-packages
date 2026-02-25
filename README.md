# Simplified testing of Sitecore package installations

Have you ever found the setup of Sitecore module packages to be time consuming and a pain to automate? Did you know that modules can be converted from the standard module zip to a web deployment version?

The following repo provides some details about how you can get started.

## Setup

1. Clone this repo
2. From an elevated prompt run the `init.ps1` with the path to the license file. An elevated prompt is only necessary for this step.

```powershell
.\init.ps1 [-LicenseXmlPath "C:\License\license.xml"] [-HostName "dev.local"] [-SitecoreAdminPassword "Password12345"] [-SqlSaPassword "Password12345"]
```

3. Build the appropriate Docker images and then start up.

```powershell
.\up.ps1 [-IncludeSpe] [-IncludeSxa] [-IncludePackages] [-SkipBuild] [-IncludeMaintenance]
```

4. Tear down and cleanup code changes when done.

```powershell
.\down.ps1 [-Cleanup]
```

### Package/Code Deployment

Packages and code can be delivered to the running environment in three ways depending on when you need them applied:

| Location | When applied | Use case |
|---|---|---|
| `.\docker\build\packages\` | Baked into the image at build time | Packages that must be present before Sitecore first starts |
| `.\docker\releases\` | Deployed by scripts when containers start | Packages to install on each fresh environment |
| `.\docker\deploy\` | Hot-deployed via volume mount at any time | Fastest path for iterating on code changes |

### Scripts

| Script | Description |
|---|---|
| `init.ps1` | One-time setup: generates TLS certificates, populates `.env`. Run once from an elevated prompt. |
| `up.ps1` | Builds images (unless `-SkipBuild`) and starts the environment. Optionally runs `deploy.ps1` and maintenance tasks. |
| `build.ps1` | Builds Docker images. Called by `up.ps1` but can also be run standalone to rebuild without restarting containers. |
| `deploy.ps1` | Installs packages from `.\docker\releases\` into running containers. Run this after containers are up whenever you add new packages to that folder. |
| `down.ps1` | Stops containers. Use `-Cleanup` to also clear data volumes and build artifacts. |

## Testing

- Run the script `up.ps1`

## Demo

![Test-Sitecore-Packages-720](https://user-images.githubusercontent.com/933163/81630806-287b4480-93cc-11ea-9fd1-025dd24e9891.gif)
