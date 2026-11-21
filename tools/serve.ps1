# Minimal static file server for testing the app locally: .\tools\serve.ps1 [-Port 8765]
param([int]$Port = 8765)
$root = Split-Path -Parent $PSScriptRoot
$types = @{ ".html"="text/html; charset=utf-8"; ".css"="text/css; charset=utf-8"; ".js"="text/javascript; charset=utf-8";
  ".json"="application/json; charset=utf-8"; ".webmanifest"="application/manifest+json"; ".png"="image/png"; ".svg"="image/svg+xml" }
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/")
$l.Start()
Write-Host "Serving $root on http://localhost:$Port"
while ($l.IsListening) {
  $c = $l.GetContext()
  $rel = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart("/"))
  if ($rel -eq "") { $rel = "index.html" }
  $file = [System.IO.Path]::GetFullPath((Join-Path $root $rel))
  if ($file.StartsWith($root) -and (Test-Path $file -PathType Leaf) -and $rel -notmatch "^(work|tools)/") {
    $bytes = [System.IO.File]::ReadAllBytes($file)
    $ext = [System.IO.Path]::GetExtension($file).ToLower()
    $c.Response.ContentType = $(if ($types[$ext]) { $types[$ext] } else { "application/octet-stream" })
    $c.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  } else { $c.Response.StatusCode = 404 }
  $c.Response.Close()
}
