param([string]$GameDir)

# FF8R Draw 100 Mod - apply
# Patches the draw-to-stock routine in FFVIII_EFIGS.dll so any successful Draw
# fills the spell's stock to 100. Two bytes change: mov bl,[esi] -> mov bl,100.
# ASCII-only on purpose so Windows PowerShell 5.1 parses it under any code page.

$ErrorActionPreference = 'Stop'
# Print a clean one-line message instead of a PowerShell stack trace on failure.
trap { Write-Host ''; Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }

# --- Locate this script's folder (works even if $PSScriptRoot is empty) ---
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
             elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
             else { (Get-Location).Path }

# --- Locate the game folder by finding FFVIII_EFIGS.dll ---
# Search: an explicit -GameDir, else walk up from the script folder. This works
# whether the mod folder sits inside the game folder, the scripts were dropped
# straight into the game folder, or they are nested a few levels deep.
function Find-GameDir([string]$start, [string]$override) {
    $dllName = 'FFVIII_EFIGS.dll'
    if ($override) {
        $p = Join-Path $override $dllName
        if (Test-Path $p) { return (Resolve-Path $override).Path }
        throw "FFVIII_EFIGS.dll was not found in the folder you passed with -GameDir: '$override'"
    }
    $dir = $start
    for ($i = 0; $i -lt 8 -and $dir; $i++) {
        if (Test-Path (Join-Path $dir $dllName)) { return $dir }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    throw ("Could not find FFVIII_EFIGS.dll. Put this script (or the Draw100Mod " +
           "folder) inside your 'FINAL FANTASY VIII Remastered' game folder, or run it " +
           "with:  -GameDir `"<full path to the game folder>`"")
}

$gameDir = Find-GameDir $scriptDir $GameDir
$dll = Join-Path $gameDir 'FFVIII_EFIGS.dll'
$bak = Join-Path $gameDir 'FFVIII_EFIGS.dll.draw100-backup'
Write-Host "Game folder: $gameDir"

$knownOffset = 0x2BED0F
# inc byte[esi]; mov ecx,[esi+2C]; mov eax,[116CB5E0]; push ebx; mov bl,[esi]; lea edx,[ecx+4]
$context  = [byte[]](0xFE,0x06,0x8B,0x4E,0x2C,0xA1,0xE0,0xB5,0x6C,0x11,0x53,0x8A,0x1E,0x8D,0x51,0x04)
$patched  = [byte[]](0xFE,0x06,0x8B,0x4E,0x2C,0xA1,0xE0,0xB5,0x6C,0x11,0x53,0xB3,0x64,0x8D,0x51,0x04)
$ctxStart = $knownOffset - 11   # context begins 11 bytes before the patch site

function Test-Bytes([byte[]]$hay, [int]$at, [byte[]]$needle) {
    if ($at -lt 0 -or $at + $needle.Length -gt $hay.Length) { return $false }
    for ($i = 0; $i -lt $needle.Length; $i++) { if ($hay[$at+$i] -ne $needle[$i]) { return $false } }
    return $true
}

$bytes = [System.IO.File]::ReadAllBytes($dll)

$site = $null
if (Test-Bytes $bytes $ctxStart $context) { $site = $ctxStart }
elseif (Test-Bytes $bytes $ctxStart $patched) { Write-Host 'Draw 100 Mod is already applied. Nothing to do.'; return }
else {
    Write-Host 'Known offset did not match; scanning the DLL for the draw code...'
    $hits = @()
    for ($i = 0; $i -le $bytes.Length - $context.Length; $i++) {
        if ($bytes[$i] -eq 0xFE -and (Test-Bytes $bytes $i $context)) { $hits += $i }
    }
    if ($hits.Count -eq 1) { $site = $hits[0]; Write-Host ('Found the draw code at file offset 0x{0:X}' -f $site) }
    elseif ($hits.Count -eq 0) { throw 'Draw code pattern not found. The DLL may be from a different game version; not patching.' }
    else { throw "Draw code pattern matched $($hits.Count) times (ambiguous); not patching." }
}

if (-not (Test-Path $bak)) {
    Copy-Item $dll $bak
    Write-Host "Backed up original DLL to: $bak"
}

$fs = [System.IO.File]::Open($dll, 'Open', 'ReadWrite')
try {
    $fs.Position = $site + 11
    $fs.WriteByte(0xB3); $fs.WriteByte(0x64)   # mov bl, 100
    $fs.Flush()
    $fs.Position = $site
    $chk = New-Object byte[] $patched.Length
    [void]$fs.Read($chk, 0, $chk.Length)
    for ($i = 0; $i -lt $patched.Length; $i++) {
        if ($chk[$i] -ne $patched[$i]) { throw 'Verification failed. Run restore to revert from backup.' }
    }
}
finally { $fs.Close() }
Write-Host 'Draw 100 Mod applied and verified. Draw now fills stock to 100.'
