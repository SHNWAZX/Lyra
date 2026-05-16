param(
    [string]$PackagePath = (Join-Path $PSScriptRoot "Lyra_4.1.1.0_x64.msixbundle"),
    [string]$CertificatePath = (Join-Path $PSScriptRoot "Lyra_4.1.1.0_x64.cer"),
    [string]$DotNetRuntimeInstallerPath = (Join-Path $PSScriptRoot "dotnet-runtime-10.0.8-win-x64.exe"),
    [string]$WindowsAppRuntimeInstallerPath = (Join-Path $PSScriptRoot "windowsappruntimeinstall-x64.exe")
)

$ErrorActionPreference = "Stop"

$expectedSubject = "CN=Lyra"

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    $arguments = @(
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        "`"$PSCommandPath`"",
        "-PackagePath",
        "`"$PackagePath`"",
        "-CertificatePath",
        "`"$CertificatePath`"",
        "-DotNetRuntimeInstallerPath",
        "`"$DotNetRuntimeInstallerPath`"",
        "-WindowsAppRuntimeInstallerPath",
        "`"$WindowsAppRuntimeInstallerPath`""
    )

    Write-Host "Requesting administrator permission to trust the Lyra certificate..."
    $elevated = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs -Wait -PassThru
    exit $elevated.ExitCode
}

$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$CertificatePath = (Resolve-Path -LiteralPath $CertificatePath).Path
$DotNetRuntimeInstallerPath = (Resolve-Path -LiteralPath $DotNetRuntimeInstallerPath).Path
$WindowsAppRuntimeInstallerPath = (Resolve-Path -LiteralPath $WindowsAppRuntimeInstallerPath).Path

Unblock-File -LiteralPath $PackagePath -ErrorAction SilentlyContinue
Unblock-File -LiteralPath $CertificatePath -ErrorAction SilentlyContinue
Unblock-File -LiteralPath $DotNetRuntimeInstallerPath -ErrorAction SilentlyContinue
Unblock-File -LiteralPath $WindowsAppRuntimeInstallerPath -ErrorAction SilentlyContinue

$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
if ($certificate.Subject -ne $expectedSubject) {
    throw "Certificate subject mismatch. Expected $expectedSubject but found $($certificate.Subject)."
}

if ($certificate.NotAfter -lt (Get-Date)) {
    throw "Certificate has expired. Certificate expired on $($certificate.NotAfter)."
}

function Test-DotNet10Runtime {
    $dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnet) {
        return $false
    }

    $runtimes = & $dotnet.Source --list-runtimes 2>$null
    return [bool]($runtimes | Where-Object { $_ -match '^Microsoft\.NETCore\.App\s+10\.' })
}

if (-not (Test-DotNet10Runtime)) {
    Write-Host "Installing .NET 10 runtime..."
    $dotnetInstall = Start-Process -FilePath $DotNetRuntimeInstallerPath -ArgumentList "/install", "/quiet", "/norestart" -Wait -PassThru
    if ($dotnetInstall.ExitCode -notin 0, 3010) {
        throw ".NET runtime installer failed with exit code $($dotnetInstall.ExitCode)."
    }
}
else {
    Write-Host ".NET 10 runtime is already installed."
}

Write-Host "Installing Windows App Runtime 1.8..."
$windowsAppRuntimeInstall = Start-Process -FilePath $WindowsAppRuntimeInstallerPath -ArgumentList "--quiet", "--force" -Wait -PassThru
if ($windowsAppRuntimeInstall.ExitCode -ne 0) {
    throw "Windows App Runtime installer failed with exit code $($windowsAppRuntimeInstall.ExitCode)."
}

Write-Host "Trusting Lyra certificate $($certificate.Thumbprint)..."
Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\LocalMachine\Root" | Out-Null
Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" | Out-Null

Write-Host "Installing Lyra package..."
try {
    Add-AppxPackage -Path $PackagePath -ForceApplicationShutdown
}
catch {
    $package = Get-AppxPackage -Name LyraDev -ErrorAction SilentlyContinue
    if (-not $package) {
        throw
    }

    Write-Host "Lyra package is already installed."
}

Write-Host "Launching Lyra..."
$package = Get-AppxPackage -Name LyraDev -ErrorAction Stop
Start-Process explorer.exe "shell:AppsFolder\$($package.PackageFamilyName)!App"

Write-Host "Lyra installed successfully."
