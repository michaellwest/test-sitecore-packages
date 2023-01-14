# Custom Tools

Add any files that would be useful during the container startup. Typically scripts are added and referenced by the `entrypoint`:

**Example:** The following demonstrates adding a custom _Debugger.ps1_ to the tools folder and then referenced by the entrypoint.

```yaml
entrypoint: powershell -Command "& c:/tools/entrypoints/iis/Debugger.ps1;c:/tools/entrypoints/iis/Development.ps1;"
```
