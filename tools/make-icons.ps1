# Draws the app icons (a dark TV screen with an amber S?E? slug) into icons/.
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root "icons"
New-Item -ItemType Directory -Force $dir | Out-Null

function New-Icon([int]$size, [string]$name, [double]$inset) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = "AntiAlias"; $g.TextRenderingHint = "AntiAliasGridFit"
  $g.Clear([System.Drawing.ColorTranslator]::FromHtml("#0F111A"))
  $pad = [int]($size * $inset)
  $w = $size - 2 * $pad; $h = [int]($w * 0.72); $y = [int](($size - $h) / 2)
  $r = [int]($w * 0.12)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $path.AddArc($pad, $y, $r * 2, $r * 2, 180, 90); $path.AddArc($pad + $w - $r * 2, $y, $r * 2, $r * 2, 270, 90)
  $path.AddArc($pad + $w - $r * 2, $y + $h - $r * 2, $r * 2, $r * 2, 0, 90); $path.AddArc($pad, $y + $h - $r * 2, $r * 2, $r * 2, 90, 90)
  $path.CloseFigure()
  $g.FillPath((New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#1C2033"))), $path)
  $g.DrawPath((New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#2E3350")), ([single]($size * 0.02))), $path)
  $amber = [System.Drawing.ColorTranslator]::FromHtml("#F2B33D")
  $font = New-Object System.Drawing.Font "Consolas", ([single]($w * 0.2)), ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat; $fmt.Alignment = "Center"; $fmt.LineAlignment = "Center"
  $rect = New-Object System.Drawing.RectangleF $pad, $y, $w, $h
  $g.DrawString("S?E?", $font, (New-Object System.Drawing.SolidBrush $amber), $rect, $fmt)
  $bmp.Save((Join-Path $dir $name), [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
}
New-Icon 192 "icon-192.png" 0.1
New-Icon 512 "icon-512.png" 0.1
New-Icon 512 "icon-maskable-512.png" 0.2
New-Icon 180 "apple-touch-icon.png" 0.1
"icons written to $dir"
