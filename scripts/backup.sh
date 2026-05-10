#!/bin/bash
set -e

BACKUP_DIR="/opt/statuspulse/backups"
TIMESTAMP=$(date +'%Y-%m-%d_%H%M%S')
FILENAME="statuspulse_db_${TIMESTAMP}.sql.gz"
BACKUP_PATH="${BACKUP_DIR}/${FILENAME}"

# Load environment variables
source /opt/statuspulse/.env

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

mkdir -p "$BACKUP_DIR"

log "Starting PostgreSQL backup..."

# Dump the database from the running docker container
docker compose -f /opt/statuspulse/docker-compose.yml exec -T db pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_PATH"

log "Backup completed: $BACKUP_PATH"

# Rotate older backups (keep last 7)
log "Rotating old backups..."
ls -t "$BACKUP_DIR"/statuspulse_db_*.sql.gz | tail -n +8 | xargs -I {} rm -- {}

# Optional S3 upload
if [ -n "$S3_BUCKET" ]; then
  log "Uploading to S3 bucket: $S3_BUCKET..."
  aws s3 cp "$BACKUP_PATH" "s3://${S3_BUCKET}/backups/${FILENAME}"
  log "S3 upload completed."
fi

log "Backup process finished."
