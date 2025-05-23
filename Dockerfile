# Build stage with explicit platform specification
FROM --platform=$TARGETPLATFORM ghcr.io/astral-sh/uv:python3.12-alpine AS uv

# Install the project into /app
WORKDIR /app

# Enable bytecode compilation
ENV UV_COMPILE_BYTECODE=1

# Copy from the cache instead of linking since it's a mounted volume
ENV UV_LINK_MODE=copy

# Install the project's dependencies using the lockfile and settings
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --frozen --no-install-project --no-dev --no-editable

# Then, add the rest of the project source code and install it
# Installing separately from its dependencies allows optimal layer caching
ADD . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev --no-editable

# Final stage with explicit platform specification
FROM --platform=$TARGETPLATFORM python:3.12-alpine

LABEL org.opencontainers.image.source=https://github.com/sparfenyuk/mcp-proxy
LABEL org.opencontainers.image.description="Connect to MCP servers that run on SSE transport, or expose stdio servers as an SSE server using the MCP Proxy server."
LABEL org.opencontainers.image.licenses=MIT

# Install Node.js and npm to run MCP servers that develop with JavaScript
RUN apk add --update nodejs npm

COPY --from=uv --chown=app:app /app/.venv /app/.venv

# Place executables in the environment at the front of the path
ENV PATH="/app/.venv/bin:$PATH"

# Support
ENV SSE_PORT=3000
ENV COMMAND=""
CMD mcp-proxy --sse-port $SSE_PORT --sse-host 0.0.0.0 --env PATH $PATH -- $COMMAND
