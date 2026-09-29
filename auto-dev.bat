@echo off
cd /d "%~dp0"
title One Piece Roblox - Auto Sync

echo Demarrage du serveur Rojo...
start "Rojo Server" cmd /k ""%~dp0rojo.exe" serve"

echo.
echo Synchronisation GitHub automatique active.
echo Verification toutes les 2 secondes.
echo Laisse cette fenetre ouverte.
echo.

:loop
git fetch origin main --quiet
if errorlevel 1 (
    echo [ERREUR] Impossible de contacter GitHub.
    timeout /t 2 /nobreak >nul
    goto loop
)

for /f %%i in ('git rev-parse HEAD') do set LOCAL=%%i
for /f %%i in ('git rev-parse origin/main') do set REMOTE=%%i

if not "%LOCAL%"=="%REMOTE%" (
    echo [MAJ] Nouvelle version detectee...
    git merge --ff-only origin/main
    if errorlevel 1 echo [ERREUR] La mise a jour automatique a echoue.
)

timeout /t 2 /nobreak >nul
goto loop
