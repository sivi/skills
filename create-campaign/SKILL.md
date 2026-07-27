---
name: create-campaign
description: Use when someone asks to create a multi-channel campaign, generate ads across platforms, create a campaign creative set, or produce designs for multiple channels at once. Also use when the user mentions 'campaign creatives,' 'multi-channel ads,' 'ad set,' 'creative set,' 'make ads for all platforms,' 'generate all formats,' 'cross-channel campaign,' 'omnichannel creatives,' 'campaign assets,' 'social media campaign,' or 'I need ads for Instagram and Facebook.' Generates a complete set of on-brand design variants across selected channels from one brief, using per-design submission and polling. Results saved as an HTML file with embedded designs and edit buttons. For single designs, see generate-design.
argument-hint: [campaign brief — describe the offer, product, target audience, and desired channels]
---

## What This Skill Does

Takes one campaign brief and generates a complete multi-channel creative set. Generates copy per channel, submits `designs-from-content` requests (one per channel/format) using the generate-design submit-and-poll pattern, downloads all variants, and writes the results to `brands/<slug>/campaigns/<campaign-name>.html` with embedded images and edit buttons.


## Steps

### 1. Parse arguments

- `prompt` — the campaign brief (required). Should include: product/offer, target audience, tone, key messaging.
- `channels` — list of channels/formats to generate (optional; ask user if not specified).

If `prompt` is missing, ask: "What is the campaign about? Describe the product, offer, and target audience."

### 2. Resolve brand

Follow standard brand resolution in `_shared/conventions.md` → Active Brand Resolution.

### 2.1. Extract brand colors and fonts

Read `brands/<slug>/brand.md` and extract:

- **Colors** — from the `## Colors` section (hex codes like `#5662EC`). If the brand has colors defined, use them. If no colors are found, **form a color palette relevant to the campaign brief** — analyze the product, offer, target audience, and tone to determine appropriate colors (e.g., warm vibrant tones for summer sales, cool blues for tech products, earthy greens for eco brands). Generate 2–4 hex colors that complement the messaging. Do not omit `colors`.

- **Fonts** — from the `## Fonts` section. If the brand has fonts defined, convert each to a `fontGroups` entry. If no fonts are found, **decide on Google Font names** for heading, subHeading, and body that fit the tone of the campaign (e.g., Poppins for bold/promotional, Playfair Display for elegant/premium, Roboto for modern/tech, Montserrat for clean/corporate). Then **query each font name via the Sivi Get Fonts API** to get the actual font `id`:

  ```bash
  # Query fonts by name — one call per decided font name
  # Example: heading=Poppins, subHeading=Poppins, body=Inter
  curl -s -X POST "https://connect.sivi.ai/api/prod/v2/general/font/get" \
    -H "sivi-api-key: $SIVI_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"name": "Poppins", "limit": 5}' -o /tmp/sivi_font_heading.json

  curl -s -X POST "https://connect.sivi.ai/api/prod/v2/general/font/get" \
    -H "sivi-api-key: $SIVI_API_KEY" \
    -H "Content-Type: application/json" \
    -d '{"name": "Inter", "limit": 5}' -o /tmp/sivi_font_body.json
  ```

  Parse each response with `python3` to extract the font `id` and `name` from `body.data[0]`. Use the returned `id` and `name` to build the `fontGroups` array with `heading`, `subHeading`, and `body` types. Do not omit `fontGroups`.

Build a single `SETTINGS_JSON` string that will be embedded in **every** channel payload's `settings` field. This is critical — all channel requests MUST use the exact same `settings` object for visual consistency across the entire campaign. If multiple options are possible for any setting, pick one and use it for all channels:

```python
# Example with brand colors and fonts
settings = {
    "mode": "brand",
    "currentbId": "<BRAND_ID>",
    "colors": ["#5662EC", "#EF9AB2"],
    "fontGroups": [
        {"id": "<FONT_ID_1>", "name": "<FONT_NAME_1>", "type": "heading", "status": "enabled", "addedBy": "system"},
        {"id": "<FONT_ID_2>", "name": "<FONT_NAME_2>", "type": "subHeading", "status": "enabled", "addedBy": "system"},
        {"id": "<FONT_ID_3>", "name": "<FONT_NAME_3>", "type": "body", "status": "enabled", "addedBy": "system"}
    ]
}
```

**Colors and fontGroups MUST always be present in settings.** Use brand-extracted values when available; otherwise generate a relevant color palette from the campaign brief and fetch fonts from the API.

**The same `SETTINGS_JSON` MUST be reused verbatim in every channel's payload. Do not vary settings per channel — consistency is the goal.**

### 3. Determine channels

If the user didn't specify channels, ask which ones they need. Present the channel matrix (see `_shared/channel-matrix.md` for the full list). Common defaults:

| Channel | Type | Subtype | Dimensions |
|---|---|---|---|
| Instagram Post | instagram | instagram-post | 1080x1080 |
| Instagram Story | instagram | instagram-story | 1080x1920 |
| Facebook Ad | facebook | facebook-ad | 1200x628 |
| LinkedIn Post | linkedin | linkedIn-post | 1200x627 |
| YouTube Thumbnail | youtube | youtube-thumbnail | 1280x720 |
| Email Banner | email | wide | 600x200 |
| Display Ad (Rectangle) | displayAds | displayAds-large-rectangle | 336x280 |
| Twitter Post | twitter | twitter-post | 1200x675 |

### 4. Generate copy for each channel

Follow the content generation instructions in `_shared/content-generation.md`. Generate one `content` object per channel, tailored to the channel's format and dimensions. Present all copy grouped by channel and ask for one approval.

### 5. Handle images

If no images were provided by the user, ask: "No images were provided for this campaign. Would you like me to generate images using AI?"

If yes, follow generate-design's Step 1C to generate image prompts (background + contained modes) and call `handle-media` (Source 4: AI generation) for each. Show generated images and ask for approval. Add the approved image URL to `assets.images` in all channel payloads.

If no, proceed with `assets.images: []`.

### 5.1. Compose mandatory design instructions (and inspiration references)

**`designInstructions` is MANDATORY for this skill.** A single detailed instructions string is authored once and reused verbatim across every channel payload — this is what makes all channel sizes (Instagram Post, Facebook Ad, LinkedIn Post, Story, Email Banner, etc.) render in a similar, cohesive visual style.

Do this AFTER copy is approved (Step 4) and channels/sizes are locked (Step 3), and BEFORE building payloads (Step 7). You now have all the inputs needed: the approved copy text, the image(s) that will be placed, and the full set of target sizes.

**How to compose `DESIGN_INSTRUCTIONS`:**

1. **Start from the brief.** If the user provided composition, layout, positioning, spacing, mood, or color-palette guidance in the brief, capture ALL of it verbatim — element counts, alignment, positioning (e.g., "three speaker portraits aligned horizontally across the center", "top section features a shield-shaped panel", "event details in the lower-right"). Do NOT drop layout details.
2. **Whether the user provided nothing, minimal, or detailed guidance, ALWAYS expand it into a detailed instructions string.** The string must describe:
   - **Composition & focal point** — where the headline/offer/CTA sits, where the product/hero image sits, how the elements are stacked or aligned.
   - **Layout across sizes** — how the same idea adapts across the selected channel sizes (square vs vertical story vs wide banner vs email banner). Explicitly acknowledge the sizes in use (e.g., "on square 1080×1080 formats, headline top-left with product bottom-right; on 1080×1920 stories, stack headline over product with CTA at the bottom third; on 1200×628 wide formats, headline left, product right, CTA under headline").
   - **Image treatment** — how the provided/generated image should be placed (full-bleed, cutout, contained, with gradient/overlay), matched to the actual image content.
   - **Text treatment** — hierarchy of the approved copy (title dominant, offer accent, CTA button), how much text volume fits each size, negative-space guidance.
   - **Background & text colors** — explicitly specify the background color (hex) and text colors (hex) for headline, body, and CTA. Use the brand/campaign colors resolved in Step 2.1. State them as concrete hex values (e.g., "background: #FFFFFF; headline text: #1A1A2E; body text: #4A4A6A; CTA button fill: #5662EC, CTA text: #FFFFFF"). Ensure contrast meets readability. These colors guide Sivi's layout engine and keep all channel sizes visually consistent.
3. **Match image, text, and size.** The instructions must reference the actual copy pieces (title, offer, CTA) and the actual image subject (e.g., "the product photo of X"), not generic placeholders.
4. **One string, reused for every channel.** Do NOT vary the instructions per channel — the point is style consistency across sizes. Any per-size adaptation goes INSIDE this single string.

Store the composed string as the `DESIGN_INSTRUCTIONS` variable used by every channel payload in Step 7. This field is always included as a top-level `designInstructions` field on every payload.

**Inspiration image URLs (optional)** — any URLs the user shared as visual references (e.g., "make it look like this", "similar to this poster", "use this as reference/inspiration"). Collect these into an `INSPIRATION_JSON` array of `{"url": "..."}` objects and include as `assets.inspiration` in every channel payload. If none provided, set to `[]`.

### 6. Estimate credits and confirm

Calculate: `num_channels × numOfVariants` designs. Tell the user:

> "This campaign will generate <N> designs across <M> channels. This will use <N> Sivi credits. Proceed?"

### 7. Build payloads

For each channel, write a `designs-from-content` payload to `/tmp/sivi_batch_payload_<N>.json`:

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_ID="<BRAND_ID>"
BRAND_SLUG="<brand-slug>"
CAMPAIGN_NAME="<campaign-name>"
OUTPUT_DIR="brands/$BRAND_SLUG/campaigns/$CAMPAIGN_NAME"
mkdir -p "$OUTPUT_DIR"

# Build settings JSON — colors and fontGroups are always present
# Use brand colors if found in brand.md; otherwise generate a palette relevant to the campaign brief
# Use brand fonts if found in brand.md; otherwise decide Google font names and query via API

# Step 1: If no brand colors, generate a relevant palette from the campaign brief
# (agent analyzes the brief and picks 2-4 hex colors that fit the tone)

# Step 2: If no brand fonts, decide Google font names for heading, subHeading, body
# based on the campaign tone, then query each via Sivi Get Fonts API to get the font id
# Example: Poppins (heading + subHeading), Inter (body) for modern/clean tone
HEADING_FONT_NAME="<DECIDED_HEADING_FONT>"
SUBHEADING_FONT_NAME="<DECIDED_SUBHEADING_FONT>"
BODY_FONT_NAME="<DECIDED_BODY_FONT>"

curl -s -X POST "https://connect.sivi.ai/api/prod/v2/general/font/get" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$HEADING_FONT_NAME\", \"limit\": 5}" -o /tmp/sivi_font_heading.json
curl -s -X POST "https://connect.sivi.ai/api/prod/v2/general/font/get" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$SUBHEADING_FONT_NAME\", \"limit\": 5}" -o /tmp/sivi_font_subheading.json
curl -s -X POST "https://connect.sivi.ai/api/prod/v2/general/font/get" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$BODY_FONT_NAME\", \"limit\": 5}" -o /tmp/sivi_font_body.json

# Extract font ids from API responses
HEADING_FONT_ID=$(python3 -c "import json; d=json.load(open('/tmp/sivi_font_heading.json')); print(d['body']['data'][0]['id'])")
SUBHEADING_FONT_ID=$(python3 -c "import json; d=json.load(open('/tmp/sivi_font_subheading.json')); print(d['body']['data'][0]['id'])")
BODY_FONT_ID=$(python3 -c "import json; d=json.load(open('/tmp/sivi_font_body.json')); print(d['body']['data'][0]['id'])")

SETTINGS_JSON=$(python3 -c "
import json
settings = {
    'mode': 'brand',
    'currentbId': '$BRAND_ID',
    'colors': <BRAND_OR_GENERATED_COLORS>,
    'fontGroups': [
        {'id': '$HEADING_FONT_ID', 'name': '$HEADING_FONT_NAME', 'type': 'heading', 'status': 'enabled', 'addedBy': 'system'},
        {'id': '$SUBHEADING_FONT_ID', 'name': '$SUBHEADING_FONT_NAME', 'type': 'subHeading', 'status': 'enabled', 'addedBy': 'system'},
        {'id': '$BODY_FONT_ID', 'name': '$BODY_FONT_NAME', 'type': 'body', 'status': 'enabled', 'addedBy': 'system'}
    ],
    'designModel': 'sivi-gen-3h-preview'
}
print(json.dumps(settings))
")

# Shared fields — built once in Step 5.1 and reused verbatim in every channel payload.
# DESIGN_INSTRUCTIONS: MANDATORY — detailed composition/layout/image/text/size guidance authored in Step 5.1.
# INSPIRATION_JSON: JSON array of {"url": "..."} inspiration references ("[]" if none).
export DESIGN_INSTRUCTIONS="<DETAILED_DESIGN_INSTRUCTIONS_FROM_STEP_5_1>"
export INSPIRATION_JSON='<INSPIRATION_ARRAY_JSON_OR_[]>'

# Channel 1: Instagram Post — with approved copy as content
# designInstructions is MANDATORY — always include the DESIGN_INSTRUCTIONS string.
python3 -c "
import json, os
DI = os.environ['DESIGN_INSTRUCTIONS']
INSP = json.loads(os.environ.get('INSPIRATION_JSON', '[]'))
payload = {
    'name': 'Campaign - Instagram Post',
    'type': 'instagram',
    'subtype': 'instagram-post',
    'content': {'title': '<APPROVED_TITLE>', 'offer': '<APPROVED_OFFER>', 'text': '<APPROVED_TEXT>', 'button': '<APPROVED_CTA>'},
    'designInstructions': DI,
    'numOfVariants': 1,
    'outputFormat': ['jpg'],
    'language': 'english',
    'assets': {'images': [], 'logos': [], 'icons': [], 'inspiration': INSP},
    'settings': $SETTINGS_JSON
}
print(json.dumps(payload))
" > /tmp/sivi_batch_payload_1.json

# Channel 2: Facebook Ad — with approved copy as content
python3 -c "
import json, os
DI = os.environ['DESIGN_INSTRUCTIONS']
INSP = json.loads(os.environ.get('INSPIRATION_JSON', '[]'))
payload = {
    'name': 'Campaign - Facebook Ad',
    'type': 'facebook',
    'subtype': 'facebook-ad',
    'content': {'title': '<APPROVED_TITLE>', 'offer': '<APPROVED_OFFER>', 'text': '<APPROVED_TEXT>', 'button': '<APPROVED_CTA>'},
    'designInstructions': DI,
    'numOfVariants': 1,
    'outputFormat': ['jpg'],
    'language': 'english',
    'assets': {'images': [], 'logos': [], 'icons': [], 'inspiration': INSP},
    'settings': $SETTINGS_JSON
}
print(json.dumps(payload))
" > /tmp/sivi_batch_payload_2.json

# Repeat for each channel, using the SAME $SETTINGS_JSON...
echo "PAYLOADS_READY"
```

**Payload notes:**
- Replace `<APPROVED_*>` placeholders with the actual approved copy for each channel.
- Each channel gets its own `content` object — copy may differ per channel (e.g., shorter text for email banner).
- Omit `dimension` for standard types (instagram, facebook, etc.). Only include `dimension` when `type` is `custom`.
- Include `siviAssets: []` when no local file uploads. Use `assets.images` for public URL assets.
- **`designInstructions`** is MANDATORY and always included as a top-level field. The detailed string authored in Step 5.1 is reused verbatim across every channel payload — do not vary it per channel. This is the primary mechanism for keeping all sizes in a consistent visual style.
- **`assets.inspiration`** carries reference images the user shared as visual guidance (Step 5.1). The same inspiration array is reused across every channel payload. Set to `[]` if none provided.

### 8. Execute designs

`generate-design` is the base skill for all composites. For each design payload, follow the `generate-design` skill's submit-and-poll pattern (see `_shared/submit-and-poll-content.sh`). For each channel:
1. Submit the payload to `designs-from-content`
2. Poll `get-request-status` until `completed` or `failed`
3. Download all variants and options to `OUTPUT_DIR`
4. Repeat for the next channel

### 9. Write campaign result HTML

After all designs are downloaded, write `brands/<slug>/campaigns/<campaign-name>.html`.

**Read the shared template at `_shared/campaign-result.html`** to get the full HTML skeleton with styles. Replace the `{{PLACEHOLDER}}` tokens with actual values:

- `{{CAMPAIGN_NAME}}` — campaign name
- `{{BRAND_NAME}}` — resolved brand name
- `{{DATE}}` — generation date
- `{{CHANNELS}}` — comma-separated list of channels
- `{{BRIEF_TEXT}}` — the original campaign brief
- `{{SUMMARY_TEXT}}` — 1-2 sentence summary

For each channel/format, repeat the `.design-group` block:
- `{{CHANNEL_NAME}}` — e.g., "Instagram Post", "Facebook Ad"
- `{{WIDTH}}`, `{{HEIGHT}}` — design dimensions
- For each option (base variant = Option 1, `options[]` sub-variants = Option 2+), repeat the `.design-card` block:
  - `{{OPTION_NUMBER}}` — 1, 2, 3, etc.
  - `{{VARIANT_IMAGE_URL}}` — remote `variantImageUrl` from the API response
  - `{{VARIANT_EDIT_LINK}}` — remote `variantEditLink` from the API response

**Do NOT hardcode the HTML or styles** — always read `_shared/campaign-result.html` and use it as the template.

After writing the file, **open it in the user's browser** using the platform-appropriate command:
- macOS: `open brands/<slug>/campaigns/<campaign-name>.html`
- Linux: `xdg-open brands/<slug>/campaigns/<campaign-name>.html`
- Windows (Git Bash / WSL): `start brands/<slug>/campaigns/<campaign-name>.html`

### 10. Display results

Follow the Display Contract in `_shared/conventions.md`. For each channel, list all designs as Option 1, Option 2, ... Option N (base variant = Option 1, `options[]` sub-variants = Option 2+). Read each image file, render inline markdown, print size and edit links.

### 11. Handle errors

Follow error handling in `_shared/conventions.md`.

## Notes

- Composites default to `designs-from-content` API with copy as the `content` object. `designs-from-prompt` is available as an alternative for direct generation without copy review.
- Use `settings.mode: "brand"` + `currentbId` for all channel requests when a brand is active. `colors` and `fontGroups` MUST always be present in settings — use brand-extracted values from `brand.md` when available; otherwise generate a color palette relevant to the campaign brief and fetch fonts from the Sivi Get Fonts API (`POST font/get`).
- **All channel payloads MUST use the exact same `settings` object** (same mode, currentbId, colors, fontGroups). Build `SETTINGS_JSON` once and reuse it for every channel. Do not vary settings per channel.
- The campaign name is slugified from the brief (e.g., "Summer Sale 2025" → "summer-sale-2025").
- Images are saved to `brands/<slug>/campaigns/<campaign-name>/` subfolder.
- If some channels fail while others succeed, still write results for successful channels and note failures in the summary.
- Variant count tolerance: some channels may return fewer variants than requested — proceed with what's returned.
