FROM node:20-alpine

WORKDIR /app

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

# Run lightweight Wisp/Bare proxy server
CMD ["node", "server.js"]
