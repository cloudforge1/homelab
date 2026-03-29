# OpenSpace — Self-evolving AI agent engine (dashboard API)
# https://github.com/HKUDS/OpenSpace
#
# Clones latest OpenSpace at build time. Rebuild to update:
#   docker compose -f docker-compose.openspace.yml build --no-cache openspace
# ───────────────────────────────────────────────────────────

FROM python:3.12-slim

LABEL org.opencontainers.image.source="https://github.com/HKUDS/OpenSpace"
LABEL org.opencontainers.image.description="OpenSpace dashboard API"

RUN apt-get update && apt-get install -y --no-install-recommends \
        git curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Clone OpenSpace (blob filter skips binary blobs like screenshots/images)
RUN git clone --filter=blob:none \
        https://github.com/HKUDS/OpenSpace.git /app

WORKDIR /app

# Install Python deps (includes openspace-mcp and openspace-dashboard bins)
RUN pip install --no-cache-dir -e .

# Persist skill DB and model cache in named volumes
RUN mkdir -p /app/.openspace /app/openspace/skills

ENV OPENSPACE_WORKSPACE=/app
# Make dashboard bind on all interfaces inside the container
ENV OPENSPACE_DASHBOARD_HOST=0.0.0.0
ENV OPENSPACE_DASHBOARD_PORT=7788

EXPOSE 7788

# Startup: dashboard API (frontend runs separately via pnpm openspace:dashboard:ui)
CMD ["openspace-dashboard", "--port", "7788"]
