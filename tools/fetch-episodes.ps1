# Downloads a show's full episode list from TVmaze into work/<Id>.ref.json.
# The English summaries there are reference material for writing original Hebrew blurbs.
# They are never published: work/ is not part of the site.
#
# Usage: .\tools\fetch-episodes.ps1 -Id friends -He "חברים" -Query "Friends" [-TvmazeId 431] [-Tint "#7B5EA7"]
param(
  [Parameter(Mandatory)] [string]$Id,
  [Parameter(Mandatory)] [string]$He,
  [string]$Query,
  [int]$TvmazeId = 0,
  [string]$Tint = "#6B7280"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$workDir = Join-Path $root "work"
New-Item -ItemType Directory -Force $workDir | Out-Null

if ($TvmazeId -gt 0) {
  $show = Invoke-RestMethod "https://api.tvmaze.com/shows/$TvmazeId`?embed=episodes"
} else {
  $show = Invoke-RestMethod ("https://api.tvmaze.com/singlesearch/shows?q=" + [uri]::EscapeDataString($Query) + "&embed=episodes")
}

function Remove-Html([string]$s) {
  if (-not $s) { return "" }
  $t = [regex]::Replace($s, "<[^>]+>", " ")
  $t = [System.Net.WebUtility]::HtmlDecode($t)
  return ([regex]::Replace($t, "\s+", " ")).Trim()
}

$eps = $show._embedded.episodes | Where-Object { $_.type -eq "regular" -and $null -ne $_.number } |
  Sort-Object season, number | ForEach-Object {
    [pscustomobject][ordered]@{ s = [int]$_.season; e = [int]$_.number; title = $_.name; airdate = $_.airdate; ref = (Remove-Html $_.summary) }
  }

$maxSeason = ($eps | Measure-Object -Property s -Maximum).Maximum
$seasons = @()
for ($i = 1; $i -le $maxSeason; $i++) {
  $seasons += (($eps | Where-Object { $_.s -eq $i } | Measure-Object -Property e -Maximum).Maximum)
}

$out = [ordered]@{
  id = $Id; he = $He; en = $show.name; tint = $Tint; tvmazeId = $show.id
  premiered = $show.premiered; seasons = $seasons; eps = @($eps)
}
$path = Join-Path $workDir "$Id.ref.json"
[System.IO.File]::WriteAllText($path, ($out | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding $false))
$noRef = @($eps | Where-Object { -not $_.ref }).Count
"{0} | TVmaze {1} | premiered {2} | {3} seasons {4} | {5} episodes ({6} without summary) -> work/{7}.ref.json" -f $show.name, $show.id, $show.premiered, $seasons.Count, ($seasons -join ","), @($eps).Count, $noRef, $Id
