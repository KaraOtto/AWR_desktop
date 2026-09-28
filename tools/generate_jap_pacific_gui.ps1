$ErrorActionPreference = "Stop"
$ModRoot = Split-Path -Parent $PSScriptRoot
$MapRoot = Join-Path $ModRoot "gfx\interface\JAP_pacific\map"
$RenderScale = 2

$States = Get-Content (Join-Path $MapRoot 'state_manifest.csv') | ForEach-Object {
	$p = $_ -split ';'
	[pscustomobject]@{ Id=[int]$p[0]; X=[int]$p[1]; Y=[int]$p[2]; W=[int]$p[3]; H=[int]$p[4] }
}
$Regions = @{}
Get-Content (Join-Path $MapRoot 'region_manifest.csv') | ForEach-Object {
	$p = $_ -split ';'
	$Regions[$p[0]] = [pscustomobject]@{ Key=$p[0]; X=[int]$p[1]; Y=[int]$p[2]; States=@($p[3] -split ',' | ForEach-Object {[int]$_}) }
}

function Get-SideTrigger([string]$Side) {
	if ($Side -eq 'JAP') {
		return 'OR = { original_tag = JAP is_in_faction_with = JAP is_subject_of = JAP }'
	}
	return 'OR = { original_tag = USA is_in_faction_with = USA is_subject_of = USA }'
}

function Get-RegionControl([string]$Key, [string]$Side, [bool]$Negate = $false) {
	$condition = ($Regions[$Key].States | ForEach-Object { "$_ = { controller = { $(Get-SideTrigger $Side) } }" }) -join ' '
	if ($Negate) { return "NOT = { AND = { $condition } }" }
	return "AND = { $condition }"
}

$gfx = [System.Text.StringBuilder]::new()
[void]$gfx.AppendLine('spriteTypes = {')
[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_pacific_map_base`" textureFile = `"gfx/interface/JAP_pacific/map/pacific_map_base.png`" }")
[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_pacific_map_borders`" textureFile = `"gfx/interface/JAP_pacific/map/pacific_map_borders.png`" }")
[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_pacific_flag_JAP`" textureFile = `"gfx/interface/JAP_pacific/map/pacific_flag_JAP.png`" }")
[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_pacific_flag_USA`" textureFile = `"gfx/interface/JAP_pacific/map/pacific_flag_USA.png`" }")
foreach ($s in $States) {
	[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_pacific_state_$($s.Id)`" textureFile = `"gfx/interface/JAP_pacific/map/state_$($s.Id).png`" noOfFrames = 2 }")
}
$arrowKeys = @('north_1','north_2','north_3','north_4','south_1','south_2','east_1','east_2','rabaul_1')
foreach ($key in $arrowKeys) {
	[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_pacific_arrow_$key`" textureFile = `"gfx/interface/JAP_pacific/map/arrow_$key.png`" }")
}
$islandKeys = @('philippines','marianas','new_guinea','wake','midway','hawaii','iwo_jima','okinawa')
foreach ($key in $islandKeys) {
	[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_pacific_isolation_$key`" textureFile = `"gfx/interface/JAP_pacific/map/isolation_$key.png`" }")
}
[void]$gfx.AppendLine('}')

$gui = [System.Text.StringBuilder]::new()
[void]$gui.AppendLine('guiTypes = {')
[void]$gui.AppendLine("`tcontainerWindowType = {")
[void]$gui.AppendLine("`t`tname = `"JAP_pacific_strategy_map_window`"")
[void]$gui.AppendLine("`t`tposition = { x = 0 y = 0 }")
[void]$gui.AppendLine("`t`tsize = { width = 500 height = 342 }")
[void]$gui.AppendLine("`t`tclipping = no")
[void]$gui.AppendLine("`t`tinstantTextBoxType = { name = `"map_title`" position = { x = 0 y = 5 } font = `"hoi_20b`" text = `"JAP_pacific_map_title`" format = center maxWidth = 500 alwaystransparent = yes }")
[void]$gui.AppendLine("`t`tinstantTextBoxType = { name = `"map_subtitle`" position = { x = 0 y = 29 } font = `"hoi_16mbs`" text = `"JAP_pacific_map_subtitle`" format = center maxWidth = 500 alwaystransparent = yes }")
[void]$gui.AppendLine("`t`ticonType = { name = `"pacific_base`" spriteType = `"GFX_JAP_pacific_map_base`" position = { x = 0 y = 50 } scale = 0.5 alwaystransparent = yes }")
foreach ($s in $States) {
	$x=[int]($s.X/$RenderScale); $y=50+[int]($s.Y/$RenderScale)
	[void]$gui.AppendLine("`t`ticonType = { name = `"state_$($s.Id)_JAP`" spriteType = `"GFX_JAP_pacific_state_$($s.Id)`" position = { x = $x y = $y } frame = 1 scale = 0.5 alwaystransparent = yes }")
	[void]$gui.AppendLine("`t`ticonType = { name = `"state_$($s.Id)_USA`" spriteType = `"GFX_JAP_pacific_state_$($s.Id)`" position = { x = $x y = $y } frame = 2 scale = 0.5 alwaystransparent = yes }")
}
[void]$gui.AppendLine("`t`ticonType = { name = `"pacific_borders`" spriteType = `"GFX_JAP_pacific_map_borders`" position = { x = 0 y = 50 } scale = 0.5 alwaystransparent = yes }")
foreach ($key in $arrowKeys) {
	[void]$gui.AppendLine("`t`ticonType = { name = `"arrow_$key`" spriteType = `"GFX_JAP_pacific_arrow_$key`" position = { x = 0 y = 50 } scale = 0.5 alwaystransparent = yes }")
}
foreach ($key in $islandKeys) {
	[void]$gui.AppendLine("`t`ticonType = { name = `"isolation_$key`" spriteType = `"GFX_JAP_pacific_isolation_$key`" position = { x = 0 y = 50 } scale = 0.5 alwaystransparent = yes }")
	$r=$Regions[$key]; $tx=[int]($r.X/2)-36; $ty=50+[int]($r.Y/2)-9
	[void]$gui.AppendLine("`t`tinstantTextBoxType = { name = `"isolation_$($key)_label`" position = { x = $tx y = $ty } font = `"hoi_16mbs`" text = `"JAP_pacific_map_isolated_marker`" format = center maxWidth = 72 alwaystransparent = yes }")
}
# Static labels identify only the largest island chains and add no gameplay.
$mapLabelOffsets = [ordered]@{
	'marianas'=@(8,-18); 'carolines'=@(-45,8); 'marshalls'=@(18,12); 'solomons'=@(10,10); 'hawaii'=@(10,8)
}
foreach ($key in $mapLabelOffsets.Keys) {
	$r=$Regions[$key]; $offset=$mapLabelOffsets[$key]
	$lx=[Math]::Max(2,[Math]::Min(420,[int]($r.X/2)+$offset[0])); $ly=50+[int]($r.Y/2)+$offset[1]
	[void]$gui.AppendLine("`t`tinstantTextBoxType = { name = `"map_label_$key`" position = { x = $lx y = $ly } font = `"hoi_16mbs`" text = `"JAP_pacific_map_label_$key`" format = left maxWidth = 78 alwaystransparent = yes }")
}
# Japan and the US west coast retain flag textures inside their State masks.
# Only directly controlled overseas key bases receive physical flagpoles.
$flagBases = [ordered]@{ 'singapore'=1021; 'philippines'=327; 'rabaul'=737; 'marianas'=646; 'wake'=632; 'midway'=631; 'hawaii'=629; 'iwo_jima'=645; 'okinawa'=526 }
foreach ($key in $flagBases.Keys) {
	$r=$Regions[$key]; $fx=[Math]::Max(0,[Math]::Min(454,[int]($r.X/2)-7)); $fy=50+[int]($r.Y/2)-40
	[void]$gui.AppendLine("`t`ticonType = { name = `"flag_$($key)_JAP`" spriteType = `"GFX_JAP_pacific_flag_JAP`" position = { x = $fx y = $fy } scale = 0.5 alwaystransparent = yes }")
	[void]$gui.AppendLine("`t`ticonType = { name = `"flag_$($key)_USA`" spriteType = `"GFX_JAP_pacific_flag_USA`" position = { x = $fx y = $fy } scale = 0.5 alwaystransparent = yes }")
}
[void]$gui.AppendLine("`t`tinstantTextBoxType = { name = `"map_legend`" position = { x = 6 y = 316 } font = `"hoi_16mbs`" text = `"JAP_pacific_map_legend`" format = center maxWidth = 488 alwaystransparent = yes }")
[void]$gui.AppendLine("`t}")
[void]$gui.AppendLine('}')

$scripted = [System.Text.StringBuilder]::new()
[void]$scripted.AppendLine('scripted_gui = {')
[void]$scripted.AppendLine("`tJAP_pacific_strategy_map_ui = {")
[void]$scripted.AppendLine("`t`tcontext_type = decision_category")
[void]$scripted.AppendLine("`t`twindow_name = `"JAP_pacific_strategy_map_window`"")
[void]$scripted.AppendLine("`t`ttriggers = {")
foreach ($s in $States) {
	[void]$scripted.AppendLine("`t`t`tstate_$($s.Id)_JAP_visible = { $($s.Id) = { controller = { $(Get-SideTrigger 'JAP') } } }")
	[void]$scripted.AppendLine("`t`t`tstate_$($s.Id)_USA_visible = { $($s.Id) = { controller = { $(Get-SideTrigger 'USA') } } }")
}
[void]$scripted.AppendLine("`t`t`tarrow_north_1_visible = { has_war_with = USA $(Get-RegionControl 'marianas' 'JAP' $true) }")
[void]$scripted.AppendLine("`t`t`tarrow_north_2_visible = { has_war_with = USA $(Get-RegionControl 'marianas' 'JAP') $(Get-RegionControl 'wake' 'JAP' $true) }")
[void]$scripted.AppendLine("`t`t`tarrow_north_3_visible = { has_war_with = USA $(Get-RegionControl 'wake' 'JAP') $(Get-RegionControl 'midway' 'JAP' $true) }")
[void]$scripted.AppendLine("`t`t`tarrow_north_4_visible = { has_war_with = USA $(Get-RegionControl 'midway' 'JAP') $(Get-RegionControl 'hawaii' 'JAP' $true) }")
[void]$scripted.AppendLine("`t`t`tarrow_south_1_visible = { has_war = yes $(Get-RegionControl 'malaya' 'JAP' $true) }")
[void]$scripted.AppendLine("`t`t`tarrow_south_2_visible = { has_war = yes $(Get-RegionControl 'malaya' 'JAP') $(Get-RegionControl 'singapore' 'JAP' $true) }")
[void]$scripted.AppendLine("`t`t`tarrow_east_1_visible = { has_war = yes $(Get-RegionControl 'philippines' 'JAP' $true) }")
[void]$scripted.AppendLine("`t`t`tarrow_east_2_visible = { has_war = yes $(Get-RegionControl 'philippines' 'JAP') $(Get-RegionControl 'dei' 'JAP' $true) }")
[void]$scripted.AppendLine("`t`t`tarrow_rabaul_1_visible = { has_war = yes $(Get-RegionControl 'new_guinea' 'JAP' $true) }")
foreach ($key in $islandKeys) {
	[void]$scripted.AppendLine("`t`t`tisolation_$($key)_visible = { OR = { has_country_flag = JAP_pacific_$($key)_isolated has_country_flag = JAP_pacific_$($key)_blockaded } }")
	[void]$scripted.AppendLine("`t`t`tisolation_$($key)_label_visible = { OR = { has_country_flag = JAP_pacific_$($key)_isolated has_country_flag = JAP_pacific_$($key)_blockaded } }")
}
foreach ($key in $flagBases.Keys) {
	$state=$flagBases[$key]
	[void]$scripted.AppendLine("`t`t`tflag_$($key)_JAP_visible = { $state = { controller = { original_tag = JAP } } }")
	[void]$scripted.AppendLine("`t`t`tflag_$($key)_USA_visible = { $state = { controller = { original_tag = USA } } }")
}
[void]$scripted.AppendLine("`t`t}")
[void]$scripted.AppendLine("`t}")
[void]$scripted.AppendLine('}')

New-Item -ItemType Directory -Force (Join-Path $ModRoot 'interface') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $ModRoot 'common\scripted_guis') | Out-Null
[System.IO.File]::WriteAllText((Join-Path $ModRoot 'interface\JAP_pacific_map.gfx'),$gfx.ToString(),[System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $ModRoot 'interface\JAP_pacific_map.gui'),$gui.ToString(),[System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $ModRoot 'common\scripted_guis\JAP_pacific_map.txt'),$scripted.ToString(),[System.Text.UTF8Encoding]::new($false))
Write-Host "Generated Pacific strategy GUI for $($States.Count) states and $($Regions.Count) regions."
