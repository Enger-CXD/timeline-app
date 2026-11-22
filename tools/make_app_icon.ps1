# 生成 App 图标：橙色底 + 白色沙漏
# 输出 1024 母图，再导出 Android mipmap 与 iOS AppIcon 全尺寸（均为不含透明通道的 24 位 PNG）
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = 'D:\Android\time_line_demo'
$master = Join-Path $root 'assets_icon_1024.png'

function New-RoundedRectPath([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $p.AddArc($x, $y, $d, $d, 180, 90)
  $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $p.CloseFigure()
  return $p
}

function Get-IconBitmap([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  # 画布坐标统一按 1024 设计，其它尺寸按比例缩放
  $s = $size / 1024.0
  $g.ScaleTransform($s, $s)

  # 橙色背景（自适应图标的前景需要透明底）
  if (-not $transparent) {
    $bg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 135, 31))
    $g.FillRectangle($bg, 0, 0, 1024, 1024)
  }

  $white = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 40)
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Miter

  # 上下两块“木板”
  $plateTop = New-RoundedRectPath 300 206 424 64 22
  $plateBottom = New-RoundedRectPath 300 754 424 64 22
  $g.FillPath($white, $plateTop)
  $g.FillPath($white, $plateBottom)

  # 沙漏玻璃外壳（两条 V 形粗线，中间自然收成细颈）
  [System.Drawing.PointF[]]$upper = @(
    (New-Object System.Drawing.PointF(334, 270)),
    (New-Object System.Drawing.PointF(512, 492)),
    (New-Object System.Drawing.PointF(690, 270))
  )
  [System.Drawing.PointF[]]$lower = @(
    (New-Object System.Drawing.PointF(334, 754)),
    (New-Object System.Drawing.PointF(512, 532)),
    (New-Object System.Drawing.PointF(690, 754))
  )
  $g.DrawLines($pen, $upper)
  $g.DrawLines($pen, $lower)

  # 上球里的沙子（漏斗状堆积）+ 中间细流 + 下球沙堆
  $upperSand = New-Object System.Drawing.Drawing2D.GraphicsPath
  $upperSand.AddPolygon([System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF(512, 470)),
    (New-Object System.Drawing.PointF(464, 412)),
    (New-Object System.Drawing.PointF(560, 412))
  ))
  $g.FillPath($white, $upperSand)

  $stream = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 12)
  $g.DrawLine($stream, 512, 466, 512, 596)

  $lowerSand = New-Object System.Drawing.Drawing2D.GraphicsPath
  $lowerSand.AddPolygon([System.Drawing.PointF[]]@(
    (New-Object System.Drawing.PointF(512, 594)),
    (New-Object System.Drawing.PointF(446, 690)),
    (New-Object System.Drawing.PointF(578, 690))
  ))
  $g.FillPath($white, $lowerSand)

  $g.Dispose()
  return $bmp
}

# 母图
$masterBmp = Get-IconBitmap 1024
$masterBmp.Save($master, [System.Drawing.Imaging.ImageFormat]::Png)
$masterBmp.Dispose()
Write-Output "母图: $master"

# Android mipmap
$androidMap = @{ 'mdpi' = 48; 'hdpi' = 72; 'xhdpi' = 96; 'xxhdpi' = 144; 'xxxhdpi' = 192 }
foreach ($key in $androidMap.Keys) {
  $px = $androidMap[$key]
  $outPath = Join-Path $root "android\app\src\main\res\mipmap-$key\ic_launcher.png"
  $bmp = Get-IconBitmap $px
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output "Android $key ($px px) -> $outPath"
}

# Android 自适应图标前景（透明底，108dp 画布）
$fgMap = @{ 'mdpi' = 108; 'hdpi' = 162; 'xhdpi' = 216; 'xxhdpi' = 324; 'xxxhdpi' = 432 }
foreach ($key in $fgMap.Keys) {
  $px = $fgMap[$key]
  $outPath = Join-Path $root "android\app\src\main\res\mipmap-$key\ic_launcher_foreground.png"
  $bmp = Get-IconBitmap $px -transparent
  $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  Write-Output "Android 前景 $key ($px px) -> $outPath"
}

# 自适应图标背景色 + anydpi-v26 装配文件
$colorsXml = Join-Path $root 'android\app\src\main\res\values\colors.xml'
@'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#F5871F</color>
</resources>
'@ | Set-Content -Path $colorsXml -Encoding utf8

$anyDpiDir = Join-Path $root 'android\app\src\main\res\mipmap-anydpi-v26'
if (-not (Test-Path $anyDpiDir)) { New-Item -ItemType Directory -Path $anyDpiDir | Out-Null }
@'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
'@ | Set-Content -Path (Join-Path $anyDpiDir 'ic_launcher.xml') -Encoding utf8
Write-Output 'Android 自适应图标装配完成'

# iOS AppIcon：文件名形如 Icon-App-60x60@3x.png
$iosDir = Join-Path $root 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
$files = Get-ChildItem -Path $iosDir -Filter 'Icon-App-*.png'
foreach ($f in $files) {
  if ($f.Name -match 'Icon-App-([\d\.]+)x[\d\.]+@(\d)x\.png') {
    $pt = [double]$matches[1]
    $scale = [int]$matches[2]
    $px = [int][Math]::Round($pt * $scale)
    $bmp = Get-IconBitmap $px
    $bmp.Save($f.FullName, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "iOS $($f.Name) ($px px)"
  }
}
Write-Output '图标导出完成'

