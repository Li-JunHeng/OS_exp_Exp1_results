@echo off
setlocal EnableExtensions

set "REMOTE=origin"
set "BRANCH=main"

if not "%~1"=="" set "REMOTE=%~1"
if not "%~2"=="" set "BRANCH=%~2"

if not defined GITHUB_TOKEN if defined GH_TOKEN set "GITHUB_TOKEN=%GH_TOKEN%"

if not defined GITHUB_TOKEN (
    echo Missing GitHub token.
    echo.
    echo Set a token for this cmd window first:
    echo   set GITHUB_TOKEN=your_github_pat
    echo.
    echo Then run:
    echo   %~nx0
    echo.
    echo Optional:
    echo   %~nx0 origin main
    exit /b 2
)

git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo This script must be run inside a Git repository.
    exit /b 2
)

for /f "delims=" %%U in ('git remote get-url "%REMOTE%" 2^>nul') do set "REMOTE_URL=%%U"
if not defined REMOTE_URL (
    echo Remote "%REMOTE%" does not exist.
    exit /b 2
)

echo %REMOTE_URL% | findstr /i /b "https://github.com/" >nul
if errorlevel 1 (
    echo Remote "%REMOTE%" is not a GitHub HTTPS URL:
    echo   %REMOTE_URL%
    echo.
    echo Set it first, for example:
    echo   git remote set-url origin https://github.com/Li-JunHeng/OS_exp_Exp1_results.git
    exit /b 2
)

set "ASKPASS=%TEMP%\git-https-token-askpass-%RANDOM%-%RANDOM%.bat"
(
    echo @echo off
    echo echo %%~1 ^| findstr /i "Username" ^>nul
    echo if not errorlevel 1 ^(
    echo     echo x-access-token
    echo ^) else ^(
    echo     echo %%GITHUB_TOKEN%%
    echo ^)
) > "%ASKPASS%"

set "GIT_ASKPASS=%ASKPASS%"
set "GIT_TERMINAL_PROMPT=0"

git -c credential.helper= push "%REMOTE%" "%BRANCH%"
set "PUSH_EXIT=%ERRORLEVEL%"

del "%ASKPASS%" >nul 2>nul
exit /b %PUSH_EXIT%
