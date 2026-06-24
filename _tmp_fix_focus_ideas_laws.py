from pathlib import Path
import re
from collections import defaultdict

ROOT = Path(r"C:\Users\33503\Documents\Paradox Interactive\Hearts of Iron IV\mod\AWR_desktop")
SRC = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\394360\3273220145")
VANILLA = Path(r"C:\Program Files (x86)\Steam\steamapps\common\Hearts of Iron IV")

OUT_IDEAS = ROOT / "common" / "ideas" / "CHI_focus_missing_ideas.txt"
OUT_LOC = ROOT / "localisation" / "simp_chinese" / "CHI_focus_missing_ideas_l_simp_chinese.yml"

TARGET_FOCUS = {
    "CHI.txt", "CHI_shared_ccw.txt", "CHI_shared_subbranches.txt",
    "GXC.txt", "SHX.txt", "SIK.txt", "TNG.txt", "NEA.txt", "MAN.txt", "EHB.txt", "MON.txt", "NXM.txt",
    "ECA.txt", "PLM.txt", "JAP.txt",
    "shared_focus_china_warlord.txt", "shared_focus_china_ma_cliques.txt", "shared_focus_japan_puppet.txt",
}

RESTORE_MANPOWER = ["ETH_chitet_law", "ETH_chitet_law_peace_time", "SWI_citizen_militia_1", "SWI_citizen_militia_2", "propaganda_recruits"]
RESTORE_ECONOMY = ["totaler_krieg_economy", "national_defense_state", "new_economic_policy", "new_economic_policy_2", "capital_investment_model", "JAP_war_communism_idea", "evacuated_assets_law"]

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

def strip_comments(text: str) -> str:
    return re.sub(r"#.*", "", text)

def find_named_block(text: str, key: str, start_pos=0):
    m = re.search(r'(?m)^[ \t]*' + re.escape(key) + r'[ \t]*=[ \t]*\{', text[start_pos:])
    if not m:
        return None
    s = start_pos + m.start()
    brace = text.find("{", start_pos + m.end() - 1)
    depth = 0
    i = brace
    in_str = False
    esc = False
    while i < len(text):
        ch = text[i]
        if in_str:
            if esc:
                esc = False
            elif ch == "\\":
                esc = True
            elif ch == '"':
                in_str = False
        else:
            if ch == '"':
                in_str = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    e = i + 1
                    while e < len(text) and text[e] in " \t\r\n":
                        e += 1
                    return s, e
        i += 1
    return None

def container_insert(path: Path, container: str, child_name: str, child_block: str) -> bool:
    text = read_text(path)
    if re.search(r'(?m)^[ \t]*' + re.escape(child_name) + r'[ \t]*=[ \t]*\{', text):
        return False
    block = find_named_block(text, container)
    if not block:
        return False
    s, e = block
    close = text.rfind("}", s, e)
    insert = "\n\n" + indent_block(child_block.strip(), "\t\t") + "\n"
    text = text[:close] + insert + text[close:]
    write_text(path, text)
    return True

def indent_block(block: str, indent: str) -> str:
    lines = block.splitlines()
    return "\n".join(indent + line.rstrip() for line in lines)

def extract_child_block_from_file(path: Path, child_name: str):
    if not path.exists():
        return None
    text = read_text(path)
    block = find_named_block(text, child_name)
    if not block:
        return None
    s, e = block
    return text[s:e].strip()

def restore_laws():
    restored = []
    for name in RESTORE_MANPOWER:
        block = extract_child_block_from_file(SRC / "common" / "ideas" / "_manpower.txt", name)
        if not block:
            block = extract_child_block_from_file(VANILLA / "common" / "ideas" / "_manpower.txt", name)
        if block and container_insert(ROOT / "common" / "ideas" / "_manpower.txt", "mobilization_laws", name, block):
            restored.append(name)
    for name in RESTORE_ECONOMY:
        block = extract_child_block_from_file(SRC / "common" / "ideas" / "_economic.txt", name)
        if not block:
            block = extract_child_block_from_file(VANILLA / "common" / "ideas" / "_economic.txt", name)
        if block and container_insert(ROOT / "common" / "ideas" / "_economic.txt", "economy", name, block):
            restored.append(name)
    return restored

def collect_focus_idea_refs():
    refs = set()
    for path in (ROOT / "common" / "national_focus").glob("*.txt"):
        if path.name not in TARGET_FOCUS or "PRC" in path.name.upper():
            continue
        text = strip_comments(read_text(path))
        patterns = [
            r'\b(?:add_ideas|remove_ideas|has_idea)\s*=\s*\{([^{}]+)\}',
            r'\b(?:add_ideas|remove_ideas|has_idea|remove_idea|add_idea|idea)\s*=\s*([A-Za-z0-9_:\.-]+)',
        ]
        for m in re.finditer(patterns[0], text):
            refs.update(x for x in re.findall(r'\b[A-Za-z][A-Za-z0-9_:\.-]*\b', m.group(1)) if x not in {"days"})
        for m in re.finditer(patterns[1], text):
            refs.add(m.group(1))
    return {r for r in refs if not r.lower().startswith("prc_") and r not in {"yes", "no", "ROOT", "FROM", "PREV"}}

def collect_defined_ideas(base: Path):
    defined = set()
    for path in (base / "common" / "ideas").glob("*.txt"):
        if "PRC" in path.name.upper():
            continue
        text = read_text(path)
        # This intentionally over-collects nested names; good enough to avoid duplicate definitions.
        defined.update(re.findall(r'(?m)^[ \t]*([A-Za-z][A-Za-z0-9_:\.-]*)[ \t]*=[ \t]*\{', text))
    for path in (base / "common" / "characters").glob("*.txt"):
        if "PRC" in path.name.upper():
            continue
        text = read_text(path)
        defined.update(re.findall(r'\bidea_token\s*=\s*"?([A-Za-z][A-Za-z0-9_:\.-]*)"?', text))
    return defined

def source_idea_blocks(base: Path):
    found = {}
    for path in (base / "common" / "ideas").glob("*.txt"):
        if "PRC" in path.name.upper():
            continue
        text = read_text(path)
        for cat in re.finditer(r'(?m)^[ \t]*([A-Za-z][A-Za-z0-9_:\.-]*)[ \t]*=[ \t]*\{', text):
            cat_name = cat.group(1)
            if cat_name == "ideas":
                continue
        # Simpler: find every named block; parent category fallback country.
        for name in re.findall(r'(?m)^[ \t]*([A-Za-z][A-Za-z0-9_:\.-]*)[ \t]*=[ \t]*\{', text):
            if name in {"ideas", "country", "hidden_ideas", "law", "mobilization_laws", "economy", "trade_laws", "political_advisor", "theorist", "army_chief", "navy_chief", "air_chief", "high_command"}:
                continue
            block = extract_child_block_from_file(path, name)
            if block:
                found.setdefault(name, ("country", block, path.name))
    return found

def collect_loc_keys(base: Path):
    keys = set()
    loc_dir = base / "localisation" / "simp_chinese"
    if not loc_dir.exists():
        return keys
    for path in loc_dir.glob("*.yml"):
        if "PRC" in path.name.upper():
            continue
        text = read_text(path)
        keys.update(re.findall(r'(?m)^[ \t]*([A-Za-z0-9_:\.-]+):', text))
    return keys

def collect_loc_entries(base: Path):
    entries = {}
    loc_dir = base / "localisation" / "simp_chinese"
    if not loc_dir.exists():
        return entries
    for path in loc_dir.glob("*.yml"):
        if "PRC" in path.name.upper():
            continue
        for line in read_text(path).splitlines():
            m = re.match(r'^([ \t]*)([A-Za-z0-9_:\.-]+):.*$', line)
            if m:
                entries.setdefault(m.group(2), line)
    return entries

def write_missing_ideas_and_loc():
    refs = collect_focus_idea_refs()
    current_defs = collect_defined_ideas(ROOT) | collect_defined_ideas(VANILLA)
    source_defs = source_idea_blocks(SRC)
    missing_defs = sorted(r for r in refs if r not in current_defs and r in source_defs and not r.lower().startswith("prc_"))

    if missing_defs:
        groups = defaultdict(list)
        for idea in missing_defs:
            cat, block, srcfile = source_defs[idea]
            groups[cat].append((idea, block, srcfile))
        parts = ["ideas = {", "\tcountry = {"]
        for idea, block, srcfile in groups["country"]:
            parts.append(f"\n\t\t# {idea}，来源：common/ideas/{srcfile}")
            parts.append(indent_block(block, "\t\t"))
        parts += ["\t}", "}"]
        write_text(OUT_IDEAS, "\n".join(parts) + "\n")

    current_loc = collect_loc_keys(ROOT) | collect_loc_keys(VANILLA)
    source_loc = collect_loc_entries(SRC)
    wanted = set(refs) | {r + "_desc" for r in refs}
    loc_lines = []
    for key in sorted(wanted):
        if key not in current_loc and key in source_loc and not key.lower().startswith("prc_"):
            loc_lines.append(source_loc[key])
    if loc_lines:
        write_text(OUT_LOC, "l_simp_chinese:\n " + "\n ".join(line.strip() for line in loc_lines) + "\n")
    return refs, missing_defs, loc_lines

def main():
    restored = restore_laws()
    refs, missing_defs, loc_lines = write_missing_ideas_and_loc()
    print("restored_laws", len(restored), restored)
    print("focus_idea_refs", len(refs))
    print("missing_idea_defs_copied", len(missing_defs))
    print("missing_loc_lines_copied", len(loc_lines))

if __name__ == "__main__":
    main()
