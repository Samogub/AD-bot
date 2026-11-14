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

; 14.11 (players): a loading screen while the update runs, and the bot is locked - no clicks (UiClick), no F1-F3 (#HotIf in
; RaidBot.ahk), no closing (UpdExitGuard). RunWait lets timers run, so UpdFrame draws ~30 frames a second while it waits.
; Escape hatch: no result in 5 min -> the PowerShell process is closed and the failure path unlocks the bot.
updView := {stage: "", mb: 0, msg: "", t0: 0, at: 0, shown: 0, done: false, killed: false, from: "", to: "", fake: 0}
updPid := 0
UPD_PROG := A_Temp "\adbot_update_progress.txt"
OnExit(UpdExitGuard, -1)

UpdExitGuard(reason, code) {
    if updBusy && !updView.done && reason != "Shutdown" && reason != "Logoff" && reason != "Error" {   ; the copy over the bot folder must not be cut off (an AHK error dialog's Exit still works)
        try Log("UPDATE: closing ignored while the update runs (" reason ")")
        return 1
    }
}

UpdateRun(*) {
    global updBusy, updView, updPid
    if !UpdateAvail() || updBusy
        return
    if MsgBox("Update AD Bot to the newest version from GitHub?`n`nYour settings and recorded runs stay. The bot stops, downloads the update (up to a minute) and starts again.", "AD Bot - UPDATE", "OKCancel Iconi 4096") != "OK"
        return
    wasRunning := running
    if running
        Stop(false)
    try FileDelete UPD_PROG
    try FileDelete A_Temp "\adbot_update.log"             ; the failure box must not show the line of an older update
    updView :={stage: "start", mb: 0, msg: "", t0: A_TickCount, at: A_TickCount, shown: 0, done: false, killed: false, from: BuildLocal(), to: updRemote, fake: 0}
    updBusy := true, updPid := 0
    Log("UPDATE: downloading build " updRemote)
    try Layout()                                          ; the window (not the hotbar) - the loading screen is drawn into it
    SetTimer(UpdFrame, 33)
    rc := 1
    try rc := RunWait('powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' A_ScriptDir '\tools\update.ps1" -Dir "' A_ScriptDir '" -Repo "' UPD_REPO '" -Prog "' UPD_PROG '"', , "Hide", &updPid)
    rc0 := rc
    if updView.killed || rc != 0 && rc != 2              ; 0 done, 2 done with files in use; anything else (1, PowerShell did not start the script...) failed
        rc := 1
    if rc = 1 {
        SetTimer(UpdFrame, 0)
        updBusy := false
        msg := ""
        try msg := Trim(FileRead(A_Temp "\adbot_update.log"))
        if updView.killed
            msg := "no answer in 5 minutes - stopped. " msg
        else if msg = ""
            msg := "the update script did not run (code " rc0 ")"
        Log("UPDATE failed: " msg)
        SetStatus("update failed")
        try UiInvalidate()
        MsgBox("The update did not work:`n" msg "`n`nTry again later. If the bot behaves strangely now, download the newest version from GitHub (keep your raid.ini and the dimension folder).", "AD Bot - UPDATE", "Icon! 4096")
        return
    }
    Log("UPDATE: done" (rc = 2 ? " (some files were in use)" : "") " - restarting the bot")
    updView.stage := "restart", updView.at := A_TickCount, updView.done := true
    t := A_TickCount
    while (A_TickCount - t < 1500 || updView.shown < 0.995) && A_TickCount - t < 4000   ; the finale: the ring fills up (a fast update takes ~3 s), then the new copy starts
        Sleep 30
    SetTimer(UpdFrame, 0)
    try Run('"' A_AhkPath '" "' A_ScriptFullPath '"' (wasRunning ? " start" : ""))   ; #SingleInstance Force: the new copy replaces this one; it farms on if it did
    catch as e {
        updBusy := false                                  ; never leave the bot locked: the files are new, a manual start picks them up
        Log("UPDATE: restart failed - " e.Message)
        try UiInvalidate()
        MsgBox("The update is installed, but the bot could not start again by itself (" e.Message ").`nClose it and start RaidBot.ahk again.", "AD Bot - UPDATE", "Icon! 4096")
        return
    }
    ExitApp
}

; one frame: reads the stage written by update.ps1 ("download|6.4", "unpack", "install", "done", "fail|why"), then draws
UpdFrame() {
    global updView
    if !updBusy {
        SetTimer(UpdFrame, 0)
        return
    }
    if !updView.done {
        txt := ""
        try txt := Trim(FileRead(UPD_PROG))               ; may be half written: a bad line is only skipped
        s := StrSplit(txt, "|", , 2)
        if s.Length && s[1] ~= "^(download|unpack|install|done|fail)$" {
            if s[1] != updView.stage
                updView.stage := s[1], updView.at := A_TickCount
            if s[1] = "download" && s.Length > 1 && IsNumber(s[2])
                updView.mb := Number(s[2])
            if s[1] = "fail" && s.Length > 1
                updView.msg := s[2]
        }
        if A_TickCount - updView.t0 > 300000 && !updView.killed {
            updView.killed := true
            Log("UPDATE: no result after 5 min - stopping it")
            try Run('taskkill /T /F /PID ' updPid, , "Hide")   ; the whole tree: a robocopy started by the script must not go on writing into the bot folder
        }
    }
    try UiRender()
}

; how full the ring should be now: each stage owns a part, and inside it creeps on with time (GitHub sends no size)
UpdTarget() {
    v := updView, el := ((v.fake ? v.fake : A_TickCount) - v.at) / 1000
    creep(base, span, tau) => base + span * (1 - Exp(-el / tau))
    switch v.stage {
        case "download": return 0.04 + 0.56 * (1 - Exp(-v.mb / 6))
        case "unpack":   return creep(0.62, 0.16, 3)
        case "install":  return creep(0.80, 0.17, 4)
        case "done", "restart": return 1
        default:         return creep(0, 0.04, 2)
    }
}

; the loading screen, drawn instead of the page in both skins (UiRender calls it while updBusy)
UpdRender() {
    global gr, uiBmp, hits, tmap, uiShotFile, updView
    k := skin = "compact" ? CK() : UI_K
    W := PW / k, H := PH / k
    tm := tmap, tmap := false                             ; the compact light theme must not remap these colours
    cv := Canvas(PW, PH, "06050B")
    gr := cv[2]
    hbm := 0
    try {                                                 ; an error mid-frame must not leak the canvas every 33 ms or keep tmap off
        DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", k, "float", k, "int", 0)
        hits := []                                        ; nothing is clickable while it runs
        tgt := UpdTarget()
        updView.shown := updView.fake ? tgt : updView.shown + (tgt - updView.shown) * 0.12
        UpdScene(W, H)
        if uiShotFile != ""
            UiShotSave(cv[1])
    } finally {
        hbm := ToHbm(cv)                                  ; frees the canvas
        gr := 0
        tmap := tm
    }
    if uiBmp
        DllCall("DeleteObject", "ptr", uiBmp)
    uiBmp := hbm
    UiBlit()
}

UpdScene(W, H) {
    v := updView
    t := (v.fake ? v.fake : A_TickCount) / 1000
    pi := 3.14159265
    small := H < 330                                      ; the compact window with every group folded
    top := small ? 54 : 92, bot := small ? 34 : 96
    cx := W / 2, cy := top + (H - top - bot) / 2
    R := Max(26, Min(W * 0.2, (H - top - bot) * 0.3))
    hi := C.hi, a1 := C.acc, a2 := C.acc2
    ; nebula: two soft clouds of the theme colours drifting around the portal
    Glow(cx, cy, R * 3.4, R * 2.5, a1, 64)
    Glow(cx + Cos(t * 0.35) * R * 0.9, cy + Sin(t * 0.35) * R * 0.55, R * 2.3, R * 1.7, a2, 52)
    Glow(cx - Cos(t * 0.27) * R * 1.1, cy - Sin(t * 0.27) * R * 0.4, R * 1.6, R * 1.2, hi, 30)
    ; warp field: sparks fly out of the portal and speed up (golden-angle spread, each on its own clock)
    Loop 72 {
        i := A_Index
        ang := i * 2.39996
        ph := Mod(t * (0.10 + Mod(i * 37, 100) / 420) + i * 0.1373, 1)
        d := R * 0.95 + ph * ph * Max(W, H) * 0.75
        sz := 0.8 + ph * 2.4
        Dot(cx + Cos(ang) * d - sz / 2, cy + Sin(ang) * d * 0.78 - sz / 2, sz, Mod(i, 3) ? "FFFFFF" : hi, Round(230 * Sin(ph * pi)))
    }
    UpdOrbit(cx, cy, R, t, true)                          ; the back half of the tilted ring goes behind the portal
    ; portal: glow, dark core, three counter-rotating arcs
    Glow(cx, cy, R * 1.3, R * 1.3, hi, 110 + Round(40 * Sin(t * 2.2)))
    Dot(cx - R * 0.86, cy - R * 0.86, R * 1.72, "06050B", 240)
    UpdArc(cx, cy, R * 1.17, t * 95, 250, a1, 150, 2)
    UpdArc(cx, cy, R * 1.31, -t * 62 + 40, 140, a2, 130, 1.5)
    UpdArc(cx, cy, R * 1.45, t * 38 + 200, 70, hi, 100, 1)
    ; progress ring: faint track, gradient bar, a bright comet at its head
    p := Min(1, Max(0, v.shown))
    UpdArc(cx, cy, R, 0, 360, "FFFFFF", 26, 6)
    UpdArc(cx, cy, R, -90, Max(1, 360 * p), a1, 255, 6, hi)
    ha := (-90 + 360 * p) * pi / 180, hx := cx + R * Cos(ha), hy := cy + R * Sin(ha)
    Glow(hx, hy, 18, 18, "FFFFFF", 150)
    Dot(hx - 4, hy - 4, 8, "FFFFFF")
    UpdOrbit(cx, cy, R, t, false)
    ; centre: percent (and the MB while downloading); the stage name under the ring, clear of the orbit
    Tx(Round(p * 100) "%", "head", Max(14, Round(R * 0.42)), 1, "FFFFFF", cx - R, cy - R * 0.38, 2 * R, R * 0.56, 1)
    if v.stage = "download"
        Tx(Format("{:.1f}", v.mb) " MB", "mono", Max(9, Round(R * 0.1)), 0, "C9C3E0", cx - R * 0.8, cy + R * 0.2, 1.6 * R, 18, 1)
    lab := v.stage = "download" ? "Downloading" : v.stage = "unpack" ? "Unpacking" : v.stage = "install" ? "Installing"
        : v.stage = "done" || v.stage = "restart" ? "Done · restarting" : "Connecting to GitHub"
    Tx(StrUpper(lab), "ui", small ? 9 : 11, 1, "C9C3E0", 0, cy + R * 1.42, W, 18, 1)
    ; title
    Tx("AD BOT", "head", small ? 10 : 12, 1, hi, 0, small ? 8 : 22, W, 18, 1)
    Tx("UPDATING", "head", small ? 16 : 24, 1, "FFFFFF", 0, small ? 22 : 40, W, small ? 22 : 34, 1)
    if !small
        Tx("build " v.from "  ›  " v.to, "mono", 10, 0, "8C86A8", 0, 74, W, 16, 1)
    if small
        return
    ; stages: done ones ticked, the current one breathes, the next ones are dim
    names := [["Download", "download"], ["Unpack", "unpack"], ["Install", "install"], ["Restart", "restart"]]
    cur := v.stage = "unpack" ? 2 : v.stage = "install" ? 3 : v.stage = "done" || v.stage = "restart" ? 4 : 1
    pw := Min(W - 32, 520), gap := 8, bw := (pw - 3 * gap) / 4, bx := (W - pw) / 2, by := H - 70
    for i, n in names {
        x := bx + (i - 1) * (bw + gap)
        if i < cur || v.stage = "restart" {
            FillRR(x, by, bw, 28, 14, a2, 70)
            StrokeRR(x, by, bw, 28, 14, hi, 130)
            Tx("✓  " n[1], "ui", 11, 1, "FFFFFF", x, by, bw, 28, 1)
        } else if i = cur {
            GradRR(x, by, bw, 28, 14, a1, 150 + Round(60 * Sin(t * 4)), a2, 200)
            Tx(n[1], "ui", 11, 1, "FFFFFF", x, by, bw, 28, 1)
        } else {
            FillRR(x, by, bw, 28, 14, "FFFFFF", 10)
            Tx(n[1], "ui", 11, 0, "6E6886", x, by, bw, 28, 1)
        }
    }
    Tx(W < 600 ? "Locked until the update is done" : "The bot is locked until the update is done - it starts again by itself.", "ui", 10, 0, "8C86A8", 0, H - 32, W, 16, 1)
}

; the tilted ring of particles around the portal: back = the half behind it (dim), else the front half (bright, bigger)
UpdOrbit(cx, cy, R, t, back) {
    Loop 24 {
        a := A_Index * 6.28318 / 24 + t * 0.55
        z := Sin(a)
        if back ? z >= 0 : z < 0
            continue
        s := 1.6 + 2.6 * (z + 1) / 2
        Dot(cx + Cos(a) * R * 1.8 - s / 2, cy + z * R * 1.12 - s / 2, s, Mod(A_Index, 4) ? C.hi : "FFFFFF", back ? 70 : 235)
    }
}

UpdArc(cx, cy, r, start, sweep, hex, a, w, hex2 := "") {
    br := 0
    if hex2 != "" {
        br := LineBrush(cx - r, cy - r, 2 * r, 2 * r, hex, a, hex2, a, false)
        DllCall("gdiplus\GdipCreatePen2", "ptr", br, "float", w, "int", 2, "ptr*", &pen := 0)
    } else
        DllCall("gdiplus\GdipCreatePen1", "uint", Col(hex, a), "float", w, "int", 2, "ptr*", &pen := 0)
    DllCall("gdiplus\GdipSetPenStartCap", "ptr", pen, "int", 2)   ; round ends
    DllCall("gdiplus\GdipSetPenEndCap", "ptr", pen, "int", 2)
    DllCall("gdiplus\GdipDrawArc", "ptr", gr, "ptr", pen, "float", cx - r, "float", cy - r, "float", 2 * r, "float", 2 * r, "float", start, "float", sweep)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    if br
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
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
