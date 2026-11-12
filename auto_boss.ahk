; auto_boss.ahk - bossAuto: in Raid and Speed Raid the game's own Auto fights the boss; the bot only keeps Auto switched on.
; Facts (4.11): Auto stays on after a death inside the run, and turns off after a teleport / new run.
; Templates: img\auto_off.png = white "AUTO" letters of the OFF button (dark red diamond), img\auto_on.png = white "AUTO ON" letters.

AUTO_OFF_PTS := [[-6, 6], [54, 6], [24, -16]]    ; diamond fill (red) at offsets from the letters' top-left: guards against white blobs
autoTries := 0, autoAt := 0, autoWinAt := 0, autoFailLogged := false, autoOnLogged := false
autoSeen := 0                                    ; last tick with a sign of the run (ENEMIES LEFT or the Auto button)
autoBtnAt := 0                                   ; last tick the Auto button was seen
autoOffSince := 0, autoWaitLogAt := 0, autoFailN := 0   ; OFF stability: first tick of the current uninterrupted OFF sighting
autoLook := '', autoRGB := ''                  ; last AutoOffVisible look: red|black and the rgb of the deciding diamond point
autoNoneSince := 0, autoMissLogged := false      ; neither OFF nor ON seen: since when / already told in the log this run
; Blind mode (11.11, player report: on his PC neither auto_off.png nor auto_on.png ever matched, 0 presses in a whole day): when the button was not
; recognised for the first 8 s of a run, the bot reads the diamond by its colours (8 points inside it): bright pink / violet = ON, dark = OFF.
; No assumption about the state at the start of a run: it is pressed only when it really looks dark for 2.5 s.
autoLookOff := "", autoLookOn := "", autoBlindAt := 0, autoBlindTries := 0, autoBlindSince := 0, autoBlindOnLogged := false, autoBlindLogged := false

AutoReset() {
    global autoTries, autoAt, autoWinAt, autoFailLogged, autoOnLogged, autoBtnAt, autoOffSince, autoFailN, autoNoneSince, autoMissLogged
    global autoBlindAt, autoBlindTries, autoBlindSince, autoBlindOnLogged, autoBlindLogged
    autoTries := 0, autoAt := 0, autoWinAt := 0, autoFailLogged := false, autoOnLogged := false, autoBtnAt := 0, autoOffSince := 0, autoFailN := 0, autoNoneSince := 0, autoMissLogged := false
    autoBlindAt := 0, autoBlindTries := 0, autoBlindSince := 0, autoBlindOnLogged := false, autoBlindLogged := false   ; the learned looks stay
}

; colours at 8 points inside the diamond, away from the letters
AutoDiamond() {
    v := []
    for p in [[0, -26], [0, 26], [31, 0], [-31, 0], [14, -20], [-14, -20], [14, 20], [-14, 20]] {
        c := Integer(PixelGetColor(AUTO_BTN[1] + p[1], AUTO_BTN[2] + p[2]))
        v.Push(c >> 16 & 0xFF, c >> 8 & 0xFF, c & 0xFF)
    }
    return v
}

AutoLookDist(a, b) {
    s := 0
    for i, x in a
        s += Abs(x - b[i])
    return s / a.Length
}

; the button is not recognised by the pictures: look at its colours. ON is a bright pink / violet diamond, OFF is a dark one - no learning, no
; assumption about the state at the start of a run (11.11 player: Auto was already ON, the first blind press switched it OFF).
AutoBlind(kind) {
    global autoBlindTries, autoBlindSince, autoBlindLogged, autoAt, autoOnLogged
    cur := AutoDiamond()
    m := 0
    for x in cur
        m += x
    m := m / cur.Length
    st := m >= 125 ? "on" : m <= 105 ? "off" : ""
    if !autoBlindLogged {
        autoBlindLogged := true
        Log(kind ": Auto: the button is not recognised by the pictures - using its colours (brightness " Round(m) " = " (st != "" ? st : "unclear") ")")
        Screenshot("auto_missing")                          ; how the button really looks on this PC
    }
    if st = "on" {
        autoBlindSince := 0
        if autoBlindTries {
            Log("Auto: on after try " autoBlindTries " (colours)")
            autoBlindTries := 0
            autoOnLogged := true
        } else if !autoOnLogged {
            autoOnLogged := true
            Log("Auto: on (colours)")
        }
        return
    }
    if st != "off" {                                        ; neither (dimmed screen, results): do nothing
        autoBlindSince := 0
        return
    }
    if A_TickCount - autoAt < 3000
        return
    if !autoBlindSince
        autoBlindSince := A_TickCount
    if A_TickCount - autoBlindSince < 2500
        return
    if autoBlindTries >= 3 && A_TickCount - autoAt < 15000
        return
    autoBlindTries := autoBlindTries >= 3 ? 1 : autoBlindTries + 1, autoAt := A_TickCount, autoBlindSince := 0
    Log(kind ": Auto looks off (brightness " Round(m) ") - pressed by colours (try " autoBlindTries ")")
    AutoClickBtn()
}
AutoBox() => [AUTO_BTN[1] - 60, AUTO_BTN[2] - 60, AUTO_BTN[1] + 60, AUTO_BTN[2] + 60]

; OFF button visible near AUTO_BTN: letters match and the diamond around them is red or near-black
AutoOffVisible() {
    global autoLook, autoRGB
    b := AutoBox()
    if !FindImg("auto_off.png", &x, &y, b[1], b[2], b[3], b[4])
        return false
    red := 0, redRGB := "", blackRGB := ""
    for p in AUTO_OFF_PTS {
        c := Integer(PixelGetColor(x + p[1], y + p[2]))
        r := c >> 16 & 0xFF, gg := c >> 8 & 0xFF, bl := c & 0xFF
        ; 6.11: the OFF diamond can also be near-black (29,17,14). ON is pink (255,118,176) and does pass the colour test;
        ; only the size of the template auto_off.png (48x12, the short "AUTO" letters) keeps ON from being taken for OFF
        if r >= 100 && r - gg >= 40 && r - bl >= 40 {
            red++, redRGB := r "," gg "," bl
        } else if Max(r, gg, bl) < 70 {
            red++, blackRGB := r "," gg "," bl
        }
    }
    autoLook := redRGB != "" ? "red" : "black"
    autoRGB := redRGB != "" ? redRGB : blackRGB
    return red >= 2
}

AutoOnVisible() {
    b := AutoBox()
    return FindImg("auto_on.png", &x, &y, b[1], b[2], b[3], b[4])
}

; The ENEMIES LEFT picture flickers on bright maps (4.11: one raid became 5 "fights"), so the run stays "in fight"
; while ENEMIES LEFT or the Auto button is seen, and after that until the lobby (PLAY) shows or 3 min pass without any sign.
; Returns the fight state to use instead of the raw ENEMIES LEFT result.
AutoRunOn(rawFight) {
    global autoSeen, autoBtnAt, fightSince
    if cfg["bossAuto"] != "1" || !BossFight()
        return rawFight
    if FindImg("play.png", &px, &py, 1500, 800, 1920, 1060) {    ; lobby: the run is over (or never began); ENEMIES LEFT seen here is a false hit
        if fightSince
            AutoRunEnd()
        return false
    }
    btn := AutoOffVisible() || AutoOnVisible()
    if btn
        autoBtnAt := A_TickCount
    if rawFight || btn {
        autoSeen := A_TickCount
        return true
    }
    if !fightSince                                          ; the run has not started yet
        return false
    if A_TickCount - autoSeen < 180000
        return true
    AutoRunEnd()
    return false
}

; run over: the fight ended at the last sign (not at the lobby), and the sticky time counts as run out
AutoRunEnd() {
    global lastFight, fightSince
    lastFight := autoSeen
    d := FIGHT_STICKY - (A_TickCount - lastFight)
    if d > 0
        lastFight -= d, fightSince -= d
}

; ms since the fight ended (the game's Speed Raid timer starts at the victory)
SinceFight() => cfg["bossAuto"] = "1" && autoSeen ? A_TickCount - autoSeen : A_TickCount - lastFight

; physical click on AUTO: longer press than ClickXY (the game can miss a ~10 ms click made right after the mouse move)
AutoClickBtn() {
    if !running
        return
    ; 11.11: one jump from the park point was not taken by the game (3 clicks, Auto still off); a small move onto the button first, like ClickXY
    MouseMove AUTO_BTN[1] + 3, AUTO_BTN[2] + 3, 0
    Sleep 60
    MouseMove AUTO_BTN[1], AUTO_BTN[2], 0
    Sleep 120
    if !running
        return
    Click "Down"
    Sleep 70
    Click "Up"
    Sleep 250
    ParkMouse()
}

; press AUTO only when the OFF look is really seen (never blindly: while dead Auto stays on)
; and only when it has been seen steadily: 1 s for the red diamond, 2.5 s for the near-black one (it can also mean "button unavailable")
AutoEnsure() {
    global autoTries, autoAt, autoWinAt, autoFailLogged, autoOnLogged, autoOffSince, autoWaitLogAt, autoFailN, autoLook, autoRGB, autoNoneSince, autoMissLogged
    kind := lastEntered = "speed" ? "Speed Raid" : lastEntered = "infinity" ? "Infinity" : "raid"
    if !autoBtnAt && fightSince && A_TickCount - fightSince >= 8000 {   ; the pictures never matched in this run: use the colours of the button
        AutoBlind(kind)
        return
    }
    offNow := AutoOffVisible()
    if !offNow
        autoOffSince := 0                                   ; OFF gone: stability starts again
    else if !autoOffSince
        autoOffSince := A_TickCount
    if A_TickCount - autoAt < 3000                          ; give the click time to show
        return
    if offNow {
        stable := A_TickCount - autoOffSince
        if stable < (autoLook = "black" ? 2500 : 1000) {
            if A_TickCount - autoWaitLogAt >= 10000 {
                autoWaitLogAt := A_TickCount
                Log(kind ": Auto: off seen, waiting stable (" autoLook ")")
            }
            return
        }
        if autoTries && A_TickCount - autoWinAt > 30000
            autoTries := 0                                  ; max 3 tries per 30 s
        if autoTries >= 3 && A_TickCount - autoAt >= 15000
            autoTries := 0                                  ; 15 s after the last click: allow a new series
        if autoTries >= 3 {
            if !autoFailLogged {
                autoFailLogged := true
                autoFailN++
                Log("Auto: still off after 3 clicks")
                if autoFailN = 1
                    Screenshot("auto_fail")
            }
            return
        }
        if !autoTries {
            autoWinAt := A_TickCount
            autoFailLogged := false
        }
        autoTries++
        autoAt := A_TickCount
        Log(kind ": Auto pressed (try " autoTries ", diamond " autoLook " rgb=" autoRGB ", stable " stable " ms)")
        AutoClickBtn()
    } else if AutoOnVisible() {
        autoNoneSince := 0
        if autoTries {
            Log("Auto: on after try " autoTries)
            autoTries := 0
            autoOnLogged := true
        } else if !autoOnLogged {
            autoOnLogged := true
            Log("Auto: on")
        }
    } else {
        ; 11.11 player report (0.3.5): a raid with no "Auto pressed" / "Auto: on" at all = the bot never saw the AUTO button.
        ; Once per run: say so in the log and keep a screenshot with the button area, so the next report shows how it looks there.
        if !autoNoneSince
            autoNoneSince := A_TickCount
        if !autoMissLogged && A_TickCount - autoNoneSince > 30000 {
            autoMissLogged := true
            Log(kind ": the AUTO button is not found on the screen for 30 s (looked near " AUTO_BTN[1] "," AUTO_BTN[2] ", pixel " Format("{:06X}", Integer(PixelGetColor(AUTO_BTN[1], AUTO_BTN[2])) & 0xFFFFFF) ")")
            Screenshot("auto_missing")
        }
    }
}
