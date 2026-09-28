param(
  [string]$Source = 'C:\Users\THANH\.codex\generated_images\01a05cb4-6c72-7630-b589-d6991fbe9f27\exec-636344a3-7928-4513-af6e-f0fe6c2448ee.png',
  [string]$Output = "$PSScriptRoot\assets\feature-graphic-1024x500.png"
)

Add-Type -AssemblyName System.Drawing

$sourceImage = [System.Drawing.Image]::FromFile($Source)
$canvas = New-Object System.Drawing.Bitmap 1024, 500
$graphics = [System.Drawing.Graphics]::FromImage($canvas)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$sourceRatio = $sourceImage.Width / $sourceImage.Height
$targetRatio = 1024 / 500
if ($sourceRatio -gt $targetRatio) {
  $cropHeight = $sourceImage.Height
  $cropWidth = [int]($cropHeight * $targetRatio)
  $cropX = [int](($sourceImage.Width - $cropWidth) / 2)
  $cropY = 0
} else {
  $cropWidth = $sourceImage.Width
  $cropHeight = [int]($cropWidth / $targetRatio)
  $cropX = 0
  $cropY = [int](($sourceImage.Height - $cropHeight) / 2)
}
$dest = New-Object System.Drawing.Rectangle 0, 0, 1024, 500
$src = New-Object System.Drawing.Rectangle $cropX, $cropY, $cropWidth, $cropHeight
$graphics.DrawImage($sourceImage, $dest, $src, [System.Drawing.GraphicsUnit]::Pixel)

$shade = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(105,4,14,11))
$graphics.FillRectangle($shade, 0, 0, 1024, 500)

$brandFont = New-Object System.Drawing.Font 'Segoe UI', 54, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$taglineFont = New-Object System.Drawing.Font 'Segoe UI', 25, ([System.Drawing.FontStyle]::Regular), ([System.Drawing.GraphicsUnit]::Pixel)
$labelFont = New-Object System.Drawing.Font 'Segoe UI', 18, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
$white = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
$muted = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(225,218,235,227))
$mint = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,113,230,177))
$dark = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255,9,35,28))

$graphics.DrawString('RepCoach AI', $brandFont, $white, 58, 145)
$graphics.DrawString('Count smarter. Train with purpose.', $taglineFont, $muted, 62, 222)
$graphics.FillRectangle($mint, 62, 280, 205, 42)
$graphics.DrawString('ON-DEVICE POSE AI', $labelFont, $dark, 75, 287)

$directory = Split-Path -Parent $Output
New-Item -ItemType Directory -Force $directory | Out-Null
$canvas.Save($Output, [System.Drawing.Imaging.ImageFormat]::Png)

$shade.Dispose(); $brandFont.Dispose(); $taglineFont.Dispose(); $labelFont.Dispose(); $white.Dispose(); $muted.Dispose(); $mint.Dispose(); $dark.Dispose()
$graphics.Dispose(); $canvas.Dispose(); $sourceImage.Dispose()

$iconSourcePath = Join-Path $PSScriptRoot '..\rep_counter_app\assets\branding\app-icon-1024.png'
$iconOutputPath = Join-Path $PSScriptRoot 'assets\app-icon-512.png'
$iconSource = [System.Drawing.Image]::FromFile($iconSourcePath)
$iconCanvas = New-Object System.Drawing.Bitmap 512, 512
$iconGraphics = [System.Drawing.Graphics]::FromImage($iconCanvas)
$iconGraphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$iconGraphics.DrawImage($iconSource, 0, 0, 512, 512)
$iconCanvas.Save($iconOutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$iconGraphics.Dispose(); $iconCanvas.Dispose(); $iconSource.Dispose()
