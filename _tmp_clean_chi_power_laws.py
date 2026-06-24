from pathlib import Path
import re

ROOT = Path(r"C:\Users\33503\Documents\Paradox Interactive\Hearts of Iron IV\mod\AWR_desktop")

def read_text(path: Path) -> str:
    for enc in ("utf-8-sig", "utf-8", "cp936", "latin-1"):
        try:
            return path.read_text(encoding=enc)
        except UnicodeDecodeError:
            continue
    return path.read_text(errors="ignore")

def write_text(path: Path, text: str):
    path.write_text(text, encoding="utf-8-sig")

def find_block(text: str, key: str):
    m = re.search(r'(?m)^([ \t]*)' + re.escape(key) + r'\s*=\s*\{', text)
    if not m:
        return None
    brace = text.find("{", m.end() - 1)
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
                    end = i + 1
                    while end < len(text) and text[end] in " \t\r\n":
                        end += 1
                    return m.start(), end
        i += 1
    raise RuntimeError(f"Unclosed block {key}")

def remove_top_block(path_rel: str, key: str):
    path = ROOT / path_rel
    text = read_text(path)
    block = find_block(text, key)
    if block:
        s, e = block
        text = text[:s] + text[e:]
        write_text(path, text)
        return True
    return False

def remove_from_key_to_next_top(path_rel: str, key: str):
    path = ROOT / path_rel
    text = read_text(path)
    m = re.search(r'(?m)^' + re.escape(key) + r'\s*=\s*\{', text)
    if not m:
        return False
    n = re.search(r'(?m)^\S[^\r\n=]*=\s*\{', text[m.end():])
    if n:
        end = m.end() + n.start()
    else:
        end = len(text)
    text = text[:m.start()] + text[end:]
    write_text(path, text)
    return True

def remove_lines_matching(path_rel: str, patterns):
    path = ROOT / path_rel
    text = read_text(path)
    lines = text.splitlines(keepends=True)
    out = []
    removed = 0
    for line in lines:
        if any(p.search(line) for p in patterns):
            removed += 1
            continue
        out.append(line)
    if removed:
        write_text(path, "".join(out))
    return removed

def law_block_names(path_rel: str, container: str):
    path = ROOT / path_rel
    text = read_text(path)
    outer = find_block(text, container)
    if not outer:
        return []
    s, e = outer
    body = text[s:e]
    # Direct child blocks inside law container.
    names = []
    i = body.find("{") + 1
    while i < len(body):
        m = re.search(r'(?m)^\s*([A-Za-z0-9_:\.-]+)\s*=\s*\{', body[i:])
        if not m:
            break
        name = m.group(1)
        start = i + m.start()
        brace = body.find("{", start)
        depth = 0
        j = brace
        while j < len(body):
            if body[j] == "{":
                depth += 1
            elif body[j] == "}":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        names.append(name)
        i = j + 1
    return names

VANILLA_MANPOWER = {
    "disarmed_nation", "volunteer_only", "limited_conscription", "extensive_conscription",
    "service_by_requirement", "all_adults_serve", "scraping_the_barrel"
}
VANILLA_ECONOMY = {
    "undisturbed_isolation", "isolation", "civilian_economy", "low_economic_mobilisation",
    "partial_economic_mobilisation", "war_economy", "tot_economic_mobilisation"
}

def remove_non_law_children(path_rel: str, container: str, keep: set):
    path = ROOT / path_rel
    text = read_text(path)
    removed = []
    changed = True
    while changed:
        changed = False
        outer = find_block(text, container)
        if not outer:
            break
        s, e = outer
        body = text[s:e]
        base = s
        i = body.find("{") + 1
        while True:
            m = re.search(r'(?m)^\s*([A-Za-z0-9_:\.-]+)\s*=\s*\{', body[i:])
            if not m:
                break
            name = m.group(1)
            start = i + m.start()
            if name in {"allowed", "available", "modifier", "ai_will_do", "on_add", "allowed_to_remove"}:
                i = i + m.end()
                continue
            abs_start = base + start
            tmp = find_block(text[abs_start:], name)
            if not tmp:
                i = i + m.end()
                continue
            bs, be = tmp
            abs_s = abs_start + bs
            abs_e = abs_start + be
            if name not in keep and name not in {"law", "use_list_view"}:
                text = text[:abs_s] + text[abs_e:]
                removed.append(name)
                changed = True
                break
            i = start + (abs_e - abs_s)
    if removed:
        write_text(path, text)
    return removed

def main():
    removed = {}
    removed["category_block"] = remove_top_block(r"common\decisions\categories\CHI_decision_categories.txt", "CHI_political_power_struggle")
    try:
        removed["decision_block"] = remove_top_block(r"common\decisions\CHI_decisions.txt", "CHI_political_power_struggle")
    except RuntimeError:
        removed["decision_block"] = remove_from_key_to_next_top(r"common\decisions\CHI_decisions.txt", "CHI_political_power_struggle")
    pats = [
        re.compile(r'custom_effect_tooltip\s*=\s*enable_power_struggle'),
        re.compile(r'WTT_not_taking_over_national_leadership\s*=\s*(yes|no)'),
        re.compile(r'WTT_not_china_leader_refused_to_give_up_national_leadership\s*=\s*(yes|no)'),
    ]
    for rel in [
        r"common\national_focus\GXC.txt",
        r"common\national_focus\SHX.txt",
        r"common\national_focus\SIK.txt",
        r"common\national_focus\TNG.txt",
        r"common\national_focus\shared_focus_china_warlord.txt",
    ]:
        removed[rel] = remove_lines_matching(rel, pats)
    removed["manpower_wrong_laws"] = remove_non_law_children(r"common\ideas\_manpower.txt", "mobilization_laws", VANILLA_MANPOWER)
    removed["economy_wrong_laws"] = remove_non_law_children(r"common\ideas\_economic.txt", "economy", VANILLA_ECONOMY)
    print(removed)

if __name__ == "__main__":
    main()
