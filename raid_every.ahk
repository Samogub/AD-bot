; raid_every.ahk - raidEvery N (raid.ini [raid], default 1 = every hour as before): the hourly raid is done only in hours
; divisible by N (N=3: 00, 03, 06 ...). In the other hours the bot stays in Infinity / Dimension and Speed Raid is not held back for the raid.

; 12.11: raidMin (raid.ini [raid], 0-59, default 0) = the minute of the local hour when the raid starts. In a half-hour time zone
; (India +5:30) the game's raid starts at xx:30 local, so all raid timing uses a clock shifted back by raidMin.
RaidShift() => -Min(59, Max(0, Num("raidMin", 0)))
RaidNow() => DateAdd(A_Now, RaidShift(), "Minutes")
RaidHour() => Integer(FormatTime(RaidNow(), "H"))
RaidMin() => Integer(FormatTime(RaidNow(), "m"))
RaidKey() => FormatTime(RaidNow(), "yyyyMMddHH")
RaidEvery() => Min(24, Max(1, Num("raidEvery", 1)))

RaidHourOk(h) => Mod(h, RaidEvery()) = 0

; the NEXT hour is a raid hour (the bot leaves Infinity / Dimension for it at the end of this hour)
RaidNextOk() => RaidHourOk(Mod(RaidHour() + 1, 24))

; seconds to the start of the next raid hour; with N = 1 the same as to the next full hour
RaidLeft() {
    h := RaidHour()
    Loop 24 {
        if RaidHourOk(Mod(h + A_Index, 24))
            return A_Index * 3600 - SecOfHour()
    }
    return 3600 - SecOfHour()
}

; text for the log when this hour has no raid because of raidEvery, else ""
RaidSkipNote() {
    if cfg["raid"] = "1" && RaidEvery() > 1 && !RaidHourOk(RaidHour())
        return "raid skipped this hour: raidEvery " RaidEvery()
    return ""
}
; mm:ss under 1 h, else 2h05 (raidEvery > 1 gives timers over 60 min)
ClockTxt(sec) => sec >= 3600 ? Format("{}h{:02}", sec // 3600, Mod(sec // 60, 60)) : Format("{:02}:{:02}", sec // 60, Mod(sec, 60))
