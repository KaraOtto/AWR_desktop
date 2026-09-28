param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$issues = New-Object System.Collections.Generic.List[string]
$scriptFiles = Get-ChildItem -LiteralPath $Root -Recurse -File | Where-Object { $_.Extension -in '.txt', '.yml' }

foreach ($file in $scriptFiles) {
    $text = [IO.File]::ReadAllText($file.FullName)
    $depth = 0
    $inQuote = $false
    $escaped = $false
    for ($i = 0; $i -lt $text.Length; $i++) {
        $c = $text[$i]
        if ($escaped) { $escaped = $false; continue }
        if ($c -eq '\') { $escaped = $true; continue }
        if ($c -eq '"') { $inQuote = -not $inQuote; continue }
        if (-not $inQuote) {
            if ($c -eq '{') { $depth++ }
            elseif ($c -eq '}') { $depth-- }
            if ($depth -lt 0) { $issues.Add("$($file.FullName): closing brace without opener"); break }
        }
    }
    if ($depth -ne 0) { $issues.Add("$($file.FullName): brace depth $depth") }
    if ($inQuote) { $issues.Add("$($file.FullName): unclosed quote") }
}

$loc = Join-Path $Root 'localisation\simp_chinese\CHI_corruption_l_simp_chinese.yml'
if (Test-Path -LiteralPath $loc) {
    $bytes = [IO.File]::ReadAllBytes($loc)
    if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
        $issues.Add("${loc}: localisation file is missing UTF-8 BOM")
    }
}

$required = @(
    'common\on_actions\CHI_on_actions.txt',
    'common\scripted_effects\CHI_corruption_effects.txt',
    'common\ideas\CHI_corruption_ideas.txt',
    'common\unit_leader\CHI_corruption_traits.txt',
    'common\decisions\CHI_corruption_decisions.txt',
    'common\decisions\categories\CHI_corruption_categories.txt',
    'events\CHI_corruption_events.txt',
    'localisation\simp_chinese\CHI_corruption_l_simp_chinese.yml'
)
foreach ($relative in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $Root $relative))) { $issues.Add("missing: $relative") }
}

if ($issues.Count -gt 0) {
    $issues | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Host "Validated $($scriptFiles.Count) script/localisation files under $Root"
