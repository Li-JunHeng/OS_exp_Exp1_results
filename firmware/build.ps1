$ErrorActionPreference = "Stop"

$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Build = Join-Path $Root "build\firmware"
$Memory = Join-Path $Root "memory"
$FallbackBin = "C:\Users\Administrator\.platformio\packages\toolchain-riscv\bin"

New-Item -ItemType Directory -Force -Path $Build | Out-Null
New-Item -ItemType Directory -Force -Path $Memory | Out-Null

function Find-Tool($name) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $fallback = Join-Path $FallbackBin "$name.exe"
    if (Test-Path $fallback) { return $fallback }
    throw "Missing RISC-V tool: $name"
}

$Gcc = Find-Tool "riscv64-unknown-elf-gcc"
$Objcopy = Find-Tool "riscv64-unknown-elf-objcopy"
$Objdump = Find-Tool "riscv64-unknown-elf-objdump"

$Common = @(
    "-march=rv32i",
    "-mabi=ilp32",
    "-mno-relax",
    "-ffreestanding",
    "-nostdlib",
    "-fno-builtin",
    "-fno-pic",
    "-fno-asynchronous-unwind-tables",
    "-O2",
    "-Wall",
    "-Wextra",
    "-I$PSScriptRoot"
)

$Sources = @("start.S", "trap_entry.S", "game.c", "input.c", "render.c", "world.c")
$Objects = @()

foreach ($src in $Sources) {
    $in = Join-Path $PSScriptRoot $src
    $base = [System.IO.Path]::GetFileNameWithoutExtension($src)
    $sout = Join-Path $Build "$base.s"
    $oout = Join-Path $Build "$base.o"

    if ($src.EndsWith(".c")) {
        & $Gcc @Common -S $in -o $sout
        & $Gcc @Common -c $sout -o $oout
    } else {
        & $Gcc @Common -c $in -o $oout
    }
    $Objects += $oout
}

$Elf = Join-Path $Build "game.elf"
$Bin = Join-Path $Build "game.bin"
$Dump = Join-Path $Build "game.dump"
$Linker = Join-Path $PSScriptRoot "linker.ld"

& $Gcc @Common "-T$Linker" "-Wl,--no-relax" "-Wl,-Map,$Build\game.map" $Objects -o $Elf
& $Objcopy -O binary -j .text -j .rodata $Elf $Bin
& $Objdump -d $Elf | Out-File -Encoding ASCII $Dump

$dumpText = Get-Content $Dump -Raw
if ($dumpText -match "\s(c\.|c\.)") {
    throw "Compressed instruction detected in objdump output"
}
if ($dumpText -match "\b(mul|mulh|mulhsu|mulhu|div|divu|rem|remu)\b") {
    throw "RV32M instruction detected in objdump output"
}

function Write-Dat($Path, [byte[]]$Bytes, [int]$Words) {
    $lines = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $Words; $i++) {
        $b0v = if (($i * 4 + 0) -lt $Bytes.Length) { $Bytes[$i * 4 + 0] } else { 0 }
        $b1v = if (($i * 4 + 1) -lt $Bytes.Length) { $Bytes[$i * 4 + 1] } else { 0 }
        $b2v = if (($i * 4 + 2) -lt $Bytes.Length) { $Bytes[$i * 4 + 2] } else { 0 }
        $b3v = if (($i * 4 + 3) -lt $Bytes.Length) { $Bytes[$i * 4 + 3] } else { 0 }
        $b0 = [uint32]$b0v
        $b1 = [uint32]$b1v
        $b2 = [uint32]$b2v
        $b3 = [uint32]$b3v
        $word = (($b3 -shl 24) -bor ($b2 -shl 16) -bor ($b1 -shl 8) -bor $b0)
        $lines.Add(("{0:x8}" -f $word))
    }
    [System.IO.File]::WriteAllLines($Path, $lines)
}

$ProgramBytes = [System.IO.File]::ReadAllBytes($Bin)
if ($ProgramBytes.Length -gt 16384) {
    throw "Firmware text image is larger than the current 16 KiB instruction ROM: $($ProgramBytes.Length)"
}

Write-Dat (Join-Path $Memory "testac.dat") $ProgramBytes 4096
Write-Dat (Join-Path $Memory "D_mem.dat") ([byte[]]::new(0)) 1024

Write-Host "Firmware ready:"
Write-Host "  ELF:  $Elf"
Write-Host "  ROM:  $(Join-Path $Memory 'testac.dat')"
Write-Host "  RAM:  $(Join-Path $Memory 'D_mem.dat')"
