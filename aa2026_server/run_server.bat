@echo off
REM Double-click this file (Windows) to set up and start the AutoAssist server.
cd /d "%~dp0"

if not exist venv (
  echo Creating Python environment (first time only)...
  python -m venv venv
  if errorlevel 1 (
    echo Could not run "python". Install Python 3.10+ from python.org and tick "Add Python to PATH".
    pause
    exit /b 1
  )
)
call venv\Scripts\activate.bat

echo Installing requirements (quick after the first time)...
pip install -r requirements.txt
if errorlevel 1 (
  echo Installing failed. Check your internet connection and try again.
  pause
  exit /b 1
)

if not exist .env (
  copy .env.example .env >nul
  echo.
  echo A file called .env was created in this folder.
  echo Open it in Notepad, paste your Groq key after GROQ_API_KEY=, save, then run this file again.
  pause
  exit /b 0
)

echo.
echo Starting AutoAssist server on port 8000. Keep this window open.
echo Test it in your browser: http://localhost:8000/health
uvicorn app.main:app --host 0.0.0.0 --port 8000
pause
