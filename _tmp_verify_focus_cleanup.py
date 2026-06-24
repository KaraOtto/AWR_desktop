from pathlib import Path
import re

ROOT = Path(r"C:\Users\33503\Documents\Paradox Interactive\Hearts of Iron IV\mod\AWR_desktop")
VANILLA = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Hearts of Iron IV")

def read_text(path: Path) -> str:
    for enc in ("utf-8-sig", "utf-8", "cp936", "latin-1"):
        try:
            return path.read_text(encoding=enc)
        except UnicodeDecodeError:
            continue
    return path.read_text(errors="ignore")

def child_names(path: Path, container: str):
    text = read_text(path)
    m = re.search(r'(?m)^[ \t]*' + re.escape(container) + r'[ \t]*=[ \t]*\{', text)
    if not m:
        return []
    start = text.find("{", m.end() - 1)
    names = []
    depth = 0
    line_start = True
    i = start
    while i < len(text):
        ch = text[i]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                break
        if depth == 1:
            lm = re.match(r'\s*([A-Za-z][A-Za-z0-9_:\.-]*)\s*=\s*\{', text[i:])
            if lm:
                names.append(lm.group(1))
        i += 1
    return sorted(set(names))

def loc_keys(base: Path):
    keys = set()
    d = base / "localisation" / "simp_chinese"
    if not d.exists():
        return keys
    for p in d.glob("*.yml"):
        if "PRC" in p.name.upper():
            continue
        keys.update(re.findall(r'(?m)^[ \t]*([A-Za-z0-9_:\.-]+):', read_text(p)))
    return keys

def main():
    residual = []
    for sub in ["common/national_focus", "common/decisions", "events", "localisation/simp_chinese"]:
        for p in (ROOT / sub).rglob("*.txt" if sub != "localisation/simp_chinese" else "*.yml"):
            if "PRC" in p.name.upper():
                continue
            text = read_text(p)
            for pat in ["custom_effect_tooltip = enable_power_struggle", "CHI_political_power_struggle", "WTT_national_leadership", "CHI_power_struggle_on_map"]:
                if pat in text:
                    residual.append((str(p.relative_to(ROOT)), pat))
    print("power_struggle_residuals", len(residual))
    for x in residual[:40]:
        print("  ", x[0], x[1])
    print("manpower_children", child_names(ROOT / "common" / "ideas" / "_manpower.txt", "mobilization_laws"))
    print("economy_children", child_names(ROOT / "common" / "ideas" / "_economic.txt", "economy"))
    print("focus_missing_ideas_file_exists", (ROOT / "common" / "ideas" / "CHI_focus_missing_ideas.txt").exists())
    print("focus_missing_loc_file_exists", (ROOT / "localisation" / "simp_chinese" / "CHI_focus_missing_ideas_l_simp_chinese.yml").exists())

if __name__ == "__main__":
    main()
