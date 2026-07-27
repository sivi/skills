---
name: get-fonts
description: Use when someone asks to search for fonts, list available fonts, find a font by name, browse font families, or check what fonts are available in Sivi. Also use when the user mentions 'get fonts,' 'find font,' 'search fonts,' 'list fonts,' 'available fonts,' 'font by name,' 'what fonts can I use,' 'show me fonts,' 'sans-serif fonts,' 'serif fonts,' 'handwriting fonts,' 'display fonts,' 'monospace fonts,' or 'system fonts.' Queries the Sivi font library by name, classification, or source. Returns font ID, name, and classification for each match. For uploading custom fonts, see upload-fonts (coming soon). For using fonts in brand profiles, see manage-brand.
argument-hint: [font name to search, optional classification filter, optional source filter]
---

## What This Skill Does

A Layer 1 atomic engine that queries the Sivi font library via `POST font/get`. Supports filtering by:

- **Name** — partial or full font name (e.g., "Roboto", "Open", "Montserrat")
- **Classification** — font category: `serif`, `sans-serif`, `display`, `handwriting`, `monospace`
- **Source** — `system` (built-in Google Fonts) or `user` (uploaded custom fonts)

Returns a list of matching fonts with their `id`, `name`, and `classification`. Supports pagination via cursor.


## ⚠️ Cross-Platform Compatibility — MANDATORY

- **NEVER use `head -n -1`** or `jq`. Use `python3` for JSON parsing.
- **ALWAYS use `curl -o <file> -w '%{http_code}'`** to separate HTTP status from response body.
- **Temp files**: Use `/tmp/`.


## Steps

### 1. Parse arguments

- `name` — font name to search for (optional). Supports partial matches.
- `classification` — array of font categories to filter by (optional). Valid values: `serif`, `sans-serif`, `display`, `handwriting`, `monospace`.
- `source` — font source filter (optional). `system` for built-in Google Fonts, `user` for uploaded custom fonts. Default: no filter (returns all).
- `limit` — number of results per page (optional, default: `20`).

If no arguments are provided, ask: "What font are you looking for? You can search by name (e.g., 'Roboto'), classification (serif, sans-serif, display, handwriting, monospace), or source (system, user)."

### 2. Query the Sivi font library

Call `POST font/get` with the provided filters.

```bash
#!/bin/bash
set -e
source <SKILL_REPO>/.env

FONT_NAME="<FONT_NAME_OR_OMIT>"
CLASSIFICATION="<CLASSIFICATION_OR_OMIT>"
SOURCE="<system_OR_user_OR_OMIT>"
LIMIT="<LIMIT_OR_20>"
CURSOR="<CURSOR_OR_NULL>"

PAYLOAD=$(python3 -c "
import json
data = {
    'limit': $LIMIT,
    'cursor': '$CURSOR' if '$CURSOR' and '$CURSOR' != 'null' else None
}
name = '''$FONT_NAME'''
if name:
    data['name'] = name
classification = '''$CLASSIFICATION'''
if classification:
    data['classification'] = [classification]
source = '''$SOURCE'''
if source:
    data['source'] = source
print(json.dumps(data))
")

HTTP_CODE=$(curl -s -o /tmp/sivi_fonts_response.json -w '%{http_code}' \
  -X POST "https://connect.sivi.ai/api/prod/v2/general/font/get" \
  -H "Content-Type: application/json" \
  -H "sivi-api-key: $SIVI_API_KEY" \
  -d "$PAYLOAD")

BODY=$(cat /tmp/sivi_fonts_response.json)

if [ "$HTTP_CODE" != "200" ]; then
  echo "ERROR: HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

python3 -c "
import json, sys
d = json.load(sys.stdin)
fonts = d.get('body', {}).get('data', [])
cursor = d.get('body', {}).get('meta', {}).get('cursor')
if not fonts:
    print('No fonts found matching your criteria.')
else:
    for f in fonts:
        print(f\"- {f.get('name', '')} (id: {f.get('id', '')}, classification: {f.get('classification', '')})\")
if cursor:
    print(f\"\\nMORE_RESULTS_CURSOR={cursor}\")
" <<< "$BODY"
```

### 3. Handle pagination

If the response includes a `cursor` value, there are more results available. If the user wants to see more, re-run the script with `CURSOR` set to the returned cursor value.

### 4. Display results to user

Present the font list in a readable format:

```
Found N fonts:

1. Roboto (id: f_abc123, classification: sans-serif)
2. Open Sans (id: f_def456, classification: sans-serif)
3. Playfair Display (id: f_ghi789, classification: serif)
```

If a cursor was returned, inform the user: "More results available. Ask to see more and I'll fetch the next page."

### 5. Handle errors

| HTTP Code | Meaning | User Message |
|---|---|---|
| 401 | Authentication failed | "Your SIVI_API_KEY is missing or invalid. Check your .env file." |
| 422 | Invalid input | "Invalid input: <error message from API>. Check the font name and filters." |
| 500 | Server error | "Sivi server errored. Please retry in a moment." |

## Notes

- The `name` parameter supports partial matching — searching "Open" will return "Open Sans", "Open Sans Condensed", etc.
- `source: "system"` returns built-in Google Fonts available in Sivi (free, enabled fonts).
- `source: "user"` returns fonts uploaded by the authenticated user.
- Results are paginated — use the returned `cursor` value in subsequent requests to fetch more results.
- The font `id` returned can be used when specifying fonts in brand profiles or design requests.
- Classification values: `serif`, `sans-serif`, `display`, `handwriting`, `monospace`.
- The `font/get` API docs: https://developer.sivi.ai/docs/sivi-api/core-api/fonts/get-fonts
