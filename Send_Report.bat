@echo off
rem Packs the log, settings, the newest screenshots and a short PC description into AD-Bot-report-<version>.zip next to the bot. Send that file to the author.
cd /d "%~dp0"
set VER=unknown
for /f tokens^=2^ delims^=^" %%v in ('findstr /b "APP_VERSION" ui.ahk') do set VER=%%v
set ZIP=AD-Bot-report-v%VER%.zip
if exist "%ZIP%" del "%ZIP%"
if exist _report rmdir /s /q _report
mkdir _report
if exist raid.log copy /y raid.log _report >nul
rem raid.ini without the private server link (the zip goes into a public channel)
if exist raid.ini powershell -NoProfile -Command "Get-Content 'raid.ini' | Where-Object { $_ -notmatch '^\s*serverLink\s*=' } | Set-Content '_report\raid.ini'"
rem only the 10 newest screenshots (the ones of a problem are the newest), each shrunk to a 1280 px JPEG (~100 KB; the old PNGs were 2-3 MB each and the zip did not fit into Discord), and the 2 newest old logs
if exist shots powershell -NoProfile -Command "Add-Type -AssemblyName System.Drawing; New-Item -ItemType Directory -Force '_report\shots' | Out-Null; $enc = [Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'; $p = New-Object Drawing.Imaging.EncoderParameters 1; $p.Param[0] = New-Object Drawing.Imaging.EncoderParameter ([Drawing.Imaging.Encoder]::Quality), ([long]65); Get-ChildItem 'shots\*.png','shots\*.jpg' | Sort-Object LastWriteTime -Descending | Select-Object -First 10 | ForEach-Object { $i = [Drawing.Image]::FromFile($_.FullName); $w = 1280; $h = [int]($i.Height * $w / $i.Width); $b = New-Object Drawing.Bitmap $w, $h; $g = [Drawing.Graphics]::FromImage($b); $g.InterpolationMode = 'HighQualityBicubic'; $g.DrawImage($i, 0, 0, $w, $h); $b.Save('_report\shots\' + $_.BaseName + '.jpg', $enc, $p); $g.Dispose(); $b.Dispose(); $i.Dispose() }"
if exist logs powershell -NoProfile -Command "New-Item -ItemType Directory -Force '_report\logs' | Out-Null; Get-ChildItem 'logs\*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 2 | Copy-Item -Destination '_report\logs'"
if exist dimension\giant\log.txt copy /y dimension\giant\log.txt _report\dimension_log.txt >nul
echo version %VER%> _report\version.txt
rem what this PC looks like (Windows, screen, scale, language): the usual reasons for "the bot does not find the buttons"
powershell -NoProfile -Command "$o = Get-CimInstance Win32_OperatingSystem; Add-Type -AssemblyName System.Windows.Forms; $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $lp = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).LogPixels; $ap = (Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -ErrorAction SilentlyContinue).AppliedDPI; $('Windows: ' + $o.Caption + ' ' + $o.Version; 'Screen (as Windows reports it): ' + $b.Width + 'x' + $b.Height; 'Scale (LogPixels / AppliedDPI, 96 = 100 percent): ' + $lp + ' / ' + $ap; 'Culture: ' + (Get-Culture).Name; 'Windows Update service: ' + (Get-Service wuauserv -ErrorAction SilentlyContinue).Status) | Out-File '_report\diag.txt' -Encoding utf8"
powershell -NoProfile -Command "Compress-Archive -Path '_report\*' -DestinationPath '%ZIP%'"
rmdir /s /q _report
echo.
powershell -NoProfile -Command "$m = [math]::Round((Get-Item '%ZIP%').Length / 1MB, 1); 'Size: ' + $m + ' MB' + $(if ($m -gt 9) { ' - too big for Discord (limit 10 MB): send raid.log from the bot folder and the 3 newest pictures from the shots folder instead' } else { ' - fits into Discord' })"
echo Done: %ZIP% - send this file to the author.
pause
