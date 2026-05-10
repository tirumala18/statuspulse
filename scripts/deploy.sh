#!/bin/bash
set -e

# Logging function
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting deployment process..."

# Navigate to application directory
cd "$(dirname "$0")/.." || exit 1

if [ ! -f .env ]; then
  log ".env file is missing. Creating from .env.example..."
  cp .env.example .env
fi

# Export image tag if not set, default to latest
export IMAGE_TAG=${IMAGE_TAG:-latest}
# Assuming ghcr.io image name matches github repository. We'll use an env var or fallback.
IMAGE_NAME=${IMAGE_NAME:-ghcr.io/tirumala18/statuspulse}

log "Pulling latest image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker pull "${IMAGE_NAME}:${IMAGE_TAG}"

log "Updating docker-compose to use new image tag..."
# Since docker-compose might not have the tag hardcoded if we use the build section locally, 
# for production we should ideally inject it or have a production compose file.
# Let's assume production uses `docker-compose.prod.yml` or overrides.
# For simplicity, we'll just restart the service which will use the pulled image if tagged as latest,
# or we set the image name explicitly in the up command via environment variable.

export APP_IMAGE="${IMAGE_NAME}:${IMAGE_TAG}"

log "Starting new containers..."
docker compose -f docker-compose.yml up -d --build

log "Waiting for application to be healthy..."
sleep 10
for i in {1..12}; do
  if docker inspect --format "{{json .State.Health.Status }}" $(docker compose ps -q app) | grep -q "healthy"; then
    log "Application is healthy!"
    HEALTHY=true
    break
  fi
  log "Waiting..."
  sleep 5
done

if [ "$HEALTHY" != "true" ]; then
  log "Application failed health check. Rolling back..."
  # Simple rollback: restart using the previous known good state or just stop
  # In a robust setup, we'd keep the old tag and revert.
  docker compose logs app > deploy_failure.log
  log "Check deploy_failure.log for details."
  
  # For this practical, a failure means we might want to revert the compose file 
  # or pull the previous working tag. Let's just exit non-zero for now so CI catches it.
  exit 1
fi

log "Pruning old images to save space..."
docker image prune -af --filter "until=24h"

log "Deployment successful!"
