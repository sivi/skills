---
name: brand-assets
description: Use when someone asks to upload brand assets, add images to a brand, upload a logo, manage media library, or upload local files for design generation. Also use when the user mentions 'upload image,' 'add logo to brand,' 'brand assets,' 'media library,' 'upload product photo,' 'add image to brand,' 'asset management,' 'upload local file,' 'my image is not a URL,' 'use local image for design,' 'pick images from URL,' or 'extract images from webpage.' Uploads local files to Sivi via presigned URL, registers them in the media library, and saves references in the brand's assets folder. Also supports registering images from remote URLs (including product/webpage URLs for auto-picking). This is the brand-scoped asset manager — for lightweight image resolution without brand association, see handle-media. For generating AI images, see enhance-media. For brand identity setup, see brand-context.
argument-hint: [file path or URL to upload, and asset type (photo/logo/icon)]
---

## What This Skill Does

Solves the "local files can't be used" limitation and adds URL-based image registration. Supports 3 input methods:

1. **Local file upload** — Gets a presigned upload URL from Sivi's `get-presigned-url` endpoint, uploads the file to S3, then registers it via `create-media`.
2. **Remote image URL** — Provides a direct image URL (e.g., `https://example.com/photo.jpg`) to `create-media` with the `url` parameter. Sivi fetches and stores the image.
3. **Product/webpage URL auto-pick** — Provides a product page or webpage URL (e.g., `https://shop.example.com/product`) to `create-media` with the `url` parameter. Sivi auto-picks relevant images from the page.

The resulting media ID (`mId`) and public URL can then be used as asset URLs in any other Sivi skill (generate-design, campaign, etc.).


## ⚠️ Cross-Platform Compatibility — MANDATORY

- **NEVER use `head -n -1`** or `jq`. Use `python3` for JSON parsing.
- **ALWAYS use `curl -o <file> -w '%{http_code}'`** to separate HTTP status from response body.
- **Temp files**: Use `/tmp/`.


## Steps

### 1. Parse arguments

- `filePath` — local file path to upload (required for local files). OR
- `url` — publicly accessible URL to register directly (no upload needed). Can be:
  - **Direct image URL** (e.g., `https://example.com/photo.jpg`) — Sivi fetches and stores that specific image.
  - **Product/webpage URL** (e.g., `https://shop.example.com/product`) — Sivi auto-picks relevant images from the page.
- `type` — asset type: `photo`, `logo`, `illustration`, `screenshot`, or `backdrop` (default: `photo`)
- `subType` — media subtype (default: auto-detect based on type)

If no file or URL is provided, ask: "What file would you like to upload? Please provide a local file path, a direct image URL, or a product/webpage URL to auto-pick images from."

### 2. Resolve brand

Follow the **Active Brand Resolution** flow in `_shared/conventions.md`. The `bId` is needed for presigned URL and create-media calls.

### 3. Step A — Get presigned upload URL (Bash tool call #1)

Only needed for local file uploads. Skip to Step C if using a public URL.

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

FILE_PATH="<FILE_PATH>"
BRAND_ID="<BRAND_ID>"
ASSET_TYPE="<photo_OR_logo_OR_illustration_OR_screenshot_OR_backdrop>"

# Determine extension and content type from file
FILE_EXT=$(basename "$FILE_PATH" | sed 's/.*\.//' | tr '[:upper:]' '[:lower:]')
case "$FILE_EXT" in
  jpg|jpeg) CONTENT_TYPE="image/jpeg" ;;
  png) CONTENT_TYPE="image/png" ;;
  svg) CONTENT_TYPE="image/svg+xml" ;;
  webp) CONTENT_TYPE="image/webp" ;;
  gif) CONTENT_TYPE="image/gif" ;;
  bmp) CONTENT_TYPE="image/bmp" ;;
  tiff|tif) CONTENT_TYPE="image/tiff" ;;
  *) CONTENT_TYPE="image/jpeg"; FILE_EXT="jpeg" ;;
esac

PAYLOAD=$(python3 -c "
import json
print(json.dumps({
    'type': '$ASSET_TYPE',
    'extension': '$FILE_EXT',
    'contentType': '$CONTENT_TYPE',
    'bId': '$BRAND_ID',
    'expiresIn': 300
}))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_presigned_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/files/get-presigned-url" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_presigned_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

UPLOAD_URL=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['uploadUrl'])" <<< "$BODY")
echo "UPLOAD_URL=$UPLOAD_URL"
echo "CONTENT_TYPE=$CONTENT_TYPE"
```

### 4. Step B — Upload file to presigned URL (Bash tool call #2)

```bash
#!/bin/bash
set -e

FILE_PATH="<FILE_PATH>"
UPLOAD_URL="<UPLOAD_URL_FROM_STEP_A>"
CONTENT_TYPE="<CONTENT_TYPE>"

HTTP_CODE=$(curl -s -o /tmp/sivi_upload_response.json -w '%{http_code}' \
  -X PUT \
  -H "Content-Type: $CONTENT_TYPE" \
  --data-binary "@$FILE_PATH" \
  "$UPLOAD_URL")

if [ "$HTTP_CODE" != "200" ] && [ "$HTTP_CODE" != "204" ]; then
  echo "ERROR: Upload failed with HTTP $HTTP_CODE"
  cat /tmp/sivi_upload_response.json
  exit 1
fi

echo "UPLOAD_SUCCESS"
echo "UPLOADED_URL=$UPLOAD_URL"
```

### 5. Step C — Register media in Sivi (Bash tool call #3)

For presigned uploads, use `uploadUrl`. For public image URLs or product/webpage URLs, use `url`.

**Option 1: Presigned upload** (after completing Steps A and B):

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_ID="<BRAND_ID>"
ASSET_TYPE="<photo_OR_logo>"
UPLOADED_URL="<UPLOAD_URL_FROM_STEP_B>"

PAYLOAD=$(python3 -c "
import json
data = {
    'type': '$ASSET_TYPE',
    'subType': 'photograph',
    'uploadUrl': '''$UPLOADED_URL''',
    'bId': '$BRAND_ID'
}
print(json.dumps(data))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_create_media_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/media/create" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_create_media_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

MEDIA_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['mId'])" <<< "$BODY")
MEDIA_URL=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['url'])" <<< "$BODY")

echo "MEDIA_ID=$MEDIA_ID"
echo "MEDIA_URL=$MEDIA_URL"
```

**Option 2: Remote URL or product/webpage URL** (skip Steps A and B):

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_ID="<BRAND_ID>"
ASSET_TYPE="<photo_OR_logo>"
REMOTE_URL="<DIRECT_IMAGE_URL_OR_PRODUCT_WEBPAGE_URL>"

PAYLOAD=$(python3 -c "
import json
data = {
    'type': '$ASSET_TYPE',
    'subType': 'photograph',
    'url': '''$REMOTE_URL''',
    'bId': '$BRAND_ID'
}
print(json.dumps(data))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_create_media_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/media/create" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_create_media_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

MEDIA_ID=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['mId'])" <<< "$BODY")
MEDIA_URL=$(python3 -c "import json,sys; d=json.load(sys.stdin); print(d['body']['media']['url'])" <<< "$BODY")

echo "MEDIA_ID=$MEDIA_ID"
echo "MEDIA_URL=$MEDIA_URL"
```

### 6. Save asset reference to brand folder

Copy the uploaded file to the brand's assets folder and update `brand.md`:

```bash
#!/bin/bash
set -e

BRAND_SLUG="<brand-slug>"
FILE_PATH="<FILE_PATH>"
ASSETS_DIR="brands/$BRAND_SLUG/assets"
mkdir -p "$ASSETS_DIR"

# Copy file to brand assets folder
FILE_NAME=$(basename "$FILE_PATH")
cp "$FILE_PATH" "$ASSETS_DIR/$FILE_NAME"

echo "ASSET_SAVED=$ASSETS_DIR/$FILE_NAME"
```

### 7. Confirm to user

Tell the user:
> "Asset uploaded and registered. Media ID: `<mId>`. The file is saved in `brands/<slug>/assets/<filename>`. You can now use this asset in any Sivi design skill by referencing the file path or media ID."

If the user wants to generate a design using this asset, offer to proceed with generate-design, passing the media URL as an asset.

### 8. Handle errors

- On 401: "Your SIVI_API_KEY is missing or invalid."
- On 400: "Uploaded file not found in S3. Ensure the upload completed successfully."
- On 422: "Invalid input: <error>. Check the file type and brand ID."
- On 500: "Sivi server errored. Please retry."

## Notes

- Supported file types: jpg, jpeg, png, svg, webp, gif, bmp, tiff.
- The presigned URL expires after 300 seconds (5 minutes) — upload promptly.
- For **public image URLs** (already hosted), skip Steps A and B — call create-media directly with `url` instead of `uploadUrl`.
- For **product/webpage URLs**, also skip Steps A and B — call create-media with `url` set to the webpage URL. Sivi will auto-pick relevant images from the page.
- The `mId` returned can be used in `generate` (enhance-media) for image enhancement.
- The media URL returned can be used as an asset URL in generate-design and other design skills.
- Always associate assets with a brand via `bId` — this keeps the media library organized per brand.
- **Relationship to `handle-media`:** This skill is the brand-scoped asset manager — it requires a brand, saves files to `brands/<slug>/assets/`, and updates `brand.md`. For lightweight image resolution without brand association (used by composite skills internally), use `handle-media` instead.
