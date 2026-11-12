#!/usr/bin/env bash
# macOS / Linux: ./run_server.sh
cd "$(dirname "$0")"
[ -d venv ] || python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
if [ ! -f .env ]; then
  cp .env.example .env
  echo "Created .env - open it, paste your Groq key after GROQ_API_KEY=, save, then run this again."
  exit 0
fi
echo "Starting AutoAssist server on port 8000 (Ctrl+C to stop)"
uvicorn app.main:app --host 0.0.0.0 --port 8000
