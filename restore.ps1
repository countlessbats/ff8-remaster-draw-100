# FF8R Draw 100 Mod — restore
# Reverts the 2-byte patch in FFVIII_EFIGS.dll (mov bl,100 -> mov bl,[esi]).
# Falls back to the full DLL backup only if the targeted revert cannot be done.
$ErrorActionPreference = 'Stop'

$dll = Join-Path (Split-Path -Parent $PSScriptRoot) 'FFVIII_EFIGS.dll'
$bak = Join-Path $PSScriptRoot 'FFVIII_EFIGS.dll.bak'

$knownOffset = 0x2BED0F
$context  = [byte[]](0xFE,0x06,0x8B,0x4E,0x2C,0xA1,0xE0,0xB5,0x6C,0x11,0x53,0x8A,0x1E,0x8D,0x51,0x04)
$patched  = [byte[]](0xFE,0x06,0x8B,0x4E,0x2C,0xA1,0xE0,0xB5,0x6C,0x11,0x53,0xB3,0x64,0x8D,0x51,0x04)
$ctxStart = $knownOffset - 11

function Test-Bytes([byte[]]$hay, [int]$at, [byte[]]$needle) {
    if ($at -lt 0 -or $at + $needle.Length -gt $hay.Length) { return $false }
    for ($i = 0; $i -lt $needle.Length; $i++) { if ($hay[$at+$i] -ne $needle[$i]) { return $false } }
    return $true
}

$bytes = [System.IO.File]::ReadAllBytes($dll)

$site = $null
if (Test-Bytes $bytes $ctxStart $patched) { $site = $ctxStart }
elseif (Test-Bytes $bytes $ctxStart $context) { Write-Host 'DLL is already original — nothing to restore.'; return }
else {
    $hits = @()
    for ($i = 0; $i -le $bytes.Length - $patched.Length; $i++) {
        if ($bytes[$i] -eq 0xFE -and (Test-Bytes $bytes $i $patched)) { $hits += $i }
    }
    if ($hits.Count -eq 1) { $site = $hits[0] }
    elseif (Test-Path $bak) {
        Write-Host 'Patch site not found — restoring full DLL from backup.'
        Copy-Item $bak $dll -Force
        Write-Host 'Restored FFVIII_EFIGS.dll from backup.'
        return
    }
    else { throw 'Patch site not found and no backup exists. Use Steam "Verify integrity of game files".' }
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
        if ($chk[$i] -ne $context[$i]) { throw 'Verification failed — copy FFVIII_EFIGS.dll.bak over FFVIII_EFIGS.dll manually.' }
    }
}
finally { $fs.Close() }
Write-Host 'Original draw code restored and verified.'
