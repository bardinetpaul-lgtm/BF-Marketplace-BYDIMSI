@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul

REM ============================================================
REM  Script automatique : envoie le marketplace dimsi-plugins
REM  vers ton repo GitHub bardinetpaul-lgtm/BF-Marketplace-BYDIMSI
REM
REM  Usage : double-clique sur ce fichier
REM ============================================================

echo.
echo ========================================================
echo   PUSH AUTOMATIQUE DU MARKETPLACE DIMSI
echo ========================================================
echo.

cd /d "%~dp0"
echo Dossier de travail : %CD%
echo.

REM Verification que git est installe
where git >nul 2>nul
if errorlevel 1 (
    echo [ERREUR] Git n'est pas installe sur ton ordinateur.
    echo.
    echo Telecharge-le ici : https://git-scm.com/download/win
    echo Puis relance ce script.
    echo.
    pause
    exit /b 1
)

REM Verification que les fichiers cles sont presents
if not exist ".claude-plugin\marketplace.json" (
    echo [ERREUR] Le fichier .claude-plugin\marketplace.json est manquant !
    echo Le script doit etre dans le dossier dimsi-plugins.
    echo.
    pause
    exit /b 1
)

echo [OK] Git detecte
echo [OK] Structure marketplace verifiee
echo.

REM Configurer git si pas deja fait
git config --global --get user.email >nul 2>nul
if errorlevel 1 (
    echo Configuration de git...
    git config --global user.email "p.bardinet@dimsi.fr"
    git config --global user.name "Paul Bardinet"
)

REM Demande l'URL du repo
echo URL du repo GitHub cible :
echo   https://github.com/bardinetpaul-lgtm/BF-Marketplace-BYDIMSI.git
echo.
set "REPO_URL=https://github.com/bardinetpaul-lgtm/BF-Marketplace-BYDIMSI.git"
set /p CONFIRM="Appuie sur Entree pour utiliser cette URL, ou tape une autre URL : "
if not "!CONFIRM!"=="" set "REPO_URL=!CONFIRM!"
echo.
echo Repo cible : !REPO_URL!
echo.

REM Initialiser git si necessaire
if not exist ".git" (
    echo Initialisation de git...
    git init
    git branch -M main
) else (
    echo [INFO] Repo git deja initialise
)

REM Configurer le remote
git remote remove origin 2>nul
git remote add origin "!REPO_URL!"

REM Ajouter tous les fichiers (y compris .claude-plugin)
echo.
echo Ajout de tous les fichiers (y compris dossiers caches)...
git add -A
git add .claude-plugin -f
git add plugins/feuilles-de-temps-batiment/.claude-plugin -f
git add plugins/check-facture-aditec/.claude-plugin -f

REM Verifier ce qui va etre pushe
echo.
echo ========================================================
echo Fichiers qui vont etre envoyes :
echo ========================================================
git status --short
echo.

REM Commit
set "COMMIT_MSG=Setup marketplace dimsi-plugins avec feuilles-de-temps et check-facture"
set /p USER_MSG="Message de commit (Entree pour le defaut) : "
if not "!USER_MSG!"=="" set "COMMIT_MSG=!USER_MSG!"

git commit -m "!COMMIT_MSG!" 2>nul
if errorlevel 1 (
    echo [INFO] Rien de nouveau a committer ou commit deja fait
)

REM Push
echo.
echo ========================================================
echo Envoi vers GitHub...
echo ========================================================
echo.
echo NOTE : si GitHub te demande des identifiants :
echo   - Username : ton pseudo GitHub (bardinetpaul-lgtm)
echo   - Password : un Personal Access Token (PAS ton mot de passe)
echo     Cree-le sur https://github.com/settings/tokens
echo     avec la permission "repo"
echo.

git push -u origin main --force

if errorlevel 1 (
    echo.
    echo ========================================================
    echo [ERREUR] Le push a echoue
    echo ========================================================
    echo.
    echo Causes possibles :
    echo   1. Identifiants incorrects ^(utilise un Personal Access Token^)
    echo   2. Le repo n'existe pas encore sur GitHub
    echo      Cree-le ici : https://github.com/new
    echo      Nom : BF-Marketplace-BYDIMSI
    echo   3. Pas de connexion internet
    echo.
) else (
    echo.
    echo ========================================================
    echo   SUCCES ! Marketplace pushe sur GitHub
    echo ========================================================
    echo.
    echo Verifie ici :
    echo https://github.com/bardinetpaul-lgtm/BF-Marketplace-BYDIMSI
    echo.
    echo Pour utiliser le marketplace dans Claude Code :
    echo   /plugin marketplace add bardinetpaul-lgtm/BF-Marketplace-BYDIMSI
    echo   /plugin install feuilles-de-temps-batiment
    echo   /plugin install check-facture-aditec
    echo.
)

pause
