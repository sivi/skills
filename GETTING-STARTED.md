> **Private:** Please don't share this document or your API key with anyone else.

# Setting Up Sivi Design Skills

Set up the Sivi design skills in Claude Code and create your first designs — no coding experience needed.

## What you need

- **Claude Code** installed ([download here](https://claude.com/claude-code))
- A **Sivi API key** — *(provided to you separately)*

That's it. Everything else installs automatically.

---

## Step 1 — Install the skills

Open Claude Code, open a new folder where you want to work (let's say `sivi-designs`), and paste this in the chat:

```bash
npx skills add sivi/skills
```

This downloads the design skills into your workspace. When it finishes, you'll have `setup-sivi`, `generate-design`, and a few others.

---

## Step 2 — Add your Sivi API key

You add your key **once** and it's saved locally (never shared or uploaded). The easiest way is to let Claude do it — just ask in the chat:

> **Set up Sivi with my API key**

Claude runs the `setup-sivi` skill, which creates the key file for you, asks for your key, saves it, and verifies it works. Paste your key when prompted.

That's it. Every other Sivi skill finds this key automatically — you never set it up again or repeat it per skill.

**Prefer to do it by hand?** The key lives in the `setup-sivi` skill folder. Copy the example file and add your key:

```bash
cp .agents/skills/setup-sivi/.env.example .agents/skills/setup-sivi/.env
```

Open the new `.env` file in any text editor and replace the placeholder with your real key:

```bash
export SIVI_API_KEY="paste-your-sivi-key-here"
```

Save and close. Done.

> **Tip:** Your key stays private — the `.env` file is never committed to git or sent anywhere except Sivi.

---

## Step 3 — Set up the Doqfy brand

This tells the skills to use Doqfy's real colors, fonts, and logo automatically.

Create the brand folder in your working directory:

```bash
mkdir -p brands/doqfy
```

Put the provided `brand.md` file inside `brands/doqfy/`.

That's it — the `brand.md` file already contains everything the skills need (Sivi Brand ID, colors, fonts, logo, and sample images).

---

# Creating Designs

Open Claude Code in this folder and just ask, in plain English. For example:

> Create a LinkedIn post for Doqfy
>
> Make a LinkedIn ad for Doqfy about faster contract approvals
>
> Create an Instagram post for Doqfy — eSign & eStamp in one place

Claude will write the copy, pick an on-brand image and logo, generate the design, show it to you, and open a results page in your browser with a link to edit each design in Sivi.

## Tips for better results

- **Name the format** — "LinkedIn post", "Instagram story", "poster", etc.
- **Give the message** — a headline, an offer, or a call-to-action.
- **Ask for options** — "give me 3 variations" (up to 4).
- **Use your own copy** — paste exact wording and it'll be used as-is, for example:

> Create a Doqfy LinkedIn ad with headline "Sign Contracts in Minutes" and button "Book a Demo"

## Where your designs go

Every design is saved as a web page in `brands/doqfy/campaigns/`. Open any of those pages in a browser to see the designs and click **Edit this design** to fine-tune them in Sivi.
