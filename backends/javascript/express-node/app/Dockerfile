FROM node:24.21-slim
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY server.js migration.sql ./
EXPOSE 8000
CMD ["node", "server.js"]
