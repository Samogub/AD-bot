; update.ahk - the UPDATE button (14.11, players: "add an UPDATE button so we do not have to check Discord again and again").
; build.txt (written by make_release.ps1: yyyyMMddHHmm) = this build. The bot reads build.txt of the GitHub repository at start and
; every hour; a bigger number shows the UPDATE button. UPDATE: Stop, tools\update.ps1 downloads the repository and copies it over the
; bot folder (raid.ini, logs, screenshots and recorded runs stay), then the bot starts again.
; No build.txt (the author's working copies) = no check, no button: they must never be overwritten from GitHub.

UPD_REPO := "Samogub/AD-bot"
updRemote := "", updBusy := false

BuildLocal() {
    try return Trim(FileRead(A_ScriptDir "\build.txt"))
    return ""
}

UpdateAvail() {
    global updBusy, updRemote
    if !IsSet(updBusy) || !IsSet(updRemote)               ; the HUD is drawn before this file's lines above have run
        return false
    loc := BuildLocal()
    return !updBusy && IsDigit(loc) && loc != "" && IsDigit(updRemote) && updRemote != "" && Number(updRemote) > Number(loc)
}

; GitHub's build.txt -> updRemote. Asynchronous: the request runs in the background and a 0.5 s timer looks for the answer, so the
; bot loop and a recorded run are never held up (a waiting request could stop them for seconds). Any failure leaves the button hidden.
UpdateCheck() {
    static req := 0, t0 := 0
    if !IsDigit(BuildLocal()) || BuildLocal() = "" || req
        return
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(5000, 5000, 5000, 5000)
        req.Open("GET", "https://raw.githubusercontent.com/" UPD_REPO "/main/build.txt", true)
        req.Send()
        t0 := A_TickCount
        SetTimer(Poll, 500)
    } catch
        req := 0

    Poll() {
        global updRemote
        done := false
        try done := req.WaitForResponse(0)                ; 0 = do not wait, only ask
        if !done && A_TickCount - t0 < 20000
            return
        SetTimer(Poll, 0)
        was := UpdateAvail()
        try if done && req.Status = 200 && RegExMatch(Trim(req.ResponseText), "^\d{8,14}$", &m)
            updRemote := m[0]
        req := 0
        if UpdateAvail() && !was {
            Log("UPDATE available: build " updRemote " (this one " BuildLocal() ")")
            try UiInvalidate()
        }
    }
}

UpdateRun(*) {
    global updBusy
    if !UpdateAvail() || updBusy
        return
    if MsgBox("Update AD Bot to the newest version from GitHub?`n`nYour settings and recorded runs stay. The bot stops, downloads the update (up to a minute) and starts again.", "AD Bot - UPDATE", "OKCancel Iconi 4096") != "OK"
        return
    wasRunning := running
    if running
        Stop(false)
    updBusy := true
    SetStatus("updating from GitHub...")
    Log("UPDATE: downloading build " updRemote)
    try UiInvalidate()
    Sleep 100
    rc := 1
    try rc := RunWait('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' A_ScriptDir '\tools\update.ps1" -Dir "' A_ScriptDir '" -Repo "' UPD_REPO '"', , "Hide")
    if rc = 1 {
        updBusy := false
        msg := ""
        try msg := Trim(FileRead(A_Temp "\adbot_update.log"))
        Log("UPDATE failed: " msg)
        SetStatus("update failed")
        MsgBox("The update did not work:`n" msg "`n`nTry again later. If the bot behaves strangely now, download the newest version from GitHub (keep your raid.ini and the dimension folder).", "AD Bot - UPDATE", "Icon! 4096")
        return
    }
    Log("UPDATE: done" (rc = 2 ? " (some files were in use)" : "") " - restarting the bot")
    Run('"' A_AhkPath '" "' A_ScriptFullPath '"' (wasRunning ? " start" : ""))   ; #SingleInstance Force: the new copy replaces this one; it farms on if it did
    ExitApp
}

; 14.11 bot counter: while the bot farms it sends its random id (raid.ini [ui] botId) to the author's counter once an hour.
; Only that id - no name, no game data; the counter keeps no IP.
STATS_URL := "https://adbot-stats.adbot-stats.workers.dev/ping?id="

BotId() {
    static id := ""
    if id != ""
        return id
    id := IniRead(INI, "ui", "botId", "")
    if !RegExMatch(id, "^[0-9a-f]{16}$") {
        id := ""
        loop 16
            id .= Format("{:x}", Random(0, 15))
        try IniWrite id, INI, "ui", "botId"
    }
    return id
}

; checked every minute: the first ping ~1 min after Start, then one per 55 min while running. Asynchronous like UpdateCheck.
StatsPing() {
    static req := 0, last := 0, t0 := 0
    if !IsSet(running) || !running || req || (last && A_TickCount - last < 3300000)
        return
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(5000, 5000, 5000, 5000)
        req.Open("GET", STATS_URL BotId(), true)
        req.Send()
        last := t0 := A_TickCount
        SetTimer(PingWait, 1000)
    } catch
        req := 0

    PingWait() {
        done := false
        try done := req.WaitForResponse(0)
        if !done && A_TickCount - t0 < 20000
            return
        SetTimer(PingWait, 0)
        req := 0
    }
}

SetTimer(() => UpdateCheck(), -8000)                  ; after the start-up (own closure: the same function would replace the hourly timer)
SetTimer(UpdateCheck, 3600000)
SetTimer(StatsPing, 60000)
