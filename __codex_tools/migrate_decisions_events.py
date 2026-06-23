from __future__ import annotations

import re
import shutil
from collections import defaultdict
from pathlib import Path


SRC = Path(r"C:\Program Files (x86)\Steam\steamapps\workshop\content\394360\3273220145")
DST = Path(r"C:\Users\33503\Desktop\重置总部")

TAGS = {
    "CHI", "MAN", "PLM", "ECA", "EHB", "GXC", "SHX", "TNG", "MON", "NEA", "SIK",
    "XSM", "NXM", "GSM", "EGM", "TIB", "HMI", "ATM", "KHR", "KRS",
}

KEYWORDS = [
    "CHI", "china", "China", "chinese", "Chinese", "KMT", "warlord", "Warlord",
    "RCM_china", "rcmchina", "RCM_EFM", "guangxi", "shanxi", "xibei", "sinkiang",
    "xinjiang", "tibet", "mongol", "mengjiang", "manchukuo", "pailingmiao",
    "east_hebei", "east_chahar", "northeast", "ma_clique", "ma_cliques",
]

TEXT_EXTS = {".txt", ".yml", ".gui", ".gfx"}
RELEVANT_FILE_RE = re.compile(
    r"(?i)("
    r"^CHI|^chi|china|chinese|warlord|xsm|manchukuo|^MAN|^MON|mongolia|mengjiang|"
    r"sinkiang|tibet|guangxi|shanxi|pailingmiao|NCHI|zongdu|KMT|anti_japan|"
    r"warofresistance|WTT_border|WTT_politcal|RCM_China|RCM_warlords|"
    r"RCM_EFM_Warlord|RCM_EFM_New_Guangxi|RCM_EFM_Shanxi|RCM_Manchukuo|"
    r"RCM_mengjiang|RCM_mongolia|RCM_Sinkiang|RCM_Tibet|RCM_NewsEvents|"
    r"RCM_EFM_NewsEvents|RCM_border_conflict|RCM_clique_remove_core"
    r")"
)


def read_text(path: Path) -> str:
    data = path.read_bytes()
    for enc in ("utf-8-sig", "utf-8", "gbk", "latin1"):
        try:
            return data.decode(enc)
        except UnicodeDecodeError:
            pass
    return data.decode("utf-8", errors="replace")


def write_text(path: Path, text: str, bom: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8-sig" if bom else "utf-8")


def strip_comments(text: str) -> str:
    lines = []
    for line in text.splitlines():
        if "#" in line:
            line = line[: line.index("#")]
        lines.append(line)
    return "\n".join(lines)


def text_files(root: Path, recursive: bool = True) -> list[Path]:
    if not root.exists():
        return []
    it = root.rglob("*") if recursive else root.glob("*")
    return sorted(p for p in it if p.is_file() and p.suffix.lower() in TEXT_EXTS)


EVENT_REF_RE = re.compile(
    r"(?<![\w.])(?:country_event|news_event|unit_leader_event)\s*=\s*(?:\{\s*id\s*=\s*)?([A-Za-z_][\w.]*\.\d+)",
    re.I | re.S,
)
EVENT_DEF_RE = re.compile(r"\b(?:country_event|news_event)\s*=\s*\{[^{}]*?\bid\s*=\s*([A-Za-z_][\w.]*\.\d+)", re.S)
NEWS_DEF_RE = re.compile(r"\bnews_event\s*=\s*\{[^{}]*?\bid\s*=\s*([A-Za-z_][\w.]*\.\d+)", re.S)
DECISION_ASSIGN_RE = re.compile(
    r"\b(?:activate_decision|remove_decision|complete_decision|has_decision|cancel_decision|mission_timeout)\s*=\s*([A-Za-z_][\w]*)"
)


def seed_target_files() -> list[Path]:
    roots = [
        DST / "common" / "national_focus",
        DST / "history" / "countries",
        DST / "common" / "ideas",
        DST / "common" / "characters",
        DST / "common" / "decisions",
        DST / "events",
    ]
    files: list[Path] = []
    for root in roots:
        files.extend(text_files(root))
    return files


def collect_seed_refs() -> tuple[set[str], set[str]]:
    event_refs: set[str] = set()
    decision_refs: set[str] = set()
    for path in seed_target_files():
        text = strip_comments(read_text(path))
        event_refs.update(EVENT_REF_RE.findall(text))
        decision_refs.update(DECISION_ASSIGN_RE.findall(text))
    return event_refs, decision_refs


def relevant_text(text: str, file_name: str = "") -> bool:
    haystack = text + "\n" + file_name
    tag_hit = any(re.search(rf"(?<![A-Za-z0-9_]){re.escape(tag)}(?![A-Za-z0-9_])", haystack) for tag in TAGS)
    keyword_hit = any(k in haystack for k in KEYWORDS)
    return tag_hit or keyword_hit


def relevant_file_name(path: Path) -> bool:
    return bool(RELEVANT_FILE_RE.search(path.name))


def source_decision_tokens(path: Path, text: str) -> set[str]:
    tokens: set[str] = set()
    # Top-level-ish decision/category ids at line starts. This is intentionally broad,
    # because source files often omit strict formatting.
    for m in re.finditer(r"(?m)^\s*([A-Za-z_][\w]*)\s*=\s*\{", text):
        token = m.group(1)
        if token not in {"visible", "available", "target_trigger", "complete_effect", "remove_effect", "days_remove"}:
            tokens.add(token)
    return tokens


def select_decision_files(decision_refs: set[str]) -> tuple[list[Path], list[Path]]:
    selected_decisions: set[Path] = set()
    selected_categories: set[Path] = set()
    for folder, bucket in [
        (SRC / "common" / "decisions", selected_decisions),
        (SRC / "common" / "decisions" / "categories", selected_categories),
    ]:
        for path in text_files(folder, recursive=False):
            text = read_text(path)
            tokens = source_decision_tokens(path, text)
            if tokens & decision_refs or relevant_file_name(path):
                bucket.add(path)
    return sorted(selected_decisions), sorted(selected_categories)


def source_event_definitions(files: list[Path]) -> dict[str, Path]:
    defs: dict[str, Path] = {}
    for path in files:
        text = read_text(path)
        for event_id in EVENT_DEF_RE.findall(text):
            defs.setdefault(event_id, path)
    return defs


def select_event_files(seed_event_refs: set[str], decision_files: list[Path]) -> list[Path]:
    refs = set(seed_event_refs)
    for path in decision_files:
        refs.update(EVENT_REF_RE.findall(strip_comments(read_text(path))))

    all_events = text_files(SRC / "events")
    defs = source_event_definitions(all_events)
    selected: set[Path] = {defs[r] for r in refs if r in defs}

    for path in all_events:
        if path in selected:
            continue
        if relevant_file_name(path):
            selected.add(path)
    return sorted(selected)


def is_news_file(path: Path, text: str) -> bool:
    return "news_event" in text or "news" in path.stem.lower()


def guess_owner(old_id: str, path: Path) -> str:
    hay = f"{path.stem.lower()} {old_id.lower()}"
    checks = [
        ("MAN", ["man", "manchukuo"]),
        ("ECA", ["eca", "mengjiang", "mengjiang", "men", "east_chahar", "chahar"]),
        ("EHB", ["ehb", "east_hebei", "hebei"]),
        ("GXC", ["gxc", "guangxi"]),
        ("SHX", ["shx", "shanxi", "shansi"]),
        ("TNG", ["tng", "tungan"]),
        ("MON", ["mon", "mongol"]),
        ("NEA", ["nea", "northeast", "fengtian"]),
        ("SIK", ["sik", "sinkiang", "xinjiang"]),
        ("TIB", ["tib", "tibet"]),
        ("XSM", ["xsm", "ma_clique", "ma_cliques", "qinghai", "xibei"]),
        ("PLM", ["plm", "pailingmiao"]),
        ("HMI", ["hmi", "hami"]),
        ("ATM", ["atm", "altay"]),
        ("KHR", ["khr", "kashgar"]),
        ("KRS", ["krs", "karasahr"]),
    ]
    for tag, needles in checks:
        if any(n in hay for n in needles):
            return tag
    return "CHI"


def build_event_id_map(event_files: list[Path]) -> tuple[dict[str, str], dict[str, str]]:
    counters: dict[str, int] = defaultdict(lambda: 1)
    mapping: dict[str, str] = {}
    kind_by_old: dict[str, str] = {}
    for path in event_files:
        text = read_text(path)
        for old_id in EVENT_DEF_RE.findall(text):
            owner = guess_owner(old_id, path)
            is_news = old_id in set(NEWS_DEF_RE.findall(text))
            namespace = f"AWR_{owner}_news" if is_news else f"AWR_{owner}"
            while f"{namespace}.{counters[namespace]}" in mapping.values():
                counters[namespace] += 1
            mapping[old_id] = f"{namespace}.{counters[namespace]}"
            kind_by_old[old_id] = "news" if is_news else "event"
            counters[namespace] += 1
    return mapping, kind_by_old


def replace_event_ids(text: str, mapping: dict[str, str]) -> str:
    # Longest first prevents replacing a prefix-like id before its longer sibling.
    for old, new in sorted(mapping.items(), key=lambda item: len(item[0]), reverse=True):
        text = re.sub(rf"(?<![\w.]){re.escape(old)}(?![\w.])", new, text)
    return text


def normalize_event_file(path: Path, mapping: dict[str, str], namespace_lines: set[str]) -> str:
    text = read_text(path)
    text = replace_event_ids(text, mapping)
    text = re.sub(r"(?m)^\s*add_namespace\s*=\s*[A-Za-z_][\w.]*\s*\r?\n?", "", text)
    text = re.sub(r"(?m)^\s*namespace\s*=\s*[A-Za-z_][\w.]*\s*\r?\n?", "", text)
    header = "\n".join(f"add_namespace = {ns}" for ns in sorted(namespace_lines))
    return f"{header}\n\n{text.strip()}\n"


def merge_files(files: list[Path], title: str) -> str:
    chunks = [f"# {title}", ""]
    for path in files:
        chunks.append(f"# ===== SOURCE: {path.relative_to(SRC)} =====")
        chunks.append(read_text(path).strip())
        chunks.append("")
    return "\n".join(chunks).rstrip() + "\n"


def copy_relevant_localisation(event_id_map: dict[str, str], decision_files: list[Path], category_files: list[Path], event_files: list[Path]) -> int:
    loc_root = SRC / "localisation" / "simp_chinese"
    if not loc_root.exists():
        return 0

    relevant_ids = set(event_id_map)
    relevant_ids.update(event_id_map.values())
    for path in decision_files + category_files:
        text = read_text(path)
        relevant_ids.update(source_decision_tokens(path, text))
        relevant_ids.update(EVENT_REF_RE.findall(text))

    selected_lines: list[str] = ["l_simp_chinese:"]
    used = 0
    key_re = re.compile(r"^\s*([^:#\s]+):")
    for path in text_files(loc_root):
        if "\\replace\\" in str(path).lower():
            continue
        text = read_text(path)
        include_file = relevant_file_name(path)
        for line in text.splitlines():
            if not line.strip() or line.lstrip().startswith("#") or line.strip() == "l_simp_chinese:":
                continue
            m = key_re.match(line)
            key = m.group(1) if m else ""
            if include_file or any(key == rid or key.startswith(rid + ".") for rid in relevant_ids):
                selected_lines.append(replace_event_ids(line, event_id_map))
                used += 1
    if used:
        write_text(DST / "localisation" / "simp_chinese" / "events_decisions_l_simp_chinese.yml", "\n".join(selected_lines) + "\n", bom=True)
    return used


def rewrite_target_refs(event_id_map: dict[str, str]) -> list[Path]:
    changed: list[Path] = []
    roots = [
        DST / "common" / "national_focus",
        DST / "history" / "countries",
        DST / "common" / "ideas",
        DST / "common" / "characters",
        DST / "common" / "decisions",
        DST / "events",
        DST / "localisation" / "simp_chinese",
    ]
    for root in roots:
        for path in text_files(root):
            text = read_text(path)
            new = replace_event_ids(text, event_id_map)
            if new != text:
                write_text(path, new, bom=path.suffix.lower() == ".yml")
                changed.append(path)
    return changed


def validate_event_braces(paths: list[Path]) -> list[str]:
    bad: list[str] = []
    for path in paths:
        text = read_text(path)
        balance = 0
        for ch in text:
            if ch == "{":
                balance += 1
            elif ch == "}":
                balance -= 1
                if balance < 0:
                    break
        if balance != 0:
            bad.append(str(path.relative_to(DST)))
    return bad


def main() -> None:
    if not SRC.exists():
        raise SystemExit(f"missing source mod: {SRC}")
    if not DST.exists():
        raise SystemExit(f"missing target: {DST}")

    event_refs, decision_refs = collect_seed_refs()
    decision_files, category_files = select_decision_files(decision_refs)
    event_files = select_event_files(event_refs, decision_files)
    event_id_map, event_kind = build_event_id_map(event_files)
    event_defs_by_file: dict[Path, set[str]] = defaultdict(set)
    for path in event_files:
        for event_id in EVENT_DEF_RE.findall(read_text(path)):
            event_defs_by_file[path].add(event_id)

    dec_out = DST / "common" / "decisions"
    cat_out = DST / "common" / "decisions" / "categories"
    ev_out = DST / "events"

    write_text(dec_out / "shared_focus_china_decisions.txt", merge_files(decision_files, "中国及地方势力决议整理"))
    write_text(cat_out / "shared_focus_china_decision_categories.txt", merge_files(category_files, "中国及地方势力决议分类整理"))

    ordinary_event_files: list[Path] = []
    news_event_files: list[Path] = []
    for path in event_files:
        text = read_text(path)
        if is_news_file(path, text):
            news_event_files.append(path)
        else:
            ordinary_event_files.append(path)

    ordinary_namespaces = {new.rsplit(".", 1)[0] for old, new in event_id_map.items() if event_kind.get(old) == "event"}
    news_namespaces = {new.rsplit(".", 1)[0] for old, new in event_id_map.items() if event_kind.get(old) == "news"}

    ordinary_text = "# 中国及地方势力事件整理\n\n"
    for path in ordinary_event_files:
        file_map = {old: new for old, new in event_id_map.items() if old in event_defs_by_file[path]}
        namespaces = {new.rsplit(".", 1)[0] for new in file_map.values() if new.rsplit(".", 1)[0] in ordinary_namespaces}
        ordinary_text += f"# ===== SOURCE: {path.relative_to(SRC)} =====\n"
        ordinary_text += normalize_event_file(path, event_id_map, namespaces or ordinary_namespaces)
        ordinary_text += "\n"

    news_text = "# 中国及地方势力新闻事件整理\n\n"
    for path in news_event_files:
        file_map = {old: new for old, new in event_id_map.items() if old in event_defs_by_file[path]}
        namespaces = {new.rsplit(".", 1)[0] for new in file_map.values() if new.rsplit(".", 1)[0] in news_namespaces}
        news_text += f"# ===== SOURCE: {path.relative_to(SRC)} =====\n"
        news_text += normalize_event_file(path, event_id_map, namespaces or news_namespaces)
        news_text += "\n"

    write_text(ev_out / "AWR_CHI_events.txt", ordinary_text)
    write_text(ev_out / "AWR_CHI_news.txt", news_text)

    changed_refs = rewrite_target_refs(event_id_map)
    loc_lines = copy_relevant_localisation(event_id_map, decision_files, category_files, event_files)

    out_event_files = [ev_out / "AWR_CHI_events.txt", ev_out / "AWR_CHI_news.txt"]
    brace_bad = validate_event_braces(out_event_files)

    missing_event_refs = sorted(r for r in event_refs if r not in event_id_map)
    duplicate_new_ids = sorted(k for k, v in defaultdict(list, ((None, []) for _ in [])).items())
    reverse: dict[str, list[str]] = defaultdict(list)
    for old, new in event_id_map.items():
        reverse[new].append(old)
    duplicate_new_ids = sorted(new for new, olds in reverse.items() if len(olds) > 1)

    report = [
        "决议与事件搬运整理报告",
        "======================",
        "",
        f"源模组: {SRC}",
        f"目标目录: {DST}",
        "",
        f"种子事件引用: {len(event_refs)}",
        f"种子决议引用: {len(decision_refs)}",
        f"搬运决议文件: {len(decision_files)}",
        f"搬运决议分类文件: {len(category_files)}",
        f"搬运事件文件: {len(event_files)}",
        f"事件 id 规范化映射: {len(event_id_map)}",
        f"汉化行数: {loc_lines}",
        f"同步改写目标引用文件: {len(changed_refs)}",
        "",
        "输出文件:",
        "- common/decisions/shared_focus_china_decisions.txt",
        "- common/decisions/categories/shared_focus_china_decision_categories.txt",
        "- events/AWR_CHI_events.txt",
        "- events/AWR_CHI_news.txt",
        "- localisation/simp_chinese/events_decisions_l_simp_chinese.yml",
        "",
        "说明:",
        "- 普通事件统一为 AWR_TAG.N；新闻事件统一为 AWR_TAG_news.N。",
        "- 决议 id 文档没有强制格式，本轮保留源 id，并按共享中国区域文件整理。",
        "- 事件/决议源文件中原有注释原样保留；没有再添加会破坏语法的行内注释。",
        "",
        f"事件输出括号异常: {len(brace_bad)}",
        *[f"- {x}" for x in brace_bad[:50]],
        "",
        f"未在搬运源事件中找到的旧事件引用: {len(missing_event_refs)}",
        *[f"- {x}" for x in missing_event_refs[:80]],
        "",
        f"重复新事件 id: {len(duplicate_new_ids)}",
        *[f"- {x}" for x in duplicate_new_ids[:80]],
        "",
        "事件 id 映射:",
        *[f"- {old} -> {new}" for old, new in sorted(event_id_map.items())],
    ]
    write_text(DST / "决议与事件搬运整理报告.txt", "\n".join(report) + "\n")

    print(f"decision_files={len(decision_files)}")
    print(f"category_files={len(category_files)}")
    print(f"event_files={len(event_files)}")
    print(f"event_id_map={len(event_id_map)}")
    print(f"changed_ref_files={len(changed_refs)}")
    print(f"loc_lines={loc_lines}")
    print(f"missing_event_refs={len(missing_event_refs)}")
    print(f"brace_bad={len(brace_bad)}")
    print(f"duplicate_new_ids={len(duplicate_new_ids)}")


if __name__ == "__main__":
    main()
