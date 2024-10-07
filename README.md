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
.\up.ps1 [-IncludeSpe] [-IncludeSxa] [-IncludePackages] [-SkipBuild] [-SkipIndexing]
```

4. Tear down and cleanup code changes when done.

```powershell
.\down.ps1 [-Cleanup]
```

### Package/Code Deployment

- Packages contained within `.\docker\build\releases` will be included in the built images.
- Packages contained within `.\docker\releases` will be deployed after the containers startup.
- Code contained within `.\deploy` will be deployed any time after containers startup. This is the best way to quickly test code changes.

## Testing

- Run the script `up.ps1`

## Demo

![Test-Sitecore-Packages-720](https://user-images.githubusercontent.com/933163/81630806-287b4480-93cc-11ea-9fd1-025dd24e9891.gif)
