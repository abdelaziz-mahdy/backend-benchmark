FROM node:latest

WORKDIR /app

COPY package*.json ./

RUN npm install

# Install curl
RUN apt-get update && apt-get install -y curl

COPY . .

EXPOSE 8000

CMD ["node", "server.js"]
