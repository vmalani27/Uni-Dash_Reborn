@echo off
setlocal

call "%~dp0backend_venv\Scripts\activate.bat"
uvicorn app.main:app

endlocal
