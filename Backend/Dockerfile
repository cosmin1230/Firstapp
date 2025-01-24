# Use official Node.js image as the base image
FROM node:16-alpine

# Set the working directory in the container
WORKDIR /usr/src/app

# Copy package.json and package-lock.json first (for caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy the rest of the backend files into the container
COPY . .

# Expose the port that the backend will run on (assuming port 3000)
EXPOSE 3000

# Start the backend server
CMD ["node", "server.js"]