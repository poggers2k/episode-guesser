# Safely replaces one blurb (parses and re-writes the JSON; never edits text by search-and-replace).
# Usage: .\tools\set-blurb.ps1 -Id friends -Season 3 -Episode 15 -Text "תקציר חדש"
#        -Text "" leaves the episode out of the game.
param(
  [Parameter(Mandatory)] [string]$Id,
  [Parameter(Mandatory)] [int]$Season,
  [Parameter(Mandatory)] [int]$Episode,
  [Parameter(Mandatory)] [AllowEmptyString()] [string]$Text
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
$path = Join-Path $root ("work\out\$Id\s{0:D2}.json" -f $Season)
$obj = [System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json
$key = [string]$Episode
if (-not ($obj.PSObject.Properties.Name -contains $key)) { throw "S${Season}E${Episode} is not in $path" }
# Hebrew geresh/gershayim by code point: the script file itself stays pure ASCII so Windows PowerShell reads it correctly.
$Text = $Text.Replace("'", [string][char]0x05F3).Replace('"', [string][char]0x05F4).Trim()
$obj.$key = $Text
[System.IO.File]::WriteAllText($path, ($obj | ConvertTo-Json), $utf8)
"S${Season}E${Episode} updated"
