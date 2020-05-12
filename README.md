# Simplified testing of Sitecore package installations

Have you ever found the setup of Sitecore module packages to be time consuming and a pain to automate? Did you know that modules can be converted from the standard module zip to a web deployment version? 

The following repo provides some details about how you can get started.

## Setup

The first thing you need to do is have a Sitecore module package you want to test out.

* Download and extract the Sitecore Azure Toolkit from Sitecore's website [here](https://dev.sitecore.net/Downloads.aspx).
* Run the following script against your Sitecore module package.
 ```
 # Assumes you extracted the toolkit to the path C:\Sitecore\sat
 Import-Module -Name "C:\Sitecore\sat\tools\Sitecore.Cloud.Cmdlets.dll"

$path = "C:\Projects\test-sitecore-packages\releases\YourCustomPackage.zip"
$destination = "C:\Projects\test-sitecore-packages\releases\"

ConvertTo-SCModuleWebDeployPackage -Path $path  -Destination $destination -DisableDacPacOptions '*' -Verbose  -Force

# Generates YourCustomPackage.scwdp.zip
# => C:\Projects\test-sitecore-packages\releases\YourCustomPackage.scwdp.zip
```

## Testing

* Run the script `up.ps1`

## Demo

![Test-Sitecore-Packages-720](https://user-images.githubusercontent.com/933163/81630806-287b4480-93cc-11ea-9fd1-025dd24e9891.gif)
