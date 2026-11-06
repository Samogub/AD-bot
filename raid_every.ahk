; raid_every.ahk - raidEvery N (raid.ini [raid], default 1 = every hour as before): the hourly raid is done only in hours
; divisible by N (N=3: 00, 03, 06 ...). In the other hours the bot stays in Infinity / Dimension and Speed Raid is not held back for the raid.

RaidEvery() => Min(24, Max(1, Num("raidEvery", 1)))

RaidHourOk(h) => Mod(h, RaidEvery()) = 0

; the NEXT hour is a raid hour (the bot leaves Infinity / Dimension for it at the end of this hour)
RaidNextOk() => RaidHourOk(Mod(Integer(A_Hour) + 1, 24))

; seconds to the start of the next raid hour; with N = 1 the same as to the next full hour
RaidLeft() {
    h := Integer(A_Hour)
    Loop 24 {
        if RaidHourOk(Mod(h + A_Index, 24))
            return A_Index * 3600 - SecOfHour()
    }
    return 3600 - SecOfHour()
}

; text for the log when this hour has no raid because of raidEvery, else ""
RaidSkipNote() {
    if cfg["raid"] = "1" && RaidEvery() > 1 && !RaidHourOk(Integer(A_Hour))
        return "raid skipped this hour: raidEvery " RaidEvery()
    return ""
}
; mm:ss under 1 h, else 2h05 (raidEvery > 1 gives timers over 60 min)
ClockTxt(sec) => sec >= 3600 ? Format("{}h{:02}", sec // 3600, Mod(sec // 60, 60)) : Format("{:02}:{:02}", sec // 60, Mod(sec, 60))
