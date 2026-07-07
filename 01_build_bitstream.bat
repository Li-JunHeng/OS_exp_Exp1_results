@echo off
setlocal
cd /d "%~dp0"
vivado -mode batch -source scripts\build_bitstream.tcl
pause
