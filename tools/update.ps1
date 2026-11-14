# AD Bot update (UPDATE button, update.ahk): downloads the newest build from GitHub and copies it over the bot folder.
# The player's files stay: raid.ini, logs, screenshots, recorded runs (dimension\ only gets runs it does not have yet), runs\.
# Exit code: 0 = done, 2 = done but some files were in use (copied next time), 1 = failed (nothing important changed).
param([string]$Dir, [string]$Repo = "Samogub/AD-bot")
$ErrorActionPreference = "Stop"
$log = Join-Path $env:TEMP "adbot_update.log"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP ("adbot_update_" + [guid]::NewGuid().ToString("N"))
$code = 1
try {
    if (!(Test-Path (Join-Path $Dir "RaidBot.ahk"))) { throw "not a bot folder: $Dir" }
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp "main.zip"
    Invoke-WebRequest "https://github.com/$Repo/archive/refs/heads/main.zip" -OutFile $zip -UseBasicParsing -TimeoutSec 120
    Expand-Archive $zip -DestinationPath $tmp -Force
    $src = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (!$src -or !(Test-Path (Join-Path $src.FullName "RaidBot.ahk"))) { throw "RaidBot.ahk is not in the download" }
    # everything except the player's own files; fonts stay (loaded by the running bot, locked)
    robocopy $src.FullName $Dir /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP /XD dimension runs logs shots rec fonts .git docs /XF raid.ini raid.log README.md .gitignore | Out-Null
    $rc = $LASTEXITCODE
    if ($rc -ge 16) { throw "copy failed (robocopy $rc)" }
    # dimension\: only runs the player does not have yet (a new mode), never over a recording
    if (Test-Path (Join-Path $src.FullName "dimension")) {
        robocopy (Join-Path $src.FullName "dimension") (Join-Path $Dir "dimension") /E /XC /XN /XO /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 16) { throw "copy of dimension failed (robocopy $LASTEXITCODE)" }
    }
    # fonts\: only new font files (the ones in use are locked by the running bot)
    if (Test-Path (Join-Path $src.FullName "fonts")) {
        robocopy (Join-Path $src.FullName "fonts") (Join-Path $Dir "fonts") /E /XC /XN /XO /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    }
    $code = if ($rc -ge 8) { 2 } else { 0 }
    "$(Get-Date -Format s) update done (robocopy $rc)" | Out-File $log -Encoding utf8
} catch {
    "$(Get-Date -Format s) update failed: $($_.Exception.Message)" | Out-File $log -Encoding utf8
    $code = 1
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
exit $code
