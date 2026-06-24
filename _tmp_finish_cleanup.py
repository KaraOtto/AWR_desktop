from pathlib import Path
import re

ROOT = Path(r"C:\Users\33503\Documents\Paradox Interactive\Hearts of Iron IV\mod\AWR_desktop")
VANILLA = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Hearts of Iron IV")

TARGET_FOCUS = {
    "CHI.txt", "CHI_shared_ccw.txt", "CHI_shared_subbranches.txt",
    "GXC.txt", "SHX.txt", "SIK.txt", "TNG.txt", "NEA.txt", "MAN.txt", "EHB.txt", "MON.txt", "NXM.txt",
    "ECA.txt", "PLM.txt", "JAP.txt",
    "shared_focus_china_warlord.txt", "shared_focus_china_ma_cliques.txt", "shared_focus_japan_puppet.txt",
}

def read_text(path: Path) -> str:
    for enc in ("utf-8-sig", "utf-8", "cp936", "latin-1"):
        try:
            return path.read_text(encoding=enc)
        except UnicodeDecodeError:
            continue
    return path.read_text(errors="ignore")

def write_text(path: Path, text: str):
    path.write_text(text, encoding="utf-8-sig")

def remove_enable_tooltips():
    changed = []
    for rel in [r"events\AWR_CHI_news.txt", r"events\AWR_SIK.txt"]:
        path = ROOT / rel
        text = read_text(path)
        lines = text.splitlines(keepends=True)
        out = [line for line in lines if "custom_effect_tooltip = enable_power_struggle" not in line]
        if len(out) != len(lines):
            write_text(path, "".join(out))
            changed.append(rel)
    return changed

def collect_refs():
    refs = set()
    for p in (ROOT / "common" / "national_focus").glob("*.txt"):
        if p.name not in TARGET_FOCUS or "PRC" in p.name.upper():
            continue
        text = re.sub(r"#.*", "", read_text(p))
        for m in re.finditer(r'\b(?:add_ideas|remove_ideas|has_idea)\s*=\s*\{([^{}]+)\}', text):
            refs.update(x for x in re.findall(r'\b[A-Za-z][A-Za-z0-9_:\.-]*\b', m.group(1)) if x != "days")
        for m in re.finditer(r'\b(?:add_ideas|remove_ideas|has_idea|remove_idea|add_idea|idea)\s*=\s*([A-Za-z0-9_:\.-]+)', text):
            refs.add(m.group(1))
    return {r for r in refs if not r.lower().startswith("prc_") and r not in {"yes", "no", "ROOT", "FROM", "PREV"}}

def defs(base: Path):
    d = set()
    for folder in ["common/ideas", "common/characters"]:
        root = base / folder
        if not root.exists():
            continue
        for p in root.glob("*.txt"):
            if "PRC" in p.name.upper():
                continue
            text = read_text(p)
            if folder.endswith("ideas"):
                d.update(re.findall(r'(?m)^[ \t]*([A-Za-z][A-Za-z0-9_:\.-]*)[ \t]*=[ \t]*\{', text))
            else:
                d.update(re.findall(r'\bidea_token\s*=\s*"?([A-Za-z][A-Za-z0-9_:\.-]*)"?', text))
    return d

def locs(base: Path):
    out = set()
    root = base / "localisation" / "simp_chinese"
    if not root.exists():
        return out
    for p in root.glob("*.yml"):
        if "PRC" in p.name.upper():
            continue
        out.update(re.findall(r'(?m)^[ \t]*([A-Za-z0-9_:\.-]+):', read_text(p)))
    return out

def residual_power():
    hits = []
    for sub, glob in [("common/national_focus", "*.txt"), ("common/decisions", "*.txt"), ("events", "*.txt"), ("localisation/simp_chinese", "*.yml")]:
        root = ROOT / sub
        if not root.exists():
            continue
        for p in root.rglob(glob):
            if "PRC" in p.name.upper():
                continue
            text = read_text(p)
            for pat in ["custom_effect_tooltip = enable_power_struggle", "CHI_political_power_struggle", "WTT_national_leadership", "CHI_power_struggle_on_map"]:
                if pat in text:
                    hits.append((str(p.relative_to(ROOT)), pat))
    return hits

def main():
    changed = remove_enable_tooltips()
    refs = collect_refs()
    all_defs = defs(ROOT) | defs(VANILLA)
    all_locs = locs(ROOT) | locs(VANILLA)
    missing_defs = sorted(r for r in refs if r not in all_defs)
    missing_locs = sorted(k for r in refs for k in (r, r + "_desc") if k not in all_locs)
    hits = residual_power()
    print("removed_tooltip_files", changed)
    print("power_residuals", len(hits))
    for h in hits[:40]:
        print("  ", h[0], h[1])
    print("focus_missing_defs_after_copy", len(missing_defs))
    for x in missing_defs[:80]:
        print("  def", x)
    print("focus_missing_locs_after_copy", len(missing_locs))
    for x in missing_locs[:80]:
        print("  loc", x)

if __name__ == "__main__":
    main()
