FROM node:20-bookworm-slim

# Install Chromium and fonts for Cloud Browser streaming
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-freefont-ttf \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Configure Puppeteer to use installed Chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium

# Install production dependencies
COPY package*.json ./
RUN npm install --omit=dev

# Copy application source code
COPY . .

# Default environment configuration
ENV NODE_ENV=production
ENV PORT=3000

# Expose standard port
EXPOSE 3000

# Run lightweight Wisp/Bare and Cloud Browser server
CMD ["node", "server.js"]
