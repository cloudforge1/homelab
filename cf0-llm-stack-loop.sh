#!/usr/bin/env bash
# cf0-llm-stack-loop.sh — Retry wrapper for unattended deployment
# Run: sudo screen -dmS llm bash /opt/cf0-scripts/cf0-llm-stack-loop.sh
#
# Retries with exponential backoff on failure.
# Logs to /var/log/cf0-llm-stack-loop.log
set -uo pipefail  # no -e — we handle errors ourselves

MAX_ATTEMPTS=25
BASE_DELAY=30
MAX_DELAY=600
SCRIPT_PATH="/opt/cf0-scripts/cf0-llm-stack.sh"
LOGFILE="/var/log/cf0-llm-stack-loop.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"; }

log "===================================================================="
log "  cf0 LLM + AI Tools Stack — Loop Wrapper"
log "  Max attempts: ${MAX_ATTEMPTS}, Base delay: ${BASE_DELAY}s"
log "  Script: ${SCRIPT_PATH}"
log "===================================================================="

attempt=0
delay=$BASE_DELAY

while [[ $attempt -lt $MAX_ATTEMPTS ]]; do
    ((attempt++))
    log ""
    log ">>> ATTEMPT ${attempt}/${MAX_ATTEMPTS} (next delay: ${delay}s)"
    log ""

    bash "$SCRIPT_PATH" >> "$LOGFILE" 2>&1
    EXIT_CODE=$?

    if [[ $EXIT_CODE -eq 0 ]]; then
        log ""
        log "===================================================================="
        log "  SUCCESS on attempt ${attempt}!"
        log "  All services deployed. Run: llm-status"
        log "===================================================================="
        exit 0
    fi

    log "FAILED (exit code: ${EXIT_CODE}) — sleeping ${delay}s before retry..."

    # Exponential backoff: 30, 60, 120, 240, 480, 600, 600, ...
    sleep "$delay"
    delay=$((delay * 2))
    if [[ $delay -gt $MAX_DELAY ]]; then
        delay=$MAX_DELAY
    fi
done

log ""
log "===================================================================="
log "  EXHAUSTED all ${MAX_ATTEMPTS} attempts!"
log "  Check logs: tail -100 /var/log/cf0-llm-stack.log"
log "  Check containers: docker ps -a"
log "===================================================================="
exit 1
