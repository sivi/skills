---
name: write-copy
description: Use when someone asks to generate ad copy, write headlines, create copy suggestions, or draft marketing text — without generating a design. Also use when the user mentions 'copy suggestions,' 'headline ideas,' 'ad copy,' 'write copy for my ad,' 'content for my design,' 'text for my banner,' 'offer text,' 'bullet points for my ad,' 'CTA text,' or 'what should my ad say.' Generates structured copy variations using content expert instructions — no API call needed. Default is 2 variations; user can request more (e.g., 3–4 for A/B testing). Copy is presented in readable format for user review and edit, with JSON output for use in generate-design. For generating designs (which now includes copy generation as step 1), see generate-design.
argument-hint: "prompt describing the product, offer, or campaign"
---

## What This Skill Does

The agent acts as a content expert and generates copy variations for a design — no API call needed. Default is 2; user can request more (e.g., for A/B testing). The copy uses Sivi's allowed semantics so it can be fed directly to `generate-design` when the user is ready to generate visuals.

This is a **copy-only skill**. It does not call any Sivi API. To generate designs from the approved copy, the user should run `generate-design` with the approved copy.


## Steps

### 1. Parse arguments

- `prompt` — description of the product, offer, or campaign (required).
- `type` — design category for context (default: `custom`)
- `subtype` — format variant (default: `custom`)
- `dimension` — `{width, height}` (only when type is `custom`; default: `{"width": 800, "height": 800}`)
- `language` — language for text (default: `english`)

If `prompt` is missing, ask: "What product or offer would you like copy for? Describe it briefly."

### 2. Resolve brand (if brands/ exists)

Follow the standard brand resolution:
1. Scan for `brands/` directory.
2. Match brand name from prompt, or use single brand, or ask user.
3. Read `brands/<slug>/brand.md` for brandId and brand persona (emotions, industry, audience, designTags).
4. Use the brand persona to inform copy tone and style — the agent incorporates this directly into the generated copy.

### 3. Generate copy variations (agent — no API call)

You are a content expert. For the given request, target language, and design size, create N unique copy variations (default: 2; or the count requested by the user) that will be rendered as text layers in a design.

The design combines text + primary asset (image) + logo + vector elements. The text must fit within the design's pixel dimensions alongside these other elements — leave visual breathing room.

#### Allowed Semantics

Use ONLY these semantics in each copy variation. Never invent new semantics — map any other concept to the closest allowed one.

`title`, `text`, `offer`, `coupon`, `button`, `bulletlist`, `numberedlist`, `imagetitletextlist`, `imagetextlist`, `titletextlist`, `textlist`, `quote`, `hashtag`, `caption`, `date_time`, `phone`, `email`, `website`, `address`, `whatsapp`, `instagram`, `facebook`, `linkedin`, `twitter`, `behance`, `dribbble`, `pinterest`, `slack`

**Rules:**
- All values must be non-empty strings.
- `bulletlist` and `numberedlist` must be arrays of 2+ non-empty strings.
- The same semantic may appear multiple times within a copy (e.g., multiple `text` entries for date, time, location).
- `title` is the headline — as a standalone semantic, it appears at most once per copy. `title` may also appear inside repeating list units.
- Repeating units (speaker portraits, team members, product cards) must use the matching list semantic — an array of objects:
  - `imagetitletextlist`: array of `{ image, title, text }` objects
  - `imagetextlist`: array of `{ image, text }` objects
  - `titletextlist`: array of `{ title, text }` objects
  - `textlist`: array of `{ text }` objects
  - The `image` value is a placeholder: `"image.jpg"` for person photos, `"icon.svg"` for all other icons.
  - `imagetextlist` with `"icon.svg"` can be used instead of `bulletlist` when list items benefit from icons (features, benefits, contact details).

#### Text Volume — Match to Design Size

Use the smallest dimension as your guide:

- **Small (< 500px)**: 2–4 semantic blocks, keep each value under 40 characters
- **Medium (500–1000px)**: 3–5 semantic blocks, keep each value under 60 characters
- **Large (> 1000px)**: 4–7 semantic blocks, keep each value under 80 characters

Less is more — a cramped design is worse than a clean one.

#### Content Rules

1. Use only semantics appropriate for the design format. Do not add `button` or interactive semantics for static formats (thumbnails, covers, posters, banners).
2. No empty values — every semantic must have meaningful, non-placeholder text.
3. Include phone, email, website, address, `date_time`, `offer`, `coupon`, or social profiles only if the user asked. Use handles exactly as provided (no URLs, no @handle). For `whatsapp`, include only the number. Never invent contact details.
4. Each semantic stands alone — no repeated values within a single copy.
5. Write all text in the target language.
6. Copies are design content (text layers in the visual), not social post captions or descriptions.
7. If brand persona is available, match the tone (emotions), industry vocabulary, and target audience.

#### Present the variations

Present the copy variations in a readable format — not JSON. Example (2 variations shown; extend for more):

```
## Copy Variation 1

**Title:** Summer Collection Launch
**Offer:** 30% Off All New Arrivals
**Text:** Refresh your wardrobe with vibrant summer styles
**Button:** Shop Now

## Copy Variation 2

**Title:** Hello Summer
**Offer:** Buy 2 Get 1 Free
**Bulletlist:**
  - 100% organic cotton
  - Free shipping over $50
  - 30-day returns
**Button:** Explore Collection
```

### 4. User reviews and edits

Ask the user:

> "Here are N copy variations. Which one would you like to use? You can also mix and match — pick a title from one and an offer from another, or edit any text."

If the user edits the copy, use their final approved text as the output.

### 5. Output the approved copy

Present the final approved copy in readable format. Also provide the copy in Sivi's JSON content format so the user can feed it directly to `generate-design` (content mode) when they're ready for visuals:

```json
{
  "title": "Summer Collection Launch",
  "offer": "30% Off All New Arrivals",
  "text": "Refresh your wardrobe with vibrant summer styles",
  "button": "Shop Now"
}
```

Tell the user:
> "Copy is ready. To generate designs from this copy, run generate-design with this content."

## Notes

- **No API call** — this skill is copy-only. The agent generates copy directly using the content expert instructions.
- To generate designs from the approved copy, the user runs `generate-design` with the approved copy (content mode auto-detects the semantic format).
- If brand persona is available, the agent matches tone (emotions), industry vocabulary, and target audience.
- User-edited copy always takes priority — use the user's final approved text.
- The JSON content format uses allowed semantics as keys:
  - String semantics (`title`, `text`, `offer`, `coupon`, `button`, `quote`, `caption`, `date_time`, etc.) → string values
  - `bulletlist`, `numberedlist` → array of strings
  - `imagetitletextlist`, `imagetextlist`, `titletextlist`, `textlist` → array of objects
  - Social semantics (`phone`, `email`, `website`, `address`, `whatsapp`, `instagram`, etc.) → string values
- The design size determines text volume — always respect the small/medium/large guidelines when writing copy.
