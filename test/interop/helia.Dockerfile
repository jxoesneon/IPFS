FROM node:20-slim

WORKDIR /app

# Copy only the Helia interop harness files.
COPY test/interop/helia/package.json ./
RUN npm install

COPY test/interop/helia/ ./

EXPOSE 4001 5001

CMD ["node", "server.js"]
