@echo off
setlocal
cd /d "%~dp0"
vivado -mode batch -source scripts\program_board.tcl
pause
