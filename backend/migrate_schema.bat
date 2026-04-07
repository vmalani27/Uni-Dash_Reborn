@echo off
setlocal

if "%~1"=="" (
    echo Usage: migrate_schema.bat "migration label"
    exit /b 1
)

call "%~dp0backend_venv\Scripts\activate.bat"
python "%~dp0scripts\migrate_schema.py" %*

endlocal
