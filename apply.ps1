# FF8R Draw 100 Mod — apply
# Patches the draw-to-stock routine in FFVIII_EFIGS.dll so any successful Draw
# fills the spell's stock to 100. Two bytes change: mov bl,[esi] -> mov bl,100.
$ErrorActionPreference = 'Stop'

$dll = Join-Path (Split-Path -Parent $PSScriptRoot) 'FFVIII_EFIGS.dll'
$bak = Join-Path $PSScriptRoot 'FFVIII_EFIGS.dll.bak'

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
elseif (Test-Bytes $bytes $ctxStart $patched) { Write-Host 'Draw 100 Mod is already applied.'; return }
else {
    Write-Host 'Known offset does not match — scanning DLL...'
    $hits = @()
    for ($i = 0; $i -le $bytes.Length - $context.Length; $i++) {
        if ($bytes[$i] -eq 0xFE -and (Test-Bytes $bytes $i $context)) { $hits += $i }
    }
    if ($hits.Count -eq 1) { $site = $hits[0]; Write-Host ('Found unique match at file offset 0x{0:X}' -f $site) }
    elseif ($hits.Count -eq 0) { throw 'Pattern not found. DLL layout differs (game update?). Not patching.' }
    else { throw "Pattern matched $($hits.Count) times — ambiguous. Not patching." }
}

if (-not (Test-Path $bak)) {
    Copy-Item $dll $bak
    Write-Host "Backed up original DLL -> $bak"
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
        if ($chk[$i] -ne $patched[$i]) { throw 'Verification failed — restore from backup with restore.ps1' }
    }
}
finally { $fs.Close() }
Write-Host 'Draw 100 Mod applied and verified. Draw now fills stock to 100.'
