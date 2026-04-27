#!/usr/bin/env sh
# extract-assets.sh
# Re-runnable POSIX script that produces all committed image artifacts under
# /site/public/assets/. Run from any directory; uses absolute paths throughout.
#
# This script is NOT executed during `pnpm build`. Coolify does not need
# pdftoppm, gh, or python3 installed. The resulting images are committed as
# the source of truth for the build.
#
# Running twice is idempotent: output files are overwritten in place.
# Pre-requisites: pdftoppm (poppler), gh (GitHub CLI), python3+Pillow (PIL),
#                 sips (built-in macOS).

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ASSETS="${REPO_ROOT}/site/public/assets"

echo "=== extract-assets.sh starting ==="
echo "REPO_ROOT: ${REPO_ROOT}"
echo "ASSETS:    ${ASSETS}"
echo ""

# ---------------------------------------------------------------------------
# 1. ClearGate slides -> /site/public/assets/cleargate/
# ---------------------------------------------------------------------------
CG_PDF="${REPO_ROOT}/ClearGate_AI_Orchestration.pdf"
CG_OUT="${ASSETS}/cleargate"
mkdir -p "${CG_OUT}"

echo "[1/5] Extracting ClearGate slides (pdftoppm quality=75)..."
TMP_CG=$(mktemp -d)
pdftoppm -r 150 -jpeg -jpegopt quality=75 "${CG_PDF}" "${TMP_CG}/page"

cp "${TMP_CG}/page-01.jpg" "${CG_OUT}/01-cover.jpg"
cp "${TMP_CG}/page-02.jpg" "${CG_OUT}/02-vibe-trap.jpg"
cp "${TMP_CG}/page-05.jpg" "${CG_OUT}/03-pipeline.jpg"
cp "${TMP_CG}/page-06.jpg" "${CG_OUT}/04-gates.jpg"
cp "${TMP_CG}/page-07.jpg" "${CG_OUT}/05-four-agents.jpg"
cp "${TMP_CG}/page-08.jpg" "${CG_OUT}/06-karpathy-wiki.jpg"
cp "${TMP_CG}/page-09.jpg" "${CG_OUT}/07-vs-vibe.jpg"
cp "${TMP_CG}/page-12.jpg" "${CG_OUT}/08-ledger.jpg"

rm -rf "${TMP_CG}"
echo "    Done. $(ls "${CG_OUT}/"*.jpg | wc -l | tr -d ' ') files written."

# ---------------------------------------------------------------------------
# 2. Tee-Mo slides -> /site/public/assets/teemo/
# ---------------------------------------------------------------------------
TM_PDF="${REPO_ROOT}/Tee-Mo_Sovereign_Intelligence.pdf"
TM_OUT="${ASSETS}/teemo"
mkdir -p "${TM_OUT}"

echo "[2/5] Extracting Tee-Mo slides (pdftoppm quality=75)..."
TMP_TM=$(mktemp -d)
pdftoppm -r 150 -jpeg -jpegopt quality=75 "${TM_PDF}" "${TMP_TM}/page"

cp "${TMP_TM}/page-01.jpg" "${TM_OUT}/01-cover.jpg"
cp "${TMP_TM}/page-02.jpg" "${TM_OUT}/02-multiplayer.jpg"
cp "${TMP_TM}/page-03.jpg" "${TM_OUT}/03-zero-friction.jpg"
cp "${TMP_TM}/page-04.jpg" "${TM_OUT}/04-woven-thread.jpg"
cp "${TMP_TM}/page-06.jpg" "${TM_OUT}/05-read-act-automate.jpg"
cp "${TMP_TM}/page-07.jpg" "${TM_OUT}/06-rag-vs-router.jpg"
cp "${TMP_TM}/page-09.jpg" "${TM_OUT}/07-byok.jpg"
cp "${TMP_TM}/page-10.jpg" "${TM_OUT}/08-isolation.jpg"

rm -rf "${TMP_TM}"
echo "    Done. $(ls "${TM_OUT}/"*.jpg | wc -l | tr -d ' ') files written."

# ---------------------------------------------------------------------------
# 3. Exa images -> /site/public/assets/exa/
# ---------------------------------------------------------------------------
EXA_OUT="${ASSETS}/exa"
mkdir -p "${EXA_OUT}"

echo "[3/5] Fetching Exa images from GitHub..."

# Helper: fetch a file from the exa-slack-agent repo.
# For files > 1 MB the contents API returns empty content; we fall back to
# fetching the git blob by SHA which works for any size.
fetch_exa() {
  SRC="$1"
  DEST="$2"
  printf "    Fetching img/%s -> %s ... " "${SRC}" "${DEST}"

  # Get file metadata (sha + content)
  META=$(gh api "repos/eugene-burachevskiy/exa-slack-agent/contents/img/${SRC}")
  CONTENT=$(printf '%s' "${META}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('content',''))" 2>/dev/null || true)

  if [ -z "${CONTENT}" ] || [ "${CONTENT}" = "None" ]; then
    # File > 1 MB: use git blob API by SHA
    SHA=$(printf '%s' "${META}" | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
    gh api "repos/eugene-burachevskiy/exa-slack-agent/git/blobs/${SHA}" \
      --jq '.content' | base64 -d > "${EXA_OUT}/${DEST}"
  else
    printf '%s' "${CONTENT}" | base64 -d > "${EXA_OUT}/${DEST}"
  fi

  # Downscale to max 960px wide if needed, then further to meet 400 KB cap
  W=$(sips -g pixelWidth "${EXA_OUT}/${DEST}" 2>/dev/null | awk '/pixelWidth/{print $2}')
  if [ -n "${W}" ] && [ "${W}" -gt 960 ]; then
    sips -Z 960 "${EXA_OUT}/${DEST}" 2>/dev/null
  fi
  SIZE=$(wc -c < "${EXA_OUT}/${DEST}")
  while [ "${SIZE}" -gt 409600 ]; do
    CUR_W=$(sips -g pixelWidth "${EXA_OUT}/${DEST}" 2>/dev/null | awk '/pixelWidth/{print $2}')
    NEW_W=$(( CUR_W * 85 / 100 ))
    sips -Z "${NEW_W}" "${EXA_OUT}/${DEST}" 2>/dev/null
    SIZE=$(wc -c < "${EXA_OUT}/${DEST}")
  done

  echo "$(( SIZE / 1024 )) KB"
}

fetch_exa "exa-header.png"                "01-header.png"
fetch_exa "speak-exa.png"                 "02-speak.png"
fetch_exa "never-miss-pr.png"             "03-pr.png"
fetch_exa "digest.png"                    "04-digest.png"
fetch_exa "llmwiki-carousel.png"          "05-llmwiki.png"
fetch_exa "exa-architecture-main.png"     "06-arch-main.png"
fetch_exa "exa-architecture-at-scale.png" "07-arch-scale.png"

echo "    Done. $(ls "${EXA_OUT}/"*.png | wc -l | tr -d ' ') files written."

# ---------------------------------------------------------------------------
# 4. Team photos -> /site/public/assets/team/
# HALT if any source file is missing. Check ALL before copying ANY.
# ---------------------------------------------------------------------------
TEAM_SRC="${REPO_ROOT}/team-photos"
TEAM_OUT="${ASSETS}/team"
mkdir -p "${TEAM_OUT}"

echo "[4/5] Copying team photos..."
for WHO in christophe sandro eugene; do
  SRC_FILE="${TEAM_SRC}/${WHO}.jpg"
  if [ ! -f "${SRC_FILE}" ]; then
    echo "missing: ${WHO}.jpg — required source file not found at ${SRC_FILE}" >&2
    exit 1
  fi
done
# All present — now copy
for WHO in christophe sandro eugene; do
  cp "${TEAM_SRC}/${WHO}.jpg" "${TEAM_OUT}/${WHO}.jpg"
done
echo "    Done. $(ls "${TEAM_OUT}/"*.jpg | wc -l | tr -d ' ') files written."

# ---------------------------------------------------------------------------
# 5. OG card -> /site/public/assets/og/og-card.png (1200x630, <=200 KB)
# Generated via Python + Pillow (PIL).
# ---------------------------------------------------------------------------
OG_OUT="${ASSETS}/og"
mkdir -p "${OG_OUT}"
OG_CARD="${OG_OUT}/og-card.png"

echo "[5/5] Generating OG card (1200x630)..."
python3 << 'PYEOF'
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1200, 630
OUT = "/Users/ssuladze/Documents/Dev/Hakathon/site/public/assets/og/og-card.png"

img = Image.new("RGB", (W, H), (10, 10, 11))
draw = ImageDraw.Draw(img)

# Gradient top bar (8px) and bottom bar
for x in range(W):
    t = x / W
    if t < 0.5:
        r = int(234 + (251 - 234) * (t * 2))
        g = int(88  + (113 - 88)  * (t * 2))
        b = int(12  + (133 - 12)  * (t * 2))
    else:
        r = int(251 + (234 - 251) * ((t - 0.5) * 2))
        g = int(113 + (88  - 113) * ((t - 0.5) * 2))
        b = int(133 + (12  - 133) * ((t - 0.5) * 2))
    for y in range(8):
        draw.point((x, y), (r, g, b))
    for y in range(H - 8, H):
        draw.point((x, y), (r, g, b))

# Orange accent left column (16px)
for y in range(8, H - 8):
    t = y / H
    r = int(234 + (251 - 234) * t)
    g = int(88  + (113 - 88)  * t)
    b = int(12  + (133 - 12)  * t)
    for x in range(16):
        draw.point((x, y), (r, g, b))

# Try system fonts, fall back to default
try:
    title_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 70)
    tag_font   = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 42)
    label_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 28)
except Exception:
    try:
        title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 70)
        tag_font   = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 42)
        label_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)
    except Exception:
        title_font = ImageFont.load_default(size=70)
        tag_font   = ImageFont.load_default(size=42)
        label_font = ImageFont.load_default(size=28)

TITLE = "Slop-Masters · Code Fest 2026"
TAG   = "Three solutions. One thesis."

draw.text((W // 2, 260), TITLE, fill=(245, 245, 244), font=title_font, anchor="mm")
draw.text((W // 2, 360), TAG,   fill=(161, 161, 170), font=tag_font,   anchor="mm")

# Solution labels with colored dots
LABELS = [("ClearGate", (234, 88,  12)),
          ("Tee-Mo",    (251, 113, 133)),
          ("Exa",       (  0, 213,  99))]
LY = 460
spacing = 220
start_x = W // 2 - spacing
for i, (label, color) in enumerate(LABELS):
    lx = start_x + i * spacing
    r = 12
    draw.ellipse((lx - r, LY - r, lx + r, LY + r), fill=color)
    draw.text((lx + 20, LY), label, fill=color, font=label_font, anchor="lm")

img.save(OUT, "PNG", optimize=True)
size = os.path.getsize(OUT)
print(f"    OG card: {OUT} ({size // 1024} KB)")
PYEOF

echo ""
echo "=== Summary ==="
echo "  cleargate: $(ls "${ASSETS}/cleargate/"*.jpg 2>/dev/null | wc -l | tr -d ' ') JPEGs"
echo "  teemo:     $(ls "${ASSETS}/teemo/"*.jpg     2>/dev/null | wc -l | tr -d ' ') JPEGs"
echo "  exa:       $(ls "${ASSETS}/exa/"*.png       2>/dev/null | wc -l | tr -d ' ') PNGs"
echo "  team:      $(ls "${ASSETS}/team/"*.jpg      2>/dev/null | wc -l | tr -d ' ') JPEGs"
echo "  og:        $(ls "${ASSETS}/og/"*.png        2>/dev/null | wc -l | tr -d ' ') PNGs"
echo "  total:     $(du -sh "${ASSETS}" 2>/dev/null | cut -f1)"
echo "=== Done ==="
