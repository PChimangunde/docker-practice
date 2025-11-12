# ---------------------------------------------------------------------
# STAGE 1: 'base'
# This stage sets up the common environment for both build and production.
# ---------------------------------------------------------------------
# Use a lightweight Node.js image based on Alpine Linux
FROM node:22-alpine3.18 AS base

# Set the working directory inside the container
WORKDIR /app


# ---------------------------------------------------------------------
# STAGE 2: 'builder'
# This stage builds the TypeScript app.
# It will contain all devDependencies and source code, but will be
# thrown away after the build is complete.
# ---------------------------------------------------------------------
FROM base AS builder

# Copy package files and tsconfig
COPY package*.json ./
COPY tsconfig.json ./

# Install ALL dependencies (including devDependencies)
# We need 'typescript', 'ts-node', etc., to build the project.
RUN npm install

# Copy the full source code into the container
# We do this *after* npm install to leverage Docker's build cache.
# If only code changes, Docker re-uses the 'npm install' layer.
COPY . .

# Compile TypeScript to JavaScript (creates the /dist folder)
RUN npm run build


# ---------------------------------------------------------------------
# STAGE 3: 'production'
# This is the final, optimized image we will actually run.
# It starts fresh from the 'base' image and copies *only* what's needed.
# ---------------------------------------------------------------------
FROM base AS production

# Set working directory again (it's a clean stage)
WORKDIR /app

# Copy the compiled 'dist' folder from the 'builder' stage
COPY --from=builder /app/dist ./dist

# Copy the 'package.json' and 'tsconfig.json' from the 'builder' stage
# We need package.json to install production dependencies.
# We need tsconfig.json because 'dist/index.js' might use paths from it.
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/tsconfig.json ./

# Install *only* production dependencies
# This is a key optimization. We skip all devDependencies.
RUN npm install --omit=dev

# Clean up the npm cache to reduce the final image size
RUN npm cache clean --force

# Set the environment variable for the port
# This will be used by 'src/index.ts' (process.env.PORT)
ENV PORT=5000

# Inform Docker that the container listens on this port
EXPOSE 5000

# The final command to run the compiled JavaScript app
# This is more direct and efficient than using 'npm start'.
CMD ["node", "dist/index.js"]