$ErrorActionPreference = "Stop"
$ModRoot = Split-Path -Parent $PSScriptRoot
$RenderScale = 2
$Manifest = Join-Path $ModRoot "gfx\interface\JAP_china_incident\map\map_manifest.csv"
$Rows = Get-Content $Manifest | ForEach-Object {
	$p = $_ -split ';'
	[pscustomobject]@{ Id = [int]$p[0]; X = [int]$p[1]; Y = [int]$p[2]; W = [int]$p[3]; H = [int]$p[4] }
}
$Flags = Get-Content (Join-Path $ModRoot "gfx\interface\JAP_china_incident\map\flag_manifest.csv") | ForEach-Object {
	$p = $_ -split ';'
	[pscustomobject]@{ Tag = $p[0]; Frame = [int]$p[1] }
}

$gfx = [System.Text.StringBuilder]::new()
[void]$gfx.AppendLine('spriteTypes = {')
[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_cis_map_base`" textureFile = `"gfx/interface/JAP_china_incident/map/china_incident_map_base.png`" }")
[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_cis_map_borders`" textureFile = `"gfx/interface/JAP_china_incident/map/china_incident_map_borders.png`" }")
foreach ($r in $Rows) {
	[void]$gfx.AppendLine("`tspriteType = { name = `"GFX_JAP_cis_state_$($r.Id)`" textureFile = `"gfx/interface/JAP_china_incident/map/state_$($r.Id).png`" noOfFrames = $($Flags.Count) }")
}
[void]$gfx.AppendLine('}')

$gui = [System.Text.StringBuilder]::new()
[void]$gui.AppendLine('guiTypes = {')
[void]$gui.AppendLine("`tcontainerWindowType = {")
[void]$gui.AppendLine("`t`tname = `"JAP_cis_china_map_window`"")
[void]$gui.AppendLine("`t`tposition = { x = 0 y = 0 }")
[void]$gui.AppendLine("`t`tsize = { width = 500 height = 340 }")
[void]$gui.AppendLine("`t`tclipping = no")
[void]$gui.AppendLine("`t`tinstantTextBoxType = { name = `"map_title`" position = { x = 0 y = 7 } font = `"hoi_20b`" text = `"JAP_cis_map_title`" format = center maxWidth = 500 alwaystransparent = yes }")
[void]$gui.AppendLine("`t`tinstantTextBoxType = { name = `"map_side`" position = { x = 0 y = 30 } font = `"hoi_16mbs`" text = `"JAP_cis_map_side_label`" format = center maxWidth = 500 alwaystransparent = yes }")
[void]$gui.AppendLine("`t`ticonType = { name = `"china_base`" spriteType = `"GFX_JAP_cis_map_base`" position = { x = 15 y = 49 } scale = 0.5 alwaystransparent = yes }")
foreach ($r in $Rows) {
	$x = 15 + [int]($r.X / $RenderScale); $y = 49 + [int]($r.Y / $RenderScale)
	foreach ($flag in $Flags) {
		[void]$gui.AppendLine("`t`ticonType = { name = `"state_$($r.Id)_$($flag.Tag)`" spriteType = `"GFX_JAP_cis_state_$($r.Id)`" position = { x = $x y = $y } frame = $($flag.Frame) scale = 0.5 alwaystransparent = yes }")
	}
}
[void]$gui.AppendLine("`t`ticonType = { name = `"china_borders`" spriteType = `"GFX_JAP_cis_map_borders`" position = { x = 15 y = 49 } scale = 0.5 alwaystransparent = yes }")
[void]$gui.AppendLine("`t`tinstantTextBoxType = { name = `"map_legend`" position = { x = 10 y = 313 } font = `"hoi_16mbs`" text = `"JAP_cis_map_legend`" format = center maxWidth = 480 alwaystransparent = yes }")
[void]$gui.AppendLine("`t}")
[void]$gui.AppendLine('}')

$scripted = [System.Text.StringBuilder]::new()
[void]$scripted.AppendLine('scripted_gui = {')
[void]$scripted.AppendLine("`tJAP_cis_china_map_ui = {")
[void]$scripted.AppendLine("`t`tcontext_type = decision_category")
[void]$scripted.AppendLine("`t`twindow_name = `"JAP_cis_china_map_window`"")
[void]$scripted.AppendLine("`t`ttriggers = {")
foreach ($r in $Rows) {
	foreach ($flag in $Flags) {
		$independent = if ($flag.Tag -eq 'JAP') { "AND = { is_in_faction = no original_tag = JAP }" } else { "AND = { is_in_faction = no original_tag = $($flag.Tag) has_war_with = JAP }" }
		$faction = "AND = { is_in_faction = yes faction_leader = { original_tag = $($flag.Tag) } OR = { original_tag = JAP is_in_faction_with = JAP has_war_with = JAP faction_leader = { has_war_with = JAP } } }"
		[void]$scripted.AppendLine("`t`t`tstate_$($r.Id)_$($flag.Tag)_visible = { $($r.Id) = { controller = { OR = { $independent $faction } } } }")
	}
}
[void]$scripted.AppendLine("`t`t}")
[void]$scripted.AppendLine("`t}")
[void]$scripted.AppendLine('}')

New-Item -ItemType Directory -Force (Join-Path $ModRoot 'common\scripted_guis') | Out-Null
[System.IO.File]::WriteAllText((Join-Path $ModRoot 'interface\JAP_china_incident_map.gfx'), $gfx.ToString(), [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $ModRoot 'interface\JAP_china_incident_map.gui'), $gui.ToString(), [System.Text.UTF8Encoding]::new($false))
[System.IO.File]::WriteAllText((Join-Path $ModRoot 'common\scripted_guis\JAP_china_incident_map.txt'), $scripted.ToString(), [System.Text.UTF8Encoding]::new($false))
Write-Host "Generated scripted decision map GUI for $($Rows.Count) Chinese core states."
