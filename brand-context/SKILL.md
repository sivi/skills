---
name: brand-context
description: Use when someone asks to set up a brand, extract brand identity, create a brand profile, or onboard a new brand for design generation. Also use when the user mentions 'brand setup,' 'brand context,' 'extract brand,' 'brand identity,' 'brand profile,' 'onboard brand,' 'add a brand,' 'set up my brand,' 'brand colors,' 'brand fonts,' 'brand persona,' or 'configure brand.' Supports two creation paths: (A) extract from a website URL, or (B) create from brand name + description. Checks local brands folder for existing brands before creating. Registers the brand with Sivi, saves to brands/<slug>/brand.md. All other Sivi skills use this brand context automatically. For managing existing brands (list, update, archive), see manage-brand. For uploading brand assets (logos, images), see brand-assets.
argument-hint: [website URL OR brand name + description]
---

## What This Skill Does

Creates a brand profile and registers it with Sivi. Two creation paths:

- **Path A — URL extraction** (preferred when URL available): Extracts brand identity (name, description, colors, fonts, logo, persona) from a website URL using the Sivi `extract` API. User reviews and corrects the extracted details.
- **Path B — Name + description** (when no URL): User provides a brand name and short description. The agent infers a minimal persona (industry, emotions, audience, design tags) from the description.

Before creating, checks the local `brands/` folder for an existing brand with the same name. If found, offers to update it instead of creating a duplicate.

After creation, registers the brand with Sivi via `create-brand` and pins it as default via `set-default-brand`. Saves all details to `brands/<slug>/brand.md` and downloads the logo into `brands/<slug>/assets/`.

This is the **foundation skill** — once a brand is set up, every other Sivi skill (generate-design, create-campaign, create-a-plus-content, etc.) automatically uses the brand identity for on-brand design generation via `settings.mode: "brand"`.

Supports multiple brands — an agency can set up unlimited brands, each in its own folder under `brands/`.


## ⚠️ Cross-Platform Compatibility — MANDATORY

**This skill runs on macOS, Linux, or Windows (Git Bash / WSL).** Follow these rules in ALL bash scripts:

- **NEVER use `head -n -1`** — macOS BSD `head` does not support negative line counts.
- **NEVER use `jq`** — use `python3` for all JSON parsing.
- **ALWAYS use `curl -o <file> -w '%{http_code}'`** to separate HTTP status from response body.
- **Temp files**: Use `/tmp/` (maps to valid temp dir on all platforms).


## Steps

### 1. Parse arguments

Collect the brand name and optional URL from the user:

- If the user provides a website URL (starts with `https://` or `http://`), record it. Also accept an optional `brandName` override.
- If the user provides a brand name but no URL, record the name.
- If neither a URL nor a brand name is provided, ask: "What brand would you like to set up? Provide the brand name and website URL (if available)."

**Do NOT choose a creation path or ask for a description yet.** Path selection happens only after step 2 confirms no existing brand matches locally.

### 2. Check for existing local brands

Before choosing a creation path, check the local `brands/` folder to avoid duplicates.

Scan for a `brands/` directory in the current workspace:
- If `brands/` exists, list existing brand folders.
- If the user's brand name matches an existing folder (case-insensitive), ask: "A brand profile for <name> already exists locally. Do you want to update it or create a new one?"
- If updating, read the existing `brands/<slug>/brand.md` and proceed to step 5 (review/correct).
- If no local match → **choose the creation path** based on the user's input from step 1:
  - URL was provided → proceed to Path A (step 3).
  - No URL, only brand name → proceed to Path B (step 4b). Ask for a short description if not yet provided: "Can you give a one-line description of <name>? (e.g., what they do, their industry)"

### 3. Path A — Extract brand from URL (steps 3–4)

> **Skip to step 4b if using Path B (name + description, no URL).**

### 3a. Step A — Extract brand from URL (Bash tool call #1)

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_URL="<BRAND_URL>"

PAYLOAD=$(python3 -c "
import json
print(json.dumps({'brandUrl': '$BRAND_URL'}))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_extract_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/brand/extract" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_extract_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

REQUEST_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['requestId'])" <<< "$BODY")

echo "REQUEST_ID=$REQUEST_ID"
```

### 4. Step B — Poll for extraction result (Bash tool call #2)

The extract API is asynchronous. Poll using `get-request-status` until the status is `completed`.

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

REQUEST_ID="<REQUEST_ID_FROM_STEP_A>"
MAX_ATTEMPTS=20
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Poll attempt $ATTEMPT/$MAX_ATTEMPTS..."

  QUERY_PARAMS=$(python3 -c "
import json, urllib.parse
params = json.dumps({'requestId': '$REQUEST_ID'})
print(urllib.parse.quote(params, safe=''))
")

  HTTP_CODE=$(curl -s -o /tmp/sivi_status_response.json -w '%{http_code}' \
    -X GET "https://connect.sivi.ai/api/prod/v2/general/get-request-status?queryParams=$QUERY_PARAMS" \
    -H "sivi-api-key: $SIVI_API_KEY")

  BODY=$(cat /tmp/sivi_status_response.json)

  if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: HTTP $HTTP_CODE"
    echo "$BODY"
    exit 1
  fi

  STATUS=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['status'])" <<< "$BODY")

  if [ "$STATUS" = "completed" ]; then
    echo "EXTRACTION COMPLETE"
    # Extract brand details
    python3 -c "
import json, sys
d = json.load(sys.stdin)
result = d['body']['result']
bd = result['brandDetails']
print(f\"BRAND_NAME={bd.get('brandName', '')}\")
print(f\"BRAND_DESCRIPTION={bd.get('brandDescription', '')}\")
print(f\"BRAND_URL={bd.get('brandUrl', '')}\")
print(f\"BRAND_LOGO={bd.get('brandLogo', '')}\")
print(f\"BRAND_COLORS={','.join(bd.get('brandColors', []))}\")
print(f\"BRAND_FONTS={','.join(bd.get('brandFonts', []))}\")
persona = bd.get('brandPersona', {})
print(f\"PERSONA_EMOTIONS={','.join(persona.get('emotions', []))}\")
print(f\"PERSONA_INDUSTRY={persona.get('industry', '')}\")
print(f\"PERSONA_AUDIENCE={','.join(persona.get('audience', []))}\")
print(f\"PERSONA_DESIGN_TAGS={','.join(persona.get('designTags', []))}\")
" <<< "$BODY"
    exit 0
  elif [ "$STATUS" = "failed" ] || [ "$STATUS" = "suspended" ]; then
    echo "EXTRACTION FAILED ($STATUS)"
    echo "$BODY"
    exit 1
  fi

  sleep 10
done

echo "TIMEOUT"
exit 1
```

### 4b. Path B — Infer persona from name + description (no API call)

> **Used only when no URL is provided.** The agent infers brand persona fields from the brand name and description. No extraction API call needed.

Based on the brand name and description, the agent determines:

- **brandName** — from user input
- **brandDescription** — from user input
- **brandUrl** — empty string (user can add later)
- **brandLogo** — empty string (user can add later via brand-assets)
- **brandColors** — agent picks 2–3 colors appropriate for the industry (e.g., a tech brand might get `["#2563EB", "#1E40AF", "#3B82F6"]`, a children's brand might get `["#F59E0B", "#EF4444", "#10B981"]`)
- **brandFonts** — empty array (Sivi auto-selects)
- **brandPersona.emotions** — agent infers 1–2 emotions from the description (e.g., a playful brand → `["happy", "excited"]`, a luxury brand → `["sophisticated", "calm"]`)
- **brandPersona.industry** — agent infers from the description (e.g., "technology", "fashion", "food", "education", "health")
- **brandPersona.audience** — agent infers 1–2 audience segments
- **brandPersona.designTags** — agent infers 2–3 design tags (e.g., `["minimal", "modern", "bold"]`)

Present the inferred values to the user for review:

> "Here's what I've inferred for **<name>**:
> - Description: <description>
> - Colors: <colors>
> - Persona: <emotions>, <industry>, <audience>, <design tags>
>
> Does this look right? You can adjust any of these before I create the brand."

After user approval (or corrections), proceed to step 5 with the inferred/approved values.

### 5. Step C — Create brand in Sivi (Bash tool call #3)

Only `brandName` and `brandDescription` are required — the API auto-fills `brandPersona` with sensible defaults if omitted. Include optional fields (`brandUrl`, `brandLogo`, `brandColors`, `brandFonts`, `brandPersona`) only when the user or extraction provided actual values for them.

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

# ✅ Replace placeholders with actual values from step 3/4b.
# ✅ Only brandName and brandDescription are required.
# ✅ Remove optional fields that have no value — do NOT send empty strings or null.
PAYLOAD=$(python3 << 'PYEOF'
import json
data = {
    "brandName": "BRAND_NAME_PLACEHOLDER",
    "brandDescription": "BRAND_DESCRIPTION_PLACEHOLDER"
}
# --- Optional fields (uncomment and fill if values are available) ---
# data["brandUrl"] = "https://example.com"
# data["brandLogo"] = "https://example.com/logo.png"
# data["brandColors"] = ["#5662EC", "#EF9AB2"]
# data["brandFonts"] = []
# data["brandPersona"] = {
#     "emotions": ["happy"],
#     "industry": "fashion",
#     "audience": ["young adults"],
#     "designTags": ["minimal", "modern"]
# }
print(json.dumps(data))
PYEOF
)

HTTP_CODE=$(curl -s -o /tmp/sivi_create_brand_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/brand/create" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_create_brand_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

BRAND_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); brands=d['body']['brandDetails']; print(brands[0]['bId'])" <<< "$BODY")
echo "BRAND_ID=$BRAND_ID"
```

### 6. Step D — Set default brand status

**Check if any existing local brand has `**Default Brand:** true`.**

- If no existing brand has `**Default Brand:** true` → call the Sivi API to set this brand as default, and set the new brand's `**Default Brand:** true` in step 8:

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_ID="<BRAND_ID_FROM_STEP_C>"

PAYLOAD=$(python3 -c "import json; print(json.dumps({'bId': '$BRAND_ID'}))")

HTTP_CODE=$(curl -s -o /tmp/sivi_set_default_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/brand/set-default" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_set_default_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

echo "DEFAULT BRAND SET"
```

- If an existing brand already has `**Default Brand:** true` → **skip the API call**. Set the new brand's `**Default Brand:** false` in step 8. Do NOT change the existing default brand.

There can be only one default brand. The new brand becomes default only when no other default exists.

### 7. Step E — Download logo and create brand folder (Bash tool call #5)

```bash
#!/bin/bash
set -e¬

BRAND_SLUG="<brand-slug>"
BRAND_LOGO_URL="<BRAND_LOGO_URL>"
BRANDS_DIR="brands"
BRAND_DIR="$BRANDS_DIR/$BRAND_SLUG"
ASSETS_DIR="$BRAND_DIR/assets"
CAMPAIGNS_DIR="$BRAND_DIR/campaigns"

mkdir -p "$ASSETS_DIR"
mkdir -p "$CAMPAIGNS_DIR"

if [ -n "$BRAND_LOGO_URL" ] && [[ "$BRAND_LOGO_URL" == https://* ]]; then
  LOGO_EXT=$(basename "$BRAND_LOGO_URL" | sed 's/.*\.//' | tr -cd '[:alnum:]')
  if [ -z "$LOGO_EXT" ]; then
    LOGO_EXT="png"
  fi
  curl -sL -o "$ASSETS_DIR/logo.$LOGO_EXT" "$BRAND_LOGO_URL"
  echo "LOGO_SAVED=$ASSETS_DIR/logo.$LOGO_EXT"
else
  echo "LOGO_SAVED=none"
fi

echo "BRAND_DIR=$BRAND_DIR"
```

### 8. Write `brand.md`

Create the file `brands/<slug>/brand.md` with the following structure. Replace all placeholders with actual values from the extraction.

Auto-choose the Settings fields based on the brand persona (emotions, industry, design tags). Each field is an array — include ALL values that match the brand's personality, not just one:

- **theme**: `light`, `dark`, `colorful` — include all that fit (e.g., `["light", "colorful"]` for a clean but vibrant brand)
- **frameStyle**: `plain`, `box`, `bar-accent` — include all that fit (e.g., `["plain", "bar-accent"]` for a minimal but bold brand)
- **backdropStyle**: `minimalist`, `imagery`, `artistic` — include all that fit (e.g., `["minimalist", "artistic"]` for a clean creative brand)
- **focus**: `text`, `image`, `neutral` — include all that fit (e.g., `["text", "image"]` for a content-rich visual brand)
- **imageStyle**: `cover`, `cover-with-linear-gradient`, `cover-with-overlay`, `container`, `section`, `section-with-container`, `mask`, `cutout`, `cutout-with-vectors`, `content-free-form` — include all that fit (e.g., `["cover", "cutout", "content-free-form"]` for a versatile creative brand)

```markdown
# <Brand Name>

*Created: <date> | Sivi Brand ID: <brandId>*

## Brand Identity

**Name:** <brandName>
**Description:** <brandDescription>
**URL:** <brandUrl>
**Logo:** brands/<slug>/assets/logo.png
**Sivi Brand ID:** <brandId>
**Default Brand:** <true if no existing default, false otherwise>

## Colors

<list each color as a hex swatch>
- `#5662EC`
- `#EF9AB2`

## Fonts

<list fonts or "No custom fonts — Sivi will auto-select">

## Brand Persona

- **Emotions:** happy, excited
- **Industry:** technology
- **Audience:** tech enthusiasts
- **Design Tags:** minimal, innovative

## Design Preferences

- **Mode:** brand (uses Sivi brand persona for all design generation)
- **Language:** english

## Settings

- **theme:** <auto-chosen array>
- **frameStyle:** <auto-chosen array>
- **backdropStyle:** <auto-chosen array>
- **focus:** <auto-chosen array>
- **imageStyle:** <auto-chosen array>

## Campaigns

Campaign results are saved in `brands/<slug>/campaigns/`.
```

### 9. Confirm to user

Tell the user:
> "Brand **<name>** is set up and saved to `brands/<slug>/brand.md`. All Sivi design skills will now use this brand's identity automatically. You can add more brands anytime by running brand-context again."

## Handle errors

- On 401: "Your SIVI_API_KEY is missing or invalid. Check your .env file."
- On 402: "You have insufficient Sivi credits. Visit sivi.ai to add credits."
- On 422: "Invalid input: <error message>. Please check the URL and try again."
- On 500: "Sivi server errored. Please retry in a moment."
- On extraction timeout: "Brand extraction is taking longer than expected. Please try again or provide brand details manually."

## Notes

- The brand slug is derived from the brand name: lowercase, spaces → hyphens, alphanumeric only (e.g., "Acme Co" → "acme-co").
- If `brandFonts` is empty from extraction, that's normal — Sivi will auto-select fonts based on industry and persona.
- The `brandId` (bId) returned by create-brand is critical — it's what other skills use for `settings.mode: "brand"` + `currentbId`.
- If the brand already exists in Sivi (same name), create-brand may return the existing brand. Check the response and inform the user.
- Logo download is best-effort — if the logo URL is missing or fails, skip it and inform the user. They can add it later via brand-assets.
- Never hardcode the API key — always use `$SIVI_API_KEY` from `.env`.
- **Path B** (name + description) is useful when the brand doesn't have a website, or the user is in a hurry. The inferred persona can always be refined later via manage-brand.
- **This skill is only invoked when the user explicitly asks to create/set up a brand.** Other skills (generate-design, create-campaign, etc.) never trigger brand creation as a fallback — they fall back to the default brand instead.
