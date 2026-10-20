# browser-sandbox: Playwright MCP server with VNC browser preview
FROM node:22-slim

# Install dependencies for Playwright browsers and display/VNC
RUN apt-get update && apt-get install -y \
    # Playwright browser dependencies
    libnss3 \
    libnspr4 \
    libdbus-1-3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    libatspi2.0-0 \
    libxshmfence1 \
    # Display and VNC
    xvfb \
    x11vnc \
    novnc \
    websockify \
    fluxbox \
    # Utilities
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Install Playwright MCP globally
RUN npm install -g @playwright/mcp@latest

# Install Playwright browsers: chrome on amd64, chromium on arm64
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      npx playwright install chrome; \
    else \
      npx playwright install chromium; \
    fi

# Set display environment
ENV DISPLAY=:99

# Expose ports: MCP server and noVNC web interface
EXPOSE 8931 6080

# Create browser data directory
RUN mkdir -p /data

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Clean up stale X lock files (survive docker restart)\n\
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99\n\
# Chrome profile locks name the previous container hostname and block launch\n\
rm -f /data/SingletonLock /data/SingletonCookie /data/SingletonSocket\n\
\n\
# Start virtual display (large enough for a 1080x720 browser viewport and chrome)\n\
Xvfb :99 -screen 0 1280x900x24 &\n\
sleep 2\n\
\n\
# Start window manager\n\
fluxbox &\n\
sleep 1\n\
\n\
# Start VNC server\n\
x11vnc -display :99 -forever -shared -rfbport 5900 -nopw &\n\
sleep 1\n\
\n\
# Start noVNC web server\n\
websockify --web /usr/share/novnc 6080 localhost:5900 &\n\
\n\
# Start Playwright MCP server with persistent user data.\n\
# Use desktop emulation explicitly; --device also enables mobile/touch behavior.\n\
ARCH=$(dpkg --print-architecture)\n\
if [ "$ARCH" = "amd64" ]; then\n\
  BROWSER_ARGS=(--browser chrome)\n\
  BROWSER_VERSION=$(google-chrome --version | grep -oE "[0-9]+(\\.[0-9]+){3}" | head -1)\n\
else\n\
  CHROMIUM_PATH=$(find /root/.cache/ms-playwright -name "chrome" -path "*/chromium-*/chrome-linux*/*" | head -1)\n\
  BROWSER_ARGS=(--executable-path "$CHROMIUM_PATH")\n\
  BROWSER_VERSION=$("$CHROMIUM_PATH" --version | grep -oE "[0-9]+(\\.[0-9]+){3}" | head -1)\n\
fi\n\
BROWSER_VERSION=${BROWSER_VERSION:-147.0.0.0}\n\
DESKTOP_UA="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$BROWSER_VERSION Safari/537.36"\n\
exec npx @playwright/mcp@latest --port 8931 --host 0.0.0.0 --allowed-hosts "*" "${BROWSER_ARGS[@]}" --user-data-dir /data --shared-browser-context --no-sandbox --viewport-size "1080x720" --user-agent "$DESKTOP_UA"\n\
' > /app/start.sh && chmod +x /app/start.sh

# Volume for persistent browser data
VOLUME /data

CMD ["/app/start.sh"]
