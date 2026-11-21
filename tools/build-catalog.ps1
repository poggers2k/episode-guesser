# Rebuilds data/catalog.json (the list of series the app shows) from every data/series/*.json.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
# tools/genres.json maps series id -> "sitcom" | "drama" (the app groups the home screen by it)
$genres = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "genres.json"), $utf8) | ConvertFrom-Json
$items = @()
foreach ($f in Get-ChildItem (Join-Path $root "data\series") -Filter *.json | Sort-Object Name) {
  $s = [System.IO.File]::ReadAllText($f.FullName, $utf8) | ConvertFrom-Json
  $playable = @($s.eps | Where-Object { $_[3] }).Count
  $g = $genres.($s.id); if (-not $g) { $g = "other" }
  $items += [ordered]@{
    id = $s.id; he = $s.he; en = $s.en; tint = $s.tint; genre = $g
    seasons = $s.seasons.Count; episodes = @($s.eps).Count; playable = $playable
    v = (Get-FileHash $f.FullName -Algorithm SHA1).Hash.Substring(0, 10)
  }
}
$catalog = [ordered]@{ updated = (Get-Date).ToString("yyyy-MM-dd"); series = $items }
[System.IO.File]::WriteAllText((Join-Path $root "data\catalog.json"), ($catalog | ConvertTo-Json -Depth 4), $utf8)
"catalog: $($items.Count) series"
