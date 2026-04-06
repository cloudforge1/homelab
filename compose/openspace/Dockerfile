# OpenSpace — Self-evolving AI agent engine (dashboard + API)
# https://github.com/HKUDS/OpenSpace

ARG OPENSPACE_REF=90b2ffab6ad7acdda006ba7ada6e62022a0531d6

FROM node:20-bookworm-slim AS source

ARG OPENSPACE_REF

RUN apt-get update && apt-get install -y --no-install-recommends \
                git ca-certificates \
        && rm -rf /var/lib/apt/lists/*

RUN git clone --filter=blob:none https://github.com/HKUDS/OpenSpace.git /src \
        && git -C /src checkout "$OPENSPACE_REF" \
        && rm -rf /src/.git

FROM source AS frontend-builder

WORKDIR /src/frontend

RUN npm install \
        && npm run build

FROM python:3.12-slim

LABEL org.opencontainers.image.source="https://github.com/HKUDS/OpenSpace"
LABEL org.opencontainers.image.description="OpenSpace dashboard with bundled frontend"

RUN apt-get update && apt-get install -y --no-install-recommends \
                curl ca-certificates \
        && rm -rf /var/lib/apt/lists/*

COPY --from=source /src /app

WORKDIR /app

RUN pip install --no-cache-dir -e .

# Patch mcp_server.py: FastMCP >=1.20 removed sse_params from run(),
# port/host must be set on the settings object before calling run().
# Also disable DNS rebinding protection so LAN clients can connect.
RUN sed -i \
    's/mcp\.run(transport="sse", sse_params={"port": args\.port})/mcp.settings.host = "0.0.0.0"; mcp.settings.port = args.port; mcp.settings.transport_security.enable_dns_rebinding_protection = False; mcp.run(transport="sse")/' \
    /app/openspace/mcp_server.py

COPY --from=frontend-builder /src/frontend/dist /app/frontend/dist

RUN mkdir -p /app/.openspace /app/openspace/skills

ENV OPENSPACE_WORKSPACE=/app
ENV OPENSPACE_DASHBOARD_HOST=0.0.0.0
ENV OPENSPACE_DASHBOARD_PORT=7788

EXPOSE 7788

CMD ["openspace-dashboard", "--host", "0.0.0.0", "--port", "7788"]
