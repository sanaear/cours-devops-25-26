# Use the official Node.js image as a base
FROM node:25-alpine3.21

# Copy package.json for dependency installation and other files
COPY package.json /app/
COPY src /app/

# Set the working directory inside the container
WORKDIR /app

# Install dependencies
RUN npm install

# Define the command to run your app
CMD ["node", "server.js"]
