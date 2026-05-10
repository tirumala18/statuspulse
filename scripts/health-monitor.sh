#!/bin/bash

LOG_FILE="/var/log/statuspulse-monitor.log"
BASE_URL=${BASE_URL:-"http://localhost:8000"}
DOMAIN=${DOMAIN:-"statuspulse.local"}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

send_alert() {
  local message=$1
  log "ALERT: $message"
  if [ -n "$ALERT_WEBHOOK_URL" ]; then
    curl -s -X POST -H 'Content-type: application/json' --data "{\"text\":\"$message\"}" "$ALERT_WEBHOOK_URL"
  fi
}

log "Starting health monitor checks..."

# 1. Check /health endpoint
HEALTH_STATUS=$(curl -s -o /tmp/health_monitor.json -w "%{http_code}" "$BASE_URL/health" --max-time 10 || echo "TIMEOUT")
if [ "$HEALTH_STATUS" != "200" ]; then
  send_alert "StatusPulse API health check failed! HTTP Status: $HEALTH_STATUS"
elif ! grep -q '"status":"healthy"' /tmp/health_monitor.json; then
  send_alert "StatusPulse API is not healthy! Response: $(cat /tmp/health_monitor.json)"
fi

# 2. Check disk usage > 80%
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
  send_alert "High disk usage detected: ${DISK_USAGE}%"
fi

# 3. Check memory usage > 90%
MEMORY_USAGE=$(free | awk '/Mem/ {printf("%3.0f\n", ($3/$2) * 100)}')
if [ "$MEMORY_USAGE" -gt 90 ]; then
  send_alert "High memory usage detected: ${MEMORY_USAGE}%"
fi

# 4. Check expected Docker containers are running
EXPECTED_CONTAINERS=("statuspulse-app-1" "statuspulse-db-1" "statuspulse-redis-1" "caddy")
for container in "${EXPECTED_CONTAINERS[@]}"; do
  # Check if container is running (ignore exact name match issues by checking compose ps if needed, 
  # or fallback to loose matching for this script)
  if ! docker ps --format '{{.Names}}' | grep -q "$container"; then
    send_alert "Expected Docker container is NOT running: $container"
  fi
done

# 5. Check TLS certificate expires within 14 days
# Note: Requires the domain to be accessible externally if using external check, 
# or check locally via cert files. We'll use openssl against the domain.
if [ "$DOMAIN" != "statuspulse.local" ]; then
  EXPIRY_DATE=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
  if [ -n "$EXPIRY_DATE" ]; then
    EXPIRY_EPOCH=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_EPOCH=$(date +%s)
    DAYS_LEFT=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
    if [ "$DAYS_LEFT" -le 14 ]; then
      send_alert "TLS certificate for $DOMAIN expires in $DAYS_LEFT days!"
    fi
  fi
fi

log "Health monitor checks completed."
