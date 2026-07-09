FROM node:22-slim

WORKDIR /app

# Install curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Copy only the Helia interop harness files.
COPY test/interop/helia/package.json ./
RUN npm install

COPY test/interop/helia/server.js ./
COPY test/interop/swarm.key /swarm.key

EXPOSE 4001 5001

CMD ["node", "server.js"]
