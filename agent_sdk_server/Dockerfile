FROM node:20-alpine

# Install bash for POSIX shell requirement
RUN apk add --no-cache bash

# Set SHELL environment variable required by Claude CLI
ENV SHELL=/bin/bash

WORKDIR /app

COPY package*.json ./
COPY tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build

RUN npm prune --production

# Create non-root user and switch to it
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001 && \
    chown -R nodejs:nodejs /app

USER nodejs

CMD ["npm", "start"]
