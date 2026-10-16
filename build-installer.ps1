<#
Builds dist\UzbekKeyboardSetup.exe: one setup program that shows the Classic, Direct and
Turkish-style layouts and installs only the one the person picks.

Before running: in MSKLC, open each .klc (File > Load Source File) and run
Project > Build DLL and Setup Package. MSKLC writes each package to Documents\<kbd name>;
a copy in this folder (.\<kbd name>) works too. The newer of the two is used.
#>
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$documents = [Environment]::GetFolderPath('MyDocuments')
$layouts = @(
    @{ Kbd = 'uzlat26'; Klc = 'Uzbek-Latin-2026-Classic.klc' },
    @{ Kbd = 'uzlt26d'; Klc = 'Uzbek-Latin-2026-Direct.klc' },
    @{ Kbd = 'uzlt26t'; Klc = 'Uzbek-Latin-2026-Turkish-style.klc' }
)

$packages = Join-Path $root 'installer\packages'
if (Test-Path $packages) { Remove-Item $packages -Recurse -Force }

foreach ($layout in $layouts) {
    $found = @($root, $documents) |
        ForEach-Object { Join-Path (Join-Path $_ $layout.Kbd) "$($layout.Kbd)_amd64.msi" } |
        Where-Object { Test-Path $_ } |
        Sort-Object { (Get-Item $_).LastWriteTime } -Descending
    if (-not $found) {
        throw "No MSKLC package for $($layout.Klc). In MSKLC: File > Load Source File, then Project > Build DLL and Setup Package."
    }
    $msi = @($found)[0]
    $source = Split-Path $msi
    $klcTime = (Get-Item (Join-Path $root $layout.Klc)).LastWriteTime
    if ((Get-Item $msi).LastWriteTime -lt $klcTime) {
        throw "The MSKLC package in $source is older than $($layout.Klc). Rebuild it in MSKLC first."
    }
    # The .msi files read the keyboard DLL from these folders next to them, so both are needed.
    $target = Join-Path $packages $layout.Kbd
    New-Item -ItemType Directory -Force $target | Out-Null
    Copy-Item (Join-Path $source '*.msi') $target
    foreach ($arch in 'amd64', 'i386', 'ia64', 'wow64') {
        Copy-Item (Join-Path $source $arch) $target -Recurse
    }
    Write-Host "Packed $($layout.Kbd) from $source"
}

dotnet build (Join-Path $root 'installer\UzbekKeyboardSetup.csproj') -c Release --nologo -v minimal
if ($LASTEXITCODE -ne 0) { throw 'Build failed.' }

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
Copy-Item (Join-Path $root 'installer\bin\Release\net48\UzbekKeyboardSetup.exe') $dist -Force
Write-Host "Done: $(Join-Path $dist 'UzbekKeyboardSetup.exe')"
