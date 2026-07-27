---
name: handle-media
description: Use when another skill needs to resolve an image source into a Sivi media ID (mId) or media URL. Handles 4 input sources — local file upload, direct image URL, product/webpage URL auto-pick, and AI generation — and returns a unified result (mId + mediaUrl). This is a utility skill referenced by composite skills (generate-design, create-a-plus-content, etc.) to avoid duplicating media handling scripts. For brand-scoped asset management with folder saving, see brand-assets. For standalone AI image generation/enhancement, see enhance-media.
argument-hint: "image source: file path, image URL, product/webpage URL, or AI generation prompt"
---

## What This Skill Does

A lightweight Layer 1 atomic engine that resolves **any image source** into a Sivi media reference (`mId` + `mediaUrl`). No brand required, no save-to-folder. Composite skills call this instead of inlining upload/create-media/generate scripts.

**4 input sources:**

1. **Local file** → presigned upload → `create-media` → returns `mId` + `mediaUrl`
2. **Direct image URL** → `create-media` with `url` → returns `mId` + `mediaUrl`
3. **Product/webpage URL** → `create-media` with `url` (auto-pick) → returns `mId` + `mediaUrl`
4. **AI generation** → `generate` → poll → returns `mediaUrl` (no `mId`)

**Output for the calling skill:**
- Sources 1–3: `mId` → use in `siviAssets[]`; `mediaUrl` → use in `assets.images[]` if preferred
- Source 4: `mediaUrl` → use in `assets.images[]`
- Source 2 can also be used directly in `assets.images[]` without calling this skill — only call if you need an `mId`


## ⚠️ Cross-Platform Compatibility — MANDATORY

- **NEVER use `head -n -1`** or `jq`. Use `python3` for JSON parsing.
- **ALWAYS use `curl -o <file> -w '%{http_code}'`** to separate HTTP status from response body.
- **Temp files**: Use `/tmp/`.


## Steps

### 1. Identify the input source

Determine which of the 4 sources the input is:

- **Local file** — input is a file path that exists on the local filesystem (e.g., `/Users/user/photo.jpg`, `./images/logo.png`)
- **Direct image URL** — input is a URL ending in an image extension (`.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`, `.svg`) or explicitly described as a direct image link
- **Product/webpage URL** — input is a URL that does NOT end in an image extension but is a page containing images (e.g., `https://shop.example.com/product`, `https://example.com/collection`)
- **AI generation** — input is a text prompt describing an image to generate, or the user explicitly asks for AI-generated images

If unclear, ask the user: "Is this a local file, a direct image URL, a product/webpage URL to extract images from, or should I generate an image with AI?"

### 2. Classify the asset type

For all sources, determine the asset type:

- **Logo** → `type: "logo"`, `subType: "logo"` — if the asset is a logo, brand mark, or monogram
- **Image** → `type: "photo"`, `subType: "photograph"` — if the asset is a photo, illustration, product shot, or any non-logo visual
- **Icon** → `type: "photo"`, `subType: "photograph"` — simple graphic elements (treat as image for media registration)

Classification rules:
- If the filename/URL contains "logo", "brand", "mark" → **logo**
- If unsure → **image** (default)

### 3. Resolve the media

Follow the path matching the identified source:

---

#### Source 1: Local file upload

Three-step flow: get presigned URL → upload to S3 → register via create-media.

Determine file extension and content type:
- `.jpg` / `.jpeg` → `extension: "jpeg"`, `contentType: "image/jpeg"`
- `.png` → `extension: "png"`, `contentType: "image/png"`
- `.webp` → `extension: "webp"`, `contentType: "image/webp"`
- `.svg` → `extension: "svg"`, `contentType: "image/svg+xml"`
- `.gif` → `extension: "gif"`, `contentType: "image/gif"`

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

# ✅ Replace placeholders below with actual values
LOCAL_FILE="<LOCAL_FILE_PATH>"
FILE_TYPE="<photo_OR_logo>"
FILE_SUBTYPE="<photograph_OR_logo>"
FILE_EXTENSION="<jpeg_OR_png_OR_webp_OR_svg_OR_gif>"
CONTENT_TYPE="<image/jpeg_OR_image/png_OR_etc>"
BRAND_ID="<BRAND_ID>"

# Step 1: Get presigned URL
PAYLOAD=$(python3 -c "
import json
data = {
    'type': '$FILE_TYPE',
    'extension': '$FILE_EXTENSION',
    'contentType': '$CONTENT_TYPE'
}
if '$BRAND_ID':
    data['bId'] = '$BRAND_ID'
print(json.dumps(data))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_presigned_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/files/get-presigned-url" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_presigned_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: Presigned URL request failed with HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

UPLOAD_URL=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['uploadUrl'])" <<< "$BODY")
UPLOAD_CONTENT_TYPE=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['headers']['Content-Type'])" <<< "$BODY")

echo "Got presigned URL"

# Step 2: Upload file to presigned URL
HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' \
  -X PUT \
  -H "Content-Type: $UPLOAD_CONTENT_TYPE" \
  --data-binary "@$LOCAL_FILE" \
  "$UPLOAD_URL")

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "204" ]; then
  echo "ERROR: Upload to presigned URL failed with HTTP $HTTP_CODE"
  exit 1
fi

echo "File uploaded to presigned URL"

# Step 3: Create media — register the uploaded file
PAYLOAD=$(python3 -c "
import json
data = {
    'type': '$FILE_TYPE',
    'subType': '$FILE_SUBTYPE',
    'uploadUrl': '''$UPLOAD_URL'''
}
if '$BRAND_ID':
    data['bId'] = '$BRAND_ID'
print(json.dumps(data))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_create_media_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/media/create" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_create_media_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: Create media failed with HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

M_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['mId'])" <<< "$BODY")
MEDIA_URL=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['url'])" <<< "$BODY")

echo "M_ID=$M_ID"
echo "MEDIA_URL=$MEDIA_URL"
```

---

#### Source 2: Direct image URL

Call `create-media` with the `url` parameter. Sivi fetches and stores the image.

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

IMAGE_URL="<DIRECT_IMAGE_URL>"
FILE_TYPE="<photo_OR_logo>"
FILE_SUBTYPE="<photograph_OR_logo>"
BRAND_ID="<BRAND_ID>"

PAYLOAD=$(python3 -c "
import json
data = {
    'type': '$FILE_TYPE',
    'subType': '$FILE_SUBTYPE',
    'url': '''$IMAGE_URL'''
}
if '$BRAND_ID':
    data['bId'] = '$BRAND_ID'
print(json.dumps(data))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_create_media_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/media/create" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_create_media_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: Create media failed with HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

M_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['mId'])" <<< "$BODY")
MEDIA_URL=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['url'])" <<< "$BODY")

echo "M_ID=$M_ID"
echo "MEDIA_URL=$MEDIA_URL"
```

**Note:** If the calling skill only needs the URL for `assets.images[]` and does NOT need an `mId`, skip this API call entirely and use the direct image URL as-is. Only call this when an `mId` is needed for `siviAssets[]`.

---

#### Source 3: Product/webpage URL auto-pick

Call `create-media` with the `url` parameter set to the webpage URL. Sivi auto-picks relevant images from the page.

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

WEBPAGE_URL="<PRODUCT_OR_WEBPAGE_URL>"
FILE_TYPE="<photo_OR_logo>"
FILE_SUBTYPE="<photograph_OR_logo>"
BRAND_ID="<BRAND_ID>"

PAYLOAD=$(python3 -c "
import json
data = {
    'type': '$FILE_TYPE',
    'subType': '$FILE_SUBTYPE',
    'url': '''$WEBPAGE_URL'''
}
if '$BRAND_ID':
    data['bId'] = '$BRAND_ID'
print(json.dumps(data))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_create_media_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/media/create" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_create_media_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: Create media failed with HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

M_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['mId'])" <<< "$BODY")
MEDIA_URL=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['url'])" <<< "$BODY")

echo "M_ID=$M_ID"
echo "MEDIA_URL=$MEDIA_URL"
```

---

#### Source 4: AI generation

Call `generate` with a text prompt, then poll for the result.

**Supported dimensions by model:**

Choose dimensions from the table below before calling the generate API. Using unsupported dimensions will return a 422 error.

**Nano Banana, Nano Banana 2, Nano Banana Pro, Nano Banana Lite:**

| Width | Height | Aspect Ratio |
|-------|--------|-------------|
| 1264  | 848    | ~3:2        |
| 848   | 1264   | ~2:3        |
| 1200  | 896    | ~4:3        |
| 896   | 1200   | ~3:4        |
| 1152  | 928    | ~5:4        |
| 928   | 1152   | ~4:5        |
| 1376  | 768    | ~16:9       |
| 768   | 1376   | ~9:16       |
| 1548  | 672    | ~23:10      |

**Z-Image Turbo**

| Width | Height | Aspect Ratio |
|-------|--------|-------------|
| 1024  | 1024   | 1:1         |
| 1344  | 768    | 7:4         |
| 1280  | 960    | 4:3         |
| 960   | 1280   | 3:4         |
| 768   | 1344   | 4:7         |

Select the closest supported dimension matching the design's aspect ratio. For wide banners use 1344x768 (7:4) or 1376x768 (~16:9, nano-banana only). For vertical posters use 768x1344 (4:7) or 960x1280 (3:4). For square designs use 1024x1024.

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

PROMPT_TEXT="<IMAGE_GENERATION_PROMPT>"
WIDTH="<WIDTH>"
HEIGHT="<HEIGHT>"
BRAND_ID="<BRAND_ID>"

PAYLOAD=$(python3 -c "
import json
data = {
    'prompt': '''$PROMPT_TEXT''',
    'dimensions': {'width': $WIDTH, 'height': $HEIGHT},
    'model': 'nano-banana-3-lite:1k',
    'negativePrompt': 'no text, no letters, no words, no handwriting, no calligraphy, no labels, no titles, no signs, no logos, no watermarks.'
}
if '$BRAND_ID':
    data['bId'] = '$BRAND_ID'
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

Then poll for the result:

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

REQUEST_ID="<REQUEST_ID_FROM_ABOVE>"
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))
  echo "Poll attempt $ATTEMPT/$MAX_ATTEMPTS..."

  QUERY_PARAMS=$(python3 -c "
import json, urllib.parse
params = json.dumps({'requestId': '''$REQUEST_ID'''})
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

### 4. Return result to calling skill

After the script completes, return:

- **`M_ID`** — Sivi media ID (sources 1–3). Use in `siviAssets[]` in the design payload.
- **`MEDIA_URL`** — public media URL (all sources). Use in `assets.images[]` in the design payload.

For AI generation (source 4), only `MEDIA_URL` is returned (no `mId`).

### 5. Handle errors

- On 401: "Your SIVI_API_KEY is missing or invalid."
- On 402: "Insufficient Sivi credits."
- On 400: "Uploaded file not found in S3. Ensure the upload completed successfully."
- On 422: "Invalid input: <error>. Check the URL, file type, or parameters."
- On 500: "Sivi server errored. Please retry."

## Notes

- This skill is a **utility for other skills** — it is not typically invoked directly by users.
- Brand association is **optional** — `bId` is not required by the API. If a brand was matched, pass its ID. If no brand was matched, omit `bId` entirely.
- No files are saved to the `brands/` folder. For brand-scoped asset management with folder saving, use `brand-assets` *(coming soon)*.
- Maximum of **4 image assets** total (combined `siviAssets` + `assets`) when using the generate API.
- For standalone AI image enhancement (not generation), use `enhance-media` with `model: "nano-banana:1k"`.
- Direct image URLs (source 2) can be used directly in `assets.images[]` without calling this skill. Only call `create-media` when an `mId` is needed for `siviAssets[]`.
- The `create-media` API docs: https://developer.sivi.ai/docs/sivi-api/core-api/media/create-media
