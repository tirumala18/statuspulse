#!/bin/bash
set -e

BASE_URL="http://localhost:8000"
echo "Running integration tests against $BASE_URL..."

# Helper function to check status code
check_status() {
  local expected=$1
  local actual=$2
  local endpoint=$3
  if [ "$expected" -ne "$actual" ]; then
    echo "❌ FAILED: $endpoint expected $expected but got $actual"
    exit 1
  fi
}

# 1. GET /health
echo "Testing GET /health"
HTTP_STATUS=$(curl -s -o /tmp/health.json -w "%{http_code}" "$BASE_URL/health")
check_status 200 "$HTTP_STATUS" "GET /health"

if grep -q '"status":"healthy"' /tmp/health.json; then
  echo "✅ GET /health passed"
else
  echo "❌ FAILED: GET /health response does not indicate healthy status."
  cat /tmp/health.json
  exit 1
fi

# 2. POST /services
echo "Testing POST /services"
HTTP_STATUS=$(curl -s -o /tmp/post_service.json -w "%{http_code}" -X POST "$BASE_URL/services" -H "Content-Type: application/json" -d '{"name": "test-service", "url": "http://example.com"}')
check_status 200 "$HTTP_STATUS" "POST /services"

if grep -q '"name":"test-service"' /tmp/post_service.json; then
  echo "✅ POST /services passed"
else
  echo "❌ FAILED: POST /services response incorrect."
  cat /tmp/post_service.json
  exit 1
fi

# 3. POST /services (Duplicate)
echo "Testing POST /services (Duplicate)"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/services" -H "Content-Type: application/json" -d '{"name": "test-service", "url": "http://example.com"}')
check_status 409 "$HTTP_STATUS" "POST /services (Duplicate)"
echo "✅ POST /services (Duplicate) passed"

# 4. GET /services
echo "Testing GET /services"
HTTP_STATUS=$(curl -s -o /tmp/get_services.json -w "%{http_code}" "$BASE_URL/services")
check_status 200 "$HTTP_STATUS" "GET /services"

if grep -q '"name":"test-service"' /tmp/get_services.json; then
  echo "✅ GET /services passed"
else
  echo "❌ FAILED: GET /services response incorrect."
  cat /tmp/get_services.json
  exit 1
fi

# 5. POST /incidents
echo "Testing POST /incidents"
HTTP_STATUS=$(curl -s -o /tmp/post_incident.json -w "%{http_code}" -X POST "$BASE_URL/incidents" -H "Content-Type: application/json" -d '{"service_name": "test-service", "title": "Test Incident", "description": "Test description", "severity": "minor"}')
check_status 200 "$HTTP_STATUS" "POST /incidents"

if grep -q '"status":"investigating"' /tmp/post_incident.json; then
  echo "✅ POST /incidents passed"
else
  echo "❌ FAILED: POST /incidents response incorrect."
  cat /tmp/post_incident.json
  exit 1
fi

# 6. GET /incidents
echo "Testing GET /incidents"
HTTP_STATUS=$(curl -s -o /tmp/get_incidents.json -w "%{http_code}" "$BASE_URL/incidents")
check_status 200 "$HTTP_STATUS" "GET /incidents"

if grep -q '"title":"Test Incident"' /tmp/get_incidents.json; then
  echo "✅ GET /incidents passed"
else
  echo "❌ FAILED: GET /incidents response incorrect."
  cat /tmp/get_incidents.json
  exit 1
fi

echo "🎉 All integration tests passed!"
