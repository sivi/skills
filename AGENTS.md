This file provides guidance to AI agents when working with code in this repository.

## Overview

This is a skills repository for AI agents (Claude Code, Cursor, Copilot, Windsurf, Cline, etc.) to generate production-ready design assets using the Sivi API. It contains no application code — only skill definition files (`SKILL.md`) that teach AI agents how to call the Sivi Core API via bash scripts.

Skills are installed by users via `npx skills add sivi/skills` (see [skills.sh](https://skills.sh/)).

## Repository Structure

Each skill lives in its own directory with a `SKILL.md` file containing frontmatter metadata and API documentation:

```
generate-design/SKILL.md   — design generation skill definition
```

## Skill File Format

`SKILL.md` files use YAML frontmatter with these fields:

- **`name`**, **`description`** — skill identity
- **`argument-hint`** — example argument format for the skill

The body is markdown documentation that agents consume to learn the API workflow, including step-by-step bash script templates, argument parsing rules, error handling, and result display instructions.

## Conventions

- **Spelling**: "Sivi" (capital S). The API base URL is `https://connect.sivi.ai`.
- **API key**: Always sourced from `.env` via `$SIVI_API_KEY` — never hardcoded.
- **Cross-platform**: Scripts must work on macOS, Linux, and Windows (Git Bash / WSL). Never use `head -n -1` or `jq`. Use `python3` for JSON parsing and `curl -o` for response handling.
- **License**: MIT
