@echo off
cd /d "%~dp0"

echo Demarrage du serveur Rojo...
start "Rojo Server" cmd /k ""%~dp0rojo.exe" serve"

echo Synchronisation automatique GitHub active.
echo Les nouvelles modifications seront recuperees toutes les 3 secondes.
echo Laisse cette fenetre ouverte pendant le developpement.

:loop
git pull --ff-only >nul 2>&1
timeout /t 3 /nobreak >nul
goto loop
