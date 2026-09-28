param(
	[string]$FocusFile = "common\national_focus\japan.txt",
	[string]$OutputFile = "localisation\simp_chinese\JAP_focus_l_simp_chinese.yml"
)

$ErrorActionPreference = "Stop"
$ModRoot = Split-Path -Parent $PSScriptRoot
$FocusPath = Join-Path $ModRoot $FocusFile
$OutputPath = Join-Path $ModRoot $OutputFile
$Text = [System.IO.File]::ReadAllText($FocusPath)

# 只读取 focus = {#中文名称} 紧邻的 id，避免把国策树 ID 和内嵌界面 ID 当成国策。
$Pattern = 'focus\s*=\s*\{\s*#\s*([^\r\n]+)\r?\n\s*id\s*=\s*([A-Za-z0-9_]+)'
$Matches = [regex]::Matches($Text, $Pattern)
$Entries = [ordered]@{}

foreach ($Match in $Matches) {
	$RawComment = $Match.Groups[1].Value.Trim()
	$Id = $Match.Groups[2].Value
	$Line = 1 + [regex]::Matches($Text.Substring(0, $Match.Index), "`n").Count
	# “触发XX”属于开发备注，不作为玩家可见标题；历史括注（如诺门罕）予以保留。
	$Title = [regex]::Replace($RawComment, '（触发\d+）', '').Trim()
	if (-not $Entries.Contains($Id)) {
		$Entries[$Id] = [pscustomobject]@{
			Id = $Id
			Title = $Title
			Line = $Line
			Comments = [System.Collections.Generic.List[string]]::new()
		}
	}
	$Entries[$Id].Comments.Add($RawComment)
}

function Get-Section([int]$Line) {
	if ($Line -lt 1074) { return '国内政治与战时体制' }
	if ($Line -lt 1274) { return '对外战略与大陆政策' }
	if ($Line -lt 2164) { return '工业、资源与经济动员' }
	if ($Line -lt 2682) { return '帝国陆军' }
	if ($Line -lt 3062) { return '帝国海军' }
	if ($Line -lt 3456) { return '帝国航空兵力' }
	return '太平洋战争与本土防卫'
}

function Get-Description([string]$Title, [int]$Line) {
	$Section = Get-Section $Line
	switch ($Section) {
		'国内政治与战时体制' {
			if ($Title -match '内阁') { return "组建${Title}，在不断变化的国内外局势下重整政府，并贯彻帝国的既定方针。" }
			if ($Title -match '终战|波茨坦|玉音|国体护持') { return "围绕「${Title}」作出决定，这将直接影响战争的结束方式与帝国未来的政治秩序。" }
			return "推行「${Title}」，调整国内政治与战时行政体系，使国家机器能够贯彻既定国策。"
		}
		'对外战略与大陆政策' { return "推行「${Title}」，重新部署帝国在东亚大陆的外交、统治机构与军事战略。" }
		'工业、资源与经济动员' { return "推进「${Title}」，扩充帝国及其控制区的工业、资源与战争生产能力。" }
		'帝国陆军' { return "落实「${Title}」，改进帝国陆军的编制、装备、训练与地面作战能力。" }
		'帝国海军' { return "落实「${Title}」，整备帝国海军的舰队、基地、训练与海上作战体系。" }
		'帝国航空兵力' { return "推进「${Title}」，强化航空工业、飞行训练以及陆海军航空作战能力。" }
		default { return "围绕「${Title}」制定并执行战争计划，以改善帝国在太平洋与本土防卫中的战略态势。" }
	}
}

$Builder = [System.Text.StringBuilder]::new()
[void]$Builder.AppendLine('l_simp_chinese:')
[void]$Builder.AppendLine(' # 本文件由 tools/generate_japan_focus_localisation.ps1 根据 japan.txt 中各国策 ID 后的注释生成。')
[void]$Builder.AppendLine(' # 每个条目的注释保留原始名称；原重复 ID 已在国策文件中用数字后缀拆分。')

$CurrentSection = ''
foreach ($Entry in $Entries.Values) {
	$Section = Get-Section $Entry.Line
	if ($Section -ne $CurrentSection) {
		[void]$Builder.AppendLine('')
		[void]$Builder.AppendLine(" # ===== $Section =====")
		$CurrentSection = $Section
	}
	$CommentText = $Entry.Comments -join ' / '
	[void]$Builder.AppendLine(" # $($Entry.Id)｜原注释：$CommentText")
	[void]$Builder.AppendLine(" $($Entry.Id):0 `"$($Entry.Title)`"")
	$Description = Get-Description $Entry.Title $Entry.Line
	[void]$Builder.AppendLine(" $($Entry.Id)_desc:0 `"$Description`"")
}

# HOI4 本地化要求 UTF-8 BOM。
$Utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($OutputPath, $Builder.ToString(), $Utf8Bom)
Write-Host "Generated $($Entries.Count) Japanese focus localisation entries at $OutputPath"
