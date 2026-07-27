---
name: enhance-media
description: Use when someone asks to enhance an image, generate AI images, remove background, improve image quality, or create product shots. Also use when the user mentions 'AI image generation,' 'generate an image,' 'enhance my photo,' 'remove background,' 'improve image quality,' 'make this image better,' 'product shot enhancement,' 'generate background,' 'image enhancement,' 'AI photo,' or 'touch up my image.' Uses Sivi's generate API to create or enhance images using AI models. For uploading existing local files, see brand-assets. For generating designs from prompts, see generate-design.
argument-hint: [prompt describing the image to generate or enhance, and optional image URL]
---

## What This Skill Does

Uses Sivi's `generate` API to:
- **Generate** new images from a text prompt (e.g., "A modern minimalist logo for a coffee shop")
- **Enhance** existing images (e.g., "Make this product photo more vibrant and professional")

The API is asynchronous — it returns a `requestId` that you poll via `get-request-status` until the image is ready.


## ⚠️ Cross-Platform Compatibility — MANDATORY

- **NEVER use `head -n -1`** or `jq`. Use `python3` for JSON parsing.
- **ALWAYS use `curl -o <file> -w '%{http_code}'`** to separate HTTP status from response body.
- **Temp files**: Use `/tmp/`.


## Steps

### 1. Parse arguments

- `prompt` — description of the image to generate or enhancement instructions (required).
- `imageUrl` — existing image URL to enhance (optional; if absent, generates a new image).
- `mediaId` — Sivi media ID for an existing image (optional alternative to imageUrl).
- `width` — output image width (default: 1024)
- `height` — output image height (default: 1024)
- `model` — AI model to use (default: `z-image-turbo` for generation, `nano-banana:1k` for enhancement)
- `negativePrompt` — what to avoid in the image (optional)

If `prompt` is missing, ask: "What image would you like to generate or how would you like to enhance your image?"

### 2. Resolve brand

Follow the **Active Brand Resolution** flow in `../setup-sivi/_shared/conventions.md`. A brand **must** be resolved — `bId` is mandatory for the generate API.

### 3. Step A — Submit generate request (Bash tool call #1)

```bash
#!/bin/bash
set -e
# --- load the Sivi API key from the setup-sivi skill (see setup-sivi/SKILL.md) ---
for c in ".agents/skills/setup-sivi" ".claude/skills/setup-sivi" \
         "$HOME/.agents/skills/setup-sivi" "$HOME/.claude/skills/setup-sivi"; do
  [ -f "$c/.env" ] && { SIVI_HOME="$(cd "$c" && pwd)"; break; }
done
[ -z "$SIVI_HOME" ] && { echo "Sivi not set up — run the setup-sivi skill first." >&2; exit 1; }
source "$SIVI_HOME/.env"

BRAND_ID="<BRAND_ID>"

PAYLOAD=$(python3 -c "
import json
data = {
    'prompt': '''PROMPT_PLACEHOLDER''',
    'dimensions': {'width': 1024, 'height': 1024},
    'model': 'z-image-turbo',
    'negativePrompt': 'blurry, low quality',
    'bId': '$BRAND_ID'
}
# For enhancement, add:
# data['model'] = 'nano-banana:1k'
# data['assets'] = {'photo': [{'url': 'IMAGE_URL_PLACEHOLDER'}]}
# data['siviAssets'] = [{'mId': 'MEDIA_ID_PLACEHOLDER'}]
print(json.dumps(data))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_genmedia_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/media/generate" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_genmedia_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

REQUEST_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['requestId'])" <<< "$BODY")

echo "REQUEST_ID=$REQUEST_ID"
```

### 4. Step B — Poll for result (Bash tool call #2)

```bash
#!/bin/bash
set -e
# --- load the Sivi API key from the setup-sivi skill (see setup-sivi/SKILL.md) ---
for c in ".agents/skills/setup-sivi" ".claude/skills/setup-sivi" \
         "$HOME/.agents/skills/setup-sivi" "$HOME/.claude/skills/setup-sivi"; do
  [ -f "$c/.env" ] && { SIVI_HOME="$(cd "$c" && pwd)"; break; }
done
[ -z "$SIVI_HOME" ] && { echo "Sivi not set up — run the setup-sivi skill first." >&2; exit 1; }
source "$SIVI_HOME/.env"

REQUEST_ID="<REQUEST_ID_FROM_STEP_A>"
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Poll attempt $ATTEMPT/$MAX_ATTEMPTS..."

  QUERY_PARAMS=$(python3 -c "
import json, urllib.parse
params = json.dumps({'requestId': '$REQUEST_ID'})
print(urllib.parse.quote(params, safe=''))
")

  HTTP_CODE=$(curl -s -o /tmp/sivi_media_status.json -w '%{http_code}' \
    -X GET "https://connect.sivi.ai/api/prod/v2/general/get-request-status?queryParams=$QUERY_PARAMS" \
    -H "sivi-api-key: $SIVI_API_KEY")

  BODY=$(cat /tmp/sivi_media_status.json)

  if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: HTTP $HTTP_CODE"
    echo "$BODY"
    exit 1
  fi

  STATUS=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['status'])" <<< "$BODY")

  if [ "$STATUS" = "completed" ]; then
    echo "MEDIA GENERATION COMPLETE"
    python3 -c "
import json, sys
d = json.load(sys.stdin)
result = d['body'].get('result', {})
media = result.get('media', {})
if media:
    print(f\"MEDIA_URL={media.get('url', '')}\")
    print(f\"MEDIA_ID={media.get('mId', '')}\")
else:
    # Try alternate response format
    print(f\"RESULT={json.dumps(result)}\")
" <<< "$BODY"
    exit 0
  elif [ "$STATUS" = "failed" ] || [ "$STATUS" = "suspended" ]; then
    echo "MEDIA GENERATION FAILED ($STATUS)"
    echo "$BODY"
    exit 1
  fi

  sleep 10
done

echo "TIMEOUT"
exit 1
```

### 5. Download result and save to brand assets

```bash
#!/bin/bash
set -e

MEDIA_URL="<MEDIA_URL_FROM_STEP_B>"
BRAND_SLUG="<brand-slug>"
ASSETS_DIR="brands/$BRAND_SLUG/assets"
mkdir -p "$ASSETS_DIR"

if [ -n "$MEDIA_URL" ] && [[ "$MEDIA_URL" == https://* ]]; then
  FILE_NAME="generated_$(date +%s).jpg"
  curl -sL -o "$ASSETS_DIR/$FILE_NAME" "$MEDIA_URL"
  echo "IMAGE_SAVED=$ASSETS_DIR/$FILE_NAME"
else
  echo "IMAGE_SAVED=none"
fi
```

### 6. Display result

- Read the downloaded image file.
- Render `<img src="</absolute/path/to/file.jpg>" alt="Generated Image" style="box-shadow: 0px 0px 18px rgba(0,0,0,0.18);">`.
- Print the image URL and media ID.
- Offer to use this image in generate-design or campaign.

### 7. Handle errors

- On 401: "Your SIVI_API_KEY is missing or invalid."
- On 402: "Insufficient Sivi credits."
- On 422: "Invalid input: <error>. Check your prompt and parameters."
- On 500: "Sivi server errored. Please retry."

## Notes

- For **generation** (new images): use `model: "z-image-turbo"` and no `assets`/`siviAssets`.
- For **enhancement** (existing images): use `model: "nano-banana:1k"` and include `assets.photo[].url` or `siviAssets[].mId`.
- Maximum of **4 image assets** total (combined `siviAssets` + `assets`).
- The `bId` parameter is **mandatory** — a brand must be resolved before calling the generate API.
- Supported models may change — check the Sivi API docs for the latest model names.
- The generated image can be used as an asset in generate-design by passing the media URL.
