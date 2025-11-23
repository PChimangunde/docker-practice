# Base image
FROM node:20-slim

# Set working directory
WORKDIR /app

# Copy package details first (better caching)
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy all project files
COPY . .

# Build TypeScript into /dist
RUN npm run build

# Expose application port
EXPOSE 5000

# Start the app
CMD ["npm", "start"]

