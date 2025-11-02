FROM node:20-alpine

WORKDIR /app

COPY package*.json ./
COPY tsconfig.json ./

RUN npm ci

COPY . .

RUN npm run build

RUN npm prune --production

CMD ["sh", "-c", "npm run migrate:prod && npm start"]
