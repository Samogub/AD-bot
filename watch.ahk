; Freeze watch (10.11, player request: "a system that understands the bot / the game froze").
; 1. The game: Windows marks Roblox "Not Responding" for 60 s, or its picture does not change at all for 3 min
;    -> Tick restarts Roblox (GameFrozen). The bot's own top strip is not looked at (its clock moves by itself).
; 2. The bot inside: one step of Tick runs for over 20 min (a loop that never ends) -> the bot starts itself again with "start".
; 3. The bot process: dead or blocked (no heartbeat for 2 min) -> tools\watchdog.ahk (own process, started by Start) kills it
;    and starts it again with "start". At most 3 times an hour, then it gives up and writes why into raid.log.
; heartbeat.txt = "yyyyMMddHHmmss|running(1/0)|pid", written every 10 s.

HB_FILE := A_ScriptDir "\heartbeat.txt"
busySince := 0                                            ; when the running Tick step began (0 = Tick idle)

GameFrozen() {
    static sig := "", since := 0, hungSince := 0, at := 0
    if A_TickCount - at < 10000
        return ""
    at := A_TickCount
    hw := WinExist(GAME)
    if !hw {
        sig := "", since := 0, hungSince := 0
        return ""
    }
    if DllCall("IsHungAppWindow", "ptr", hw) {
        hungSince := hungSince || A_TickCount
        if A_TickCount - hungSince > 60000 {
            sig := "", since := 0, hungSince := 0
            return "Roblox is not responding for 60 s"
        }
    } else
        hungSince := 0
    WinGetClientPos &x, &y, &w, &h, GAME
    y += 60, h -= 60                                      ; below the bot's own strip at the top
    if w < 100 || h < 100
        return ""
    px := GrabPixels(x, y, w, h), s := ""
    Loop 12 {                                             ; 24 x 12 points, colour of each
        r := (h * (2 * A_Index - 1)) // 24
        Loop 24
            s .= NumGet(px, (r * w + (w * (2 * A_Index - 1)) // 48) * 4, "uint") & 0xFFFFFF ","
    }
    if !RegExMatch(s, "[1-9]") {                          ; all black = Windows gives no picture (RDP minimised), a restart does not help
        sig := "", since := 0
        return ""
    }
    if s != sig {
        sig := s, since := A_TickCount
        return ""
    }
    if A_TickCount - since > 180000 {
        sig := "", since := 0
        return "the game picture has not changed for 3 min"
    }
    return ""
}

Heartbeat() {
    try {
        f := FileOpen(HB_FILE, "w", "UTF-8-RAW")
        f.Write(A_Now "|" (running ? 1 : 0) "|" DllCall("GetCurrentProcessId", "uint"))
        f.Close()
    }
    if running && busySince && A_TickCount - busySince > 1200000 {   ; one Tick step for 20 min: stuck inside the bot
        Log("ERROR: the bot hung inside one step for 20 min (status: " lastStatus ") - starting the bot again")
        WebhookPost("**AD Bot** " FormatTime(, "HH:mm") " - the bot hung for 20 min, starting it again")
        try Run('"' A_AhkPath '" "' A_ScriptFullPath '" start')   ; #SingleInstance: the new copy replaces this one
    }
}
SetTimer(Heartbeat, 10000)

; Start: the watchdog process (one copy; it ends by itself when the bot is stopped)
WatchdogStart() {
    Heartbeat()
    try Run('"' A_AhkPath '" "' A_ScriptDir '\tools\watchdog.ahk" "' A_ScriptFullPath '"')
}
