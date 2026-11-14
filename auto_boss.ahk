; auto_boss.ahk - bossAuto: in Raid and Speed Raid the game's own Auto fights the boss; the bot only keeps Auto switched on.
; Facts (4.11): Auto stays on after a death inside the run, and turns off after a teleport / new run.
; Templates: img\auto_off.png = white "AUTO" letters of the OFF button (dark red diamond), img\auto_on.png = white "AUTO ON" letters.

AUTO_OFF_PTS := [[-6, 6], [54, 6], [24, -16]]    ; diamond fill (red) at offsets from the letters' top-left: guards against white blobs
autoTries := 0, autoAt := 0, autoWinAt := 0, autoFailLogged := false, autoOnLogged := false
autoSeen := 0                                    ; last tick with a sign of the run (ENEMIES LEFT or the Auto button)
realFightAt := 0                                 ; last tick the ENEMIES LEFT picture itself matched (RunButtonSeen: way out of a wrong colour hit)
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
        static shotDone := false
        if !shotDone                                        ; how the button really looks on this PC (once: it costs ~0.3 s before the press)
            shotDone := true, Screenshot("auto_missing")
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
    if A_TickCount - autoBlindSince < 1000
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

; The AUTO button without the pictures: white letters in the middle of the diamond + its colours. "on" = bright pink / violet,
; "off" = dark red, "" = no button. 14.11: after a game update the pictures stopped matching (the letters moved by 1 px); a running
; raid was then taken for the lobby (a false PLAY), the bot went for the Bag and Safe mode closed the game in the middle of the raid.
; Colours measured on 22 shots of 14.11: ON point 1 ~(250,120,180) and point 4 ~(180,150,230); OFF point 1 ~(141,72,75), mean ~72.
AutoBtnByColour() {
    try {
        px := GrabPixels(AUTO_BTN[1] - 34, AUTO_BTN[2] - 8, 64, 14)    ; the letters: OFF 714..761 x 846..857, ON 706..768 x 848..856
        white := 0
        Loop 64 * 14 {
            c := NumGet(px, (A_Index - 1) * 4, "uint")
            white += (c >> 16 & 0xFF) > 215 && (c >> 8 & 0xFF) > 215 && (c & 0xFF) > 215
        }
        if white < 140 || white > 320                     ; the letters have ~215 (OFF) / ~231 (ON) white px
            return ""
        d := AutoDiamond()                                ; 8 points x r, g, b
        m := 0
        for x in d
            m += x
        m := m / d.Length
        if d[1] > 200 && d[3] > 120 && d[2] < 170 && d[12] > 180 && m >= 125   ; point 1 pink, point 4 violet
            return "on"
        if d[1] >= 90 && d[1] <= 200 && d[1] - d[2] >= 40 && d[1] - d[3] >= 40 && m <= 110   ; point 1 dark red
            return "off"
        black := true                                     ; the near-black OFF diamond (raid 4.11, 5.11, 14.11 07:04): all 8 points dark
        Loop 8
            black := black && Max(d[A_Index * 3 - 2], d[A_Index * 3 - 1], d[A_Index * 3]) < 70
        if black
            return "off"
    }
    return ""
}

; any sign of the AUTO button (pictures or colours): it exists only inside a run - never the lobby.
; Way out: the colours alone, seen for 10 min with no fight recognised, are not trusted any more (logged once) until they go away -
; a wrong colour hit outside a run must not stop the bot for ever.
RunButtonSeen() {
    static colSince := 0, distrust := false, lastCall := 0, lastRes := false
    if A_TickCount - lastCall < 200                       ; called 2-3 times per tick: one look per 0.2 s is enough
        return lastRes
    gap := A_TickCount - lastCall, lastCall := A_TickCount
    if AutoOffVisible() || AutoOnVisible()
        return lastRes := true
    if AutoBtnByColour() = "" {
        colSince := 0, distrust := false
        return lastRes := false
    }
    if A_TickCount - realFightAt < 60000 || !colSince || gap > 5000
        colSince := A_TickCount                           ; a fight is seen (or the first sighting / after a long pause): the colours are a real run
    if !distrust && A_TickCount - colSince > 600000 {
        distrust := true
        Log("WARNING: the AUTO button colours were seen for 10 min without a fight - not trusting them now")
        Screenshot("auto_colour_stuck")
    }
    return lastRes := !distrust
}

; The ENEMIES LEFT picture flickers on bright maps (4.11: one raid became 5 "fights"), so the run stays "in fight"
; while ENEMIES LEFT or the Auto button is seen, and after that until the lobby (PLAY) shows or 3 min pass without any sign.
; Returns the fight state to use instead of the raw ENEMIES LEFT result.
AutoRunOn(rawFight) {
    global autoSeen, autoBtnAt, fightSince
    if cfg["bossAuto"] != "1" || !BossFight()
        return rawFight
    pic := AutoOffVisible() || AutoOnVisible()
    if pic
        autoBtnAt := A_TickCount                            ; only the pictures: AutoEnsure uses the colours (AutoBlind) while this is 0
    btn := pic || RunButtonSeen()                        ; 14.11: the colours too - outdated pictures must not end a running raid
    ; lobby: the run is over (or never began); ENEMIES LEFT seen here is a false hit. With the AUTO button on screen a PLAY hit is false.
    ; and only after 5 s with no sign of the run (14.11: the button is hidden for a moment at a death - a false PLAY then cut the raid)
    static btnAt := 0
    if btn
        btnAt := A_TickCount
    if !btn && A_TickCount - btnAt > 5000 && FindImg("play.png", &px, &py, 1500, 800, 1920, 1060) {
        if fightSince
            AutoRunEnd()
        return false
    }
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
; and only when it has been seen steadily: 0.3 s for the red diamond, 1.5 s for the near-black one (it can also mean "button unavailable")
AutoEnsure() {
    global autoTries, autoAt, autoWinAt, autoFailLogged, autoOnLogged, autoOffSince, autoWaitLogAt, autoFailN, autoLook, autoRGB, autoNoneSince, autoMissLogged
    kind := lastEntered = "speed" ? "Speed Raid" : lastEntered = "infinity" ? "Infinity" : "raid"
    ; 14.11 (player: "it takes ~15 s to press Auto"): the waits below were 8 s / 2.5 s / 1 s - shortened
    ; 14.11 06:50: on the author's PC too the pictures stopped matching (game update?) and the colours were only used after 4 s - now
    ; at once: off 72 / on 159 brightness is a clear difference. The pictures, when they match, take over (autoBtnAt).
    if !autoBtnAt && fightSince {   ; the pictures never matched in this run: use the colours of the button
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
        if stable < (autoLook = "black" ? 1500 : 300) {
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
