# Merges the Hebrew blurbs in work/out/<Id>/sNN.json with the episode list in work/<Id>.ref.json
# into the published file data/series/<Id>.json, checks them, and rebuilds data/catalog.json.
#
# Each work/out/<Id>/sNN.json is a JSON object keyed by episode number: {"1":"תקציר...","2":"..."}
# An empty string means "not sure about this one": the episode stays in the count but is never asked.
#
# Usage: .\tools\merge-series.ps1 -Id friends        (add -CheckOnly to only report problems)
param([Parameter(Mandatory)] [string]$Id, [switch]$CheckOnly)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
$ref = [System.IO.File]::ReadAllText((Join-Path $root "work\$Id.ref.json"), $utf8) | ConvertFrom-Json
$outDir = Join-Path $root "work\out\$Id"

$problems = New-Object System.Collections.Generic.List[string]
$blurbs = @{}
for ($s = 1; $s -le $ref.seasons.Count; $s++) {
  $f = Join-Path $outDir ("s{0:D2}.json" -f $s)
  if (-not (Test-Path $f)) { $problems.Add("season ${s}: file missing ($f)"); continue }
  try { $obj = [System.IO.File]::ReadAllText($f, $utf8) | ConvertFrom-Json }
  catch { $problems.Add("season ${s}: not valid JSON - $($_.Exception.Message)"); continue }
  foreach ($p in $obj.PSObject.Properties) { $blurbs["$s-$($p.Name)"] = [string]$p.Value }
}

$eps = @(); $empty = 0
foreach ($ep in $ref.eps) {
  $key = "$($ep.s)-$($ep.e)"
  if (-not $blurbs.ContainsKey($key)) { $problems.Add("S$($ep.s)E$($ep.e): no blurb"); $d = "" }
  else { $d = $blurbs[$key].Trim() }
  if ($d -eq "") { $empty++ }
  else {
    if ($d -notmatch "[֐-׿]") { $problems.Add("S$($ep.s)E$($ep.e): not Hebrew") }
    if ($d.Length -lt 40 -or $d.Length -gt 420) { $problems.Add("S$($ep.s)E$($ep.e): length $($d.Length) (want 40-420)") }
    if ($ep.title.Length -gt 6 -and $d.ToLower().Contains($ep.title.ToLower())) { $problems.Add("S$($ep.s)E$($ep.e): blurb contains the episode title") }
  }
  $eps += ,@([int]$ep.s, [int]$ep.e, [string]$ep.title, $d)
}
$extra = $blurbs.Keys | Where-Object { $k = $_; -not ($ref.eps | Where-Object { "$($_.s)-$($_.e)" -eq $k }) }
foreach ($k in $extra) { $problems.Add("blurb for $k, which is not in the episode list") }

"{0}: {1} episodes, {2} with blurbs, {3} left empty, {4} problems" -f $Id, $ref.eps.Count, ($ref.eps.Count - $empty), $empty, $problems.Count
$problems | Select-Object -First 40 | ForEach-Object { "  - $_" }
if ($CheckOnly) { return }

$series = [ordered]@{ id = $Id; he = $ref.he; en = $ref.en; tint = $ref.tint; seasons = @($ref.seasons | ForEach-Object { [int]$_ }); eps = $eps }
$dataDir = Join-Path $root "data\series"
New-Item -ItemType Directory -Force $dataDir | Out-Null
[System.IO.File]::WriteAllText((Join-Path $dataDir "$Id.json"), ($series | ConvertTo-Json -Depth 5 -Compress), $utf8)
& (Join-Path $PSScriptRoot "build-catalog.ps1")
