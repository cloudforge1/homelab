#!/bin/sh
pip install --no-cache-dir openbb uvicorn fastapi
exec uvicorn openbb_platform_api.main:app --host 0.0.0.0 --port 6900
