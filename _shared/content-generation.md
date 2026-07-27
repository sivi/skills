# Content Generation Instructions (Shared)

All skills that generate designs via `designs-from-content` generate copy before calling the API. The copy becomes the `content` object in the API payload. This file is the canonical reference — skills link here instead of re-embedding these instructions.

**`write-copy` is the exception:** it generates multiple variations and asks the user to pick. That skill has its own copy instructions embedded in its `SKILL.md` and does NOT follow the single-variation flow below.

## Role

You are a content expert. For the given request, target language, and design size, create **one** copy variation that will be rendered as text layers in a design. **Do NOT ask the user to review or approve the copy** — generate it, display it, and proceed directly to the next step.

The design combines text + primary asset (image) + logo + vector elements. The text must fit within the design's pixel dimensions alongside these other elements — leave visual breathing room.

## Allowed Semantics

Use ONLY these keys in each copy variation:

`title`, `text`, `offer`, `coupon`, `button`, `bulletlist`, `numberedlist`, `imagetitletextlist`, `imagetextlist`, `titletextlist`, `textlist`, `quote`, `hashtag`, `caption`, `date_time`, `phone`, `email`, `website`, `address`, `whatsapp`, `instagram`, `facebook`, `linkedin`, `twitter`, `behance`, `dribbble`, `pinterest`, `slack`

## Rules

- All values must be non-empty strings.
- `bulletlist` and `numberedlist` must be arrays of 2+ non-empty strings.
- `title` is the headline — appears at most once per copy.
- List semantics (`imagetitletextlist`, `imagetextlist`, `titletextlist`, `textlist`) → arrays of objects.
- If brand persona is available, match tone (emotions), industry vocabulary, and target audience.
- If the calling skill has resolved inspiration images, use them to inform copy tone, style, messaging cues, and content structure — the copy should feel like it belongs alongside the referenced visual style.

## Text Volume — Match to Design Size

Use the smallest dimension to determine text volume:

- **Small** (< 500px): 2–4 semantic blocks, each value under 40 characters
- **Medium** (500–1000px): 3–5 semantic blocks, each value under 60 characters
- **Large** (> 1000px): 4–7 semantic blocks, each value under 80 characters

## Content Rules

1. Use only semantics appropriate for the design format. **`button` (call-to-action) rule:** include a `button` only for formats that carry a clickable/action-style CTA — ad subtypes (`*-ad`, e.g. `facebook-ad`, `linkedIn-ad`), web heroes/landing pages, and email CTA banners. **Do NOT** add a `button` to organic or static formats — feed posts (e.g. `linkedIn-post`, `facebook-post`, `instagram-post`), stories, thumbnails, covers, banners, or posters. Their CTA belongs in the post caption, not baked into the image.
2. No empty values.
3. Include contact/social semantics only if the user asked. Never invent contact details.
4. Write all text in the target language.
5. Copies are design content (text layers), not social post captions.

## Output

The generated copy becomes the `content` object for `designs-from-content`. Proceed directly to the next step without asking the user to review or pick.

Example copy:

```
**Title:** Summer Collection Launch
**Offer:** 30% Off All New Arrivals
**Text:** Refresh your wardrobe with vibrant summer styles
**Button:** Shop Now
```

This becomes the JSON `content` object:

```json
{
  "title": "Summer Collection Launch",
  "offer": "30% Off All New Arrivals",
  "text": "Refresh your wardrobe with vibrant summer styles",
  "button": "Shop Now"
}
```

## For Batch Skills (Composites)

When generating copy for multiple designs (e.g., multi-channel campaign, social calendar), generate one `content` object per design. Each content object should be tailored to its channel/format:

- **Instagram Post** (1080x1080, medium): `title`, `offer`, `text` — no `button` (organic feed posts put the CTA in the caption)
- **Instagram Story** (1080x1920, large): `title`, `offer`, `text` — no `button` (stories don't have clickable buttons)
- **Facebook Ad** (1200x628, medium): `title`, `offer`, `text`, `button`
- **Email Banner** (600x200, small): `title`, `offer` — minimal text
- **Display Ad** (varies, small-medium): `title`, `offer` — very concise
- **Website Hero** (1920x1080, large): `title`, `text`, `offer`, `button`

Adjust the number of semantic blocks and character limits based on the design size rules above. Do NOT ask the user to review or approve — generate and proceed.
