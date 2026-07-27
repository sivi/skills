---
name: setup-sivi
description: Use once to set up the Sivi skills before generating designs — creates the .env, captures the SIVI_API_KEY, and verifies it works. Also use when the user says 'set up Sivi', 'configure my Sivi API key', 'add my Sivi key', 'Sivi setup', or when another Sivi skill fails with a missing/invalid key (401) or a missing .env. This skill is the canonical home for the shared surface — it holds the one `.env` (API key) and the `_shared/` reference files that every other Sivi skill (generate-design, handle-media, enhance-media, write-copy) points to. Sibling skills never copy these — they resolve this skill's folder at runtime as `$SIVI_HOME`.
argument-hint: "optional: the Sivi API key to write into .env"
---

## What This Skill Does

One-time setup for the Sivi skills. It:

1. Creates `.env` from `.env.example` inside this skill's folder (if it doesn't exist).
2. Captures the user's `SIVI_API_KEY` and writes it into that `.env`.
3. Verifies the key with one lightweight authenticated call to `connect.sivi.ai`.

This skill is also the **shared home**. It owns:
- `.env` — the single API-key file. **Never copied** into other skills; they source it from here.
- `_shared/` — `conventions.md`, `content-generation.md`, `channel-matrix.md`, `submit-and-poll-content.sh`, `submit-and-poll-prompt.sh`, `campaign-result.html`. Every other skill references these in place.

## Why one home, no copies

After `npx skills add sivi/skills`, every skill installs as a flat sibling:

```
.agents/skills/
├── setup-sivi/     ← .env + _shared/ live here (this skill)
├── generate-design/
├── handle-media/
├── enhance-media/
└── write-copy/
```

`.claude/skills/*` are symlinks to the same folders. Because the layout is flat, any skill can resolve this one from either tree — no repo root, no duplicated `.env`, no duplicated `_shared/`. When the CLI updates the skills, there is a single source of truth to update.

## The `$SIVI_HOME` contract

Every sibling skill locates this folder at runtime and sources its `.env`. Because the shell's working directory is the user's project root (not the skill folder), sibling skills must **not** rely on `../setup-sivi` from a bash `cwd`. They use this discovery header, which tries the script's own location first (works when a `_shared/*.sh` script runs in place) and then the known install roots relative to the project cwd:

```bash
# --- locate the Sivi shared home (setup-sivi) → $SIVI_HOME ---
if [ -z "$SIVI_HOME" ]; then
  _sd="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd)"
  for c in "$_sd/.." "$_sd" \
           ".agents/skills/setup-sivi" ".claude/skills/setup-sivi" \
           "$HOME/.agents/skills/setup-sivi" "$HOME/.claude/skills/setup-sivi"; do
    if [ -f "$c/.env" ]; then SIVI_HOME="$(cd "$c" && pwd)"; break; fi
  done
fi
if [ -z "$SIVI_HOME" ]; then
  echo "Sivi is not set up. Run the setup-sivi skill first (it creates .env)." >&2
  exit 1
fi
source "$SIVI_HOME/.env"
```

After this header, `$SIVI_API_KEY` is available and `_shared/` files are at `$SIVI_HOME/_shared/...`. Markdown references to shared docs from a sibling skill use the relative sibling path `../setup-sivi/_shared/<file>` (resolved relative to that skill's own directory).

## Setup Steps

### 1. Create `.env`

This skill's folder is `$SIVI_HOME`. Create the `.env` from the template if missing (never overwrite an existing `.env`):

```bash
SETUP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ ! -f "$SETUP_DIR/.env" ]; then
  cp "$SETUP_DIR/.env.example" "$SETUP_DIR/.env"
  echo "Created $SETUP_DIR/.env"
else
  echo ".env already exists at $SETUP_DIR/.env — leaving it in place."
fi
```

### 2. Capture the API key

- If the user supplied a key as the argument, write it into `.env`.
- Otherwise, ask the user for their key (from [sivi.ai](https://sivi.ai)) and write it.

Write it **without echoing the key** into chat. Replace the placeholder line:

```bash
# KEY is the value the user provided; do not print it back
python3 - "$SETUP_DIR/.env" "$KEY" <<'PY'
import sys
path, key = sys.argv[1], sys.argv[2]
with open(path) as f:
    lines = f.readlines()
out, done = [], False
for ln in lines:
    if ln.strip().startswith("export SIVI_API_KEY="):
        out.append(f'export SIVI_API_KEY="{key}"\n'); done = True
    else:
        out.append(ln)
if not done:
    out.append(f'export SIVI_API_KEY="{key}"\n')
with open(path, "w") as f:
    f.writelines(out)
print("SIVI_API_KEY written.")
PY
```

If the user prefers to paste the key themselves, tell them to open `$SETUP_DIR/.env` and replace `your-api-key-here` with their key, then re-run verification.

### 3. Verify the key

Source the `.env` and make one lightweight authenticated request. Report the outcome by HTTP status, never printing the key:

```bash
source "$SETUP_DIR/.env"
if [ -z "$SIVI_API_KEY" ] || [ "$SIVI_API_KEY" = "your-api-key-here" ]; then
  echo "No API key set yet. Add your key to $SETUP_DIR/.env"
else
  CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "sivi-api-key: $SIVI_API_KEY" \
    "https://connect.sivi.ai/api/v1/brands")
  case "$CODE" in
    200|201) echo "✅ Sivi key verified. Setup complete." ;;
    401|403) echo "❌ Key rejected ($CODE). Check the key in $SETUP_DIR/.env." ;;
    *)       echo "⚠️ Unexpected response ($CODE). Key is set; the API may be unreachable right now." ;;
  esac
fi
```

> If the `/brands` endpoint is not the right verification path for the current API, use any minimal authenticated GET; the goal is only to distinguish a good key (2xx) from a bad key (401/403).

## After Setup

Tell the user setup is done and they can now run `generate-design`, `write-copy`, `handle-media`, or `enhance-media`. Those skills will find this folder automatically via the `$SIVI_HOME` discovery header — no per-skill configuration needed.

## Security Notes

- The key is written only to `$SIVI_HOME/.env`, which is gitignored (`*.env`). It is never copied into other skill folders and never committed.
- Never print the key back into chat or logs. Report verification by HTTP status only.
- The key is only ever sent to `connect.sivi.ai` via the `sivi-api-key` header.
