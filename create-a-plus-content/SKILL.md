---
name: create-a-plus-content
description: Use when someone asks to create Amazon A+ content, generate Enhanced Brand Content (EBC), design A+ modules, create Amazon product listing visuals, or produce A+ detail page content. Also use when the user mentions 'A+ content,' 'A+ modules,' 'EBC,' 'Amazon Enhanced Brand Content,' 'Amazon listing design,' 'product detail page,' 'Amazon brand story,' 'comparison chart,' 'A+ banner,' 'Amazon A+ template,' or 'enhance my Amazon listing.' Generates a complete set of Amazon A+ content modules (brand logo, hero image, feature highlights, comparison table, lifestyle image, spec sidebar) from a product brief, using batch submission and polling. Results saved as an HTML file with embedded designs and edit buttons. For single designs, see generate-design. For multi-channel ad campaigns, see create-campaign.
argument-hint: [product name, key features, and optional product image URL]
---

## What This Skill Does

Takes a product name + key features + optional product image and generates a complete Amazon A+ content module set:

- **Brand Logo Header** — brand identity banner
- **Hero Image** — large product showcase with headline
- **Feature Highlights** — 4 image+text blocks for key product features
- **Comparison Table** — side-by-side comparison with competitors
- **Lifestyle Image** — product in use with descriptive text
- **Spec Sidebar** — single image with technical specifications

If the product image needs enhancement (background removal, quality improvement), it routes through `enhance-media` first. Results saved to `brands/<slug>/campaigns/amazon-a-plus-<product>.html`.


## ⚠️ Cross-Platform Compatibility — MANDATORY

- **NEVER use `head -n -1`** or `jq`. Use `python3` for JSON parsing.
- **ALWAYS use `curl -o <file> -w '%{http_code}'`** to separate HTTP status from response body.
- **Temp files**: Use `/tmp/`.


## Amazon A+ Content Module Specifications

Amazon A+ content uses specific module types with fixed dimensions. All modules are generated as custom-sized designs via the Sivi API.

| Module | Sivi Type | Sivi Subtype | Dimensions | Purpose |
|---|---|---|---|---|
| Brand Logo Header | custom | custom | 600×180 | Brand identity banner |
| Hero Image | custom | custom | 970×600 | Large product showcase with headline |
| Feature Highlights (4 blocks) | custom | custom | 970×600 | 4 image+text feature blocks |
| Comparison Table | custom | custom | 970×600 | Side-by-side competitor comparison |
| Lifestyle Image | custom | custom | 970×600 | Product in use with descriptive text |
| Spec Sidebar | custom | custom | 970×300 | Single image with specifications |

**Note:** Amazon A+ content requires images at these exact dimensions. The Sivi API supports custom dimensions (200–2000px), so all modules use `type: "custom"` with `subtype: "custom"`.


## Steps

### 1. Parse arguments

- `productName` — name of the product (required).
- `features` — list of key product features/benefits (required). Ideally 4 features for the Feature Highlights module.
- `productImage` — URL to product image (optional but recommended).
- `competitors` — list of competitor product names for comparison table (optional; if not provided, generate generic comparison columns).
- `modules` — which A+ modules to generate (default: all six).

If `productName` or `features` is missing, ask: "What product is this A+ content for? List 3-4 key features to highlight."

### 2. Resolve brand

Follow the **Active Brand Resolution** flow in `_shared/conventions.md`:
1. If the user's prompt mentions a brand name → check local `brands/*/brand.md` for a match. If no match, use default brand.
2. If no brand name mentioned → use default brand (the one with `**Default Brand:** true`). If no default, use any local brand.
3. If no local brands exist → a dummy brand will be created automatically. Do NOT proceed without a brand.
5. Read `brands/<slug>/brand.md` for brandId and brand details.
6. Set `settings.mode: "brand"` + `currentbId: <brandId>`.

### 2.1. Extract brand colors and fonts

Read `brands/<slug>/brand.md` and extract:

- **Colors** — from the `## Colors` section (hex codes like `#5662EC`). If the brand has colors defined, use them. If no colors are found, **form a color palette relevant to the product/campaign text** — analyze the product name, USP, and copy to determine appropriate colors (e.g., earthy tones for organic products, bold reds for sales/promotions, blues for tech/finance). Generate 2–4 hex colors that complement the messaging. Do not omit `colors`.

- **Fonts** — from the `## Fonts` section. If the brand has fonts defined, convert each to a `fontGroups` entry. If no fonts are found, **decide on Google Font names** for heading, subHeading, and body that fit the tone of the copy (e.g., Poppins for bold/promotional, Playfair Display for elegant/premium, Roboto for modern/tech, Montserrat for clean/corporate). Then **query each font name via the Sivi Get Fonts API** to get the actual font `id`:

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

Build a `SETTINGS_JSON` Python dict string that will be embedded in every module payload's `settings` field. This ensures all modules use the same colors and fonts:

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

**Colors and fontGroups MUST always be present in settings.** Use brand-extracted values when available; otherwise generate a relevant color palette from the copy and fetch fonts from the API.

**These same colors and fontGroups MUST be passed in every module's `settings` object for visual consistency across all A+ modules.**

### 3. Handle product image (optional but recommended)

There are **4 ways** the user can provide a product image:

**Source 1: Product/webpage URL** — If the user provides a product page URL (e.g., `https://shop.example.com/product`), use `handle-media` (Source 3: product/webpage URL auto-pick) to resolve it. `handle-media` calls the `create-media` API and returns `MEDIA_URL`.

Use the returned `MEDIA_URL` as the product image URL in the design payloads below. If `handle-media` fails to extract an image, fall back to manual extraction:
1. Use `curl` to fetch the raw HTML and search for image patterns:
   ```bash
   curl -sL "<PRODUCT_URL>" | grep -oE 'https?://[^"'\'' ]+\.(jpg|jpeg|png|webp)' | sort -u
   ```
2. Pick the highest-resolution product image URL.
3. If still no image found, ask the user: "I couldn't extract a product image from that URL. Can you provide a direct image URL?"

**Source 2: Direct image URL** — If the user provides a direct image URL (e.g., `https://example.com/product.jpg`), use it directly. If the image needs enhancement (background removal, quality improvement), offer: "Would you like me to enhance the product image first? (background removal, quality improvement)"
- If yes, route through the `enhance-media` skill:
  - Use `model: "nano-banana:1k"` with the product image URL
  - Prompt: "Enhance this product photo for Amazon A+ content. Make it vibrant and professional with a clean white background."
- Use the enhanced image URL in the design payloads below.

**Source 3: Local file upload** — If the user provides a local file, route through `handle-media` (Source 1: local file upload) to upload and register it, then use the returned `MEDIA_URL`.

**Source 4: AI generation** — If no image is provided via any of the above sources, ask: "No product image was provided. Would you like me to generate one using AI?" If yes, route through `handle-media` (Source 4: AI generation) with a prompt describing the product.

**Always pass the product image as an asset** to Hero Image, Feature Highlights, Lifestyle Image, and Spec Sidebar modules. Only Brand Logo Header and Comparison Table omit the product image. Passing images significantly improves design quality — do not skip this step unless the user explicitly says no image is available.

### 3.1. Extract inspiration references (optional)

Scan the user's brief for **inspiration image URLs** — any URLs the user shared as visual references (e.g., "match this A+ style", "similar to this reference"). Collect these into an `INSPIRATION_JSON` array of `{"url": "..."}` objects to be reused as `assets.inspiration` in every module payload. If none provided, set to `[]`.

Note: The mandatory `designInstructions` string is composed later, in Step 5.1, once copy and module sizes are both known.

### 4. Generate copy for A+ modules

You are a content expert specializing in Amazon A+ content. Generate structured copy for each A+ module using Sivi allowed semantics. The copy must fit within each module's dimensions alongside images and layout elements.

**Allowed Semantics** — use ONLY these: `title`, `text`, `offer`, `bulletlist`, `numberedlist`, `imagetitletextlist`, `imagetextlist`, `titletextlist`, `textlist`, `caption`, `quote`

**Module copy guidelines:**

- **Brand Logo Header**: `title` (brand name), `text` (short brand tagline, under 60 chars)
- **Hero Image**: `title` (product headline, under 40 chars), `text` (value proposition, under 80 chars), `offer` (key benefit, under 40 chars)
- **Feature Highlights**: `imagetitletextlist` (4 items, each with title under 30 chars and text under 60 chars)
- **Comparison Table**: `title` (table heading), `titletextlist` (comparison rows — product vs competitors, each with title = feature name and text = comparison values)
- **Lifestyle Image**: `title` (lifestyle headline, under 40 chars), `text` (descriptive paragraph, under 80 chars), `caption` (use scenario, under 40 chars)
- **Spec Sidebar**: `title` (spec heading), `bulletlist` (3-5 spec items, each under 40 chars)

**Content rules:**
1. Match brand tone and vocabulary if brand persona is available.
2. Write benefit-driven copy, not just feature lists.
3. Use Amazon-optimized language (e.g., "Perfect for...", "Designed to...").
4. All values must be non-empty strings.
5. `imagetitletextlist` and `titletextlist` must be arrays of objects.

Present the copy in readable format per module. Ask the user: "Here is the A+ content copy for each module. Would you like to proceed, or adjust any text?"

After user approval, the copy becomes the `content` object for `designs-from-content` in each module's API call.

### 5. Determine modules

Default: generate all six modules. If the user specifies a subset, only generate those.

| # | Module | Dimensions | numOfVariants |
|---|---|---|---|
| 1 | Brand Logo Header | 600×180 | 1 |
| 2 | Hero Image | 970×600 | 1 |
| 3 | Feature Highlights | 970×600 | 1 |
| 4 | Comparison Table | 970×600 | 1 |
| 5 | Lifestyle Image | 970×600 | 1 |
| 6 | Spec Sidebar | 970×300 | 1 |

### 5.1. Compose mandatory design instructions

**`designInstructions` is MANDATORY for this skill.** A single detailed instructions string is authored once and reused verbatim across every A+ module payload — this is what makes all six module sizes (600×180, 970×600, 970×300) render in a similar, cohesive visual style that reads as one A+ page.

Do this AFTER copy is approved (Step 4) and modules/sizes are locked (Step 5), and BEFORE building payloads (Step 7). You now have all the inputs needed: the approved copy per module, the product image (if provided), and the fixed set of A+ module dimensions.

**How to compose `DESIGN_INSTRUCTIONS`:**

1. **Start from the brief.** If the user provided composition, layout, positioning, spacing, mood, or color-palette guidance, capture ALL of it verbatim — element counts, alignment, positioning (e.g., "hero shot with product on the left and headline stack on the right", "features arranged as a 2×2 grid", "spec bar with icons aligned in a row"). Do NOT drop layout details.
2. **Whether the user provided nothing, minimal, or detailed guidance, ALWAYS expand it into a detailed instructions string.** The string must describe:
   - **Overall A+ style** — the shared visual language that ties all six modules together (typography weight, accent color, background treatment, corner radius, iconography).
   - **Per-module layout** — how the shared style adapts across the specific A+ dimensions in use. Explicitly reference the sizes (e.g., "on the 600×180 Brand Logo Header, brand mark centered with tagline underneath; on the 970×600 Hero Image, product left third, headline + offer right two-thirds; on the 970×600 Feature Highlights, 2×2 grid of icon+title+text; on the 970×600 Comparison Table, three-column layout with sticky feature column on the left; on the 970×600 Lifestyle Image, full-bleed lifestyle photo with headline over a soft overlay in the bottom third; on the 970×300 Spec Sidebar, single horizontal row of bulleted specs").
   - **Image treatment** — how the product image should be placed across modules (full-bleed, cutout, contained, with gradient/overlay), matched to the actual product photo.
   - **Text treatment** — hierarchy of the approved copy per module (title dominant, offer accent, bullet list rhythm), text volume matched to each module's dimensions, negative-space guidance.
   - **Background & text colors** — explicitly specify the background color (hex) and text colors (hex) for headline, body, and accent/offer text. Use the brand colors resolved in Step 2.1. State them as concrete hex values (e.g., "background: #FFFFFF; headline text: #1A1A2E; body text: #4A4A6A; accent/offer: #5662EC"). Ensure contrast meets readability. These colors guide Sivi's layout engine and keep all six A+ modules visually consistent.
3. **Match image, text, and size.** The instructions must reference the actual copy pieces and the actual product (e.g., "the product photo of X"), not generic placeholders.
4. **One string, reused for every module.** Do NOT vary the instructions per module — the point is style consistency across sizes. Any per-module adaptation goes INSIDE this single string.

Store the composed string as the `DESIGN_INSTRUCTIONS` variable used by every module payload in Step 7. This field is always included as a top-level `designInstructions` field on every payload.

### 6. Estimate credits and confirm

Calculate: `sum of numOfVariants across all modules`. Tell the user:

> "This A+ content will generate <N> designs across <M> modules. This will use <N> Sivi credits. Proceed?"

### 7. Step A — Build payloads for each module (Bash tool call #1)

For each module, write a JSON payload to `/tmp/sivi_aplus_payload_<N>.json`:

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

BRAND_ID="<BRAND_ID>"
BRAND_SLUG="<brand-slug>"
PRODUCT_SLUG="<product-slug>"
OUTPUT_DIR="brands/$BRAND_SLUG/campaigns/amazon-a-plus-$PRODUCT_SLUG"
mkdir -p "$OUTPUT_DIR"

PRODUCT_IMAGE_URL="<PRODUCT_IMAGE_URL_OR_EMPTY>"

# Shared fields — reused verbatim across every module payload.
# DESIGN_INSTRUCTIONS: MANDATORY — detailed composition/layout/image/text/size guidance authored in Step 5.1.
# INSPIRATION_JSON: JSON array of {"url": "..."} inspiration references from Step 3.1 ("[]" if none).
export DESIGN_INSTRUCTIONS="<DETAILED_DESIGN_INSTRUCTIONS_FROM_STEP_5_1>"
export INSPIRATION_JSON='<INSPIRATION_ARRAY_JSON_OR_[]>'

# Build assets object — use repr() so output is valid Python (None, not null)
# Includes 'inspiration' key populated from $INSPIRATION_JSON (parsed to a Python list).
if [ -n "$PRODUCT_IMAGE_URL" ]; then
  ASSETS_JSON=$(python3 -c "
import json, os
insp = json.loads(os.environ.get('INSPIRATION_JSON', '[]'))
print(repr({'images': [{'url': '$PRODUCT_IMAGE_URL', 'imagePreference': {'crop': None, 'removeBg': None}}], 'logos': [], 'icons': [], 'inspiration': insp}))
")
else
  ASSETS_JSON=$(python3 -c "
import json, os
insp = json.loads(os.environ.get('INSPIRATION_JSON', '[]'))
print(repr({'images': [], 'logos': [], 'icons': [], 'inspiration': insp}))
")
fi

# Build settings JSON — colors and fontGroups are always present
# Use brand colors if found in brand.md; otherwise generate a palette relevant to the copy
# Use brand fonts if found in brand.md; otherwise decide Google font names and query via API

# Step 1: If no brand colors, generate a relevant palette from the product/campaign text
# (agent analyzes the copy and picks 2-4 hex colors that fit the tone)

# Step 2: If no brand fonts, decide Google font names for heading, subHeading, body
# based on the copy tone, then query each via Sivi Get Fonts API to get the font id
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

# Build NO_IMG_ASSETS_JSON — same inspiration array, but no product image (used by Brand Logo Header and Comparison Table).
NO_IMG_ASSETS_JSON=$(python3 -c "
import json, os
insp = json.loads(os.environ.get('INSPIRATION_JSON', '[]'))
print(repr({'images': [], 'logos': [], 'icons': [], 'inspiration': insp}))
")

# Module 1: Brand Logo Header (600x180)
# NOTE: Uses <NO_IMG_ASSETS_JSON> (no product image but WITH inspiration array).
# designInstructions is MANDATORY — same string used across all six modules.
python3 << 'PYEOF' > /tmp/sivi_aplus_payload_1.json
import json
content = {
    "title": "<BRAND_NAME>",
    "text": "<BRAND_TAGLINE>"
}
data = {
    "name": "A+ Brand Logo Header - <PRODUCT_NAME>",
    "type": "custom",
    "subtype": "custom",
    "dimension": {"width": 600, "height": 180},
    "content": content,
    "designInstructions": "<DESIGN_INSTRUCTIONS_VERBATIM>",
    "assets": <NO_IMG_ASSETS_JSON>,
    "language": "english",
    "numOfVariants": 1,
    "outputFormat": ["jpg"],
    "settings": <SETTINGS_JSON>
}
print(json.dumps(data))
PYEOF

# Module 2: Hero Image (970x600)
python3 << 'PYEOF' > /tmp/sivi_aplus_payload_2.json
import json
content = {
    "title": "<PRODUCT_HEADLINE>",
    "text": "<VALUE_PROPOSITION>",
    "offer": "<KEY_BENEFIT>"
}
data = {
    "name": "A+ Hero Image - <PRODUCT_NAME>",
    "type": "custom",
    "subtype": "custom",
    "dimension": {"width": 970, "height": 600},
    "content": content,
    "designInstructions": "<DESIGN_INSTRUCTIONS_VERBATIM>",
    "assets": <ASSETS_JSON>,
    "language": "english",
    "numOfVariants": 1,
    "outputFormat": ["jpg"],
    "settings": <SETTINGS_JSON>
}
print(json.dumps(data))
PYEOF

# Module 3: Feature Highlights (970x600)
python3 << 'PYEOF' > /tmp/sivi_aplus_payload_3.json
import json
content = {
    "title": "Key Features",
    "imagetitletextlist": [
        {"title": "<FEATURE_1_TITLE>", "text": "<FEATURE_1_DESC>"},
        {"title": "<FEATURE_2_TITLE>", "text": "<FEATURE_2_DESC>"},
        {"title": "<FEATURE_3_TITLE>", "text": "<FEATURE_3_DESC>"},
        {"title": "<FEATURE_4_TITLE>", "text": "<FEATURE_4_DESC>"}
    ]
}
data = {
    "name": "A+ Feature Highlights - <PRODUCT_NAME>",
    "type": "custom",
    "subtype": "custom",
    "dimension": {"width": 970, "height": 600},
    "content": content,
    "designInstructions": "<DESIGN_INSTRUCTIONS_VERBATIM>",
    "assets": <ASSETS_JSON>,
    "language": "english",
    "numOfVariants": 1,
    "outputFormat": ["jpg"],
    "settings": <SETTINGS_JSON>
}
print(json.dumps(data))
PYEOF

# Module 4: Comparison Table (970x600)
python3 << 'PYEOF' > /tmp/sivi_aplus_payload_4.json
import json
content = {
    "title": "How We Compare",
    "titletextlist": [
        {"title": "<FEATURE>", "text": "<OUR_PRODUCT> vs <COMPETITOR_1> vs <COMPETITOR_2>"},
        {"title": "<FEATURE>", "text": "<OUR_PRODUCT> vs <COMPETITOR_1> vs <COMPETITOR_2>"},
        {"title": "<FEATURE>", "text": "<OUR_PRODUCT> vs <COMPETITOR_1> vs <COMPETITOR_2>"}
    ]
}
data = {
    "name": "A+ Comparison Table - <PRODUCT_NAME>",
    "type": "custom",
    "subtype": "custom",
    "dimension": {"width": 970, "height": 600},
    "content": content,
    "designInstructions": "<DESIGN_INSTRUCTIONS_VERBATIM>",
    "assets": <NO_IMG_ASSETS_JSON>,
    "language": "english",
    "numOfVariants": 1,
    "outputFormat": ["jpg"],
    "settings": <SETTINGS_JSON>
}
print(json.dumps(data))
PYEOF

# Module 5: Lifestyle Image (970x600)
python3 << 'PYEOF' > /tmp/sivi_aplus_payload_5.json
import json
content = {
    "title": "<LIFESTYLE_HEADLINE>",
    "text": "<LIFESTYLE_DESCRIPTION>",
    "caption": "<USE_SCENARIO>"
}
data = {
    "name": "A+ Lifestyle Image - <PRODUCT_NAME>",
    "type": "custom",
    "subtype": "custom",
    "dimension": {"width": 970, "height": 600},
    "content": content,
    "designInstructions": "<DESIGN_INSTRUCTIONS_VERBATIM>",
    "assets": <ASSETS_JSON>,
    "language": "english",
    "numOfVariants": 1,
    "outputFormat": ["jpg"],
    "settings": <SETTINGS_JSON>
}
print(json.dumps(data))
PYEOF

# Module 6: Spec Sidebar (970x300)
python3 << 'PYEOF' > /tmp/sivi_aplus_payload_6.json
import json
content = {
    "title": "Technical Specifications",
    "bulletlist": [
        "<SPEC_1>",
        "<SPEC_2>",
        "<SPEC_3>",
        "<SPEC_4>"
    ]
}
data = {
    "name": "A+ Spec Sidebar - <PRODUCT_NAME>",
    "type": "custom",
    "subtype": "custom",
    "dimension": {"width": 970, "height": 300},
    "content": content,
    "designInstructions": "<DESIGN_INSTRUCTIONS_VERBATIM>",
    "assets": <ASSETS_JSON>,
    "language": "english",
    "numOfVariants": 1,
    "outputFormat": ["jpg"],
    "settings": <SETTINGS_JSON>
}
print(json.dumps(data))
PYEOF

echo "PAYLOADS_READY"
```

**Payload notes:**
- Replace all `<PLACEHOLDER>` values with the actual approved copy and product details.
- The `<ASSETS_JSON>` placeholder is replaced with the Python-built assets JSON string (containing the product image URL if provided). It includes `inspiration` populated from `INSPIRATION_JSON`.
- The `<NO_IMG_ASSETS_JSON>` placeholder (used by Brand Logo Header and Comparison Table) is `{'images': [], 'logos': [], 'icons': [], 'inspiration': <INSPIRATION_LIST>}` — same inspiration array as the other modules, just no product image.
- The `<BRAND_ID>` placeholder is replaced with the actual brand ID.
- All modules use `designs-from-content` API (content mode) for pixel-faithful text rendering.
- The Brand Logo Header module does not include the product image — it's a clean brand banner.
- The Comparison Table module does not include images — it's a text-based comparison layout.
- **`designInstructions`** is MANDATORY and always present in every module payload as a top-level field. Replace the `<DESIGN_INSTRUCTIONS_VERBATIM>` placeholder in every module with the exact detailed string authored in Step 5.1 (properly JSON-escaped for embedding in the Python-quoted string). The same string is used across all six modules — do not vary it per module. This is the primary mechanism for keeping all A+ module sizes in a consistent visual style.
- **`assets.inspiration`**: always present in every payload via `<ASSETS_JSON>` / `<NO_IMG_ASSETS_JSON>` — empty array when the user did not share references, otherwise the shared list of `{"url": "..."}` entries.

### 8. Execute designs

`generate-design` is the base skill for all composites. For each module payload, follow the `generate-design` skill's submit-and-poll pattern (see `_shared/submit-and-poll-content.sh`). For each A+ module:
1. Submit the payload to `designs-from-content`
2. Poll `get-request-status` until `completed` or `failed`
3. Download all variants and options to `OUTPUT_DIR`
4. Repeat for the next module

### 9. Write A+ content result HTML

After all designs are downloaded, write `brands/<slug>/campaigns/amazon-a-plus-<product>.html`.

**Read the shared template at `_shared/campaign-result.html`** to get the full HTML skeleton with styles. Replace the `{{PLACEHOLDER}}` tokens with actual values:

- `{{CAMPAIGN_NAME}}` — "Amazon A+ Content: <Product Name>"
- `{{BRAND_NAME}}` — resolved brand name
- `{{DATE}}` — generation date
- `{{CHANNELS}}` — "A+ Content Modules" (or list of module names)
- `{{BRIEF_TEXT}}` — product description and key features
- `{{SUMMARY_TEXT}}` — 1-2 sentence summary

For each A+ module (Brand Logo Header, Hero Image, Feature Highlights, Comparison Table, Lifestyle Image, Spec Sidebar), repeat the `.design-group` block:
- `{{CHANNEL_NAME}}` — module name (e.g., "Brand Logo Header", "Hero Image")
- `{{WIDTH}}`, `{{HEIGHT}}` — module dimensions
- For each option (base variant = Option 1, `options[]` sub-variants = Option 2+), repeat the `.design-card` block:
  - `{{OPTION_NUMBER}}` — 1, 2, 3, etc.
  - `{{VARIANT_IMAGE_URL}}` — remote `variantImageUrl` from the API response
  - `{{VARIANT_EDIT_LINK}}` — remote `variantEditLink` from the API response

**Do NOT hardcode the HTML or styles** — always read `_shared/campaign-result.html` and use it as the template.

After writing the file, **open it in the user's browser** using the platform-appropriate command:
- macOS: `open brands/<slug>/campaigns/amazon-a-plus-<product>.html`
- Linux: `xdg-open brands/<slug>/campaigns/amazon-a-plus-<product>.html`
- Windows (Git Bash / WSL): `start brands/<slug>/campaigns/amazon-a-plus-<product>.html`

### 10. Display results

For each module, list all designs uniformly as Option 1, Option 2, ... Option N:
1. The base variant is Option 1. Each sub-variant from the variant's `options[]` array is Option 2, 3, etc.
2. For each option: read the image file, render `<img src="</absolute/path>" alt="<module name> Option N" style="box-shadow: 0px 0px 18px rgba(0,0,0,0.18);">`, print `Design size: <width> x <height>`, print `[Edit](<editLink>)`.
3. The number of options varies per module — display whatever was returned (1 or more).
4. Write a summary covering all modules.

**⚠️ ALWAYS download and display all options.** The base variant and every sub-variant from `options[]` are all equal-ranking options. Never skip any.

### 11. Handle errors

- On 401: "Your SIVI_API_KEY is missing or invalid."
- On 402: "Insufficient Sivi credits. This A+ content needs <N> credits."
- On 422: "Invalid input for module <N>: <error>. Check dimensions and content."
- On 500: "Sivi server errored on module <N>. Retrying..."
- On failed status (via `get-request-status`): "Module <N> failed: <reason>. Proceeding with successful modules."

**Failed design detection:** Polling uses `get-request-status` which returns `status: "failed"` with a `reason` field. Stop polling failed designs immediately and surface the reason to the user.

## Notes

- All modules use `designs-from-content` API for pixel-faithful text rendering — A+ content requires precise text placement.
- The product image is passed as an asset to Hero Image, Feature Highlights, Lifestyle Image, and Spec Sidebar modules. The Brand Logo Header and Comparison Table modules do not include the product image.
- Amazon A+ content has strict dimension requirements — the dimensions specified above are the standard A+ module sizes. Do not change them.
- The product slug is derived from the product name (e.g., "Wireless Earbuds Pro" → "wireless-earbuds-pro").
- For local product images or product/webpage URLs, use `handle-media` to resolve them. Fall back to `curl + grep` extraction only if `handle-media` fails for webpage URLs.
- Enhancement is optional — only route through `enhance-media` if the user agrees or the image quality is poor.
- If some modules fail while others succeed, still write results for successful modules and note failures in the summary.
- Variant count tolerance: some modules may return fewer variants than requested — proceed with what's returned.
- **Options (sub-variants) are always downloaded and displayed.** Each variant may have an `options[]` array. The submit-and-poll script downloads these as `<designId>_<urlId>_v<N>_opt<M>.jpg`. Always include them in the result HTML and display output.
- **Product images must be extracted and passed as assets** when a product URL is provided. Do not submit designs with empty `assets.images` unless the user explicitly confirms no image is available.
- After generation, the user needs to manually upload the images to Amazon Seller Central > A+ Content Manager and arrange them into modules. The generated images match the exact dimensions required by each A+ module type.
- Use `settings.mode: "brand"` + `currentbId` for all module requests when a brand is active. `colors` and `fontGroups` MUST always be present in settings — use brand-extracted values from `brand.md` when available; otherwise generate a color palette relevant to the copy and fetch fonts from the Sivi Get Fonts API (`POST font/get`).
- If the user doesn't specify which modules to generate, default to all six.
