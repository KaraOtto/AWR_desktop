from pathlib import Path
import re
import shutil

ROOT = Path(r"C:\Users\33503\Documents\Paradox Interactive\Hearts of Iron IV\mod\AWR_desktop")
SRC = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\394360\3273220145")
VANILLA = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Hearts of Iron IV")

JAP_CHAR_SRC = SRC / "common" / "characters" / "JAP.txt"
JAP_CHAR_DST = ROOT / "common" / "characters" / "JAP.txt"
OUT_GFX = ROOT / "interface" / "JAP_source_portrait_aliases.gfx"
OUT_LOC = ROOT / "localisation" / "simp_chinese" / "JAP_missing_characters_l_simp_chinese.yml"
OUT_IDEA = ROOT / "common" / "ideas" / "JAP_focus_missing_ideas.txt"

NEEDED_KEYS = {
    "suzuki_kisaburo", "suzuki_kisaburo_desc",
    "mineo_osumi", "mineo_osumi_desc",
    "hachiro_arita", "hachiro_arita_desc",
    "fumimaro_konoe", "fumimaro_konoe_desc",
    "ikki_kita", "ikki_kita_desc",
    "kanji_ishiwara", "kanji_ishiwara_desc",
    "reformed_colonial_administration", "reformed_colonial_administration_desc",
    "man_zhanganchu", "man_zhanganchu_desc",
}

def read_text(path: Path) -> str:
    for enc in ("utf-8-sig", "utf-8", "cp936", "latin-1"):
        try:
            return path.read_text(encoding=enc)
        except UnicodeDecodeError:
            continue
    return path.read_text(errors="ignore")

def write_text(path: Path, text: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8-sig")

def rel(p: str) -> Path:
    return Path(p.replace("/", "\\"))

def copy_rel(path_str: str):
    dst = ROOT / rel(path_str)
    if dst.exists():
        return True
    for base in (SRC, VANILLA):
        src = base / rel(path_str)
        if src.exists():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            return True
    return False

def sprite_blocks(base: Path):
    out = {}
    for p in (base / "interface").rglob("*.gfx"):
        if "PRC" in p.name.upper():
            continue
        text = read_text(p)
        for m in re.finditer(r'spriteType\s*=\s*\{', text):
            s = m.start()
            i = text.find("{", m.end() - 1)
            depth = 0
            while i < len(text):
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        e = i + 1
                        block = text[s:e]
                        nm = re.search(r'\bname\s*=\s*"?([^"\s}]+)"?', block)
                        tex = re.search(r'\btexturefile\s*=\s*"([^"]+)"', block)
                        if nm:
                            out.setdefault(nm.group(1), (block, tex.group(1) if tex else ""))
                        break
                i += 1
    return out

def loc_entries(base: Path):
    entries = {}
    d = base / "localisation" / "simp_chinese"
    if not d.exists():
        return entries
    for p in d.rglob("*.yml"):
        if "PRC" in p.name.upper():
            continue
        for line in read_text(p).splitlines():
            m = re.match(r'^[ \t]*([A-Za-z0-9_:\.-]+):.*$', line)
            if m:
                entries.setdefault(m.group(1), line.strip())
    return entries

def current_loc_keys():
    keys = set()
    for p in (ROOT / "localisation" / "simp_chinese").glob("*.yml"):
        if "PRC" in p.name.upper():
            continue
        keys.update(re.findall(r'(?m)^[ \t]*([A-Za-z0-9_:\.-]+):', read_text(p)))
    return keys

def main():
    JAP_CHAR_DST.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(JAP_CHAR_SRC, JAP_CHAR_DST)
    char_text = read_text(JAP_CHAR_DST)
    refs = sorted(set(re.findall(r'\b(?:small|large)\s*=\s*"?([^"\s}]+)"?', char_text)))
    local_defs = sprite_blocks(ROOT)
    src_defs = sprite_blocks(SRC)
    blocks = []
    copied = []
    missing_sprites = []
    missing_files = []
    for r in refs:
        if r.startswith("GFX_"):
            if r in local_defs:
                continue
            if r in src_defs:
                block, tex = src_defs[r]
                blocks.append(block)
                if tex:
                    if copy_rel(tex):
                        copied.append(tex)
                    else:
                        missing_files.append(tex)
            else:
                missing_sprites.append(r)
        else:
            if copy_rel(r):
                copied.append(r)
            else:
                missing_files.append(r)
    if blocks:
        write_text(OUT_GFX, "spriteTypes = {\n" + "\n\n".join("    " + b.replace("\n", "\n    ") for b in blocks) + "\n}\n")

    src_loc = loc_entries(SRC)
    cur_keys = current_loc_keys()
    loc_lines = []
    for key in sorted(NEEDED_KEYS):
        if key not in cur_keys and key in src_loc:
            loc_lines.append(src_loc[key])
    if loc_lines:
        write_text(OUT_LOC, "l_simp_chinese:\n " + "\n ".join(loc_lines) + "\n")

    # Non-character focus idea left from Japan focus.
    if "reformed_colonial_administration" not in read_text(ROOT / "common" / "ideas" / "JAP_ideas.txt"):
        block = """reformed_colonial_administration = {
            picture = reformed_colonial_administration
            allowed = { always = no }
            removal_cost = -1
            modifier = {
                compliance_growth = 0.1
            }
        }"""
        write_text(OUT_IDEA, "ideas = {\n\tcountry = {\n" + "        " + block.replace("\n", "\n        ") + "\n\t}\n}\n")

    print("copied_JAP_characters", JAP_CHAR_DST)
    print("portrait_refs", len(refs), "copied_textures", len(set(copied)), "missing_sprites", len(missing_sprites), "missing_files", len(set(missing_files)))
    for x in missing_sprites[:40]:
        print("  sprite", x)
    for x in sorted(set(missing_files))[:40]:
        print("  file", x)
    print("loc_lines", len(loc_lines))

if __name__ == "__main__":
    main()
