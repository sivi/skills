# Sivi Agent Skills

Skills for AI agents to generate production-ready design assets using [Sivi](https://sivi.ai) — ads, social posts, banners, thumbnails, and more from natural language.

### generate-design
Generate design assets from a text prompt. Supports 60+ formats across Instagram, Facebook, Twitter, LinkedIn, Pinterest, YouTube, Display Ads, Amazon, Email, and custom dimensions. Returns multiple variants with preview images and edit links.

```
/generate-design A bold Instagram post announcing 30% off summer collection
```

## Installation
```
npx skills add sivi-ai/design-skills
```

Works with Claude Code, Cursor, GitHub Copilot, Windsurf, Cline, and [17+ other AI agents](https://skills.sh/).

## Setup

1. Get your API key from [sivi.ai](https://sivi.ai)
2. Add it to `.claude/skills/generate-design/.env`:

```bash
export SIVI_API_KEY="your-api-key-here"
```

## Usage
Ask your AI agent:
- "Generate an Instagram story for our summer sale"
- "Create a Facebook ad for a coffee shop grand opening"
- "Design a LinkedIn post announcing our Series A"
- "Make a YouTube thumbnail for a cooking tutorial"
- "Create a 1920x600 website hero banner for my SaaS landing page"

### Supported Platforms

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
| Custom | Any width × height |

### Options
- **Variants** — Generate 1–4 design variants per request
- **Brand colors** — Pass hex codes for on-brand output
- **Theme** — Light, dark, or colorful
- **Assets** — Include your own logos and images (public URLs)
- **Language** — Generate text in any supported language
- **Output format** — JPG or PNG

## Structure
```
.claude/skills/
  generate-design/
    SKILL.md
    .env
```

## Prerequisites
- Python 3 (pre-installed on macOS and most Linux)
- curl (pre-installed on macOS, Linux, Git Bash)
- [Sivi API key](https://sivi.ai)

## License
MIT
