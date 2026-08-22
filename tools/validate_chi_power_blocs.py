from __future__ import annotations

import re
import sys
from pathlib import Path

from PIL import Image


MOD_ROOT = Path(__file__).resolve().parents[1]
VANILLA_ROOT = Path(r"D:\Steam\steamapps\common\Hearts of Iron IV")

SCRIPT_FILES = [
    "common/dynamic_modifiers/CHI_power_blocs_dynamic_modifiers.txt",
    "common/scripted_effects/CHI_power_blocs_scripted_effects.txt",
    "common/scripted_triggers/CHI_power_blocs_scripted_triggers.txt",
    "common/on_actions/CHI_power_blocs_on_actions.txt",
    "common/decisions/categories/CHI_power_blocs_categories.txt",
    "common/decisions/CHI_power_blocs_decisions.txt",
    "common/scripted_guis/CHI_power_blocs_scripted_gui.txt",
    "common/scripted_localisation/CHI_power_blocs_scripted_localisation.txt",
    "interface/CHI_power_blocs.gui",
    "interface/CHI_power_blocs.gfx",
    "events/CHI_new_events_i.txt",
    "history/countries/CHI - China.txt",
]


def without_comments_and_strings(text: str) -> str:
    output: list[str] = []
    in_string = False
    escaped = False
    in_comment = False
    for char in text:
        if in_comment:
            if char == "\n":
                in_comment = False
                output.append(char)
            continue
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
            continue
        if char == "#":
            in_comment = True
        elif char == '"':
            in_string = True
        else:
            output.append(char)
    return "".join(output)


def assert_balanced(path: Path) -> None:
    clean = without_comments_and_strings(path.read_text(encoding="utf-8-sig"))
    depth = 0
    for char in clean:
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            assert depth >= 0, f"extra closing brace: {path}"
    assert depth == 0, f"unclosed braces ({depth}): {path}"


def validate_localisation() -> None:
    path = MOD_ROOT / "localisation/simp_chinese/CHI_power_blocs_l_simp_chinese.yml"
    raw = path.read_bytes()
    assert raw.startswith(b"\xef\xbb\xbf"), "localisation must have a UTF-8 BOM"
    text = raw.decode("utf-8-sig")
    assert text.splitlines()[0] == "l_simp_chinese:", "wrong localisation header"
    keys = re.findall(r"^ ([A-Za-z0-9_]+):", text, flags=re.MULTILINE)
    assert len(keys) == len(set(keys)), "duplicate key in CHI power-bloc localisation"

    for other in (MOD_ROOT / "localisation").rglob("*.yml"):
        if other == path:
            continue
        other_text = other.read_text(encoding="utf-8-sig", errors="ignore")
        other_keys = set(re.findall(r"^ ([A-Za-z0-9_]+):", other_text, flags=re.MULTILINE))
        overlap = set(keys) & other_keys
        assert not overlap, f"localisation collision in {other}: {sorted(overlap)}"


def validate_assets_and_gui() -> None:
    gfx = (MOD_ROOT / "interface/CHI_power_blocs.gfx").read_text(encoding="utf-8-sig")
    for texture in re.findall(r'texturefile\s*=\s*"([^"]+)"', gfx):
        asset = MOD_ROOT / texture
        assert asset.is_file(), f"missing texture: {texture}"
        assert asset.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"), f"not a PNG: {texture}"

    output = MOD_ROOT / "gfx/interface/CHI_power_blocs"
    assert Image.open(output / "power_blocs_background.png").size == (460, 205)
    assert Image.open(output / "power_blocs_category.png").size == (64, 64)
    for name in ("leader", "army", "capital", "technocrat"):
        assert Image.open(output / f"{name}_bar_strip.png").size == (220 * 21, 18)

    scripted = (MOD_ROOT / "common/scripted_guis/CHI_power_blocs_scripted_gui.txt").read_text(encoding="utf-8-sig")
    gui = (MOD_ROOT / "interface/CHI_power_blocs.gui").read_text(encoding="utf-8-sig")
    property_controls = re.findall(r"^\s*(CHI_power_bloc_[a-z_]+_bar)\s*=\s*\{", scripted, flags=re.MULTILINE)
    assert len(property_controls) == 4
    for bloc, control in zip(("leader", "army", "capital", "technocrat"), property_controls):
        assert f'name = "{control}"' in gui, f"GUI control missing: {control}"
        assert f"frame = CHI_power_bloc_{bloc}_frame" in scripted, f"bar frame not bound: {bloc}"
        assert gui.count(f'"CHI_power_bloc_{bloc}_tt"') == 3, f"tooltip coverage incomplete: {bloc}"


def validate_contracts() -> None:
    effects = (MOD_ROOT / "common/scripted_effects/CHI_power_blocs_scripted_effects.txt").read_text(encoding="utf-8-sig")
    dynamic = (MOD_ROOT / "common/dynamic_modifiers/CHI_power_blocs_dynamic_modifiers.txt").read_text(encoding="utf-8-sig")
    decisions = (MOD_ROOT / "common/decisions/CHI_power_blocs_decisions.txt").read_text(encoding="utf-8-sig")
    event = (MOD_ROOT / "events/CHI_new_events_i.txt").read_text(encoding="utf-8-sig")
    triggers = (MOD_ROOT / "common/scripted_triggers/CHI_power_blocs_scripted_triggers.txt").read_text(encoding="utf-8-sig")
    on_actions = (MOD_ROOT / "common/on_actions/CHI_power_blocs_on_actions.txt").read_text(encoding="utf-8-sig")
    history = (MOD_ROOT / "history/countries/CHI - China.txt").read_text(encoding="utf-8-sig")
    scripted_gui = (MOD_ROOT / "common/scripted_guis/CHI_power_blocs_scripted_gui.txt").read_text(encoding="utf-8-sig")
    gui = (MOD_ROOT / "interface/CHI_power_blocs.gui").read_text(encoding="utf-8-sig")
    localisation = (MOD_ROOT / "localisation/simp_chinese/CHI_power_blocs_l_simp_chinese.yml").read_text(encoding="utf-8-sig")

    initial = [0.35, 0.30, 0.20, 0.15]
    assert abs(sum(initial) - 1.0) < 1e-9
    assert "on_startup" in on_actions and "on_daily_CHI" in on_actions
    assert on_actions.count("CHI_power_blocs_initialize = yes") >= 2
    assert "add_dynamic_modifier" in effects
    assert "add_dynamic_modifier = { modifier = CHI_power_blocs_national_government }" in history
    assert "force_update_dynamic_modifier = yes" in history
    assert "set_country_flag = CHI_power_blocs_initialized" in history
    assert "dirty = CHI_power_bloc_gui_dirty" in scripted_gui
    assert "add_to_variable = { CHI_power_bloc_gui_dirty = 1 }" in effects
    assert effects.count("round_variable = CHI_power_bloc_") == 4
    assert "force_update_dynamic_modifier = yes" in effects
    assert "check_variable = { CHI_power_bloc_total < 0.001 }" in effects
    assert not re.search(r"check_variable\s*=\s*\{\s*var\s*=\s*CHI_power_bloc", effects)

    # Dynamic national-spirit sprites must resolve to a game sprite with a real DDS.
    vanilla_ideas = (VANILLA_ROOT / "interface/ideas.gfx").read_text(encoding="utf-8-sig")
    sprite = "GFX_idea_CHI_the_political_tutelage_dm"
    assert f'name = "{sprite}"' in vanilla_ideas, "unresolved dynamic national-spirit icon"
    for bloc in ("leader", "army", "capital", "technocrat"):
        assert f'CHI_power_bloc_{bloc}_value: "[?CHI.CHI_power_bloc_{bloc}_influence|%0]"' in localisation
        assert f'name = "CHI_power_bloc_{bloc}_bar"' in gui

    for index in range(4):
        values = initial.copy()
        values[index] += 0.10
        normalized = [value / sum(values) for value in values]
        assert abs(sum(normalized) - 1.0) < 1e-9
        assert all(-0.25 <= min(value, 0.5) - 0.25 <= 0.25 for value in normalized)
    for variable in set(re.findall(r"= (CHI_power_bloc_[a-z_]+_effect)", dynamic)):
        assert variable in effects, f"dynamic modifier variable is never calculated: {variable}"
    # Test decisions intentionally contain direct effects: using the same IDs
    # for decisions and scripted effects makes Clausewitz resolve them ambiguously.
    assert decisions.count("CHI_power_blocs_normalize_and_refresh = yes") == 5
    assert decisions.count("add_to_variable = { CHI_power_bloc_") == 4
    assert decisions.count("fire_only_once = no") == 5
    assert decisions.count("\n\t\t\tCHI = {") == 5
    assert "CHI_power_blocs_test_raise_leader = yes" not in decisions
    assert event.count("CHI_power_blocs_replace_bureaucratic_capital = yes") == 1
    assert not re.search(r"has_(communism|socialism|fascism)\s*[<>]", triggers)
    assert not re.search(r"check_variable\s*=\s*\{\s*var\s*=\s*CHI_power_bloc", triggers)
    assert not re.search(r"has_dynamic_modifier\s*=\s*CHI_", effects)
    assert not re.search(r"remove_dynamic_modifier\s*=\s*CHI_", effects)
    assert "CHI_power_blocs_choose_" not in decisions
    assert "custom_effect_tooltip" not in decisions
    assert "custom_modifier_tooltip" not in dynamic

    icons = set(re.findall(r"icon\s*=\s*(GFX_decision_generic_[A-Za-z0-9_]+)", decisions))
    vanilla_gfx = (VANILLA_ROOT / "interface/decisions.gfx").read_text(encoding="utf-8-sig")
    for icon in icons:
        assert f'name = "{icon}"' in vanilla_gfx, f"unknown decision icon: {icon}"

    # Exact modifier tokens were checked against the installed 1.19 data.
    required_modifiers = {
        "political_power_factor",
        "stability_factor",
        "war_support_factor",
        "army_attack_factor",
        "army_defence_factor",
        "breakthrough_factor",
        "army_org_factor",
        "supply_consumption_factor",
        "naval_coordination",
        "air_mission_efficiency",
        "production_speed_infrastructure_factor",
        "production_speed_industrial_complex_factor",
        "production_speed_arms_factory_factor",
        "production_speed_dockyard_factor",
        "industrial_capacity_factory",
        "industrial_capacity_dockyard",
		"production_factory_efficiency_gain_factor",
        "research_speed_factor",
        "special_project_speed_factor",
        "consumer_goods_factor",
        "political_advisor_cost_factor",
        "economy_cost_factor",
        "industrial_concern_cost_factor",
        "AWR_economy_development_monthly",
    }
    for modifier in required_modifiers:
        assert re.search(rf"^\s*{re.escape(modifier)}\s*=", dynamic, flags=re.MULTILINE), modifier


def main() -> int:
    for relative in SCRIPT_FILES:
        path = MOD_ROOT / relative
        assert path.is_file(), f"missing script file: {relative}"
        assert_balanced(path)
    validate_localisation()
    validate_assets_and_gui()
    validate_contracts()
    print("PASS: CHI power-bloc scripts, localisation, GUI contracts and PNG assets")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AssertionError as error:
        print(f"FAIL: {error}", file=sys.stderr)
        raise SystemExit(1)
