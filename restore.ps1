param([string]$GameDir)

# FF8R Draw 100 Mod - restore
# Reverts the 2-byte patch in FFVIII_EFIGS.dll (mov bl,100 -> mov bl,[esi]).
# Falls back to the full DLL backup only if the targeted revert cannot be done.
# ASCII-only on purpose so Windows PowerShell 5.1 parses it under any code page.

$ErrorActionPreference = 'Stop'
# Print a clean one-line message instead of a PowerShell stack trace on failure.
trap { Write-Host ''; Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
             elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
             else { (Get-Location).Path }

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
Write-Host "Game folder: $gameDir"

$context  = [byte[]](0xFE,0x06,0x8B,0x4E,0x2C,0xA1,0xE0,0xB5,0x6C,0x11,0x53,0x8A,0x1E,0x8D,0x51,0x04)
$patched  = [byte[]](0xFE,0x06,0x8B,0x4E,0x2C,0xA1,0xE0,0xB5,0x6C,0x11,0x53,0xB3,0x64,0x8D,0x51,0x04)
$knownOffset = 0x2BED0F
$ctxStart = $knownOffset - 11

function Test-Bytes([byte[]]$hay, [int]$at, [byte[]]$needle) {
    if ($at -lt 0 -or $at + $needle.Length -gt $hay.Length) { return $false }
    for ($i = 0; $i -lt $needle.Length; $i++) { if ($hay[$at+$i] -ne $needle[$i]) { return $false } }
    return $true
}

$bytes = [System.IO.File]::ReadAllBytes($dll)

$site = $null
if (Test-Bytes $bytes $ctxStart $patched) { $site = $ctxStart }
elseif (Test-Bytes $bytes $ctxStart $context) { Write-Host 'DLL is already original. Nothing to restore.'; return }
else {
    $hits = @()
    for ($i = 0; $i -le $bytes.Length - $patched.Length; $i++) {
        if ($bytes[$i] -eq 0xFE -and (Test-Bytes $bytes $i $patched)) { $hits += $i }
    }
    if ($hits.Count -eq 1) { $site = $hits[0] }
    else {
        # Targeted revert not possible; try a full backup restore.
        $bakCandidates = @(
            (Join-Path $gameDir   'FFVIII_EFIGS.dll.draw100-backup'),
            (Join-Path $scriptDir 'FFVIII_EFIGS.dll.draw100-backup'),
            (Join-Path $scriptDir 'FFVIII_EFIGS.dll.bak')          # legacy v0.1.1 location
        )
        $bak = $bakCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($bak) {
            Write-Host "Patch site not found; restoring full DLL from backup: $bak"
            Copy-Item $bak $dll -Force
            Write-Host 'Restored FFVIII_EFIGS.dll from backup.'
            return
        }
        throw 'Patch site not found and no backup exists. Use Steam: Verify integrity of game files.'
    }
}

$fs = [System.IO.File]::Open($dll, 'Open', 'ReadWrite')
try {
    $fs.Position = $site + 11
    $fs.WriteByte(0x8A); $fs.WriteByte(0x1E)   # mov bl, [esi]
    $fs.Flush()
    $fs.Position = $site
    $chk = New-Object byte[] $context.Length
    [void]$fs.Read($chk, 0, $chk.Length)
    for ($i = 0; $i -lt $context.Length; $i++) {
        if ($chk[$i] -ne $context[$i]) { throw 'Verification failed. Copy the .draw100-backup over FFVIII_EFIGS.dll manually.' }
    }
}
finally { $fs.Close() }
Write-Host 'Original draw code restored and verified.'
