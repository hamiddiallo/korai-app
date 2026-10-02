"""Icônes Korai (iOS + Android) à partir du glyphe Material « hearing_rounded »,
le même que le logo de l'application : oreille claire sur fond encre.

Usage (depuis frontend/, nécessite Pillow) :
    python3 tool/generate_app_icons.py "$(dirname $(dirname $(which flutter)))" . build/icons all

Écrit les icônes iOS (AppIcon.appiconset), l'image de lancement iOS
(LaunchImage) et les icônes Android (ic_launcher, premier plan adaptatif). L'aperçu 1024 px est dans le dossier de sortie (3e argument).
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

FLUTTER = sys.argv[1]
FRONT = sys.argv[2]
OUT = sys.argv[3]
FONT = f"{FLUTTER}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf"
GLYPH = chr(0xF7E1)                 # Icons.hearing_rounded
HERO = (0x0E, 0x2E, 0x35)           # Encre (KoraiColors.light.hero)
ON_HERO = (0xE6, 0xF0, 0xEE)        # KoraiColors.light.onHero

def render(size, glyph_ratio, bg=True, radius_ratio=0.0, ss=4):
    """Rendu suréchantillonné (ss×) puis réduit, pour des bords nets."""
    S = size * ss
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if bg:
        if radius_ratio:
            d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * radius_ratio), fill=HERO + (255,))
        else:
            d.rectangle([0, 0, S, S], fill=HERO + (255,))
    font = ImageFont.truetype(FONT, int(S * glyph_ratio))
    d.text((S / 2, S / 2), GLYPH, font=font, fill=ON_HERO + (255,), anchor="mm")
    return img.resize((size, size), Image.LANCZOS)

if __name__ == "__main__":
    mode = sys.argv[4] if len(sys.argv) > 4 else "preview"
    os.makedirs(OUT, exist_ok=True)
    master = render(1024, 0.56)
    master.convert("RGB").save(f"{OUT}/master_1024.png")
    if mode == "preview":
        sys.exit(0)

    # iOS : toutes les tailles du Contents.json, opaques (pas de canal alpha).
    ios_dir = f"{FRONT}/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    spec = json.load(open(f"{ios_dir}/Contents.json"))
    for im in spec["images"]:
        px = round(float(im["size"].split("x")[0]) * int(im["scale"].rstrip("x")))
        master.resize((px, px), Image.LANCZOS).convert("RGB").save(f"{ios_dir}/{im['filename']}")

    # Android : icône classique (API 24-25) et icône adaptative (API 26+).
    res = f"{FRONT}/android/app/src/main/res"
    densities = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for name, f in densities.items():
        legacy = render(round(48 * f), 0.56, radius_ratio=0.22)
        legacy.save(f"{res}/mipmap-{name}/ic_launcher.png")
        # Premier plan adaptatif : 108 dp, contenu dans la zone sûre centrale (72 dp).
        fg = render(round(108 * f), 0.56 * 72 / 108, bg=False)
        fg.save(f"{res}/mipmap-{name}/ic_launcher_foreground.png")

    # iOS : image de l'écran de lancement (96 pt, oreille seule ; le fond encre
    # est la couleur du storyboard LaunchScreen).
    launch = f"{FRONT}/ios/Runner/Assets.xcassets/LaunchImage.imageset"
    for scale, suffix in ((1, ""), (2, "@2x"), (3, "@3x")):
        render(96 * scale, 0.92, bg=False).save(f"{launch}/LaunchImage{suffix}.png")
    print("ok")
