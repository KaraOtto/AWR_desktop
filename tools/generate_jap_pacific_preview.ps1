$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$ModRoot = Split-Path -Parent $PSScriptRoot
$MapRoot = Join-Path $ModRoot 'gfx\interface\JAP_pacific\map'
$PreviewPath = Join-Path $ModRoot 'art_source\JAP_pacific\pacific_strategy_map_preview.png'

$stateRows = @{}
Get-Content (Join-Path $MapRoot 'state_manifest.csv') | ForEach-Object {
	$p=$_ -split ';'
	$stateRows[[int]$p[0]]=[pscustomobject]@{Id=[int]$p[0];X=[int]$p[1];Y=[int]$p[2];W=[int]$p[3];H=[int]$p[4]}
}
$regions=@{}
Get-Content (Join-Path $MapRoot 'region_manifest.csv') | ForEach-Object {
	$p=$_ -split ';'
	$regions[$p[0]]=[pscustomobject]@{X=[int]$p[1];Y=[int]$p[2];States=@($p[3]-split ','|ForEach-Object {[int]$_})}
}

$japaneseStates=@(282,528,529,530,531,532,533,534,535,536,1018,1019,1020,524,526,645,646)
$americanStates=@(336,1021,1060,1061,1062,1063,1064,1065,327,623,624,625,626,627,628,1025,1026,1027,334,335,667,668,669,672,673,1047,1048,1049,1050,1051,1052,1053,1054,1055,1056,1057,1058,523,634,638,639,979,1070,1073,629,631,632,378,385,386)

$canvas=[System.Drawing.Bitmap]::FromFile((Join-Path $MapRoot 'pacific_map_base.png'))
$result=New-Object System.Drawing.Bitmap $canvas.Width,$canvas.Height
$g=[System.Drawing.Graphics]::FromImage($result)
try {
	$g.DrawImageUnscaled($canvas,0,0)
	foreach($side in @(@{Ids=$japaneseStates;Frame=0},@{Ids=$americanStates;Frame=1})) {
		foreach($id in $side.Ids) {
			if(-not $stateRows.ContainsKey($id)){continue}
			$r=$stateRows[$id]
			$atlas=[System.Drawing.Bitmap]::FromFile((Join-Path $MapRoot "state_$id.png"))
			try {
				$src=New-Object System.Drawing.Rectangle ($side.Frame*$r.W),0,$r.W,$r.H
				$dst=New-Object System.Drawing.Rectangle $r.X,$r.Y,$r.W,$r.H
				$g.DrawImage($atlas,$dst,$src,[System.Drawing.GraphicsUnit]::Pixel)
			} finally {$atlas.Dispose()}
		}
	}
	$border=[System.Drawing.Bitmap]::FromFile((Join-Path $MapRoot 'pacific_map_borders.png'))
	try {$g.DrawImageUnscaled($border,0,0)} finally {$border.Dispose()}
	foreach($arrow in @('north_1','south_1','east_1','rabaul_1')) {
		$img=[System.Drawing.Bitmap]::FromFile((Join-Path $MapRoot "arrow_$arrow.png"))
		try {$g.DrawImageUnscaled($img,0,0)} finally {$img.Dispose()}
	}
	$flagJ=[System.Drawing.Bitmap]::FromFile((Join-Path $MapRoot 'pacific_flag_JAP.png'))
	$flagU=[System.Drawing.Bitmap]::FromFile((Join-Path $MapRoot 'pacific_flag_USA.png'))
	try {
		foreach($key in @('iwo_jima','okinawa')) {$r=$regions[$key];$x=[Math]::Max(0,[Math]::Min(916,$r.X-14));$g.DrawImageUnscaled($flagJ,$x,$r.Y-78)}
		foreach($key in @('singapore','philippines','rabaul','marianas','wake','midway','hawaii')) {$r=$regions[$key];$x=[Math]::Max(0,[Math]::Min(916,$r.X-14));$g.DrawImageUnscaled($flagU,$x,$r.Y-78)}
	} finally {$flagJ.Dispose();$flagU.Dispose()}
	$result.Save($PreviewPath,[System.Drawing.Imaging.ImageFormat]::Png)
} finally {$g.Dispose();$result.Dispose();$canvas.Dispose()}

Write-Host "Pacific static preview written to $PreviewPath"
