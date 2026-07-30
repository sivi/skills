# Sivi — Brand Marketing Skills for AI Agents

A skill system for AI agents (Claude Code, Cursor, Copilot, Windsurf, Cline, etc.) to generate fully-editable, production-ready design assets and manage brand marketing campaigns using [Sivi](https://sivi.ai)'s Large Design Model (LDM).

## Installation

```
npx skills add sivi/skills
```

Works with Claude Code, Cursor, GitHub Copilot, Windsurf, Cline, and [17+ other AI agents](https://skills.sh/).

## Setup

1. Get your API key from [sivi.ai](https://sivi.ai)
2. Run the **setup-sivi** skill once — ask your AI agent:

   > "Set up Sivi with my API key"

   It creates `.env` (from `.env.example`) inside the `setup-sivi` skill and saves your key. Every other Sivi skill finds this one `.env` automatically — you never copy it or configure keys per skill.

   Prefer to do it by hand? Copy `setup-sivi/.env.example` to `setup-sivi/.env` and set your key:

```bash
export SIVI_API_KEY="your-api-key-here"
```

## Skills

| Skill | Purpose | Trigger Examples | Status |
|---|---|---|---|
| **brand-context** | Extract brand identity from a website URL, register with Sivi, save to `brands/<slug>/brand.md` | "Set up my brand", "extract brand from URL", "brand setup" | Coming soon |
| **generate-design** | Orchestrates: copy generation → media enhancement (optional) → design generation via Sivi API. Supports prompt mode and content mode | "Create an Instagram post", "make a Facebook ad", "design from my copy" | Available |
| **write-copy** | Generate 2 structured copy variations only (no API, no design). For standalone copy needs | "Write ad copy", "headline ideas", "just the copy" | Available |
| **handle-media** | Lightweight image resolver: resolves local files, image URLs, product/webpage URLs, or AI generation into Sivi media references | "Resolve this image", "upload photo for design" | Available |
| **enhance-media** | AI image generation and enhancement (background removal, quality improvement) | "Enhance my photo", "generate an image", "remove background" | Available |
| **brand-assets** | Upload local files to Sivi via presigned URL, register in media library | "Upload image", "add logo to brand", "use local file for design" | Coming soon |
| **manage-brand** | List, update, switch, or archive brand profiles | "List my brands", "update brand colors", "switch brand" | Coming soon |
| **create-campaign** | One brief → complete multi-channel creative set (IG, FB, LinkedIn, YouTube, email, display) | "Multi-channel campaign", "ads for all platforms", "creative set" | Coming soon |
| **create-a-plus-content** | Product brief → complete Amazon A+ content module set (logo, hero, features, comparison, lifestyle, specs) | "Amazon A+ content", "EBC", "enhanced brand content", "A+ modules" | Coming soon |

## Quick Start

### 1. Set up a brand (one-time per brand) — *coming soon*

Ask your AI agent:
> "Set up a brand from https://example.com"

This extracts brand identity (colors, fonts, logo, persona) and saves it to `brands/example/brand.md`. All subsequent design skills will use this brand automatically.

### 2. Generate a design

> "Create an Instagram post for my summer sale — 30% off, targeting women 25-40."

### 3. Write copy

> "Write ad copy for my fitness app. Test different headlines."

### 4. Multi-channel campaign — *coming soon*

> "Create a multi-channel campaign for my summer sale — 30% off, targeting women 25-40. I need Instagram, Facebook, and email."

## Multi-Brand Workspace

An agency can work with multiple brands. Each brand gets its own folder:

```
brands/
├── acme-co/
│   ├── brand.md          ← brand identity + Sivi brandId
│   ├── assets/           ← logo, product images
│   └── campaigns/        ← creative output as .html files
│       ├── summer-sale-2025.html
│       └── ab-test-headlines.html
├── globex/
│   ├── brand.md
│   ├── assets/
│   └── campaigns/
└── _index.md             ← auto-generated brand index
```

### Campaign Results

Campaign outputs are saved as HTML files with embedded designs and edit buttons:

```html
### Instagram Post (1080 x 1080)

<img src="https://resources.hellosivi.com/.../ig-post_v1.jpg" alt="Instagram Post" style="box-shadow: 0px 0px 18px rgba(0,0,0,0.18);">

<a class="edit-link" href="https://instant.sivi.ai/#/variant/abc123/independent-design-editor">Edit this design</a>
```

The HTML file is the single source of truth — open it in any browser to see all designs with edit links.

## Supported Platforms

| Platform | Formats |
|----------|---------|
| Instagram | Post, Ad, Story |
| Facebook | Post, Ad, Cover |
| Twitter / X | Post, Ad, Cover |
| LinkedIn | Post, Ad, Cover, Banner |
| Pinterest | Pin (small), Standard Pin |
| WhatsApp | Post, Wide Post, Status, Business Cover |
| YouTube | Thumbnail |
| Display Ads | Half-page, Rectangle, Square, Skyscraper, Leaderboard, Banner |
| Amazon | Ad, Fullscreen, Square, Rectangle, Standard |
| Website | Rectangle, Square, Fullscreen HD, Half-page, Hello Bar |
| Email | Square, Tall, Rectangle, Wide, Small |
| Custom | Any width × height (200–2000px) |

## Structure

Skills install as flat siblings (`.agents/skills/<skill>/`, mirrored by symlinks under `.claude/skills/`). There is no repo root on the user's machine, so the shared surface — the single `.env` and the `_shared/` reference files — lives inside the **setup-sivi** skill. Every other skill resolves it at runtime as `$SIVI_HOME`; nothing is copied.

```
skills/
  setup-sivi/                 ← run once; the shared home
    SKILL.md                  ← env setup
    .env.example              ← copied to setup-sivi/.env at setup
    _shared/                  ← referenced in place by every skill (no copies)
      conventions.md
      channel-matrix.md
      content-generation.md
      submit-and-poll-content.sh
      submit-and-poll-prompt.sh
      campaign-result.html
  generate-design/SKILL.md
  handle-media/SKILL.md
  write-copy/SKILL.md
  brand-context/SKILL.md          ← coming soon
  enhance-media/SKILL.md
  brand-assets/SKILL.md           ← coming soon
  manage-brand/SKILL.md           ← coming soon
  create-campaign/SKILL.md        ← coming soon
  create-a-plus-content/SKILL.md  ← coming soon
```

## Prerequisites

- Python 3 (pre-installed on macOS and most Linux)
- curl (pre-installed on macOS, Linux, Git Bash)
- [Sivi API key](https://sivi.ai)

## License
MIT
