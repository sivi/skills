#!/bin/bash
# submit-and-poll-content.sh — Submit via designs-from-content + poll + download
# Used by: generate-design (default) and all composites
#
# This is the CANONICAL single-design template for copy-first generation.
# Use this when the user has approved copy (generated or provided directly).
# The content field contains the Sivi semantic JSON object.
#
# For direct generation without copy, use submit-and-poll-prompt.sh instead.

set -e
source <SKILL_REPO>/.env

# ============================================================================
# STEP A: Submit via designs-from-content (copy-first, pixel-faithful text)
# ============================================================================
# Build payload using python3 for safe JSON escaping
#
# ⚠️ IMPORTANT: This is a Python heredoc, NOT JSON.
#   - Use Python `None` (not JSON `null`) for null values — `null` will raise NameError.
#   - Use Python `True`/`False` (not JSON `true`/`false`) for booleans.
#   - json.dumps() converts None→null, True→true, False→false in the output.
#
#   ✅ Correct:  "imagePreference": {"crop": None, "removeBg": None}
#   ❌ Wrong:    "imagePreference": {"crop": null, "removeBg": null}  → NameError!
#
PAYLOAD=$(python3 << 'PYEOF'
import json
data = {
    "name": "DESIGN_NAME_PLACEHOLDER",
    "type": "custom",
    "subtype": "custom",
    "dimension": {"width": 800, "height": 800},
    "content": {
        "title": "TITLE_PLACEHOLDER",
        "text": "TEXT_PLACEHOLDER",
        "offer": "OFFER_PLACEHOLDER"
    },
    # Optional: free-form composition/layout/mood guidance from the user's prompt.
    # Include only when the prompt describes positioning, arrangement, element counts,
    # alignment, spacing, or mood. Omit entirely otherwise (do not send an empty string).
    # "designInstructions": "three speaker portraits aligned horizontally across the center; event details in the lower-right",
    "numOfVariants": 1,
    "outputFormat": ["jpg"],
    "language": "english",
    # assets.inspiration[] holds reference images that guide overall look/layout/style.
    # Sivi uses them as visual references, NOT as content placed in the design.
    # Example: {"url": "https://media.hellosivi.com/system/inspiration/7071aea01c5c4b36851ea2c013d684ac.jpg"}
    "assets": {"images": [], "logos": [], "icons": [], "inspiration": []},
    "siviAssets": [],
    "settings": {
        "mode": "brand",
        "currentbId": "<BRAND_ID>",
        "colors": [],
        "theme": [],
        "frameStyle": [],
        "backdropStyle": [],
        "focus": [],
        "imageStyle": [],
        "fontGroups": [],
        "designModel": "sivi-gen-3h-preview"
    }
}
print(json.dumps(data))
PYEOF
)

HTTP_CODE=$(curl -s -o /tmp/sivi_submit_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/designs-from-content" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_submit_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

DESIGN_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['designId'])" <<< "$BODY")
REQUEST_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['requestId'])" <<< "$BODY")

echo "DESIGN_ID=$DESIGN_ID"
echo "REQUEST_ID=$REQUEST_ID"

# ============================================================================
# STEP B: Poll for completion and download variants
# Uses get-request-status as the sole polling API.
# Status values: "pending", "processing", "completed", "failed", "suspended".
# Variants are in response.body.result.variations[] when status is "completed".
# ============================================================================

PREFIX="<prompt-slug>"
REQUEST_ID="<REQUEST_ID_FROM_STEP_A>"
MAX_ATTEMPTS=20
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Poll attempt $ATTEMPT/$MAX_ATTEMPTS..."

  # URL-encode the queryParams JSON for the GET request
  QUERY_PARAMS=$(python3 -c "
import json, urllib.parse
params = json.dumps({'requestId': '''$REQUEST_ID'''})
print(urllib.parse.quote(params, safe=''))
")

  HTTP_CODE=$(curl -s -o /tmp/sivi_poll_response.json -w '%{http_code}' \
    -X GET "https://connect.sivi.ai/api/prod/v2/general/get-request-status?queryParams=$QUERY_PARAMS" \
    -H "sivi-api-key: $SIVI_API_KEY")

  BODY=$(cat /tmp/sivi_poll_response.json)

  if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: HTTP $HTTP_CODE"
    echo "$BODY"
    exit 1
  fi

  # Parse the request status
  REQUEST_STATUS=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('body', {}).get('status', 'unknown'))
" <<< "$BODY")

  echo "Status: $REQUEST_STATUS"

  if [ "$REQUEST_STATUS" = "failed" ] || [ "$REQUEST_STATUS" = "suspended" ]; then
    REASON=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('body', {}).get('reason', 'Unknown error'))
" <<< "$BODY")
    echo "FAILED ($REQUEST_STATUS): $REASON"
    exit 1
  fi

  if [ "$REQUEST_STATUS" = "completed" ] || [ "$REQUEST_STATUS" = "complete" ]; then
    echo "Design generation complete!"

    # Extract variants and their options using python3
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
    print(f\"VARIANT_{i}_TYPE={v.get('variantType', '')}\")
    options = v.get('options', [])
    print(f\"VARIANT_{i}_OPTIONS_COUNT={len(options)}\")
    for j, o in enumerate(options, 1):
        print(f\"VARIANT_{i}_OPTION_{j}_URL={o.get('variantImageUrl', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_EDIT={o.get('variantEditLink', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_ID={o.get('variantId', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_WIDTH={o.get('variantWidth', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_HEIGHT={o.get('variantHeight', '')}\")
        print(f\"VARIANT_{i}_OPTION_{j}_TYPE={o.get('variantType', '')}\")
" <<< "$BODY" > /tmp/sivi_variants_info.txt

    cat /tmp/sivi_variants_info.txt

    VARIANT_COUNT=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
print(len(d.get('body', {}).get('result', {}).get('variations', [])))
" <<< "$BODY")

    # Download each variant image
    OUTPUT_DIR="<OUTPUT_DIR>"
    mkdir -p "$OUTPUT_DIR"
    IDX=1
    while [ $IDX -le $VARIANT_COUNT ]; do
      IMG_URL=$(grep "VARIANT_${IDX}_URL=" /tmp/sivi_variants_info.txt | cut -d'=' -f2-)
      if [ -n "$IMG_URL" ]; then
        if [[ "$IMG_URL" != https://* ]]; then
          echo "SKIP: VARIANT_${IDX} URL is not https, skipping for security."
        else
          URL_ID=$(basename "$IMG_URL" | sed 's/\.[^.]*$//' | tr -cd '[:alnum:]-_')
          FILE_NAME="${PREFIX}_${URL_ID}_v${IDX}.jpg"
          curl -sL -o "$OUTPUT_DIR/${FILE_NAME}" "$IMG_URL"
          echo "VARIANT_${IDX}_IMG=$OUTPUT_DIR/${FILE_NAME}"
        fi
      fi
      # Download variant options
      OPTS_COUNT=$(grep "VARIANT_${IDX}_OPTIONS_COUNT=" /tmp/sivi_variants_info.txt | cut -d'=' -f2-)
      OPTS_COUNT=${OPTS_COUNT:-0}
      OPT_IDX=1
      while [ $OPT_IDX -le $OPTS_COUNT ]; do
        OPT_URL=$(grep "VARIANT_${IDX}_OPTION_${OPT_IDX}_URL=" /tmp/sivi_variants_info.txt | cut -d'=' -f2-)
        if [ -n "$OPT_URL" ]; then
          if [[ "$OPT_URL" != https://* ]]; then
            echo "SKIP: VARIANT_${IDX}_OPTION_${OPT_IDX} URL is not https, skipping for security."
          else
            OPT_URL_ID=$(basename "$OPT_URL" | sed 's/\.[^.]*$//' | tr -cd '[:alnum:]-_')
            OPT_FILE_NAME="${PREFIX}_${OPT_URL_ID}_v${IDX}_opt${OPT_IDX}.jpg"
            curl -sL -o "$OUTPUT_DIR/${OPT_FILE_NAME}" "$OPT_URL"
            echo "VARIANT_${IDX}_OPTION_${OPT_IDX}_IMG=$OUTPUT_DIR/${OPT_FILE_NAME}"
          fi
        fi
        OPT_IDX=$((OPT_IDX + 1))
      done

      IDX=$((IDX + 1))
    done

    exit 0
  fi

  sleep 15
done

echo "TIMEOUT"
exit 1
