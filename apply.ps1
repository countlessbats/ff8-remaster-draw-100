param([string]$GameDir)

# FF8R Draw 100 Mod - apply
# Forces any successful Draw to fill the spell's stock to 100. There are TWO
# draw-to-stock routines in FFVIII_EFIGS.dll - one for in-battle Draw and one for
# field Draw Points - so this patches both. Each site changes 2 bytes:
# mov bl,[esi] (8A 1E) -> mov bl,100 (B3 64).
# ASCII-only on purpose so Windows PowerShell 5.1 parses it under any code page.

$ErrorActionPreference = 'Stop'
# Print a clean one-line message instead of a PowerShell stack trace on failure.
trap { Write-Host ''; Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red; exit 1 }

# --- Locate this script's folder (works even if $PSScriptRoot is empty) ---
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot }
             elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
             else { (Get-Location).Path }

# --- Locate the game folder by finding FFVIII_EFIGS.dll ---
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

# --- The two draw-to-stock writeback sites ---
# Context is a unique 16-byte signature; PatchOff is where the 2 patch bytes sit.
$sites = @(
    @{ Name = 'in-battle Draw';  KnownOffset = 0x2BED04; PatchOff = 11
       Context = [byte[]](0xFE,0x06,0x8B,0x4E,0x2C,0xA1,0xE0,0xB5,0x6C,0x11,0x53,0x8A,0x1E,0x8D,0x51,0x04) },
    @{ Name = 'field Draw Point'; KnownOffset = 0x2A765E; PatchOff = 10
       Context = [byte[]](0xFE,0x06,0x8D,0x51,0x04,0xA1,0xE0,0xB5,0x6C,0x11,0x8A,0x1E,0x53,0x8B,0x04,0x01) }
)

function Test-Bytes([byte[]]$hay, [int]$at, [byte[]]$needle) {
    if ($at -lt 0 -or $at + $needle.Length -gt $hay.Length) { return $false }
    for ($i = 0; $i -lt $needle.Length; $i++) { if ($hay[$at+$i] -ne $needle[$i]) { return $false } }
    return $true
}
function Get-Patched([byte[]]$context, [int]$off) {
    $p = $context.Clone(); $p[$off] = 0xB3; $p[$off+1] = 0x64; return $p   # mov bl,100
}
# Resolve a site to a file offset in $bytes, or a status. Returns a hashtable.
function Resolve-Site($site, [byte[]]$bytes) {
    $patched = Get-Patched $site.Context $site.PatchOff
    if (Test-Bytes $bytes $site.KnownOffset $site.Context) { return @{ Status='patch'; Offset=$site.KnownOffset } }
    if (Test-Bytes $bytes $site.KnownOffset $patched)       { return @{ Status='already' } }
    # Fallback: scan for the unique signature (handles a shifted layout).
    $ctxHits = @(); $patHits = @()
    for ($i = 0; $i -le $bytes.Length - $site.Context.Length; $i++) {
        if ($bytes[$i] -eq 0xFE) {
            if (Test-Bytes $bytes $i $site.Context) { $ctxHits += $i }
            elseif (Test-Bytes $bytes $i $patched)  { $patHits += $i }
        }
    }
    if ($ctxHits.Count -eq 1) { return @{ Status='patch'; Offset=$ctxHits[0] } }
    if ($ctxHits.Count -eq 0 -and $patHits.Count -ge 1) { return @{ Status='already' } }
    if ($ctxHits.Count -eq 0) { return @{ Status='notfound' } }
    return @{ Status='ambiguous'; Count=$ctxHits.Count }
}

$bytes = [System.IO.File]::ReadAllBytes($dll)

# Plan every site first; do not write anything if any site is in a bad state.
$plan = @()
foreach ($s in $sites) {
    $r = Resolve-Site $s $bytes
    switch ($r.Status) {
        'notfound'  { throw "Could not find the $($s.Name) draw code. The DLL may be a different game version; nothing was changed." }
        'ambiguous' { throw "The $($s.Name) draw pattern matched $($r.Count) times (ambiguous); nothing was changed." }
    }
    $plan += @{ Site = $s; Resolved = $r }
}

if (@($plan | Where-Object { $_.Resolved.Status -eq 'already' }).Count -eq $sites.Count) {
    Write-Host 'Draw 100 Mod is already fully applied (both draw types). Nothing to do.'
    return
}

if (-not (Test-Path $bak)) {
    Copy-Item $dll $bak
    Write-Host "Backed up original DLL to: $bak"
}

$fs = [System.IO.File]::Open($dll, 'Open', 'ReadWrite')
try {
    foreach ($p in $plan) {
        $s = $p.Site
        if ($p.Resolved.Status -eq 'already') { Write-Host "  $($s.Name): already patched."; continue }
        $site = $p.Resolved.Offset + $s.PatchOff
        $fs.Position = $site
        $fs.WriteByte(0xB3); $fs.WriteByte(0x64)   # mov bl, 100
        $fs.Flush()
        $chk = New-Object byte[] 2
        $fs.Position = $site
        [void]$fs.Read($chk, 0, 2)
        if ($chk[0] -ne 0xB3 -or $chk[1] -ne 0x64) { throw "Verification failed for $($s.Name). Run the uninstaller to revert." }
        Write-Host "  $($s.Name): patched and verified."
    }
}
finally { $fs.Close() }
Write-Host 'Draw 100 Mod applied. Both in-battle Draw and field Draw Points now fill stock to 100.'
