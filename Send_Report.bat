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
if exist raid.ini copy /y raid.ini _report >nul
rem only the 15 newest screenshots (the ones of a problem are the newest) and the 2 newest old logs: the archive stays small
if exist shots powershell -NoProfile -Command "New-Item -ItemType Directory -Force '_report\shots' | Out-Null; Get-ChildItem 'shots\*.png' | Sort-Object LastWriteTime -Descending | Select-Object -First 15 | Copy-Item -Destination '_report\shots'"
if exist logs powershell -NoProfile -Command "New-Item -ItemType Directory -Force '_report\logs' | Out-Null; Get-ChildItem 'logs\*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 2 | Copy-Item -Destination '_report\logs'"
if exist dimension\giant\log.txt copy /y dimension\giant\log.txt _report\dimension_log.txt >nul
echo version %VER%> _report\version.txt
rem what this PC looks like (Windows, screen, scale, language): the usual reasons for "the bot does not find the buttons"
powershell -NoProfile -Command "$o = Get-CimInstance Win32_OperatingSystem; Add-Type -AssemblyName System.Windows.Forms; $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; $lp = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).LogPixels; $ap = (Get-ItemProperty 'HKCU:\Control Panel\Desktop\WindowMetrics' -ErrorAction SilentlyContinue).AppliedDPI; $('Windows: ' + $o.Caption + ' ' + $o.Version; 'Screen (as Windows reports it): ' + $b.Width + 'x' + $b.Height; 'Scale (LogPixels / AppliedDPI, 96 = 100 percent): ' + $lp + ' / ' + $ap; 'Culture: ' + (Get-Culture).Name; 'Windows Update service: ' + (Get-Service wuauserv -ErrorAction SilentlyContinue).Status) | Out-File '_report\diag.txt' -Encoding utf8"
powershell -NoProfile -Command "Compress-Archive -Path '_report\*' -DestinationPath '%ZIP%'"
rmdir /s /q _report
echo.
echo Done: %ZIP% - send this file to the author.
pause
