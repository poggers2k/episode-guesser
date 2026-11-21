# Lists blurbs that contain characters other than Hebrew, printable ASCII and a few typographic marks
# (catches text broken by an encoding mix-up). Usage: .\tools\scan-chars.ps1
$root = Split-Path -Parent $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false
function Test-Odd([int]$c) { -not (($c -ge 0x0590 -and $c -le 0x05FF) -or ($c -ge 0x20 -and $c -le 0x7E) -or $c -in 0x2013, 0x2014, 0x2019, 0xA0) }
$hits = 0
foreach ($f in Get-ChildItem (Join-Path $root "work\out") -Recurse -Filter *.json) {
  $o = [System.IO.File]::ReadAllText($f.FullName, $utf8) | ConvertFrom-Json
  foreach ($p in $o.PSObject.Properties) {
    $odd = @($p.Value.ToCharArray() | Where-Object { Test-Odd ([int]$_) } | ForEach-Object { 'U+{0:X4}' -f [int]$_ })
    if ($odd.Count) { $hits++; "{0}/{1} E{2}: {3}" -f $f.Directory.Name, $f.BaseName, $p.Name, ($odd -join ",") }
  }
}
"suspicious blurbs: $hits"
