#!/bin/bash
# get-brands.sh — Fetch all brands from Sivi workspace with pagination.
# Outputs brand details in KEY=VALUE format, one brand per block.
#
# Usage:
#   source <SKILL_REPO>/.env && bash _shared/get-brands.sh
#   source <SKILL_REPO>/.env && bash _shared/get-brands.sh --name "DOMS"
#   source <SKILL_REPO>/.env && bash _shared/get-brands.sh --default
#
# Output format (one block per brand):
#   BRAND_BID=b_xxx
#   BRAND_NAME=DOMS
#   BRAND_DESCRIPTION=...
#   BRAND_URL=...
#   BRAND_COLORS=#5662EC,#EF9AB2
#   BRAND_LOGOS=https://...
#   BRAND_PERSONA_EMOTIONS=happy,excited
#   BRAND_PERSONA_INDUSTRY=technology
#   BRAND_PERSONA_AUDIENCE=tech enthusiasts
#   BRAND_PERSONA_DESIGN_TAGS=minimal,innovative
#   ---
#
# Flags:
#   --name "<name>"  — filter by case-insensitive substring match
#   --default        — return only the first brand (the workspace default)
#
# Exit code 0 with output = brands found. Exit code 0 with no output = no brands found.

set -e
source "$(dirname "$0")/../.env"

SEARCH_NAME=""
DEFAULT_ONLY=0
if [ "$1" = "--name" ] && [ -n "$2" ]; then
  SEARCH_NAME="$2"
elif [ "$1" = "--default" ]; then
  DEFAULT_ONLY=1
fi

while true; do
  PAYLOAD=$(python3 -c "
import json
data = {'limit': 50}
print(json.dumps(data))
")

  HTTP_CODE=$(curl -s -o /tmp/sivi_get_brands.json -w '%{http_code}' \
    -X POST "https://connect.sivi.ai/api/prod/v2/general/brand/get" \
    -H "Content-Type: application/json" \
    -H "sivi-api-key: $SIVI_API_KEY" \
    -d "$PAYLOAD")

  BODY=$(cat /tmp/sivi_get_brands.json)

  if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: HTTP $HTTP_CODE" >&2
    echo "$BODY" >&2
    exit 1
  fi

  # Parse brands and optionally filter by name or return only default
  python3 -c "
import json, sys

search = '$SEARCH_NAME'.lower().strip()
default_only = $DEFAULT_ONLY
d = json.load(sys.stdin)
brands = d.get('body', {}).get('brands', [])

for b in brands:
    name = b.get('brandName', '')
    if search and search not in name.lower():
        continue
    colors = [c.get('color', '') for c in b.get('brandColors', [])]
    logos = b.get('brandLogos', [])
    persona = b.get('brandPersona', {})
    print(f\"BRAND_BID={b.get('bId', '')}\")
    print(f\"BRAND_NAME={name}\")
    print(f\"BRAND_DESCRIPTION={b.get('brandDescription', '')}\")
    print(f\"BRAND_URL={b.get('brandUrl', '')}\")
    print(f\"BRAND_COLORS={','.join(colors)}\")
    print(f\"BRAND_LOGOS={','.join(logos)}\")
    print(f\"BRAND_PERSONA_EMOTIONS={','.join(persona.get('emotions', []))}\")
    print(f\"BRAND_PERSONA_INDUSTRY={persona.get('industry', '')}\")
    print(f\"BRAND_PERSONA_AUDIENCE={','.join(persona.get('audience', []))}\")
    print(f\"BRAND_PERSONA_DESIGN_TAGS={','.join(persona.get('designTags', []))}\")
    print('---')
    if default_only:
        break
" <<< "$BODY"

  if [ "$DEFAULT_ONLY" = "1" ]; then
    break
  fi

  # Check for next page
  NEXT_CURSOR=$(python3 -c "
import json, sys
d = json.load(sys.stdin)
c = d.get('body', {}).get('cursor')
print(c if c else 'null')
" <<< "$BODY")

  if [ "$NEXT_CURSOR" = "null" ]; then
    break
  fi

  CURSOR="\"$NEXT_CURSOR\""
done

exit 0
