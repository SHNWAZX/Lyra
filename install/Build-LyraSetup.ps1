param(
    [string]$OutputPath = (Join-Path $PSScriptRoot "Lyra-Setup.exe"),
    [string]$PackagePath = (Join-Path $PSScriptRoot "..\artifacts-download\Lyra_4.1.1.0_x64.msixbundle"),
    [string]$CertificatePath = (Join-Path $PSScriptRoot "..\artifacts-download\Lyra_4.1.1.0_x64.cer"),
    [string]$DotNetRuntimeInstallerPath = (Join-Path $PSScriptRoot "..\artifacts-download\deps\dotnet-runtime-10.0.8-win-x64.exe"),
    [string]$WindowsAppRuntimeInstallerPath = (Join-Path $PSScriptRoot "..\artifacts-download\deps\windowsappruntimeinstall-x64.exe")
)

$ErrorActionPreference = "Stop"

$sevenZip = "${env:ProgramFiles}\7-Zip\7z.exe"
$sfxModule = "${env:ProgramFiles}\7-Zip\7z.sfx"
if (-not (Test-Path -LiteralPath $sevenZip) -or -not (Test-Path -LiteralPath $sfxModule)) {
    throw "7-Zip with 7z.sfx is required to build Lyra-Setup.exe."
}

$OutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$CertificatePath = (Resolve-Path -LiteralPath $CertificatePath).Path
$DotNetRuntimeInstallerPath = (Resolve-Path -LiteralPath $DotNetRuntimeInstallerPath).Path
$WindowsAppRuntimeInstallerPath = (Resolve-Path -LiteralPath $WindowsAppRuntimeInstallerPath).Path
$installerScriptPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "Install-Lyra.ps1")).Path

$buildDir = Join-Path ([System.IO.Path]::GetTempPath()) ("lyra-setup-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $buildDir | Out-Null

try {
    Copy-Item -LiteralPath $PackagePath -Destination (Join-Path $buildDir "Lyra_4.1.1.0_x64.msixbundle")
    Copy-Item -LiteralPath $CertificatePath -Destination (Join-Path $buildDir "Lyra_4.1.1.0_x64.cer")
    Copy-Item -LiteralPath $DotNetRuntimeInstallerPath -Destination (Join-Path $buildDir "dotnet-runtime-10.0.8-win-x64.exe")
    Copy-Item -LiteralPath $WindowsAppRuntimeInstallerPath -Destination (Join-Path $buildDir "windowsappruntimeinstall-x64.exe")
    Copy-Item -LiteralPath $installerScriptPath -Destination (Join-Path $buildDir "Install-Lyra.ps1")

    $archivePath = Join-Path $buildDir "payload.7z"
    Push-Location $buildDir
    try {
        & $sevenZip a -t7z $archivePath "Lyra_4.1.1.0_x64.msixbundle" "Lyra_4.1.1.0_x64.cer" "dotnet-runtime-10.0.8-win-x64.exe" "windowsappruntimeinstall-x64.exe" "Install-Lyra.ps1" | Out-Host
    }
    finally {
        Pop-Location
    }

    $config = @"
;!@Install@!UTF-8!
Title="Lyra Setup"
BeginPrompt="Install Lyra?"
RunProgram="powershell.exe -NoProfile -ExecutionPolicy Bypass -File Install-Lyra.ps1"
;!@InstallEnd@!
"@

    $outputDir = Split-Path -Parent $OutputPath
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

    $stream = [System.IO.File]::Create($OutputPath)
    try {
        $sfxBytes = [System.IO.File]::ReadAllBytes($sfxModule)
        $configBytes = [System.Text.Encoding]::UTF8.GetBytes($config)
        $archiveBytes = [System.IO.File]::ReadAllBytes($archivePath)

        $stream.Write($sfxBytes, 0, $sfxBytes.Length)
        $stream.Write($configBytes, 0, $configBytes.Length)
        $stream.Write($archiveBytes, 0, $archiveBytes.Length)
    }
    finally {
        $stream.Dispose()
    }

    Get-Item -LiteralPath $OutputPath
}
finally {
    Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
