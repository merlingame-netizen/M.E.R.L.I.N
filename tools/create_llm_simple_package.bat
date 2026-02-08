@echo off
REM ============================================================================
REM Créer le package llm_simple pour upload sur Colab
REM ============================================================================

echo.
echo ========================================================================
echo  Creation du package LLM Simple
echo ========================================================================
echo.

cd /d "%~dp0"

REM Supprimer ancien package
if exist llm_simple_sources.tar.gz del /f /q llm_simple_sources.tar.gz

REM Cloner godot-cpp si nécessaire
if not exist "godot-cpp" (
    echo Clonage de godot-cpp...
    git clone --depth 1 --branch 4.2 https://github.com/godotengine/godot-cpp.git
)

REM Créer le tar.gz
echo.
echo Creation de l'archive...
tar -czf llm_simple_sources.tar.gz ^
    llm_simple/ ^
    addons/llm_simple/llm_simple.gdextension ^
    godot-cpp/

REM Vérification
if exist llm_simple_sources.tar.gz (
    echo.
    echo ========================================================================
    echo  SUCCESS!
    echo ========================================================================
    echo.
    echo Package cree: llm_simple_sources.tar.gz
    for %%A in ("llm_simple_sources.tar.gz") do echo Taille: %%~zA octets
    echo.
    echo Prochaines etapes:
    echo  1. Ouvrir Google Colab
    echo  2. Upload Compile_LLM_Simple.ipynb
    echo  3. Executer toutes les cellules
    echo  4. Upload llm_simple_sources.tar.gz quand demande
    echo.
) else (
    echo.
    echo ERREUR: Package non cree!
)

echo.
pause
