# Sivi - Design Agent Skills

Skills for AI agents to generate production-ready design assets such as ads, social posts, banners, thumbnails, and more using [Sivi](https://sivi.ai)'s Large Design Model (LDM).

### generate-design
Generate design assets from a text prompt. Supports 60+ formats across Instagram, Facebook, Twitter, LinkedIn, Pinterest, YouTube, Display Ads, Amazon, Email, and custom dimensions. Returns multiple variants with preview images and edit links.

```
/generate-design A bold Instagram post announcing 30% off summer collection
```

## Installation
```
npx skills add sivi/skills
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
- "Create four different Facebook ads. Headline: Refined Sanctuary, Description: Transform your home with KraftHaus Living., Button: Explore Now. Use Logo from https://media.hellosivi.com/logos/s6FVztpTVjO.svg. Brand Colors: #CAAB75, #F8F8F8, #000000"
- "Make a YouTube thumbnail for a cooking tutorial. Use colors red and yellow."
- "Create a 1200x600 website hero banner for my SaaS landing page. Logo: https://i.postimg.cc/HLsyY1yQ/334741881-132153419591441-4888262822416491172-n-jpg-stp-dst-jpg-s150x150-tt6-efg-ey-J2ZW5jb2Rl-X3Rh.jpg"
- "Design 3 Instagram story ads for a fitness app launch. Headline: Your Journey Starts Here. Colors: #FF6B35, #1A1A2E, #FFFFFF"
- "Generate a Pinterest pin for a vegan recipe blog. Use a dark theme with colors #2D5016, #F5E6CC, and #FFFFFF"
- "Create a LinkedIn banner for a tech startup. Headline: Building the Future of AI. Logo: https://i.postimg.cc/HLsyY1yQ/334741881-132153419591441-4888262822416491172-n-jpg-stp-dst-jpg-s150x150-tt6-efg-ey-J2ZW5jb2Rl-X3Rh.jpg. Colors: #0A66C2, #FFFFFF, #000000"
- "Make 2 Amazon product ad variants in square. Title: Premium Wireless Earbuds."
- "Design an email header image, 600 x 250. Headline: Exclusive Summer Sale. Theme: colorful. Colors: #E91E63, #FFC107, #4CAF50"

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
- **Variants** - Generate 1–4 design variants per request
- **Brand colors** - Pass hex codes for on-brand output
- **Theme** - Light, dark, or colorful
- **Assets** - Include your own logos and images (public URLs)
- **Language** - Generate text in any supported language
- **Output format** - JPG or PNG

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
