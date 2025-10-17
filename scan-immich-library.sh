#!/bin/bash
# Trigger Immich External Library Scan
# Usage: ./scan-immich-library.sh

source ~/homelab/.env

LIBRARY_ID=63ea736d-665b-44a5-82ba-7e26aade8d9e
API_KEY=${IMMICH_API_KEY}

echo Triggering Immich external library scan...
curl -X POST http://localhost:2283/api/libraries/${LIBRARY_ID}/scan   -H x-api-key: ${API_KEY}   -H Content-Type: application/json   --data-raw '{"refreshModifiedFiles": true}'   -s -o /dev/null -w HTTP Status: %{http_code}n

echo Scan triggered. Check Immich UI for progress.
