@echo off
setlocal
cd /d "%~dp0"
vivado -mode batch -source scripts\setup_project.tcl
vivado OS_Exp_1.xpr
