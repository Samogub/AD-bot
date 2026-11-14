# AD Bot update (UPDATE button, update.ahk): downloads the newest build from GitHub and copies it over the bot folder.
# The player's files stay: raid.ini, logs, screenshots, recorded runs (dimension\ only gets runs it does not have yet), runs\.
# Exit code: 0 = done, 2 = done but some files were in use (copied next time), 1 = failed (nothing important changed).
# 14.11: the loading screen of the bot reads -Prog ("stage|text": download|<MB>, unpack, install, done, fail|<why>).
param([string]$Dir, [string]$Repo = "Samogub/AD-bot", [string]$Prog = (Join-Path $env:TEMP "adbot_update_progress.txt"))
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"                  # PowerShell 5.1 is many times slower while it draws its own progress bar
$log = Join-Path $env:TEMP "adbot_update.log"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = Join-Path $env:TEMP ("adbot_update_" + [guid]::NewGuid().ToString("N"))
$code = 1
$inv = [Globalization.CultureInfo]::InvariantCulture     # "6.4", not "6,4" (the bot reads it with IsNumber)

function P([string]$s) { try { [IO.File]::WriteAllText($Prog, $s) } catch {} }   # the bot reads it every frame - a failed write is only a missed frame

try {
    if (!(Test-Path (Join-Path $Dir "RaidBot.ahk"))) { throw "not a bot folder: $Dir" }
    New-Item -ItemType Directory $tmp | Out-Null
    $zip = Join-Path $tmp "main.zip"
    P "download|0.0"
    # stream read: GitHub sends no size for the archive, so the screen shows the MB received
    $req = [Net.HttpWebRequest]::Create("https://github.com/$Repo/archive/refs/heads/main.zip")
    $req.UserAgent = "AD-Bot-Updater"
    $req.Timeout = 30000
    $req.ReadWriteTimeout = 30000
    $resp = $req.GetResponse()
    $in = $resp.GetResponseStream()
    $out = [IO.File]::Create($zip)
    try {
        $buf = New-Object byte[] 65536
        $tot = 0
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $last = -1000
        while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
            $out.Write($buf, 0, $n)
            $tot += $n
            if ($sw.ElapsedMilliseconds - $last -ge 150) { P ("download|" + ($tot / 1MB).ToString("0.0", $inv)); $last = $sw.ElapsedMilliseconds }
            if ($sw.ElapsedMilliseconds -gt 180000) { throw "download took over 3 minutes" }
        }
    } finally { $out.Close(); $in.Close(); $resp.Close() }
    P ("download|" + ($tot / 1MB).ToString("0.0", $inv))
    if ($tot -lt 100000) { throw "the download is too small ($tot bytes)" }
    P "unpack"
    Expand-Archive $zip -DestinationPath $tmp -Force
    $src = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (!$src -or !(Test-Path (Join-Path $src.FullName "RaidBot.ahk"))) { throw "RaidBot.ahk is not in the download" }
    P "install"
    # everything except the player's own files; fonts and music stay (held open by the running bot)
    robocopy $src.FullName $Dir /E /R:2 /W:1 /NFL /NDL /NJH /NJS /NP /XD dimension runs logs shots rec fonts music .git docs /XF raid.ini raid.log README.md .gitignore | Out-Null
    $rc = $LASTEXITCODE
    if ($rc -ge 16) { throw "copy failed (robocopy $rc)" }
    # dimension\: only runs the player does not have yet (a new mode), never over a recording
    if (Test-Path (Join-Path $src.FullName "dimension")) {
        robocopy (Join-Path $src.FullName "dimension") (Join-Path $Dir "dimension") /E /XC /XN /XO /R:2 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 16) { throw "copy of dimension failed (robocopy $LASTEXITCODE)" }
    }
    # fonts\ and music\: only new files (the ones in use are locked by the running bot)
    foreach ($d in "fonts", "music") {
        if (Test-Path (Join-Path $src.FullName $d)) {
            robocopy (Join-Path $src.FullName $d) (Join-Path $Dir $d) /E /XC /XN /XO /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        }
    }
    $code = if ($rc -ge 8) { 2 } else { 0 }
    "$(Get-Date -Format s) update done (robocopy $rc, $([math]::Round($tot / 1MB, 1)) MB)" | Out-File $log -Encoding utf8
    P "done"
} catch {
    "$(Get-Date -Format s) update failed: $($_.Exception.Message)" | Out-File $log -Encoding utf8
    P ("fail|" + $_.Exception.Message)
    $code = 1
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
exit $code
