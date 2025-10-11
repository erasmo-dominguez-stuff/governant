# Docker Setup

This directory contains Docker-related configuration files for the Governant project.

## Files

- `Dockerfile`: The main Dockerfile for building the application container
- `docker-compose.yml`: Docker Compose configuration for development, testing, and linting

## Usage

### Build and Run

From the project root, you can use the following commands:

```bash
# Build and start the development environment
docker-compose -f docker/docker-compose.yml --profile dev up -d

# Run tests
docker-compose -f docker/docker-compose.yml --profile test run --rm test

# Run linters
docker-compose -f docker/docker-compose.yml --profile lint run --rm lint
```

### Development

For development, you can attach to the running container:

```bash
docker exec -it governant-app bash
```

## Configuration

The Docker setup uses `uv` for Python package management and is configured to:
- Use Python 3.11
- Run as a non-root user for security
- Mount the project directory as a volume for development
- Include necessary development and testing tools
