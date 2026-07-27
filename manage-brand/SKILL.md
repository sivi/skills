---
name: manage-brand
description: Use when someone asks to list brands, update brand details, switch active brand, archive a brand, or manage existing brand profiles. Also use when the user mentions 'list my brands,' 'show brands,' 'update brand,' 'edit brand details,' 'change brand colors,' 'switch brand,' 'archive brand,' 'delete brand,' 'rebrand,' 'refresh brand,' or 'which brands do I have.' Lists, updates, or archives brand personas in Sivi and syncs the local brands/ folder. For initial brand setup from a website URL, see brand-context. For uploading brand assets, see brand-assets.
argument-hint: [action: list, update, switch, or archive — and brand name]
---

## What This Skill Does

Manages existing brand profiles:
- **list** — shows all brands in the local `brands/` folder
- **update** — modifies brand details (colors, fonts, persona) and syncs to Sivi
- **switch** — changes the active brand for subsequent design operations
- **archive** — archives a brand in Sivi and marks it as inactive locally


## ⚠️ Cross-Platform Compatibility — MANDATORY

- **NEVER use `head -n -1`** or `jq`. Use `python3` for JSON parsing.
- **ALWAYS use `curl -o <file> -w '%{http_code}'`** to separate HTTP status from response body.
- **Temp files**: Use `/tmp/`.


## Steps

### 1. Parse arguments

- `action` — `list`, `update`, `switch`, or `archive` (required).
- `brandName` — target brand name (required for update/switch/archive).

If `action` is missing, ask: "What would you like to do? (list brands, update a brand, switch active brand, or archive a brand)"

### 2. Action: List brands

#### Step A — List local brands

Scan `brands/` directory and read each `brand.md`:

```bash
#!/bin/bash
set -e

BRANDS_DIR="brands"
if [ ! -d "$BRANDS_DIR" ]; then
  echo "No brands directory found. Use brand-context to set up a brand first."
  exit 0
fi

echo "LOCAL BRANDS:"
for BRAND_DIR in "$BRANDS_DIR"/*/; do
  if [ -f "$BRAND_DIR/brand.md" ]; then
    BRAND_NAME=$(grep '^**Name:**' "$BRAND_DIR/brand.md" | head -1 | sed 's/.*:\*\* *//')
    BRAND_ID=$(grep 'Sivi Brand ID:' "$BRAND_DIR/brand.md" | head -1 | sed 's/.*: *//')
    CAMPAIGN_COUNT=$(ls "$BRAND_DIR/campaigns/"*.html 2>/dev/null | wc -l | tr -d ' ')
    SLUG=$(basename "$BRAND_DIR")
    echo "- $BRAND_NAME (slug: $SLUG, brandId: $BRAND_ID, campaigns: $CAMPAIGN_COUNT)"
  fi
done
```

### 3. Action: Update brand

1. Read the existing `brands/<slug>/brand.md` to show current details.
2. Ask the user what to update: colors, fonts, persona (emotions, industry, audience, designTags), description, or URL.
3. Call `update-brand` API with the changes.

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_ID="<BRAND_ID>"

PAYLOAD=$(python3 << 'PYEOF'
import json
data = {
    "bId": "BRAND_ID_PLACEHOLDER",
    "brandName": "UPDATED_NAME",
    "brandDescription": "UPDATED_DESCRIPTION",
    "brandColors": ["#NEW_COLOR_1", "#NEW_COLOR_2"],
    "brandFonts": [],
    "brandPersona": {
        "emotions": ["UPDATED_EMOTION"],
        "industry": "UPDATED_INDUSTRY",
        "audience": ["UPDATED_AUDIENCE"],
        "designTags": ["UPDATED_TAG_1", "UPDATED_TAG_2"]
    }
}
print(json.dumps(data))
PYEOF
)

HTTP_CODE=$(curl -s -o /tmp/sivi_update_brand_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/brand/update" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_update_brand_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

echo "BRAND_UPDATED"
```

4. Update the local `brands/<slug>/brand.md` with the new values.

### 4. Action: Switch active brand

1. List all brands (from Step 2).
2. Ask the user which brand to make active.
3. Call `set-default-brand` to pin it in Sivi.

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_ID="<BRAND_ID_TO_SWITCH_TO>"

PAYLOAD=$(python3 -c "import json; print(json.dumps({'bId': '$BRAND_ID'}))")

HTTP_CODE=$(curl -s -o /tmp/sivi_switch_brand_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/brand/set-default" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_switch_brand_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

echo "ACTIVE BRAND SWITCHED"
```

4. **Update `**Default Brand:**` field in all local `brand.md` files** — set the switched brand to `**Default Brand:** true` and all others to `**Default Brand:** false`.

5. Inform the user: "Active brand switched to **<name>**. All subsequent design skills will use this brand."

### 5. Action: Archive brand

1. Confirm with the user: "Are you sure you want to archive **<name>**? This will deactivate it in Sivi. The local brand folder will be preserved."

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_ID="<BRAND_ID_TO_ARCHIVE>"

PAYLOAD=$(python3 -c "import json; print(json.dumps({'bId': '$BRAND_ID'}))")

HTTP_CODE=$(curl -s -o /tmp/sivi_archive_brand_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/brand/archive" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_archive_brand_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

echo "BRAND_ARCHIVED"
```

2. Update the local `brands/<slug>/brand.md` to add: `**Status:** Archived (<date>)`
3. Inform the user: "Brand **<name>** archived in Sivi. Local folder preserved at `brands/<slug>/`."

### 6. Handle errors

- On 401: "Your SIVI_API_KEY is missing or invalid."
- On 422: "Invalid input: <error>. Check the brand ID and parameters."
- On 500: "Sivi server errored. Please retry."

## Notes

- Updating a brand does NOT affect previously generated designs — only future ones.
- Archiving a brand in Sivi does not delete the local folder — it's preserved for reference.
- When switching brands, all subsequent skill invocations will use the new active brand.
- The local `brands/_index.md` should be updated after any brand change (add/update/archive).
