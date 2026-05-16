param(
    [string]$PackagePath = (Join-Path $PSScriptRoot "Lyra_4.1.1.0_x64.msixbundle"),
    [string]$CertificatePath = (Join-Path $PSScriptRoot "Lyra_4.1.1.0_x64.cer")
)

$ErrorActionPreference = "Stop"

$expectedThumbprint = "AA08EF070322DFFA862B37F4F6A79AB945ACFB54"

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
        "`"$CertificatePath`""
    )

    Write-Host "Requesting administrator permission to trust the Lyra certificate..."
    Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -Verb RunAs -Wait
    exit $LASTEXITCODE
}

$PackagePath = (Resolve-Path -LiteralPath $PackagePath).Path
$CertificatePath = (Resolve-Path -LiteralPath $CertificatePath).Path

Unblock-File -LiteralPath $PackagePath -ErrorAction SilentlyContinue
Unblock-File -LiteralPath $CertificatePath -ErrorAction SilentlyContinue

$certificate = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath)
if ($certificate.Thumbprint -ne $expectedThumbprint) {
    throw "Certificate thumbprint mismatch. Expected $expectedThumbprint but found $($certificate.Thumbprint)."
}

Write-Host "Trusting Lyra certificate $($certificate.Thumbprint)..."
Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\LocalMachine\Root" | Out-Null
Import-Certificate -FilePath $CertificatePath -CertStoreLocation "Cert:\LocalMachine\TrustedPeople" | Out-Null

Write-Host "Installing Lyra package..."
Add-AppxPackage -Path $PackagePath -ForceApplicationShutdown

Write-Host "Lyra installed successfully."
