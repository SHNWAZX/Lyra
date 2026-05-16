# Lyra

Lyra is a rebranded build of the open-source Files app for Windows.

This repository keeps the original MIT license and upstream copyright notices intact. The visible app name, package identity, protocol, startup text, and generated main executable name have been changed from Files to Lyra.

## Build

The `Lyra Build` GitHub Actions workflow builds the Windows x64 sideload package and uploads it as the `Lyra-x64-package` artifact. The packaged app executable is generated as `Lyra.exe`.

## Install

Download `Lyra-Setup.exe` from the latest release and run it. The setup EXE imports the Lyra certificate and installs the MSIX bundle.

If you prefer the manual path, download the `.msixbundle`, `.cer`, and `Install-Lyra.ps1` files from the latest release into the same folder, then run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-Lyra.ps1 -PackagePath .\Lyra_4.1.1.0_x64.msixbundle -CertificatePath .\Lyra_4.1.1.0_x64.cer
```
