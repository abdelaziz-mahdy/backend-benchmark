# Use the official Node.js image as the base image
FROM oven/bun

# Set the working directory inside the container
WORKDIR /app

# Copy the package.json and bun.lockb files to the working directory
COPY package.json ./

# Install the app dependencies
RUN bun install


COPY . .

EXPOSE 8000


CMD bun run server.js


