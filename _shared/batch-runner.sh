#!/bin/bash
# batch-runner.sh — Submit N design requests in parallel, poll all in one loop
# Used by: create-campaign, social-calendar, seasonal-promo, product-launch-kit,
#          resize-ad-set, localize-campaign, ab-test-creatives, create-a-plus-content
#
# This is the CANONICAL batch execution engine. Composite skills reference this
# file at runtime — the agent reads it and follows the pattern.
# Default payload format: designs-from-content (name + content, not prompt).
# Alternative: designs-from-prompt (prompt instead of name + content) — for direct generation without copy review.

set -e
source <SKILL_REPO>/.env

# ============================================================================
# STEP A: Submit multiple design requests
# ============================================================================
# Each request is defined by a JSON payload. Build them as separate files.
# The calling skill writes payloads to /tmp/sivi_batch_payload_<N>.json
# Each payload must include "designModel" inside the "settings" object (e.g. "sivi-gen-3h-preview").

NUM_REQUESTS=<NUM_REQUESTS>
OUTPUT_DIR="<OUTPUT_DIR>"
mkdir -p "$OUTPUT_DIR"

# Write design IDs + request IDs to a file (one per line) for zsh-safe iteration
# zsh does NOT word-split unquoted variables in for loops
> /tmp/sivi_batch_design_ids.txt

for i in $(seq 1 $NUM_REQUESTS); do
  PAYLOAD=$(cat /tmp/sivi_batch_payload_${i}.json)

  HTTP_CODE=$(curl -s -o /tmp/sivi_batch_submit_${i}.json -w '%{http_code}' \
    -X POST "https://connect.sivi.ai/api/prod/v2/general/designs-from-content" \
    -H "Content-Type: application/json" \
    -H "sivi-api-key: $SIVI_API_KEY" \
    -d "$PAYLOAD")

  BODY=$(cat /tmp/sivi_batch_submit_${i}.json)

  if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR on request $i: HTTP $HTTP_CODE"
    echo "$BODY"
    exit 1
  fi

  DESIGN_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['designId'])" <<< "$BODY")
  REQUEST_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body'].get('requestId',''))" <<< "$BODY")
  echo "REQUEST_${i}_DESIGN_ID=$DESIGN_ID REQUEST_ID=$REQUEST_ID"
  echo "$DESIGN_ID $REQUEST_ID" >> /tmp/sivi_batch_design_ids.txt
done

# ============================================================================
# STEP B: Poll all requests in a single loop using get-request-status
# Uses get-request-status as the sole polling API.
# Status values: "pending", "processing", "completed", "failed", "suspended".
# Variants are in response.body.result.variations[] when status is "completed".
# ============================================================================

MAX_ATTEMPTS=30
ATTEMPT=0
COMPLETED_IDS=""
FAILED_IDS=""

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Batch poll attempt $ATTEMPT/$MAX_ATTEMPTS..."

  ALL_DONE=true

  while IFS=' ' read -r DESIGN_ID REQUEST_ID; do
    # Skip already completed or failed
    if echo "$COMPLETED_IDS" | grep -q "$DESIGN_ID" || echo "$FAILED_IDS" | grep -q "$DESIGN_ID"; then
      continue
    fi

    # URL-encode the queryParams JSON for the GET request
    QUERY_PARAMS=$(python3 -c "
import json, urllib.parse
params = json.dumps({'requestId': '''$REQUEST_ID'''})
print(urllib.parse.quote(params, safe=''))
")

    HTTP_CODE=$(curl -s -o /tmp/sivi_batch_poll_${DESIGN_ID}.json -w '%{http_code}' \
      -X GET "https://connect.sivi.ai/api/prod/v2/general/get-request-status?queryParams=$QUERY_PARAMS" \
      -H "sivi-api-key: $SIVI_API_KEY")

    BODY=$(cat /tmp/sivi_batch_poll_${DESIGN_ID}.json)

    if [ "$HTTP_CODE" != "200" ]; then
      echo "ERROR polling $DESIGN_ID: HTTP $HTTP_CODE"
      echo "$BODY"
      continue
    fi

    # Parse the request status
    REQ_STATUS=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('body', {}).get('status', 'unknown'))
" <<< "$BODY")

    if [ "$REQ_STATUS" = "failed" ] || [ "$REQ_STATUS" = "suspended" ]; then
      FAIL_REASON=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('body', {}).get('reason', 'Unknown'))
" <<< "$BODY")
      echo "DESIGN $DESIGN_ID: FAILED ($REQ_STATUS) — $FAIL_REASON"
      FAILED_IDS="$FAILED_IDS $DESIGN_ID"
      continue
    fi

    if [ "$REQ_STATUS" = "completed" ] || [ "$REQ_STATUS" = "complete" ]; then
      echo "DESIGN $DESIGN_ID: Complete!"
      COMPLETED_IDS="$COMPLETED_IDS $DESIGN_ID"

      # Extract and download variants from result.variations
      python3 -c "
import json, sys
d = json.load(sys.stdin)
variations = d.get('body', {}).get('result', {}).get('variations', [])
for i, v in enumerate(variations, 1):
    print(f\"VARIANT_{i}_URL={v.get('variantImageUrl', '')}\")
    print(f\"VARIANT_{i}_EDIT={v.get('variantEditLink', '')}\")
    print(f\"VARIANT_{i}_ID={v.get('variantId', '')}\")
    print(f\"VARIANT_{i}_WIDTH={v.get('variantWidth', '')}\")
    print(f\"VARIANT_{i}_HEIGHT={v.get('variantHeight', '')}\")
    options = v.get('options', [])
    print(f\"VARIANT_{i}_OPTIONS_COUNT={len(options)}\")
    for j, o in enumerate(options, 1):
        print(f\"VARIANT_{i}_OPTION_{j}_URL={o.get('variantImageUrl', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_EDIT={o.get('variantEditLink', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_ID={o.get('variantId', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_WIDTH={o.get('variantWidth', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_HEIGHT={o.get('variantHeight', '')}\")
" <<< "$BODY" > /tmp/sivi_batch_variants_${DESIGN_ID}.txt

      cat /tmp/sivi_batch_variants_${DESIGN_ID}.txt

      VARIANT_COUNT=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(len(d.get('body', {}).get('result', {}).get('variations', [])))
" <<< "$BODY")

      # Download each variant
      IDX=1
      while [ $IDX -le $VARIANT_COUNT ]; do
        IMG_URL=$(grep "VARIANT_${IDX}_URL=" /tmp/sivi_batch_variants_${DESIGN_ID}.txt | cut -d'=' -f2-)
        if [ -n "$IMG_URL" ]; then
          if [[ "$IMG_URL" != https://* ]]; then
            echo "SKIP: non-https URL for $DESIGN_ID variant $IDX"
          else
            URL_ID=$(basename "$IMG_URL" | sed 's/\.[^.]*$//' | tr -cd '[:alnum:]-_')
            FILE_NAME="${DESIGN_ID}_${URL_ID}_v${IDX}.jpg"
            curl -sL -o "$OUTPUT_DIR/${FILE_NAME}" "$IMG_URL"
            echo "DESIGN_${DESIGN_ID}_VARIANT_${IDX}_IMG=$OUTPUT_DIR/${FILE_NAME}"
          fi
        fi
        IDX=$((IDX + 1))
      done

      # Download variant options
      IDX=1
      while [ $IDX -le $VARIANT_COUNT ]; do
        OPTS_COUNT=$(grep "VARIANT_${IDX}_OPTIONS_COUNT=" /tmp/sivi_batch_variants_${DESIGN_ID}.txt | cut -d'=' -f2-)
        OPTS_COUNT=${OPTS_COUNT:-0}
        OPT_IDX=1
        while [ $OPT_IDX -le $OPTS_COUNT ]; do
          OPT_URL=$(grep "VARIANT_${IDX}_OPTION_${OPT_IDX}_URL=" /tmp/sivi_batch_variants_${DESIGN_ID}.txt | cut -d'=' -f2-)
          if [ -n "$OPT_URL" ]; then
            if [[ "$OPT_URL" != https://* ]]; then
              echo "SKIP: non-https URL for $DESIGN_ID variant $IDX option $OPT_IDX"
            else
              OPT_URL_ID=$(basename "$OPT_URL" | sed 's/\.[^.]*$//' | tr -cd '[:alnum:]-_')
              OPT_FILE_NAME="${DESIGN_ID}_${OPT_URL_ID}_v${IDX}_opt${OPT_IDX}.jpg"
              curl -sL -o "$OUTPUT_DIR/${OPT_FILE_NAME}" "$OPT_URL"
              echo "DESIGN_${DESIGN_ID}_VARIANT_${IDX}_OPTION_${OPT_IDX}_IMG=$OUTPUT_DIR/${OPT_FILE_NAME}"
            fi
          fi
          OPT_IDX=$((OPT_IDX + 1))
        done
        IDX=$((IDX + 1))
      done
    else
      ALL_DONE=false
    fi
  done < /tmp/sivi_batch_design_ids.txt

  if [ "$ALL_DONE" = true ] && [ -n "$COMPLETED_IDS" ]; then
    echo "ALL DESIGNS COMPLETE"
    if [ -n "$FAILED_IDS" ]; then
      echo "FAILED DESIGNS: $FAILED_IDS"
    fi
    exit 0
  fi

  sleep 15
done

echo "TIMEOUT — some designs may still be processing"
if [ -n "$FAILED_IDS" ]; then
  echo "FAILED DESIGNS: $FAILED_IDS"
fi
exit 1
