# Docker Practice: Node.js & TypeScript Guide

This repository is a personal knowledge base and hands-on project for learning Docker. It contains a simple Node.js/TypeScript/Express application and all the necessary Docker files to containerize and run it, both as a single image and as part of a multi-service application with Docker Compose.

This `README.md` file acts as a **comprehensive set of notes** covering all the fundamental Docker concepts used in this project.

## Project File Structure

```
DOCKER-PRACTICE/
│
├── .vscode/          # VS Code editor settings
├── node_modules/     # (Ignored by Docker)
├── src/              # TypeScript source code
│   └── index.ts      # Main Express server
│
├── .dockerignore     # Tells Docker which files to ignore
├── .env              # Environment variables for LOCAL development
├── docker-compose.yml# Defines multi-container services
├── Dockerfile        # PRODUCTION: Optimized multi-stage build
├── Dockerfile.demo   # BASIC: Simple, unoptimized build
├── package-lock.json # Dependency lock file
├── package.json      # Project dependencies and scripts
├── README.md         # This guide
└── tsconfig.json     # TypeScript compiler options
```

---

## Section 1: What is Docker? (The Big Idea)

At its simplest, Docker is a tool that lets you package an application and all its dependencies (like libraries, system tools, and runtime) into a single, isolated box called a **container**.

- **The Problem:** "It works on my machine, but not on yours (or on the server)\!" This happens because of differences in operating systems, installed libraries, or Node.js versions.
- **The Solution (A Container):** A container bundles _everything_ the app needs to run. This bundle is lightweight, portable, and runs exactly the same way on any machine that has Docker installed.

### Core Concepts

| Term           | Analogy       | What It Is                                                                                                                                  |
| :------------- | :------------ | :------------------------------------------------------------------------------------------------------------------------------------------ |
| **Dockerfile** | **Recipe**    | A text file with instructions (e.g., `FROM node`, `COPY .`, `RUN npm install`) that tells Docker how to build an image.                     |
| **Image**      | **Blueprint** | A read-only template. It's the "packaged" application created from the `Dockerfile`. It's a snapshot of the app and its dependencies.       |
| **Container**  | **House**     | A running instance of an image. It's the "living" application. You can have many containers (houses) built from the same image (blueprint). |
| **Registry**   | **Warehouse** | A place to store and share images. **Docker Hub** is the most popular public registry.                                                      |

---

## Section 2: Essential Docker CLI Commands (Your Cheatsheet)

These are the commands you will use 90% of the time.

### Building & Running

- **Build an image from a `Dockerfile`:**

  ```bash
  # Usage: docker build -t <image-name>:<tag> <path-to-dockerfile-context>
  docker build -t my-node-app:1.0 .

  # Build using a *specific* Dockerfile name:
  docker build -t my-demo-app -f Dockerfile.demo .
  ```

- **Run a container from an image:**

  ```bash
  # Usage: docker run [OPTIONS] <image-name>
  # -d : Detached mode (run in background)
  # -p : Publish port (host:container)
  # --name : Assign a name to the container
  docker run -d -p 5000:5000 --name my-running-app my-node-app:1.0
  ```

### Listing & Managing

- **List running containers:**

  ```bash
  docker ps
  ```

- **List ALL containers (running and stopped):**

  ```bash
  docker ps -a
  ```

- **Stop a running container:**

  ```bash
  # Use either the name or the container ID
  docker stop my-running-app
  docker stop <container-id>
  ```

- **Remove a stopped container:**

  ```bash
  docker rm my-running-app
  ```

- **List all images on your machine:**

  ```bash
  docker images
  ```

- **Remove an image:**

  ```bash
  docker rmi my-node-app:1.0
  ```

### Inspecting & Debugging

- **View the logs of a container:**

  ```bash
  # -f : Follow the log output (like 'tail -f')
  docker logs -f my-running-app
  ```

- **Execute a command inside a running container:**

  ```bash
  # This is great for debugging!
  # 'exec -it' means "execute interactively"
  # '/bin/sh' is the shell (alpine uses 'sh', others might use 'bash')
  docker exec -it my-running-app /bin/sh

  # Once inside, you can run commands like 'ls', 'pwd', 'cat /app/dist/index.js'
  ```

### Cleanup

- **The "Nuke" Button:** Remove all stopped containers, unused networks, and dangling images.

  ```bash
  docker system prune

  # Even more aggressive (removes all unused images, not just dangling):
  docker system prune -a -f
  ```

---

## Section 3: Dissecting Our Dockerfiles

This project has two `Dockerfile`s to show the difference between a simple build and an optimized one.

### Analysis 1: `Dockerfile.demo` (The Simple Way)

```dockerfile
# Base image
FROM node:22-alpine3.18
# Set working directory
WORKDIR /app
# Copy package files
COPY package*.json .
# Install ALL dependencies (dev + prod)
RUN npm install
# Copy ALL source code
COPY . .
# Build the app
RUN npm run build
# Expose port
EXPOSE 5000
# Run the app
CMD [ "npm", "start" ]
```

- **Pros:** Very simple and easy to understand.
- **Cons:**
  1.  **Huge Image Size:** It installs all `devDependencies` (`typescript`, `ts-node-dev`, etc.) into the final image, which are not needed to _run_ the app.
  2.  **Slow Rebuilds:** If you change _any_ file (even `README.md`), Docker breaks the cache for the `COPY . .` step and has to re-run _everything_ after it (including `npm run build`).
  3.  **Insecure:** It copies _everything_ (like `.git` or `.env` files if not in `.dockerignore`) into the image.

### Analysis 2: `Dockerfile` (The Optimized, Multi-Stage Way)

This is the **production-ready** standard.

#### What is a Multi-Stage Build?

A multi-stage build uses multiple `FROM` instructions. Each `FROM` starts a new "stage." This lets you separate the **build environment** (which needs `devDependencies`, `src` files) from the **production environment** (which _only_ needs the compiled `dist` folder and `node_modules`).

```dockerfile
# ----- STAGE 1: 'base' -----
# Just sets up the common working directory
FROM node:22-alpine3.18 AS base
WORKDIR /app

# ----- STAGE 2: 'builder' -----
# This stage builds the app.
FROM base AS builder
COPY package*.json ./
COPY tsconfig.json ./
# Install ALL dependencies (needed for build)
RUN npm install
COPY . .
# Compile TypeScript to JavaScript
RUN npm run build

# ----- STAGE 3: 'production' -----
# This is the *final* image. It's clean.
FROM base AS production
WORKDIR /app
# Copy *only* the build output from the 'builder' stage
COPY --from=builder /app/dist ./dist
# Copy package files (needed to install prod dependencies)
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/tsconfig.json ./

# Install ONLY production dependencies
RUN npm install --omit=dev

# ...
CMD ["node", "dist/index.js"]
```

- **Pros:**
  1.  **Minimal Image Size:** The final image (`production`) never installs `devDependencies`. It only contains the `dist` folder and production `node_modules`.
  2.  **Faster Rebuilds (Cache Optimization):** We copy `package.json` _first_ and run `npm install`. Then we `COPY . .`. If we only change our source code (e.g., `src/index.ts`), Docker re-uses the already-downloaded `npm install` layer and only re-runs the `COPY . .` and `npm run build` steps.
  3.  **More Secure:** Only the specific files we `COPY --from=builder` make it into the final image.

### The `.dockerignore` File

The `.dockerignore` file works just like `.gitignore`. It prevents files from being copied into the container's build context. This is **critical for speed and security**.

Our `.dockerignore` prevents our local `node_modules` and `.git` folder from _ever_ being sent to the Docker daemon, which speeds up the `COPY . .` step immensely.

---

## Section 4: Orchestration with Docker Compose

What if your app needs a database (like Redis) and a web server (like Nginx)? Managing three separate `docker run` commands is painful.

**Docker Compose** is a tool for defining and running **multi-container** applications. You use a single `docker-compose.yml` file to configure all your application's services, networks, and volumes.

### Analysis: `docker-compose.yml`

This file defines three services: `nginx`, `alpine`, and `redis`. They are all connected to a custom network.

```yaml
version: "3.8"
services:
  nginx:
    image: nginx:latest
    container_name: nginx_container
    ports:
      - "80:80"
    volumes:
      - nginx_data:/data # Uses a named volume
    networks:
      - "my_network" # Connects to our network

  redis:
    image: redis:latest
    container_name: redis_container
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data # Uses a named volume
    networks:
      - "my_network"

  # (alpine service omitted for brevity)

# These top-level keys *define* the resources
volumes:
  nginx_data:
  redis_data:

networks:
  my_network:
    driver: bridge
```

### Docker Volumes (Persistent Data)

**Problem:** Containers are _ephemeral_. If you `docker rm` a container, all the data inside it is **gone forever**. This is bad for a database.

**Solution: Volumes.** A volume is a mechanism for persisting data _outside_ the container's lifecycle. The data is stored on the host machine in a special area managed by Docker.

In our `docker-compose.yml`:

- `volumes: - redis_data:/data`: This maps the `/data` folder _inside_ the Redis container to a **named volume** called `redis_data`.
- `volumes: redis_data:`: This top-level key tells Docker to create and manage that named volume.

Now, if you stop and remove the `redis_container`, the `redis_data` volume _still exists_. When you start a new container, it re-attaches to the existing volume, and all your data is still there.

- **Named Volume:** (`my-data:/app/data`) Managed by Docker. Preferred way.
- **Bind Mount:** (`./my-local-folder:/app/data`) Maps a specific folder from your host machine. Good for development (e.g., mapping your `src` folder for hot-reloading).

### Docker Networks (Communication)

**Problem:** How do containers talk to each other?

**Solution: Networks.** By default, Docker Compose creates a custom **bridge network** (called `my_network` in our file) and connects all services to it.

The most important feature: **Containers on the same network can find each other using their service name.**

- **Example:** Our Node.js app (if we added it to this compose file) could connect to Redis using the hostname `redis` and port `6379`. It doesn't need to know the container's IP address.
- **e.g., `const redisClient = new Redis("redis://redis:6379")`**

---

## Section 5: How to Use This Repository

### Prerequisites

- [Git](https://git-scm.com/)
- [Node.js](https://nodejs.org/en) (for local development)
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine on Linux)

### Option 1: Run Locally (Development Mode)

This method does **not** use Docker. It's for active development with hot-reloading.

```bash
# 1. Clone the repo
git clone <your-repo-url>
cd DOCKER-PRACTICE

# 2. Install dependencies
npm install

# 3. Run the dev server
# This uses 'ts-node-dev' to watch for changes
npm run dev

# App will be running at http://localhost:5000
```

### Option 2: Build & Run the Optimized Docker Image

This builds a single image from our production `Dockerfile` and runs it.

```bash
# 1. Make sure Docker Desktop is running
# 2. Open a terminal in the project root

# 3. Build the image
# This uses our optimized multi-stage 'Dockerfile'
docker build -t my-prod-app:latest .

# 4. Run the container
docker run -d -p 5000:5000 --name my-running-app my-prod-app:latest

# App will be running at http://localhost:5000
```

### Option 3: Run All Services with Docker Compose

This is the most "production-like" way. It will start `nginx`, `alpine`, and `redis` based on the `docker-compose.yml` file.

_(Note: Our Node.js app is not currently in the `docker-compose.yml`, but you could add it as another service\!)_

```bash
# 1. Make sure Docker Desktop is running
# 2. Open a terminal in the project root

# 3. Build and start all services in detached mode
docker-compose up -d --build

# 4. Check that all containers are running
docker ps

# You should see 'nginx_container', 'alpine_container', and 'redis_container'

# 5. Stop and remove all services defined in the compose file
docker-compose down
```
