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

# Install Playwright browsers (chrome = Google Chrome, needed by @playwright/mcp)
RUN npx playwright install chrome

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
# Start virtual display\n\
Xvfb :99 -screen 0 1280x720x24 &\n\
sleep 1\n\
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
# Start Playwright MCP server with persistent user data\n\
exec npx @playwright/mcp@latest --port 8931 --host 0.0.0.0 --allowed-hosts "*" --user-data-dir /data --no-sandbox\n\
' > /app/start.sh && chmod +x /app/start.sh

# Volume for persistent browser data
VOLUME /data

CMD ["/app/start.sh"]
