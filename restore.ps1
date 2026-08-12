param([string]$GameDir)

# FF8R Draw 100 Mod - restore
# Reverts both draw-to-stock patches in FFVIII_EFIGS.dll (mov bl,100 -> mov bl,[esi])
# for the in-battle Draw site and the field Draw Point site. Falls back to the full
# DLL backup only if a targeted revert cannot be done.
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
    $p = $context.Clone(); $p[$off] = 0xB3; $p[$off+1] = 0x64; return $p
}
function Resolve-Site($site, [byte[]]$bytes) {
    $patched = Get-Patched $site.Context $site.PatchOff
    if (Test-Bytes $bytes $site.KnownOffset $patched)       { return @{ Status='revert';  Offset=$site.KnownOffset } }
    if (Test-Bytes $bytes $site.KnownOffset $site.Context)  { return @{ Status='original' } }
    $patHits = @(); $ctxHits = @()
    for ($i = 0; $i -le $bytes.Length - $site.Context.Length; $i++) {
        if ($bytes[$i] -eq 0xFE) {
            if (Test-Bytes $bytes $i $patched)      { $patHits += $i }
            elseif (Test-Bytes $bytes $i $site.Context) { $ctxHits += $i }
        }
    }
    if ($patHits.Count -eq 1) { return @{ Status='revert'; Offset=$patHits[0] } }
    if ($patHits.Count -eq 0 -and $ctxHits.Count -ge 1) { return @{ Status='original' } }
    return @{ Status='missing' }
}

$bytes = [System.IO.File]::ReadAllBytes($dll)
$plan = @()
$anyMissing = $false
foreach ($s in $sites) {
    $r = Resolve-Site $s $bytes
    if ($r.Status -eq 'missing') { $anyMissing = $true }
    $plan += @{ Site = $s; Resolved = $r }
}

if ($anyMissing) {
    # Targeted revert not possible for at least one site; try a full backup restore.
    $bakCandidates = @(
        (Join-Path $gameDir   'FFVIII_EFIGS.dll.draw100-backup'),
        (Join-Path $scriptDir 'FFVIII_EFIGS.dll.draw100-backup'),
        (Join-Path $scriptDir 'FFVIII_EFIGS.dll.bak')          # legacy v0.1.1 location
    )
    $bak = $bakCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($bak) {
        Write-Host "A patch site was not found; restoring full DLL from backup: $bak"
        Copy-Item $bak $dll -Force
        Write-Host 'Restored FFVIII_EFIGS.dll from backup.'
        return
    }
    throw 'A patch site was not found and no backup exists. Use Steam: Verify integrity of game files.'
}

if (@($plan | Where-Object { $_.Resolved.Status -eq 'original' }).Count -eq $sites.Count) {
    Write-Host 'DLL is already original (both draw types). Nothing to restore.'
    return
}

$fs = [System.IO.File]::Open($dll, 'Open', 'ReadWrite')
try {
    foreach ($p in $plan) {
        $s = $p.Site
        if ($p.Resolved.Status -eq 'original') { Write-Host "  $($s.Name): already original."; continue }
        $site = $p.Resolved.Offset + $s.PatchOff
        $fs.Position = $site
        $fs.WriteByte(0x8A); $fs.WriteByte(0x1E)   # mov bl, [esi]
        $fs.Flush()
        $chk = New-Object byte[] 2
        $fs.Position = $site
        [void]$fs.Read($chk, 0, 2)
        if ($chk[0] -ne 0x8A -or $chk[1] -ne 0x1E) { throw "Verification failed for $($s.Name). Copy the .draw100-backup over FFVIII_EFIGS.dll manually." }
        Write-Host "  $($s.Name): reverted and verified."
    }
}
finally { $fs.Close() }
Write-Host 'Original draw code restored for both draw types.'
