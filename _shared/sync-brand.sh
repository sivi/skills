#!/bin/bash
# sync-brand.sh — Create a local brand folder from Sivi get-brands API data.
# Called after get-brands.sh finds a brand that doesn't have a local folder.
#
# Usage:
#   bash _shared/sync-brand.sh <slug> <bId> <name> <description> <url> <colors_csv> <logos_csv> <emotions_csv> <industry> <audience_csv> <design_tags_csv>
#
# Creates brands/<slug>/ with assets/ and campaigns/ subdirs.
# Downloads logo if URL is available.
# Outputs: BRAND_DIR=<path> and LOGO_SAVED=<path|none>

set -e

BRAND_SLUG="$1"
BRAND_ID="$2"
BRAND_NAME="$3"
BRAND_DESCRIPTION="$4"
BRAND_URL="$5"
BRAND_COLORS="$6"
BRAND_LOGOS="$7"
BRAND_EMOTIONS="$8"
BRAND_INDUSTRY="$9"
BRAND_AUDIENCE="${10}"
BRAND_DESIGN_TAGS="${11}"

BRANDS_DIR="$(dirname "$0")/../brands"
BRAND_DIR="$BRANDS_DIR/$BRAND_SLUG"
ASSETS_DIR="$BRAND_DIR/assets"
CAMPAIGNS_DIR="$BRAND_DIR/campaigns"

mkdir -p "$ASSETS_DIR"
mkdir -p "$CAMPAIGNS_DIR"

# Download first logo if available
LOGO_SAVED="none"
if [ -n "$BRAND_LOGOS" ] && [[ "$BRAND_LOGOS" == https://* ]]; then
  FIRST_LOGO=$(echo "$BRAND_LOGOS" | cut -d',' -f1)
  LOGO_EXT=$(basename "$FIRST_LOGO" | sed 's/.*\.//' | tr -cd '[:alnum:]')
  if [ -z "$LOGO_EXT" ]; then
    LOGO_EXT="png"
  fi
  curl -sL -o "$ASSETS_DIR/logo.$LOGO_EXT" "$FIRST_LOGO"
  LOGO_SAVED="$ASSETS_DIR/logo.$LOGO_EXT"
fi

echo "BRAND_DIR=$BRAND_DIR"
echo "LOGO_SAVED=$LOGO_SAVED"
echo "BRAND_ID=$BRAND_ID"
echo "BRAND_NAME=$BRAND_NAME"
echo "BRAND_DESCRIPTION=$BRAND_DESCRIPTION"
echo "BRAND_URL=$BRAND_URL"
echo "BRAND_COLORS=$BRAND_COLORS"
echo "BRAND_EMOTIONS=$BRAND_EMOTIONS"
echo "BRAND_INDUSTRY=$BRAND_INDUSTRY"
echo "BRAND_AUDIENCE=$BRAND_AUDIENCE"
echo "BRAND_DESIGN_TAGS=$BRAND_DESIGN_TAGS"
