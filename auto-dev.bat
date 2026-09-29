@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title Les Mers Libres - Auto Sync

where git >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Git introuvable. Installe Git puis relance.
    pause
    exit /b 1
)
if not exist "%~dp0rojo.exe" (
    echo [ERREUR] Place rojo.exe dans le dossier du projet puis relance.
    pause
    exit /b 1
)
git rev-parse --is-inside-work-tree >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Ce dossier ne contient pas le depot Git du projet.
    pause
    exit /b 1
)

echo Demarrage du serveur Rojo...
start "Rojo Server" cmd /k ""%~dp0rojo.exe" serve"
echo Synchronisation GitHub active sur la branche actuellement ouverte.
echo Verification toutes les 2 secondes. Laisse cette fenetre ouverte.
echo Dans Studio : connecte Rojo puis lance Play.

:loop
call :sync
timeout /t 2 /nobreak >nul
goto loop

:sync
set "SYNC_BRANCH="
for /f "delims=" %%i in ('git branch --show-current') do set "SYNC_BRANCH=%%i"
if not defined SYNC_BRANCH (
    call :status "[PAUSE] Aucune branche active. Reviens sur main ou ta branche de travail."
    exit /b
)
git fetch origin "+refs/heads/%SYNC_BRANCH%:refs/remotes/origin/%SYNC_BRANCH%" --quiet
if errorlevel 1 (
    call :status "[ATTENTE] GitHub inaccessible ou branche absente. Nouvelle tentative automatique."
    exit /b
)
git merge-base --is-ancestor "origin/%SYNC_BRANCH%" HEAD >nul 2>nul
if not errorlevel 1 (
    call :status "[OK] %SYNC_BRANCH% synchronisee."
    exit /b
)
git diff --quiet
if errorlevel 1 (
    call :status "[PAUSE] Modifications locales detectees. Enregistre-les dans Git avant la mise a jour."
    exit /b
)
git diff --cached --quiet
if errorlevel 1 (
    call :status "[PAUSE] Modifications preparees dans Git. Termine ton commit avant la mise a jour."
    exit /b
)
git merge-base --is-ancestor HEAD "origin/%SYNC_BRANCH%" >nul 2>nul
if errorlevel 1 (
    call :status "[PAUSE] Historiques differents. Fusion manuelle necessaire, aucun fichier ecrase."
    exit /b
)
echo [MAJ] Nouvelle version de %SYNC_BRANCH%...
git merge --ff-only "origin/%SYNC_BRANCH%"
if errorlevel 1 (
    call :status "[PAUSE] Mise a jour bloquee. Lis le message Git ci-dessus."
    exit /b
)
call :status "[OK] %SYNC_BRANCH% synchronisee."
exit /b

:status
if not "%SYNC_STATUS%"=="%~1" echo %~1
set "SYNC_STATUS=%~1"
exit /b
