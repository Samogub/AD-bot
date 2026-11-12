#Requires AutoHotkey v2.0
#SingleInstance Force
#NoTrayIcon
; AD Bot watchdog (10.11): started by the bot at Start with the path of RaidBot.ahk. Every 30 s it reads heartbeat.txt
; ("yyyyMMddHHmmss|running|pid", the bot writes it every 10 s). The bot is running but its process is gone, or the heartbeat
; is older than 2 min (the bot is blocked) -> kill it and start it again with "start". At most 3 times an hour.
; The bot stopped (running 0) -> the watchdog ends.

bot := A_Args.Length ? A_Args[1] : A_ScriptDir "\..\RaidBot.ahk"
dir := RegExReplace(bot, "\\[^\\]+$")
hb := dir "\heartbeat.txt", logf := dir "\raid.log", rf := dir "\watchdog_restarts.txt"   ; the count survives: the restarted bot starts a new watchdog
SetTimer(Check, 30000)

Check() {
    restarts := []
    try {
        for t in StrSplit(Trim(FileRead(rf)), ",")
            if RegExMatch(t, "^\d{14}$") && DateDiff(A_Now, t, "Minutes") < 60
                restarts.Push(t)
    }
    try txt := FileRead(hb, "UTF-8")
    catch
        return
    p := StrSplit(Trim(txt), "|")
    if p.Length < 3
        return
    if p[2] != "1"                                        ; stopped by the player: nothing to watch
        ExitApp
    age := DateDiff(A_Now, p[1], "Seconds")
    alive := ProcessExist(p[3])
    if alive && age < 120
        return
    why := alive ? "no heartbeat for " age " s (the bot is blocked)" : "the bot process is gone"
    if restarts.Length >= 3 {
        Note("WATCHDOG: " why " - already restarted 3 times this hour, giving up")
        ExitApp
    }
    restarts.Push(A_Now)
    s := ""
    for t in restarts
        s .= t ","
    try FileDelete rf
    try FileAppend RTrim(s, ","), rf
    Note("WATCHDOG: " why " - starting the bot again")
    if alive
        try ProcessClose p[3]
    Sleep 2000
    try Run('"' A_AhkPath '" "' bot '" start', dir)
    Sleep 60000                                           ; time for the new copy to write its first heartbeat
}

Note(t) {
    try FileAppend FormatTime(, "dd.MM HH:mm:ss") ".000  " t "`n", logf, "UTF-8"
}
