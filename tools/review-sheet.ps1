# Prints one season for fact-checking: episode, title, TVmaze reference and the current Hebrew blurb.
# Usage: .\tools\review-sheet.ps1 -Id friends -Season 3
param([Parameter(Mandatory)] [string]$Id, [Parameter(Mandatory)] [int]$Season)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
[Console]::OutputEncoding = $utf8
$ref = [System.IO.File]::ReadAllText((Join-Path $root "work\$Id.ref.json"), $utf8) | ConvertFrom-Json
$out = [System.IO.File]::ReadAllText((Join-Path $root ("work\out\$Id\s{0:D2}.json" -f $Season)), $utf8) | ConvertFrom-Json
foreach ($ep in ($ref.eps | Where-Object { $_.s -eq $Season })) {
  "=== S{0}E{1} | {2}" -f $ep.s, $ep.e, $ep.title
  "REF: $($ep.ref)"
  "HE : $($out.([string]$ep.e))"
  ""
}
