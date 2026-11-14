; ui.ahk - main window, hotbar and colour themes. Included from RaidBot.ahk.
; Default style "Cosmos" (dark purple space): dark aurora background, glass panels, blue-violet gradients, sakura pink only for
; active things. The whole window is ONE bitmap drawn with GDI+ (UiRender); clicks are matched against the
; rectangles collected while drawing (hits). Fonts: Sora (titles), Inter (text), JetBrains Mono (log, keys).
; If a font is not installed, put its .ttf files into the fonts\ folder next to the script, else Segoe UI / Consolas is used.

LOGO_T := 52, LOGO_S := LOGO_T / 100          ; logo tile size in px and its scale
APP_VERSION := "0.4.1"                  ; shown under the title
APP_AUTHOR  := "Samogub"                 ; shown next to the version

; ------------------------------ themes ------------------------------
; preset= in raid.ini [theme] picks one of these; bg, card, field, text, dim, on, off, idle, acc, acc2, hi can be
; overridden one by one with 6-digit hex values. acc -> acc2 is the button gradient, hi marks active things.
THEMES := Map(
    "nocturne", {lite: 0, ov: "FFFFFF", bg: "060907", card: "050806", field: "0C110E", text: "E8DCEC", dim: "9D8AA6", on: "B0449A", off: "1A1220", idle: "5A4A66", acc: "B0449A", acc2: "64205A", hi: "E0C4EA", sb: "050806", g1: "3B1A40", lin: "C9A3D6"},
    "cosmos",   {lite: 0, stars: 1, glow: 0.22, ov: "FFFFFF", bg: "010003", card: "05030B", field: "0A0613", text: "DDD6F2", dim: "7A6FA3", on: "A78BFA", off: "130D26", idle: "3E3466", acc: "6A3BD0", acc2: "3F1A94", hi: "BFA0FF", sb: "05030B", g1: "26125C", lin: "6A3BD0"},
    "sakura",   {lite: 1, ov: "8A2F55", bg: "FBEFF3", card: "FFFFFF", field: "F7DCE6", text: "4A2535", dim: "9A6B7C", on: "E0558A", off: "EBCFDA", idle: "C9A3B2", acc: "F28FB4", acc2: "D9578F", hi: "C2336E", sb: "FFFFFF", g1: "FDF3F7", lin: "D9578F"},
    "midnight", {lite: 0, ov: "FFFFFF", bg: "0B0F1A", card: "141A2E", field: "1D2540", text: "E8ECF8", dim: "8A93B2", on: "7CF0B6", off: "2B3354", idle: "566086", acc: "5B8CFF", acc2: "7C5CFF", hi: "FF9EC4", sb: "0B0F1A", g1: "16224A", lin: "5B8CFF"},
    "aurora",   {lite: 0, ov: "FFFFFF", bg: "050B13", card: "0D1A25", field: "163042", text: "E4F5F1", dim: "78A6A8", on: "5CF2C0", off: "1F3B4C", idle: "46707A", acc: "20C9B0", acc2: "7B5CF0", hi: "7CFFD0", sb: "050B13", g1: "0B3A3A", lin: "20C9B0"},
    "metallic", {lite: 0, ov: "FFFFFF", bg: "090B10", card: "13171F", field: "1F2531", text: "E9EDF5", dim: "8B94A8", on: "C8D2E6", off: "2A3142", idle: "566074", acc: "9AA7C2", acc2: "4B5873", hi: "DCE6FA", sb: "090B10", g1: "2A3142", lin: "9AA7C2"},
    "ember",    {lite: 0, ov: "FFFFFF", bg: "0D0806", card: "1A1210", field: "2B1D18", text: "F7ECE3", dim: "A58B7C", on: "FFB86B", off: "3D2A23", idle: "6E5347", acc: "EE7A3C", acc2: "B8365A", hi: "FFC48A", sb: "0D0806", g1: "4A1F0C", lin: "EE7A3C"},
    "ironrose", {lite: 0, ov: "FFFFFF", bg: "060A11", card: "0F171F", field: "19262F", text: "E3EEF0", dim: "7E9BA2", on: "A6D8D8", off: "21313A", idle: "4B6670", acc: "5E8F9B", acc2: "24445A", hi: "AFD8DD", sb: "060A11", g1: "24445A", lin: "5E8F9B"},
    "author",   {lite: 0, ov: "FFFFFF", bg: "08080A", card: "131316", field: "202024", text: "ECECEF", dim: "9A9AA2", on: "CFCFD8", off: "2E2E34", idle: "5E5E66", acc: "7B7D8A", acc2: "3E3F4A", hi: "E4E2EC", sb: "08080A", g1: "2E2E34", lin: "7B7D8A"})
RAIDS_READY := " divine halloween shiro saiya sungomi tiger dual monke cursed "   ; raids that can be picked (Group Finder finds them by name)
THEME_ORDER := ["nocturne", "cosmos", "sakura", "midnight", "aurora", "metallic", "ironrose", "ember", "author"]
THEME_TITLES := Map("nocturne", "Nocturne", "cosmos", "Cosmos", "author", "Graphite", "midnight", "Midnight Sakura", "metallic", "Metallic", "ironrose", "Iron Rose")          ; shown instead of the capitalised key

ThemeName() {
    name := IniRead(INI, "theme", "preset", "nocturne")
    return THEMES.Has(name) ? name : "nocturne"
}

ThemeLoad() {
    base := THEMES[ThemeName()]
    o := {}
    for k in ["bg", "card", "field", "text", "dim", "on", "off", "idle", "acc", "acc2", "hi", "ov", "sb", "g1", "lin"] {
        v := IniRead(INI, "theme", k, "")
        o.%k% := RegExMatch(v, "^[0-9A-Fa-f]{6}$") ? v : base.%k%
    }
    o.lite := base.lite
    o.stars := base.HasOwnProp("stars") ? base.stars : 0     ; twinkling stars over the backdrop
    o.glow := base.HasOwnProp("glow") ? base.glow : 1        ; strength of the backdrop glows
    return o
}

SetTheme(name) {
    global C
    IniWrite name, INI, "theme", "preset"
    for k in ["bg", "card", "field", "text", "dim", "on", "off", "idle", "acc", "acc2", "hi", "ov", "sb", "g1", "lin"]
        IniDelete INI, "theme", k              ; a preset click replaces earlier per-colour overrides
    C := ThemeLoad()
    g.BackColor := C.bg
}

; HUD 2.0 one-time migration: old default theme -> Nocturne
if IniRead(INI, "ui", "hud2", "") = "" {
    IniWrite "nocturne", INI, "theme", "preset"
    IniWrite "1", INI, "ui", "hud2"
    Log("ui: theme migrated cosmos -> nocturne")
}

C := ThemeLoad()

; ------------------------------ state ------------------------------
GW := 1000, GH := 640                    ; logical window size (everything is laid out in these units)
UI_K := IsNumber(IniRead(INI, "ui", "scale", "0")) ? Number(IniRead(INI, "ui", "scale", "0")) / 100 : 0          ; [ui] scale=125 (percent) forces the size; 0 = automatic
if UI_K <= 0
    UI_K := Max(1, A_ScreenDPI / 96)                                ; same size as Windows scaling (100% -> 1000x640)
UI_K := Max(0.75, Min(UI_K, (A_ScreenHeight - 80) / GH))             ; always fits on the screen
PW := Round(GW * UI_K), PH := Round(GH * UI_K)                     ; real window size in pixels
LOGH := 98                               ; HUD 2.0: height of the log panel at the bottom (4 lines)
; HUD 2.0 layout: sidebar x 0..190, header y 0..62. Content area x 212..978 (22 px side margins), y 76..500.
; Key hints F1/F2/F3 y 502..526, log y 528..626 (GH - 14 - LOGH).
CX := 212, CY := 76, CWD := 766, CHT := 424
CX0 := CX                                ; base CX: pages are drawn with CX shifted during the page slide (step 16)
GdipInit()
UI_SHOTS := (A_Args.Length && A_Args[1] = "shots") || IniRead(INI, "ui", "uiShots", "0") = "1"   ; hidden key: snapshot test mode
uiShotFile := ""                         ; set only by UiShots: the frame being drawn is also saved here as PNG
if !InStr(RAIDS_READY, " " cfg["raidName"] " ")           ; only tested features are active in the public build
    cfg["raidName"] := "divine"
statsArm := 0                                          ; tick of the first click on "Reset statistics"
statCache := Map(), statCacheT := 0                    ; Stats page numbers read from the ini, refreshed every 5 s
connNote := "", connNoteK := "", connNoteT := 0        ; short message on a Connect card (card key srv / hook, tick)
uiShotNoLinks := false                                 ; UiShots only: draw the Connect page as if no link was saved
gr := 0                                  ; GDI+ graphics of the frame being drawn
hits := []                               ; clickable rectangles of the last frame
hoverId := ""
lastStatus := ""                         ; last status text (SetStatus)
setupDone := IniRead(INI, "setup", "done", "0") = "1"   ; the first-run Setup check must be passed once
setupOpen := false                       ; the Setup check opened again from the menu
setupBanner := "", setupBackSkin := ""   ; yellow plate (what went wrong while the bot ran) and the skin to go back to
setupRan := false, setupRes := []        ; results of the last Check
uiStatus := "stopped"
uiLog := []                              ; last log lines shown in the bottom panel
dRaid := "", dSpeed := "", dGoal := "", dDone := ""
layoutMons := 0
curTab := IniRead(INI, "ui", "tab", "")                  ; tab of the Modes page: general raid speed inf dim xdim (default general)
popOpen := ""                            ; id of the open pop-up list (Pick/Pop widgets), "" = none
popDraw := ""                            ; pop-up asked for in the frame being drawn (drawn last by DrawPop)
shotExtra := ""                          ; UiShots only: extra drawing before the pop-up (widget demo)
; HUD 2.0 step 16: animation engine (skin = full only). animVal: key -> {tgt, from, t0, dur, seen}; one timer AnimTick
animVal := Map(), animNow := A_TickCount, animFake := -1   ; animFake >= 0: fixed clock (UiShots anim test)
animTest := false, animFrame := false, animOnTimer := false, animDirty := false, animSlow := false
animFrames := 0, animMaxMs := 0, animFrameNo := 0, animSumMs := 0, animTimerRes := false, animBusy := false
OnExit(AnimResEnd)                                       ; timer resolution is paired: end it on exit if an animation left it raised
pgLast := "", pgKind := ""               ; page slide: last page|tab, "nav" (whole page) or "tab" (under the tab row)
frz := Map()                             ; values read from the ini, kept while an animation runs (no ini reads per frame)
RH2 := 56                                ; row height of the Modes settings rows (SRow)
curPage := PageNorm(IniRead(INI, "ui", "page", "home"), &curTab)
if curPage = "setup"                     ; the Setup page is not remembered between runs
    curPage := "home"
skin := IniRead(INI, "ui", "skin", "full") = "compact" && setupDone ? "compact" : "full"   ; the Setup card exists only in the full skin
cOpen := " " IniRead(INI, "ui", "cOpen", "") " "         ; open groups of the compact skin, space separated
#Include ui_compact.ahk

g := Gui("+AlwaysOnTop -Caption -DPIScale", "AD Bot")          ; sizes already include UI_K (DPI)
g.BackColor := C.bg
g.MarginX := 0, g.MarginY := 0
uiBmp := 0                                                     ; last finished frame (HBITMAP), blitted straight onto the window
uiBack := 0                                                    ; cached aurora backdrop (GDI+ bitmap), drawn once per theme
uiBackKey := ""
uiBack2 := 0                                                   ; HUD 2.0 backdrop (one soft glow), cached
uiBack2Key := ""
OnMessage(0x201, UiClick)                                      ; WM_LBUTTONDOWN
OnMessage(0x200, UiMove)                                       ; WM_MOUSEMOVE
OnMessage(0x14, (wParam, lParam, msg, hwnd) => (hwnd = g.Hwnd || (hb && hwnd = hb.Hwnd) || (sumG && hwnd = sumG.Hwnd)) ? 1 : "")   ; WM_ERASEBKGND: never erase (no flicker)
OnMessage(0xF, UiPaint)                                        ; WM_PAINT
g.OnEvent("Close", (*) => ExitApp())

; Hotbar for one monitor: while the bot runs the big window would cover the game (the bot looks for images on
; the screen), so only the Monoline strip (HotbarShow, ui_compact.ahk) is shown at the top centre, in both skins.

g.Show("Hide w" PW " h" PH)
DllCall("SetWindowRgn", "ptr", g.Hwnd, "ptr", DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", PW + 1, "int", PH + 1, "int", Round(28 * UI_K), "int", Round(28 * UI_K), "ptr"), "int", 1)
if UI_SHOTS {                                            ; HUD test: "RaidBot.ahk shots" - draw every page into shots\ui\*.png and quit (no game, no bot loop)
    if A_Args.Length > 1 && A_Args[2] = "anim"           ; "shots anim": a page slide and other animations, frames at fixed times
        UiShotsAnim()
    else if A_Args.Length > 1 && A_Args[2] = "hotbar"    ; "shots hotbar": the Monoline strip of the full skin -> shots\ui\hotbar_full.png
        UiShotHotbar()
    else
        UiShots()
    ExitApp
}
if skin = "compact"
    SkinSize()
UiCompute()
UiRender(true)
Layout()
SetTimer(UiTick, 500)
SetTimer(MusicTickFull, 1000)
SetTimer(StarTick, 200)                                  ; star animation: about 5 frames a second, only for themes with stars

; ------------------------------ public hooks used by the bot ------------------------------
UiInvalidate() => IsSet(g) && SetTimer(UiRender, -20)   ; not before the window exists (a log line during start-up)
PaintRun() => UiInvalidate()

UiSetStatus(text) {
    global uiStatus
    uiStatus := text
    UiInvalidate()
}

UiLogPush(text) {
    global uiLog
    if !IsSet(uiLog)                                     ; a log line before ui.ahk ran its top code (closing during start-up)
        uiLog := []
    text := Trim(text)
    stamp := FormatTime(, "HH:mm:ss") "  "
    first := true
    while text != "" {                                   ; long lines are wrapped (the panel is about 90 characters wide)
        chunk := SubStr(text, 1, 88)
        if StrLen(text) > 88 && (p := InStr(chunk, " ", , -1)) > 40
            chunk := SubStr(text, 1, p)
        uiLog.Push((first ? stamp : "          ") Trim(chunk))
        text := LTrim(SubStr(text, StrLen(chunk) + 1))
        first := false
    }
    while uiLog.Length > 80
        uiLog.RemoveAt(1)
    UiInvalidate()
}

; while the bot runs: only the hotbar on the game screen, also with two monitors (the big window there was in the way);
; stopped: the big window, on the monitor with the mouse
Layout() {
    global layoutMons
    layoutMons := MonitorGetCount()
    if running {
        g.Hide()
        static hbFullLogged := false
        if skin != "compact" && !hbFullLogged {
            hbFullLogged := true
            Log("ui: hotbar monoline (full skin)")
        }
        HotbarShow()
        return
    }
    HotbarHide()
    fade := skin = "compact" && !DllCall("IsWindowVisible", "ptr", g.Hwnd)   ; fade in only when the window appears
    if fade
        CompactFadePrep()
    ; 06.11: on the monitor with the mouse (where the user opened it), not always the second one
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "ptr", pt)
    mx := NumGet(pt, 0, "int"), my := NumGet(pt, 4, "int")
    MonitorGetWorkArea(MonitorGetPrimary(), &l, &t, &r, &b)
    Loop layoutMons {
        MonitorGet(A_Index, &ml, &mt, &mr, &mb)
        if mx >= ml && mx < mr && my >= mt && my < mb {
            MonitorGetWorkArea(A_Index, &l, &t, &r, &b)
            break
        }
    }
    g.Show("x" (l + (r - l - PW) // 2) " y" (t + (b - t - PH) // 2) " NoActivate")
    if fade
        CompactFadeStart()
}

StarTick() {
    if animOnTimer && skin = "full"                      ; AnimTick draws the frames (stars too) while an animation runs
        return
    if (C.stars && skin = "full" || skin = "compact") && DllCall("IsWindowVisible", "ptr", g.Hwnd)   ; compact: the moving neon on grey text
        UiRender()
}

; ------------------------------ animation engine (HUD 2.0 step 16, skin = full only) ------------------------------
; Values are tweened when their TARGET changes: AnimTarget(key, target, ms) returns the value to draw now. A key that was not
; drawn in the previous frame (new page, new widget) starts at once at its target. One timer (AnimTick, 16 ms) redraws the
; window while an animation runs and switches itself off. ease-out cubic by time, like ThemeTick.
AnimOn() {
    if skin != "full" || running
        return false
    if UI_SHOTS
        return animTest
    return DllCall("IsWindowVisible", "ptr", g.Hwnd) && !DllCall("IsIconic", "ptr", g.Hwnd)
}

AnimDur(ms) => animSlow ? Min(ms, 40) : ms       ; a slow frame (> 25 ms) was seen: the next animations take 1-2 frames

AnimCur(e) {
    if e.dur <= 0
        return e.tgt
    t := (animNow - e.t0) / e.dur
    if t >= 1
        return e.tgt
    if t < 0
        t := 0
    return e.from + (e.tgt - e.from) * (1 - (1 - t) ** 3)
}

AnimTarget(key, tgt, ms, first := "") {
    unseen := !animVal.Has(key) || animFrameNo - animVal[key].seen > 1
    if unseen {
        from := first = "" ? tgt : first
        animVal[key] := e := {tgt: tgt, from: from, t0: animNow, dur: 0, seen: animFrameNo}
        if from != tgt && AnimOn() {
            e.dur := AnimDur(ms)
            AnimKick()
        } else
            e.from := tgt
        return AnimCur(e)
    }
    e := animVal[key]
    if e.tgt != tgt {
        e.from := AnimCur(e), e.tgt := tgt, e.t0 := animNow
        e.dur := AnimOn() ? AnimDur(ms) : 0
        if e.dur
            AnimKick()
    }
    e.seen := animFrameNo
    return AnimCur(e)
}

AnimActive() {
    for k, e in animVal
        if e.dur > 0 && animNow - e.t0 < e.dur
            return true
    return false
}

AnimKick() {
    global animOnTimer, animFrames, animMaxMs, animSumMs
    if animOnTimer || UI_SHOTS
        return
    animOnTimer := true, animFrames := 0, animMaxMs := 0, animSumMs := 0
    AnimResBegin()
    SetTimer(AnimTick, 8)                                ; 16 ms was rounded up to 2 system ticks (31 ms = 30 fps); 1 ms resolution + 8 ms = ~60+ fps
}

; timeBeginPeriod(1) only while an animation series runs (once, flag), never while the bot runs
AnimResBegin() {
    global animTimerRes
    if animTimerRes || running
        return
    animTimerRes := true
    DllCall("winmm\timeBeginPeriod", "uint", 1)
}

AnimResEnd(*) {
    global animTimerRes
    if !animTimerRes
        return
    animTimerRes := false
    DllCall("winmm\timeEndPeriod", "uint", 1)
}

AnimStop(cancel) {
    global animOnTimer, animFrames, animMaxMs, animDirty, animSumMs
    SetTimer(AnimTick, 0)
    animOnTimer := false
    AnimResEnd()
    if cancel {                                          ; hidden / minimised / running / compact: values jump to their targets
        for k, e in animVal
            e.dur := 0
        animDirty := true                                ; UiTick draws the finished state when the window is back
    }
    if animFrames > 0
        try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  ui: anim " animFrames " frames, avg " Round(animSumMs / animFrames, 1) " ms, max " animMaxMs " ms`n", LOGFILE, "UTF-8"
    animFrames := 0, animMaxMs := 0, animSumMs := 0
    frz.Clear()
}

AnimTick() {
    global animFrame, animFrames, animMaxMs, animSlow, animBusy, animSumMs
    if animBusy                                          ; previous frame still running: skip, no queue (animation is by time)
        return
    if skin != "full" || running || !DllCall("IsWindowVisible", "ptr", g.Hwnd) || DllCall("IsIconic", "ptr", g.Hwnd) {
        AnimStop(true)
        return
    }
    animBusy := true
    DllCall("QueryPerformanceCounter", "int64*", &q0 := 0)
    animFrame := true
    try
        UiRender()
    catch as e {
        animFrame := false
        animBusy := false
        AnimStop(true)
        try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  ui: anim error " e.Message " (" e.What " line " e.Line ")`n", LOGFILE, "UTF-8"
        return
    }
    animFrame := false
    animBusy := false
    DllCall("QueryPerformanceCounter", "int64*", &q1 := 0)
    DllCall("QueryPerformanceFrequency", "int64*", &qf := 0)
    ms := Round((q1 - q0) * 1000 / qf)
    animFrames++
    animSumMs += ms
    animMaxMs := Max(animMaxMs, ms)
    animSlow := ms > 25
    if !AnimActive()
        AnimStop(false)
}

; value read from the ini (or a file) by a page: while an animation runs the last value is used again, so a frame does no disk reads
FrzGet(key, fn) {
    if animFrame && frz.Has(key)
        return frz[key]
    return frz[key] := fn.Call()
}

; page slide: when page / tab changes, "pg" goes 22 -> 0 (px the new content is shifted to the right)
PgWatch() {
    global pgLast, pgKind
    k := curPage "|" curTab
    if k = pgLast
        return
    old := pgLast, pgLast := k
    if old = "" || !AnimOn() {
        if animVal.Has("pg")
            animVal.Delete("pg")
        return
    }
    pgKind := SubStr(old, 1, InStr(old, "|") - 1) != curPage ? "nav" : "tab"
    animVal["pg"] := {tgt: 0, from: 22, t0: animNow, dur: AnimDur(200), seen: 0}
    AnimKick()
}

PgDx() => animVal.Has("pg") ? AnimCur(animVal["pg"]) : 0

; sidebar y of the active page (Setup sits at the bottom), -1 = none
NavY(page) {
    i := 0
    for nm in ["home", "modes", "connect", "stats", "settings"] {
        if nm = page
            return 68 + 42 * i
        i++
    }
    return page = "setup" ? GH - 18 - 40 - 42 : -1
}

Blend(c1, c2, v) {
    out := ""
    for i in [1, 3, 5] {
        p1 := Integer("0x" SubStr(c1, i, 2)), p2 := Integer("0x" SubStr(c2, i, 2))
        out .= Format("{:02X}", Round(p1 + (p2 - p1) * v))
    }
    return out
}

UiTick() {
    static ticks := 0, lastSig := ""
    global hbPulse, animDirty
    ticks++
    hbPulse := !hbPulse                                  ; blink of the hotbar dot
    if Mod(ticks, 4) = 0 && MonitorGetCount() != layoutMons    ; a monitor was plugged / unplugged
        Layout()
    if running
        MiniUpdate()
    if !DllCall("IsWindowVisible", "ptr", g.Hwnd)
        return
    sig := UiCompute()
    if sig != lastSig || animDirty {
        lastSig := sig
        animDirty := false
        UiRender()
    }
}

; strings for the Dashboard tiles; returns a signature of everything that changes on screen
UiCompute() {
    global dRaid, dSpeed, dGoal, dDone
    left := RaidLeft()
    dRaid := cfg["raid"] = "1" ? ClockTxt(left) : "—"
    sLeft := speedDue ? DateDiff(speedDue, A_Now, "Seconds") : 0         ; <= 0: Speed Raid is available now
    dSpeed := cfg["speed"] != "1" ? "—" : sLeft <= 0 ? "ready"
        : sLeft >= 3600 ? Round(sLeft / 3600) " h" : Format("{:02}:{:02}", sLeft // 60, Mod(sLeft, 60))
    goal := cfg["fightOnly"] = "1" ? "fight" : Target()
    dGoal := goal = "raid" ? "Raid" : goal = "speed" ? "Speed" : goal = "infinity" ? "Infinity" : goal = "dungeon" ? "Dimension" : goal = "fight" ? "Fight" : "—"
    dDone := raidDoneKey = RaidKey() ? "done" : cfg["raid"] = "1" && !RaidHourOk(RaidHour()) ? "skipped" : "not yet"
    return dRaid "|" dSpeed "|" dGoal "|" dDone "|" uiStatus "|" running "|" curPage "|" hoverId "|" uiLog.Length
        . "|" (WinExist(GAME) != 0) "|" curLoadout "|" (running && A_TickCount - lastFight < FIGHT_STICKY)
        . "|" sess["raids"] "," sess["infRuns"] "," sess["raidGems"] "," sess["raidTokens"] "," runTokens "," sess["speedRuns"] "," sess["dimRuns"] "," sess["speedGems"] "," sess["dimGems"] "," sess["speedTokens"]
        . "|" (curPage = "stats" ? A_Sec // 5 : "") "|" setupDone setupOpen setupRan setupRes.Length StrLen(setupBanner)
        . "|" curTab "|" popOpen "|" busy "|" SessClockTxt()
        . (skin = "compact" ? "|" CInfLeft() : "")
}

; header clock: elapsed time of the running session or the length of the last one, HH:mm (no seconds: the frame is not redrawn every second)
SessClockTxt() {
    ms := IsSet(sessStart) && sessStart ? A_TickCount - sessStart : IsSet(sessMs) ? sessMs : 0
    if ms < 60000 && !(IsSet(sessStart) && sessStart)
        return "--:--"
    m := ms // 60000
    return Format("{:02}:{:02}", m // 60, Mod(m, 60))
}

; ------------------------------ Setup check ------------------------------
SetupRun() {
    global setupRes, setupRan
    SetStatus("Setup check running")
    setupRes := SetupChecks(true), setupRan := true
    for it in setupRes
        Log("setup check: " it.state " - " it.name (it.fix != "" ? " (" it.fix ")" : ""))
    ; 11.11: the screen as it was when the check ran: one fixed file (overwritten by the next check), Send_Report.bat always packs it
    try {
        DirCreate SHOTDIR
        if SaveRegion(SHOTDIR "setup_check.jpg", 0, 0, 1920, 1080) = 0
            Log("  setup check screenshot: " SHOTDIR "setup_check.jpg")
    }
    SetStatus("Setup check done")
}

SetupFails() {
    n := 0
    for it in setupRes
        n += it.state = "fail"
    return n
}

; 8.11: the bot hit the same trouble again and again (ProblemWatch): after the player stops it, the Setup page opens by itself,
; runs the check, and a yellow plate says what went wrong (HUD 2.0: a page; the overlay card is only for the first run)
ProblemShow() {
    global problemNote, setupBanner, setupBackSkin, setupRan, setupRes
    setupBanner := "While running: " problemNote, problemNote := ""
    if skin != "full" {                                  ; the Setup page exists only in the full skin
        setupBackSkin := skin
        SetSkin("full")
        IniWrite setupBackSkin, INI, "ui", "skin"        ; temporary: closing with X / F3 instead of Back must not keep full as the start skin
    }
    setupRan := false, setupRes := []
    SetPage("setup")
    UiRender(true)
    SetTimer(SetupRun, -400)
}

SetupClose() {
    global setupDone, setupOpen, setupBanner, setupBackSkin
    setupBanner := ""
    if setupBackSkin != "" {
        s := setupBackSkin, setupBackSkin := ""
        setupOpen := false
        SetPage("home")                                     ; the Setup page is left, the next full window opens on Home
        SetSkin(s)
        return
    }
    if !setupDone {
        setupDone := true
        IniWrite "1", INI, "setup", "done"
        Log("setup check passed")
        setupOpen := false
        SetPage("home")                                     ; first run: 14.11 (players) the full window stays, on Home; compact is in Settings
        IniWrite "full", INI, "ui", "skin"
        return
    }
    setupOpen := false
}

; ------------------------------ clicks ------------------------------
HitAt(lParam) {
    k := skin = "compact" ? CK() : UI_K
    x := (lParam & 0xFFFF) / k, y := ((lParam >> 16) & 0xFFFF) / k
    i := hits.Length
    while i >= 1 {
        h := hits[i]
        if x >= h.x && x < h.x + h.w && y >= h.y && y < h.y + h.h
            return h
        i--
    }
    return {id: "", fn: "", y: y}
}

UiClick(wParam, lParam, msg, hwnd) {
    if sumG && hwnd = sumG.Hwnd {                        ; session summary: a click anywhere closes it
        SummaryHide()
        return 0
    }
    if hwnd != g.Hwnd
        return
    if updBusy                                          ; 14.11: locked while the update runs (no clicks, no dragging)
        return 0
    h := HitAt(lParam)
    if IsObject(h.fn) {
        was := running
        h.fn.Call()
        Sfx(ClickSound(h.id, was))
        UiInvalidate()
        return 0
    }
    if h.y < 62                                         ; empty part of the top bar: drag the window
        PostMessage(0xA1, 2, 0, , "ahk_id " g.Hwnd)
}

; sound of a click after its action ran: on / off for switches (t_ old rows, sw_ HUD 2.0 switches, pt_ ...), else click
ClickSound(id, was := false) {
    if skin = "full" {                                  ; HUD 2.0 sounds by id (the compact skin keeps click / on / off)
        pre := SubStr(id, 1, 4), pre3 := SubStr(id, 1, 3)
        if id = "nav_sound"                              ; the switch already ran: on plays, off is silent (Sfx checks cfg)
            return cfg["sfx"] = "1" ? "on" : "off"
        if pre = "nav_" || pre = "tab_"
            return "page"
        if pre = "pop_" || pre3 = "pk_" || SubStr(id, 1, 5) = "pick_" || pre = "seg_" || SubStr(id, 1, 6) = "clook_"
            return "pick"
        if pre3 = "dn_" || pre3 = "up_" || pre = "stp_"
            return "step"
        if SubStr(id, 1, 3) = "th_"
            return "theme"
        if SubStr(id, 1, 3) = "lk_"
            return "err"
        if id = "run"
            return running && !was ? "start" : !running && was ? "stop" : "tap"
        if SubStr(id, 1, 2) != "t_" && SubStr(id, 1, 3) != "sw_" && SubStr(id, 1, 3) != "pt_"
            return "tap"                                ; tap.wav: the louder tick (tick.wav stays, it can be locked by a running bot)
    }
    p := SubStr(id, 1, 2) = "t_" ? 2 : SubStr(id, 1, 3) = "sw_" || SubStr(id, 1, 3) = "pt_" ? 3 : 0
    if !p
        return "click"
    key := SubStr(id, p + 1)
    if key = "compact"                                  ; skin switch: the window is rebuilt, no on/off
        return "click"
    if key = "infAuto"
        return Num("infAuto", 15000) > 0 ? "on" : "off"
    if key = "loadouts_speed"                           ; second switch of the same cfg key
        key := "loadouts"
    return cfg.Get(key, "0") = "1" ? "on" : "off"
}

UiMove(wParam, lParam, msg, hwnd) {
    global hoverId
    if hwnd != g.Hwnd || updBusy
        return
    id := HitAt(lParam).id
    if id != hoverId {
        hoverId := id
        UiInvalidate()
    }
}

Hit(x, y, w, h, id, fn) => hits.Push({x: x, y: y, w: w, h: h, id: id, fn: fn})
IsHot(id) => hoverId = id

; HUD 2.0 page names: home modes connect stats settings setup. Old names stay as aliases:
; m_raid m_speed m_inf m_dim m_xdim -> modes + tab, skills -> modes + tab raid, look -> settings.
PageNorm(name, &tab) {
    if !InStr(" home modes connect stats settings setup m_raid m_speed m_inf m_dim m_xdim skills look ", " " name " ")
        name := "home"
    if SubStr(name, 1, 2) = "m_" {
        tab := SubStr(name, 3)
        name := "modes"
    } else if name = "skills" {
        tab := "raid"
        name := "modes"
    } else if name = "look"
        name := "settings"
    if name != "modes"
        tab := ""
    else if tab = "" || !InStr(" general raid speed inf dim xdim ", " " tab " ")
        tab := "general"
    return name
}

SetPage(name) {
    global curPage, curTab, popOpen
    old := curPage "|" curTab
    global setupBanner, setupBackSkin
    popOpen := ""
    tab := ""                                           ; SetPage("modes") = Modes, tab General; SetPage("m_dim") = Modes with the Dimension tab
    name := PageNorm(name, &tab)
    if name != "setup"                                  ; leaving the Setup page: the yellow plate and the way back to compact are done
        setupBanner := "", setupBackSkin := ""
    curPage := name, curTab := tab
    if curPage != "setup" {                             ; Setup is never saved: the next start opens Home (or the page left before)
        IniWrite curPage, INI, "ui", "page"
        IniWrite curTab, INI, "ui", "tab"
    }
    if curPage "|" curTab != old
        try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  ui: page = " curPage (curTab != "" ? " (" curTab ")" : "") "`n", LOGFILE, "UTF-8"   ; file only, not the log panel
}

; click on a tab of the Modes page
SetTab(name, *) {
    global curTab, popOpen
    popOpen := ""
    if curTab = name
        return
    curTab := name
    IniWrite curTab, INI, "ui", "tab"
    try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  ui: modes tab = " curTab "`n", LOGFILE, "UTF-8"   ; file only, not the log panel
}

ClosePop(*) {
    global popOpen
    popOpen := ""
}

PopToggle(id, *) {
    global popOpen
    popOpen := popOpen = id ? "" : id
}

FlipKey(key) {
    if busy && !running {
        Log("toggle click ignored: bot is still stopping")
        return
    }
    cfg[key] := cfg[key] = "1" ? "0" : "1"
    IniWrite cfg[key], INI, "raid", key
    Log("setting " key " = " cfg[key] " (applies at once)")
}

; short raid name for chips and the compact picker
RaidShort(k) => k = "saiya" ? "Saiya UI" : k = "shiro" ? "Infinity Shiro" : k = "divine" ? "Divine" : StrReplace(RAIDS[k][3], " Raid")

PickRaid(key) {
    if cfg["raidName"] = key || !InStr(RAIDS_READY, " " key " ")
        return
    cfg["raidName"] := key
    IniWrite key, INI, "raid", "raidName"
    Log("setting raid = " RAIDS[key][3] " (applies at once)")
}

PickDimName(k) {
    if cfg["dimName"] = k
        return
    cfg["dimName"] := k
    IniWrite k, INI, "raid", "dimName"
    Log("setting dimName = " k " (applies at once)")
}

PickXdim(n) {
    if cfg["xdimPick"] = n
        return
    cfg["xdimPick"] := n
    IniWrite n, INI, "raid", "xdimPick"
    Log("setting xdimPick = " n)
}

PickDimMethod(m) {
    if cfg["dimMethod"] = m
        return
    cfg["dimMethod"] := m
    IniWrite m, INI, "raid", "dimMethod"
    Log("setting dimMethod = " m " (applies at once)")
}

ToggleSkill(k) {
    off := []
    for s in StrSplit(Trim(cfg["skillsOff"]), " ")
        if s != "" && s != k
            off.Push(s)
    if SkillOn(k)
        off.Push(k)
    list := ""
    for s in off
        list .= (list = "" ? "" : " ") s
    cfg["skillsOff"] := list
    IniWrite list, INI, "raid", "skillsOff"
    Log("setting skill " k (SkillOn(k) ? " on" : " off") " (applies at once)")
}

PickCombo(k) {
    if k = "off" {
        cfg["combo"] := "0"
    } else {
        cfg["combo"] := "1"
        cfg["comboKey"] := k
        IniWrite k, INI, "raid", "comboKey"
    }
    IniWrite cfg["combo"], INI, "raid", "combo"
    Log("setting combo trigger = " (k = "off" ? "none" : k) " (applies at once)")
}

PickHold(k) {
    cfg["comboSpam"] := k
    IniWrite k, INI, "raid", "comboSpam"
    Log("setting combo hold key = " k " (applies at once)")
}

StepHold(d) {
    ms := Min(10000, Max(500, Num("comboMs", 3000) + d))
    cfg["comboMs"] := String(ms)
    IniWrite ms, INI, "raid", "comboMs"
}

OpenPath(p) {
    if !FileExist(p) && SubStr(p, -1) = "\"                ; a folder that is not made yet (clean install): make it
        try DirCreate(p)
    if FileExist(p)
        Run(p)
}

; F3: stop and reload the script (the new copy replaces this one: #SingleInstance Force); it does not start the bot
RestartBot() {
    Log("RESTART (F3)")
    if running
        Stop(false)
    Run('"' A_AhkPath '" "' A_ScriptFullPath '"')
}

; the player's own private server link: a small window with a text field, saved to raid.ini [raid] serverLink (used from the next restart of Roblox)
EditServerLink(*) {
    static dlg := 0
    if dlg {
        try dlg.Show()
        return
    }
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Private server link")
    dlg.SetFont("s10")
    dlg.AddText("w560", "Paste your Roblox private server link. Empty = the bot joins a public server after a restart.")
    ed := dlg.AddEdit("w560 r1", PrivateLink())
    note := dlg.AddText("w560 cC00000", "")
    dlg.AddButton("w110 Default", "Save").OnEvent("Click", Save)
    dlg.AddButton("x+10 w110", "Join").OnEvent("Click", Join)
    dlg.AddButton("x+10 w110", "Cancel").OnEvent("Click", Close)
    dlg.OnEvent("Close", Close)
    dlg.OnEvent("Escape", Close)
    dlg.Show()
    Save(*) {
        v := Trim(ed.Value)
        if v != "" && !RegExMatch(v, "i)roblox\.com|^roblox://") {
            note.Value := "This does not look like a Roblox link (https://www.roblox.com/games/...)."
            return false
        }
        IniWrite v, INI, "raid", "serverLink"
        Log(v = "" ? "private server link cleared" : "private server link saved")
        Close()
        return true
    }
    Join(*) {                                             ; save the link, then open it (Roblox asks to open the game)
        v := Trim(ed.Value)
        if v = "" {
            note.Value := "Paste the link first."
            return
        }
        if !Save()
            return
        Log("opening the private server link")
        try Run(ProtoLink(v))
    }
    Close(*) {
        dlg.Destroy()
        dlg := 0
    }
}

; button "Discord": the webhook link (status + screenshot in a Discord channel, see webhook.ahk)
EditWebhook(*) {
    static dlg := 0
    if dlg {
        try dlg.Show()
        return
    }
    dlg := Gui("+AlwaysOnTop +ToolWindow", "Discord status")
    dlg.SetFont("s10")
    dlg.AddText("w560", "See the bot from your phone. In your Discord server: channel settings > Integrations > Webhooks > New Webhook > Copy Webhook URL, and paste it here. Keep it private: anyone with it can post to that channel.")
    ed := dlg.AddEdit("w560 r1", WebhookUrl())
    dlg.AddText("w300", "Status + game screenshot every (minutes, 0 = only problems):")
    mins := dlg.AddEdit("x+6 yp-3 w60 Number", Trim(IniRead(INI, "raid", "webhookMin", "30")))
    note := dlg.AddText("xm w560 cC00000", "")
    dlg.AddButton("xm w110 Default", "Save").OnEvent("Click", Save)
    dlg.AddButton("x+10 w110", "Test").OnEvent("Click", Test)
    dlg.AddButton("x+10 w110", "Cancel").OnEvent("Click", Close)
    dlg.OnEvent("Close", Close)
    dlg.OnEvent("Escape", Close)
    dlg.Show()
    Check() {
        v := Trim(ed.Value)
        if v != "" && !WebhookOk(v) {
            note.Value := "This does not look like a Discord webhook link (https://discord.com/api/webhooks/...)."
            return false
        }
        IniWrite v, INI, "raid", "webhook"
        IniWrite IsInteger(mins.Value) ? mins.Value : 30, INI, "raid", "webhookMin"
        return true
    }
    Save(*) {
        if !Check()
            return
        Log(Trim(ed.Value) = "" ? "Discord webhook cleared" : "Discord webhook saved, status every " mins.Value " min")
        Close()
    }
    Test(*) {
        if !Check()
            return
        if Trim(ed.Value) = "" {
            note.Value := "Paste the link first."
            return
        }
        WebhookPost("**AD Bot** test - if you see this, it works. " WebhookStatus(), Screenshot("discord"))
        note.Value := "Test sent - look in your Discord channel."
    }
    Close(*) {
        dlg.Destroy()
        dlg := 0
    }
}

; button "Private server" (full mode) = "SERVER LINK" (compact): the same window; Join inside it opens the link
JoinPrivateServer() => EditServerLink()

ToggleRun() {
    if running
        Stop()
    else
        Start()
}

; ------------------------------ GDI+ drawing helpers ------------------------------
GdipInit() {
    if !DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
        DllCall("LoadLibrary", "str", "gdiplus")
    si := Buffer(24, 0)
    NumPut("uint", 1, si)                                 ; GdiplusStartupInput.GdiplusVersion
    DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0)   ; until the bot exits
}

Col(hex, a := 255) => (a << 24) | Integer("0x" (tmap ? TCol(hex) : hex))   ; tmap: the compact light theme is being drawn

Canvas(w, h, fill) {
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "int", w, "int", h, "int", 0, "int", 0x26200A, "ptr", 0, "ptr*", &bmp := 0)
    DllCall("gdiplus\GdipGetImageGraphicsContext", "ptr", bmp, "ptr*", &gr := 0)
    DllCall("gdiplus\GdipSetSmoothingMode", "ptr", gr, "int", 4)
    DllCall("gdiplus\GdipSetTextRenderingHint", "ptr", gr, "int", 4)
    DllCall("gdiplus\GdipGraphicsClear", "ptr", gr, "uint", Col(fill))
    return [bmp, gr]
}

ToHbm(cv) {
    DllCall("gdiplus\GdipDeleteGraphics", "ptr", cv[2])
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "ptr", cv[1], "ptr*", &hbm := 0, "uint", 0xFF000000)
    DllCall("gdiplus\GdipDisposeImage", "ptr", cv[1])
    return hbm
}

RRPath(x, y, w, h, r) {
    d := Min(r * 2, w, h)
    DllCall("gdiplus\GdipCreatePath", "int", 0, "ptr*", &path := 0)
    for a in [[x, y, 180], [x + w - d, y, 270], [x + w - d, y + h - d, 0], [x, y + h - d, 90]]
        DllCall("gdiplus\GdipAddPathArc", "ptr", path, "float", a[1], "float", a[2], "float", d, "float", d, "float", a[3], "float", 90)
    DllCall("gdiplus\GdipClosePathFigure", "ptr", path)
    return path
}

FillRR(x, y, w, h, r, hex, a := 255) {
    path := RRPath(x, y, w, h, r)
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

LineBrush(x, y, w, h, hex1, a1, hex2, a2, vert) {
    pts := Buffer(16)
    NumPut("float", x, "float", y, "float", vert ? x : x + w, "float", vert ? y + h : y, pts)
    DllCall("gdiplus\GdipCreateLineBrush", "ptr", pts, "ptr", pts.Ptr + 8, "uint", Col(hex1, a1), "uint", Col(hex2, a2), "int", 0, "ptr*", &br := 0)
    return br
}

GradRR(x, y, w, h, r, hex1, a1, hex2, a2, vert := false) {
    path := RRPath(x, y, w, h, r)
    br := LineBrush(x, y, w, h, hex1, a1, hex2, a2, vert)
    DllCall("gdiplus\GdipFillPath", "ptr", gr, "ptr", br, "ptr", path)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

StrokeRR(x, y, w, h, r, hex, a := 255, wd := 1) {
    path := RRPath(x + 0.5, y + 0.5, w - 1, h - 1, r)
    DllCall("gdiplus\GdipCreatePen1", "uint", Col(hex, a), "float", wd, "int", 2, "ptr*", &pen := 0)
    DllCall("gdiplus\GdipDrawPath", "ptr", gr, "ptr", pen, "ptr", path)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
    DllCall("gdiplus\GdipDeletePath", "ptr", path)
}

Dot(x, y, d, hex, a := 255) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", x, "float", y, "float", d, "float", d)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; soft glow: stacked translucent ellipses (centre cx, cy, radii rx, ry)
Glow(cx, cy, rx, ry, hex, a) {
    Loop 14 {
        s := 1 - (A_Index - 1) / 14
        DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, Max(1, a // 14)), "ptr*", &br := 0)
        DllCall("gdiplus\GdipFillEllipse", "ptr", gr, "ptr", br, "float", cx - rx * s, "float", cy - ry * s, "float", 2 * rx * s, "float", 2 * ry * s)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
    }
}

; glass panel: dark tint, light top-lit gradient, thin light border
Glass(x, y, w, h, r := 18, hot := false) {
    FillRR(x, y, w, h, r, C.card, C.lite ? 225 : 170)
    GradRR(x, y, w, h, r, C.ov, hot ? 26 : (C.lite ? 6 : 18), C.ov, C.lite ? 1 : 3, true)
    StrokeRR(x, y, w, h, r, C.ov, hot ? 70 : 38)
}

FontFam(role) {
    global skin
    static fams := Map(), coll := 0, inited := false
    static cNames := Map("title", ["Sora", "Segoe UI Semibold", "Segoe UI"], "head", ["Segoe UI Semibold", "Segoe UI"], "ui", ["Inter", "Segoe UI"],
        "mono", ["Consolas", "JetBrains Mono"], "icon", ["Segoe MDL2 Assets"])        ; compact: system fonts only, as before fonts\ existed
    isC := IsSet(skin) && skin = "compact"
    fk := role "|" (isC ? "c" : "f")
    static names := Map("title", ["Sora", "Segoe UI Semibold", "Segoe UI"], "head", ["Space Grotesk", "Segoe UI Semibold", "Segoe UI"], "ui", ["Inter", "Segoe UI"],
        "mono", ["JetBrains Mono", "Consolas"], "icon", ["Segoe MDL2 Assets"])
    if fams.Has(fk)
        return fams[fk]
    if !inited {
        inited := true
        if FileExist(A_ScriptDir "\fonts\*.ttf") {
            DllCall("gdiplus\GdipNewPrivateFontCollection", "ptr*", &coll)
            Loop Files A_ScriptDir "\fonts\*.ttf"
                DllCall("gdiplus\GdipPrivateAddFontFile", "ptr", coll, "wstr", A_LoopFileFullPath)
        }
    }
    for nm in (isC ? cNames[role] : names[role]) {
        fam := 0
        if !isC && coll && !DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", nm, "ptr", coll, "ptr*", &fam) && fam {
            fams[fk] := fam
            return fam
        }
        fam := 0
        if !DllCall("gdiplus\GdipCreateFontFamilyFromName", "wstr", nm, "ptr", 0, "ptr*", &fam) && fam {
            fams[fk] := fam
            return fam
        }
    }
    return 0
}

FontOf(role, px, bold) {
    static cache := Map()
    global skin
    key := (IsSet(skin) && skin = "compact" ? "c" : "f") "|" role "|" px "|" bold
    if cache.Has(key)
        return cache[key]
    fam := FontFam(role)
    font := 0
    if DllCall("gdiplus\GdipCreateFont", "ptr", fam, "float", px, "int", bold, "int", 2, "ptr*", &font) || !font
        DllCall("gdiplus\GdipCreateFont", "ptr", fam, "float", px, "int", 0, "int", 2, "ptr*", &font)   ; no bold face installed
    cache[key] := font
    return font
}

StrFmt(align) {
    static f := Map()
    if !f.Has(align) && align = -1 {                                                         ; paragraph: wraps, top-left
        DllCall("gdiplus\GdipCreateStringFormat", "int", 0, "int", 0, "ptr*", &fmt := 0)
        f[align] := fmt
    }
    if !f.Has(align) {
        DllCall("gdiplus\GdipCreateStringFormat", "int", 0x1000, "int", 0, "ptr*", &fmt := 0)   ; no wrap
        DllCall("gdiplus\GdipSetStringFormatAlign", "ptr", fmt, "int", align)                    ; 0 left, 1 centre, 2 right
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "ptr", fmt, "int", 1)                    ; centred vertically
        DllCall("gdiplus\GdipSetStringFormatTrimming", "ptr", fmt, "int", 3)                     ; ... at the end
        f[align] := fmt
    }
    return f[align]
}

; text in the box (x, y, w, h); role: title (compact) / head (full headings) / ui / mono / icon
Tx(text, role, px, bold, hex, x, y, w, h, align := 0, a := 255) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    rc := Buffer(16)
    NumPut("float", x, "float", y, "float", w, "float", h, rc)
    DllCall("gdiplus\GdipDrawString", "ptr", gr, "wstr", text, "int", -1, "ptr", FontOf(role, px, bold), "ptr", rc, "ptr", StrFmt(align), "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; paragraph that wraps inside the box (x, y, w, h)
TxP(text, role, px, hex, x, y, w, h, a := 255) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    rc := Buffer(16)
    NumPut("float", x, "float", y, "float", w, "float", h, rc)
    DllCall("gdiplus\GdipDrawString", "ptr", gr, "wstr", text, "int", -1, "ptr", FontOf(role, px, 0), "ptr", rc, "ptr", StrFmt(-1), "ptr", br)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

TxW(text, role, px, bold) {
    rc := Buffer(16, 0), box := Buffer(16, 0)
    NumPut("float", 0, "float", 0, "float", 2000, "float", 100, rc)
    DllCall("gdiplus\GdipMeasureString", "ptr", gr, "wstr", text, "int", -1, "ptr", FontOf(role, px, bold), "ptr", rc, "ptr", StrFmt(0), "ptr", box, "ptr", 0, "ptr", 0)
    return NumGet(box, 8, "float")
}

; ------------------------------ widgets ------------------------------
Btn(x, y, w, h, label, id, fn, primary := false, icon := "", off := false) {
    if off {                                               ; locked: greyed out, no clicks
        FillRR(x, y, w, h, 14, C.field, 110)
        Tx(label, "ui", 14, 1, C.idle, x, y, w, h, 1, 170)
        return
    }
    hot := IsHot(id)
    if primary
        GradRR(x, y, w, h, 14, C.acc, 255, C.acc2, 255)
    else {
        FillRR(x, y, w, h, 14, C.field)
        StrokeRR(x, y, w, h, 14, running && id = "run" ? C.hi : C.ov, running && id = "run" ? 200 : 34)
    }
    if hot
        FillRR(x, y, w, h, 14, C.ov, 26)
    fg := primary ? "FFFFFF" : C.text
    if icon != "" {
        tw := TxW(label, "ui", 14, 1)
        x0 := x + (w - (22 + 8 + tw)) / 2
        Tx(icon, "icon", 16, 0, primary ? "FFFFFF" : C.hi, x0, y, 22, h, 1)
        Tx(label, "ui", 14, 1, fg, x0 + 30, y, tw + 12, h)
    } else
        Tx(label, "ui", 14, 1, fg, x, y, w, h, 1)
    Hit(x, y, w, h, id, fn)
}

Chip(x, y, w, h, label, on, id, fn, off := false) {
    if off {                                               ; locked: greyed out, no clicks
        ChipOff(x, y, w, h, label)
        return
    }
    if on {
        GradRR(x, y, w, h, 12, C.acc, 255, C.acc2, 255)
        StrokeRR(x, y, w, h, 12, C.hi, 170)
    } else {
        FillRR(x, y, w, h, 12, C.field)
        StrokeRR(x, y, w, h, 12, C.ov, 22)
    }
    if IsHot(id)
        FillRR(x, y, w, h, 12, C.ov, 24)
    Tx(label, "ui", 14, 1, on ? "FFFFFF" : C.dim, x, y, w, h, 1)
    Hit(x, y, w, h, id, fn)
}

; locked chip: dimmed, not clickable; tag (e.g. "Soon") is drawn on the right
ChipOff(x, y, w, h, label, tag := "") {
    FillRR(x, y, w, h, 12, C.field, 110)
    if tag != "" {
        Tx(label, "ui", 13, 1, C.idle, x + 14, y, w - 100, h, 0, 170)
        Tx(tag, "ui", 10, 1, C.hi, x, y, w - 12, h, 2, 220)
    } else
        Tx(label, "ui", 14, 1, C.idle, x, y, w, h, 1, 170)
}

DrawSwitch(x, y, on) {
    if on
        GradRR(x, y, 46, 26, 13, C.acc, 255, C.acc2, 255)
    else
        FillRR(x, y, 46, 26, 13, C.off)
    Dot(on ? x + 23 : x + 3, y + 3, 20, on ? "FFFFFF" : "C4CADB")
}

ToggleRow(x, y, w, label, desc, key, off := false) {
    id := "t_" key
    on := cfg[key] = "1" && !off
    if off {                                               ; locked: greyed out, no clicks
        Tx(label, "ui", 14, 1, C.idle, x + 12, y + 6, w - 90, 22, 0, 150)
        Tx(desc, "ui", 11, 0, C.idle, x + 12, y + 28, w - 90, 18, 0, 150)
        FillRR(x + w - 60, y + 13, 46, 26, 13, C.off, 120)
        Dot(x + w - 57, y + 16, 20, "C4CADB", 90)
        return
    }
    if IsHot(id)
        FillRR(x, y, w, 52, 12, C.ov, 12)
    Tx(label, "ui", 14, 1, on ? C.text : C.dim, x + 12, y + 6, w - 90, 22)
    Tx(desc, "ui", 11, 0, C.dim, x + 12, y + 28, w - 90, 18)
    DrawSwitch(x + w - 60, y + 13, on)
    Hit(x, y, w, 52, id, FlipKey.Bind(key))
}

Panel(x, y, w, h, title) {
    Glass(x, y, w, h)
    Tx(title, "head", 15, 1, C.text, x + 20, y + 14, w - 40, 24)
}

Caption(text, x, y, w := 300) => Tx(StrUpper(text), "ui", 11, 1, C.dim, x, y, w, 16)

KeyCap(x, y, text) {
    tw := TxW(text, "mono", 12, 1)
    FillRR(x, y, tw + 18, 24, 7, C.field)
    StrokeRR(x, y, tw + 18, 24, 7, C.ov, 40)
    Tx(text, "mono", 12, 1, C.text, x, y, tw + 18, 24, 1)
    return tw + 18
}

; ------------------------------ frame ------------------------------
UiRender(force := false) {
    global gr, hits, uiBmp, popDraw, CX, animNow, animFrameNo, pgLast
    if !force && !DllCall("IsWindowVisible", "ptr", g.Hwnd)
        return
    static lastFrameLog := 0, lastSlowLog := -1000
    t0 := A_TickCount
    Critical "On"                         ; mouse messages must not interrupt a half-drawn frame (hits would be incomplete -> hover flicker)
    if updBusy && updView.stage != "" {   ; 14.11: the update loading screen replaces the page in both skins (update.ahk)
        UpdRender()
        Critical "Off"
        return
    }
    if !animFrame                        ; an animation frame does not recompute the tile texts (they read the ini): the last ones stay
        UiCompute()
    if skin = "compact" {
        pgLast := ""
        CompactRender()
        Critical "Off"
        return
    }
    animNow := animFake >= 0 ? animFake : A_TickCount
    animFrameNo++
    PgWatch()
    cv := Canvas(PW, PH, C.bg)
    gr := cv[2]
    DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", UI_K, "float", UI_K, "int", 0)
    hits := []
    popDraw := ""
    DrawBackdrop2()
    if C.stars
        DrawStars()
    DrawSidebar2()
    DrawHeader2()
    CX := CX0 + (pgKind = "nav" ? PgDx() : 0)           ; page slide: the content (and its hits) is drawn shifted
    switch curPage {
        case "modes":    PageModesTab()
        case "connect":  PageConnect()
        case "stats":    PageStats()
        case "settings": PageSettings()
        case "setup":    PageSetup()
        default:         PageHome()
    }
    CX := CX0
    DrawKeys2()
    DrawLog2()
    if IsObject(shotExtra)
        shotExtra.Call()
    DrawPop()                                            ; the pop-up is the last thing in the frame (over the log too)
    if !setupDone                                        ; the overlay card is only for the first run; later Setup is a page
        DrawSetup()
    if uiShotFile != ""
        UiShotSave(cv[1])
    hbm := ToHbm(cv)
    gr := 0
    if uiBmp
        DllCall("DeleteObject", "ptr", uiBmp)
    uiBmp := hbm
    UiBlit()
    Critical "Off"
    if UI_SHOTS || animFrame                             ; no frame-time Log() in the snapshot test; AnimTick logs its own summary
        return
    ms := A_TickCount - t0
    if ms > 25 {
        if A_TickCount - lastSlowLog >= 1000 {     ; Log() repaints the panel -> a slow frame would re-trigger itself; max 1 SLOW line/s
            Log("ui: frame " ms " ms (page " curPage ") SLOW")
            lastSlowLog := A_TickCount
        }
    } else if A_TickCount - lastFrameLog >= 30000 {
        Log("ui: frame " ms " ms (page " curPage ")")
        lastFrameLog := A_TickCount
    }
}

; ------------------------------ snapshot test mode (UI_SHOTS) ------------------------------
UiShotSave(bmp) {
    global uiShotFile
    DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid := Buffer(16))   ; PNG encoder
    res := DllCall("gdiplus\GdipSaveImageToFile", "ptr", bmp, "wstr", uiShotFile, "ptr", clsid, "ptr", 0)
    SplitPath uiShotFile, &nm
    UiShotLog(res = 0 ? "ui: shot saved " nm : "ui: shot FAILED " nm " (gdi+ error " res ")")
    uiShotFile := ""
}

; plain log line (Log() would pull in webhook / problem watch, which are not set up yet at this point of the start)
UiShotLog(text) {
    UiLogPush(text)
    try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  " text "`n", LOGFILE, "UTF-8"
}

; draws the hotbar bitmap (HotbarDraw) with demo values into a PNG; the strip window is created but never shown
UiShotHotbar() {
    global skin, running, hb, hbW, hbKey, hbBmp, uiShotFile, runGoal, lastStatus
    dir := A_ScriptDir "\shots\ui\"
    DirCreate dir
    skin := "full", running := true, runGoal := "raid", hbW := HB_W, hbKey := ""
    hb := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
    hb.BackColor := "000000"
    UiShotLog("ui: hotbar shot start (skin full, window not shown)")
    HotbarDraw("12:40", "08:15", "Raid: waiting in the lobby for the hourly raid")
    if !hbBmp {
        UiShotLog("ui: shot FAILED hotbar_full.png (no bitmap)")
        return
    }
    uiShotFile := dir "hotbar_full.png"
    res := DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbBmp, "ptr", 0, "ptr*", &pb := 0)
    if res = 0 {
        UiShotSave(pb)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pb)
    } else
        UiShotLog("ui: shot FAILED hotbar_full.png (gdi+ error " res ")")
    global updRemote                                      ; 14.11: the same bar with a new build on GitHub
    updRemote := "999999999999", hbKey := ""
    HotbarDraw("12:40", "08:15", "Raid: waiting in the lobby for the hourly raid")
    uiShotFile := dir "hotbar_update.png"
    if DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbBmp, "ptr", 0, "ptr*", &pb := 0) = 0 {
        UiShotSave(pb)
        DllCall("gdiplus\GdipDisposeImage", "ptr", pb)
    }
}

; draws every full-skin page (and the Setup card over home) to shots\ui\<name>.png; nothing is shown, clicked or saved in the ini
UiShots() {
    global curPage, curTab, skin, setupOpen, setupDone, uiShotFile, setupRes, setupRan, uiStatus, sessMs, C
    dir := A_ScriptDir "\shots\ui\"
    DirCreate dir
    skin := "full", setupDone := true, setupOpen := false
    uiStatus := "Waiting for the hourly raid at 12:40, then Speed Raid"
    sessMs := 102 * 60000
    UiShotLog("ui: shots start, " UI_K " scale, " PW "x" PH " -> " dir)
    pages := [["home", ""], ["connect", ""], ["stats", ""], ["settings", ""],
              ["modes", "general"], ["modes", "raid"], ["modes", "speed"], ["modes", "inf"], ["modes", "dim"], ["modes", "xdim"]]
    for p in pages {
        curPage := p[1], curTab := p[2], uiShotFile := dir (p[2] != "" ? "modes_" p[2] : p[1]) ".png"
        UiRender(true)
    }
    global shotExtra, popOpen, uiShotNoLinks, statsArm
    uiShotNoLinks := true, curPage := "connect", curTab := "", uiShotFile := dir "connect_empty.png"     ; Connect without links
    UiRender(true)
    uiShotNoLinks := false
    statsArm := A_TickCount, curPage := "stats", uiShotFile := dir "stats_reset_armed.png"              ; Stats after the first click on Reset
    UiRender(true)
    statsArm := 0
    curPage := "modes"                                 ; tab variants: cfg is changed in memory only (no ini writes) and put back
    keep := Map(), flags := ["soloRaid", "dungeon", "xdim", "infGameAuto"]
    for k in flags
        keep[k] := cfg[k]
    for v in [["raid", "raid", "", ""], ["raid", "raid_solo", "soloRaid", ""], ["raid", "raid_pop", "", "pick_raid"], ["inf", "inf", "", ""], ["inf", "inf_locked", "dungeon", ""], ["inf", "inf_auto", "infGameAuto", ""], ["dim", "dim_pop", "", "pick_dim"], ["dim", "dim_locked", "xdim", ""], ["xdim", "xdim_on", "xdim", ""]] {
        for k in flags
            cfg[k] := k = v[3] ? "1" : "0"             ; every variant starts with all four switched off
        curTab := v[1], uiShotFile := dir "modes_" v[2] ".png", popOpen := v[4]
        UiRender(true)
    }
    for k in flags
        cfg[k] := keep[k]
    popOpen := ""
    curPage := "modes", curTab := "general", popOpen := "demo", shotExtra := UiShotDemo   ; widgets demo: Seg, Pick, locked rows and the open Pop
    uiShotFile := dir "modes_pop.png"
    UiRender(true)
    shotExtra := "", popOpen := ""
    global setupBanner, setupBackSkin
    curPage := "home", curTab := "", setupDone := false, uiShotFile := dir "setup_overlay.png"      ; first-run card
    UiRender(true)
    setupDone := true, curPage := "setup", setupRan := true, uiShotFile := dir "setup_page.png"      ; Setup page with ok / warn / fail rows
    setupRes := [{state: "ok", name: "Screen resolution 1920x1080", fix: "", link: ""},
                 {state: "warn", name: "Windows display scale 125%", fix: "The bot is tuned for 100%. Set Display settings > Scale to 100%, then sign out and sign in again: with another scale the bot may not find the buttons.", link: "display"},
                 {state: "fail", name: "The taskbar covers 38 px of the game", fix: "Set Display settings > Scale to 100% (then sign out and sign in again), or turn on 'Automatically hide the taskbar'.", link: "display"},
                 {state: "ok", name: "Bot files (ocr.ps1, img folder)", fix: "", link: ""},
                 {state: "ok", name: "Text recognition (OCR) works", fix: "", link: ""},
                 {state: "ok", name: "Roblox window size is right (1280x720)", fix: "", link: ""},
                 {state: "ok", name: "Keyboard layout in Roblox is English", fix: "", link: ""},
                 {state: "fail", name: "The bot cannot see the game screen", fix: "Stand in the lobby, close game windows (Esc), Check again. Still failing: Scale 100%, hide the taskbar, lowest graphics, Send report.", link: ""}]
    UiRender(true)
    setupBanner := "While running: the bot could not find the PLAY button 3 times in a row", setupBackSkin := "compact"   ; plate + Back
    uiShotFile := dir "setup_banner.png"
    UiRender(true)
    setupBanner := "", setupBackSkin := ""
    curPage := "home", setupOpen := false, setupRan := true, setupRes := [{state: "fail", name: "Roblox window found", fix: ""}, {state: "ok", name: "Screen", fix: ""}, {state: "fail", name: "Taskbar", fix: ""}]
    uiShotFile := dir "badge.png"                        ; Setup badge (2 problems)
    UiRender(true)
    setupRan := false, setupRes := []
    saveC := C                                           ; the light theme (contrast check)
    o := {stars: 0, glow: 1}
    for k, v in THEMES["sakura"].OwnProps()
        o.%k% := v
    C := o
    for p in [["home", ""], ["modes", "general"], ["connect", ""], ["settings", ""]] {
        curPage := p[1], curTab := p[2], uiShotFile := dir "sakura_" p[1] ".png"
        UiRender(true)
    }
    C := saveC
    global updBusy, updView, PW, PH                      ; 14.11: the update loading screen (fake clock, no download)
    updBusy := true
    for st in [["download", 6.4, 2000], ["install", 11.8, 3000], ["restart", 11.8, 1000]] {
        updView := {stage: st[1], mb: st[2], msg: "", t0: 0, at: 1000000, shown: 0, done: false, killed: false, from: "202611140803", to: "202611141200", fake: 1000000 + st[3]}
        uiShotFile := dir "update_" st[1] ".png"
        UiRender(true)
    }
    sw := PW, sh := PH, skin := "compact"                ; the compact window: tall (groups open) and short (all folded)
    for hh in [600, 240] {
        PW := Round(CMP_W * CK()), PH := Round(hh * CK())
        updView.stage := "download", updView.fake := 1002000
        uiShotFile := dir "update_compact_" hh ".png"
        UiRender(true)
    }
    PW := sw, PH := sh, skin := "full", updBusy := false, updView.stage := ""
    UiShotLog("ui: shots done")
}

; "RaidBot.ahk shots anim": animation frames at fixed times (fake clock) -> shots\ui\anim_*.png. Nothing is shown, clicked or saved in the ini
UiShotsAnim() {
    global curPage, curTab, skin, setupDone, setupOpen, uiShotFile, uiStatus, sessMs, animTest, animFake, popOpen
    dir := A_ScriptDir "\shots\ui\"
    DirCreate dir
    skin := "full", setupDone := true, setupOpen := false
    uiStatus := "Waiting for the hourly raid at 12:40, then Speed Raid"
    sessMs := 102 * 60000
    animTest := true
    UiShotLog("ui: shots anim start")
    curPage := "home", curTab := "", animFake := 100000
    UiRender(true)                                       ; base frame: nothing animates yet
    curPage := "stats", animFake := 200000               ; Home -> Stats: sidebar strip slides down, page slides in (22 px)
    UiRender(true)
    for pc in [30, 60, 100] {
        animFake := 200000 + Round(220 * pc / 100), uiShotFile := dir "anim_nav_" pc ".png"
        UiRender(true)
    }
    curPage := "modes", curTab := "general", animFake := 300000
    UiRender(true)
    UiRender(true)
    curTab := "raid", animFake := 400000                 ; tab General -> Raid: underline slides, the tab body is shifted
    UiRender(true)
    animFake := 400000 + 90, uiShotFile := dir "anim_tab_40.png"
    UiRender(true)
    animFake := 400000 + 400
    UiRender(true)
    cfg["raid"] := cfg["raid"] = "1" ? "0" : "1"         ; switch ball half way (memory only, the ini is not written)
    animFake := 500000
    UiRender(true)
    animFake := 500000 + 55, uiShotFile := dir "anim_switch_35.png"
    UiRender(true)
    animFake := 500000 + 400
    UiRender(true)
    popOpen := "pick_raid", animFake := 600000           ; pop-up: 6 px down + shadow
    UiRender(true)
    animFake := 600000 + 45, uiShotFile := dir "anim_pop_30.png"
    UiRender(true)
    UiShotLog("ui: shots anim done")
}

; copy the finished frame onto the window in one BitBlt (no control repaint, so no flicker while the mouse moves)
UiBlit(hdc := 0) {
    own := !hdc
    if own
        hdc := DllCall("GetDC", "ptr", g.Hwnd, "ptr")
    mdc := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", uiBmp, "ptr")
    DllCall("BitBlt", "ptr", hdc, "int", 0, "int", 0, "int", PW, "int", PH, "ptr", mdc, "int", 0, "int", 0, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", old)
    DllCall("DeleteDC", "ptr", mdc)
    if own
        DllCall("ReleaseDC", "ptr", g.Hwnd, "ptr", hdc)
}

UiPaint(wParam, lParam, msg, hwnd) {
    if sumG && hwnd = sumG.Hwnd {                        ; session summary: repaint from its bitmap
        ps := Buffer(72, 0)
        hdc := DllCall("BeginPaint", "ptr", hwnd, "ptr", ps, "ptr")
        SumBlit(hdc)
        DllCall("EndPaint", "ptr", hwnd, "ptr", ps)
        return 0
    }
    if hb && hwnd = hb.Hwnd {                            ; compact hotbar: repaint from its cached bitmap
        ps := Buffer(72, 0)
        hdc := DllCall("BeginPaint", "ptr", hwnd, "ptr", ps, "ptr")
        HotbarBlit(hdc)
        DllCall("EndPaint", "ptr", hwnd, "ptr", ps)
        return 0
    }
    if hwnd != g.Hwnd
        return
    ps := Buffer(72, 0)
    hdc := DllCall("BeginPaint", "ptr", hwnd, "ptr", ps, "ptr")
    if uiBmp
        UiBlit(hdc)
    DllCall("EndPaint", "ptr", hwnd, "ptr", ps)
    return 0
}

; faint blue stars: each one fades in and out over 4-9 s and shows up in a new place every cycle
; (position = hash of star number and cycle number, so nothing is stored)
DrawStars() {
    t := A_TickCount / 1000
    Loop 90 {
        i := A_Index
        ph := t / (4 + Mod(i * 7, 6)) + Mod(i * 0.37, 1)
        cyc := Floor(ph)
        a := Sin((ph - cyc) * 3.14159) ** 2
        if a < 0.06
            continue
        x := Mod(i * 73856093 + cyc * 19349663, 1000003) / 1000003 * GW
        y := Mod(i * 83492791 + cyc * 49979687, 999983) / 999983 * GH
        Dot(x, y, Mod(i, 4) = 0 ? 3 : 2, "8AB4FF", Round(a * 190))
    }
}

OpenSettings(page, *) {
    try Run("ms-settings:" page)
}

; First-run Setup check: a card over the whole window. Until it is passed once, nothing under it can be clicked.
DrawSetup() {
    global hits
    keep := []
    for h in hits                                         ; HUD 2.0: only minimise and close stay usable (START and the menu are under the card); an empty part of the header still drags
        if h.id = "min" || h.id = "close"
            keep.Push(h)
    hits := keep
    FillRR(0, 62, GW, GH - 62, 2, C.bg, 235)
    FillRR(794, 11, 120, 40, 12, C.bg, 170)               ; START in the header looks inactive under the card
    x := 90, y := 74, w := 820, h := 552
    FillRR(x, y, w, h, 20, C.bg, 255)                     ; opaque base, so nothing shows through the glass
    Glass(x, y, w, h, 20)
    Tx(setupDone ? "Setup check" : "Welcome - check your setup first", "head", 22, 1, C.text, x + 28, y + 20, w - 56, 32)
    if setupBanner != "" {
        FillRR(x + 28, y + 50, w - 56, 38, 10, "F5B942", 45)
        Tx(Chr(0xE7BA), "icon", 14, 0, "F5B942", x + 38, y + 58, 22, 22, 1)
        Tx(setupBanner, "ui", 12, 1, "F5B942", x + 66, y + 59, w - 110, 22)
    } else
        Tx("Press Check. The bot tests what it can on this PC and tells you how to fix the rest.", "ui", 13, 0, C.dim, x + 28, y + 56, w - 56, 20)
    Caption("Automatic checks", x + 28, y + 96)
    Caption("Set these in the game yourself", x + 490, y + 96, 300)
    ry := y + 122
    if !setupRan
        Tx("Not checked yet.", "ui", 13, 0, C.idle, x + 28, ry, 400, 24)
    for it in setupRes {
        col := it.state = "ok" ? "3DD68C" : it.state = "warn" ? "F5B942" : "F2555A"
        Dot(x + 28, ry + 2, 24, col)
        Tx(Chr(it.state = "ok" ? 0xE73E : it.state = "warn" ? 0xE7BA : 0xE711), "icon", 13, 0, "FFFFFF", x + 28, ry + 2, 24, 24, 1)
        nameY := ry
        Tx(it.name, "ui", 14, 1, C.text, x + 64, ry, 320, 22)
        fh := it.fix != "" ? Ceil(StrLen(it.fix) / 68) * 14 : 0         ; 8.11: rows are compact, the list has up to 9 lines
        if it.fix != ""
            TxP(it.fix, "ui", 11, C.dim, x + 64, ry + 22, 410, fh)
        ry += it.fix != "" ? 28 + fh : 32
        if it.HasProp("link") && it.link != "" && it.state != "ok" {      ; opens the right Windows settings page; the bot changes nothing itself
            Btn(x + 384, nameY - 2, 90, 24, "Settings", "setup_link_" it.link, OpenSettings.Bind(it.link), false, Chr(0xE713))
        }
    }
    tips := SetupTips()
    ty := y + 122
    for t in tips {
        Dot(x + 490, ty + 6, 8, C.hi)
        TxP(t, "ui", 12, C.text, x + 510, ty, 280, 64)
        ty += 70
    }
    TxP("Do not use the PC while the bot runs.", "ui", 11, C.dim, x + 490, ty, 300, 32)
    ; bottom bar
    by := y + h - 68
    Btn(x + 28, by, 200, 44, setupRan ? "Check again" : "Check now", "setup_check", SetupRun, !setupRan, Chr(0xE9D9))
    fails := SetupFails()
    ok := setupDone || setupRan && !fails
    msg := !setupRan ? "Press Check to continue." : fails ? fails " problem" (fails > 1 ? "s" : "") " - the bot will not work until they are fixed. Then Check again." : "All good."
    TxP(msg, "ui", 13, setupRan && !fails ? "3DD68C" : C.dim, x + 250, by + 4, 330, 40)
    if ok
        Btn(x + w - 228, by, 200, 44, setupDone ? "Close" : "Continue", "setup_go", SetupClose, setupRan)
    else {
        FillRR(x + w - 228, by, 200, 44, 14, C.field, 120)
        Tx("Continue", "ui", 14, 1, C.idle, x + w - 228, by, 200, 44, 1, 150)
    }
}

; game advice, shown on the Setup page and on the first-run card
SetupTips() => ["Graphics quality: set it to the lowest (Esc > Settings in Roblox).",
                "Turn off visual effects and extra animations in the game settings: they hide the colours the bot reads.",
                "Keep Roblox in a window on your main monitor (not F11). Do not resize it: the bot sets the size.",
                "Loadouts: 1 for raids, 2 for Infinity or Dimension, 3 for Speed Raid - or turn Loadouts off in Modes."]

; Setup page (HUD 2.0): Check now + the result rows on the left, the in-game advice on the right.
; A yellow plate on top says what went wrong while the bot ran (ProblemShow); Back returns to the compact window.
PageSetup() {
    oy := 0
    if setupBanner != "" {
        FillRR(CX, CY, CWD, 30, 10, "F5B942", 45)
        Tx(Chr(0xE7BA), "icon", 14, 0, "F5B942", CX + 10, CY + 4, 22, 22, 1)
        Tx(setupBanner, "ui", 12, 1, "F5B942", CX + 40, CY + 4, CWD - 56, 22)
        oy := 38
    }
    y0 := CY + oy
    Btn(CX, y0, 190, 36, setupRan ? "Check again" : "Check now", "setup_check", SetupRun, !setupRan, Chr(0xE9D9))
    nFail := SetupFails()
    msg := !setupRan ? "Press Check now: the bot tests this PC and tells you how to fix the rest." : nFail ? nFail " problem" (nFail > 1 ? "s" : "") " - the bot will not work until they are fixed. Then Check again." : "All good."
    TxP(msg, "ui", 12, setupRan && !nFail ? "3DD68C" : C.dim, CX + 206, y0 + 2, setupBackSkin != "" ? CWD - 206 - 166 : CWD - 206, 34)
    if setupBackSkin != ""
        Btn(CX + CWD - 150, y0, 150, 36, "Back", "setup_back", SetupClose)
    y1 := y0 + 46, ph := CY + CHT - y1, lw := 470
    ; --- checks ---
    Glass(CX, y1, lw, ph)
    Caption("Automatic checks", CX + 20, y1 + 14)
    ry := y1 + 40, lim := y1 + ph - 10
    if !setupRan
        Tx("Not checked yet.", "ui", 13, 0, C.idle, CX + 20, ry, 400, 24)
    shown := [], nOk := 0                                            ; problems first (fail, then warn); passed checks fold into one line
    for st in ["fail", "warn"]
        for it in setupRes
            if it.state = st
                shown.Push(it)
    for it in setupRes
        if it.state = "ok"
            nOk++
        else if it.state != "fail" && it.state != "warn"
            shown.Push(it)
    for it in shown {
        fh := it.fix != "" ? Ceil(StrLen(it.fix) / 70) * 14 : 0
        if ry + (fh ? 24 + fh : 24) > lim - (nOk ? 27 : 0) {         ; out of room: the rest stays in the log
            Tx("...", "ui", 13, 1, C.dim, CX + 52, ry, 100, 20)
            break
        }
        col := it.state = "ok" ? "3DD68C" : it.state = "warn" ? "F5B942" : "F2555A"
        Dot(CX + 20, ry, 22, col)
        Tx(Chr(it.state = "ok" ? 0xE73E : it.state = "warn" ? 0xE7BA : 0xE711), "icon", 12, 0, "FFFFFF", CX + 20, ry, 22, 22, 1)
        link := it.HasProp("link") && it.link != "" && it.state != "ok"
        Tx(it.name, "ui", 13, 1, C.text, CX + 52, ry, link ? lw - 52 - 120 : lw - 72, 22)
        if link                                                      ; opens the right Windows settings page; the bot changes nothing itself
            Btn(CX + lw - 20 - 90, ry - 2, 90, 24, "Settings", "setup_link_" it.link, OpenSettings.Bind(it.link), false, Chr(0xE713))
        if it.fix != ""
            TxP(it.fix, "ui", 11, C.dim, CX + 52, ry + 24, lw - 72, fh)
        ry += fh ? 28 + fh : 27
    }
    if nOk {
        Dot(CX + 20, ry, 22, "3DD68C")
        Tx(Chr(0xE73E), "icon", 12, 0, "FFFFFF", CX + 20, ry, 22, 22, 1)
        Tx(nOk " check" (nOk > 1 ? "s" : "") " ok", "ui", 13, 1, C.text, CX + 52, ry, lw - 72, 22)
    }
    ; --- advice ---
    rx := CX + lw + 14, rw := CWD - lw - 14
    Glass(rx, y1, rw, ph)
    Caption("Set these in the game yourself", rx + 20, y1 + 14, rw - 40)
    ty := y1 + 40
    for t in SetupTips() {
        Dot(rx + 20, ty + 6, 8, C.hi)
        th := Ceil(StrLen(t) / 36) * 16
        TxP(t, "ui", 12, C.text, rx + 38, ty, rw - 58, th)
        ty += th + 10
    }
    TxP("Do not use the PC while the bot runs.", "ui", 11, C.dim, rx + 20, ty + 2, rw - 40, 32)
}

; ------------------------------ pages ------------------------------
PageHome() {
    tw := (CWD - 3 * 12) // 4, th := 70
    for i, t in [["NEXT RAID", dRaid], ["NEXT SPEED RAID", dSpeed], ["GOAL NOW", dGoal], ["THIS HOUR'S RAID", dDone]]
        Tile2(CX + (i - 1) * (tw + 12), CY, tw, th, t[1], t[2], t[2] = "done")
    for i, t in [["RAIDS", String(sess["raids"])], ["INFINITY RUNS", String(sess["infRuns"])], ["GEMS", String(SessSum(GEM_KEYS))],
                 ["TOKENS", SessSum(TOKEN_KEYS) (runTokens && (runKind = "raid" || runKind = "speed") ? "  +" runTokens : "")]]
        Tile2(CX + (i - 1) * (tw + 12), CY + th + 10, tw, th, t[1], t[2], false)
    sy := CY + 2 * th + 10                                ; the status line is gone from Home: the header chip shows it
    Tx(StrUpper("Plan  -  Raid, then Speed Raid, then one farm mode  -  loadout " (curLoadout ? curLoadout : "?") "  -  " RaidTitle()), "head", 12, 1, C.hi, CX + 4, sy + 6, CWD - 8, 20)
    py := sy + 30, rh := 42
    Glass(CX, py, CWD, 5 * rh + 8)
    dimOn := cfg["dungeon"] = "1", xOn := cfg["xdim"] = "1", infLk := dimOn || xOn
    l := FrzGet("xcyc", XdimCycle)
    rows := [["1", "Raid", RaidTitle() "  -  " (cfg["raidCreate"] = "1" ? "own room" : "Group Finder"), "raid", "m_raid", false],
             ["2", "Speed Raid", "every 30 min  -  loadout 3", "speed", "m_speed", false],
             ["3", "Infinity", infLk ? "off while Dimension is on" : "leave at " Format("{:02}:{:02}", MinSec(cfg["infStop"], 57 * 60 + 30) // 60, Mod(MinSec(cfg["infStop"], 57 * 60 + 30), 60)), "infinity", "m_inf", infLk],
             ["4", "Dimension", xOn ? "off while Extreme is on" : DimShort(DimKindUi()) "  -  slot " (InStr("2345", cfg["dimMethod"]) ? cfg["dimMethod"] : "1"), "dungeon", "m_dim", xOn],
             ["5", "Extreme Dimension", "today " XdimName(l[FrzGet("xpos0", XdimPos)]), "xdim", "m_xdim", false]]
    for i, r in rows
        PlanRow2(CX, py + 4 + (i - 1) * rh, CWD, rh, r[1], r[2], r[3], r[4], r[5], r[6])
}

; stat tile: small caption + big value (HUD 2.0 Home)
Tile2(x, y, w, h, cap, val, good := false, role := "head", px := 22) {
    Glass(x, y, w, h)
    vp := 28
    while vp > 18 && TxW(val, role, vp, 1) > w - 36
        vp -= 2                                          ; a long word shrinks instead of "..."
    Tx(val, role, vp, 1, good ? "3DD68C" : C.text, x + 18, y + 6, w - 36, 38)
    Tx(StrUpper(cap), "ui", 11, 0, C.dim, x + 18, y + 44, w - 36, 18)
}

; Plan row: number, name, caption, switch. Click on the row opens its Modes tab; click on the switch flips the mode. lk = greyed out, shows no state, writes nothing
PlanRow2(x, y, w, h, no, name, sub, key, page, lk) {
    on := cfg[key] = "1" && !lk
    id := "pl_" key
    Hit(x, y, w, h, id, SetPage.Bind(page))
    if IsHot(id)
        FillRR(x + 4, y + 2, w - 8, h - 4, 12, C.ov, 12)
    a := lk ? 120 : 255
    FillRR(x + 16, y + 9, 24, 24, 7, on ? C.on : C.field, lk ? 120 : 255)
    Tx(no, "head", 13, 1, on ? "FFFFFF" : C.dim, x + 16, y + 9, 24, 24, 1, a)
    nw := TxW(name, "ui", 15, 1) + 4
    Tx(name, "ui", 15, 1, lk ? C.idle : C.text, x + 54, y, nw + 8, h, 0, a)
    Tx(sub, "ui", 12, 0, C.dim, x + 54 + nw + 12, y, Max(40, w - 54 - nw - 12 - 90), h, 0, lk ? 120 : 255)
    if lk {
        FillRR(x + w - 66, y + 8, 46, 26, 13, C.off, 120)
        Dot(x + w - 63, y + 11, 20, "C4CADB", 90)
        return
    }
    if on {                                              ; HUD 2.0 Home: soft glow, grey knob when off
        Glow(x + w - 43, y + 21, 34, 20, C.acc, 70)
        GradRR(x + w - 66, y + 8, 46, 26, 13, C.acc, 255, C.acc2, 255)
    } else
        FillRR(x + w - 66, y + 8, 46, 26, 13, C.field)
    Dot(on ? x + w - 43 : x + w - 63, y + 11, 20, on ? "FFFFFF" : "6B6678")
    Hit(x + w - 76, y + 2, 62, h - 4, "pt_" key, FlipKey.Bind(key))
}

; ---- helpers for the settings pages ----
StepCfg(key, d, lo, hi, def) {
    v := Min(hi, Max(lo, Num(key, def) + d))
    cfg[key] := String(v)
    IniWrite v, INI, "raid", key
    Log("setting " key " = " v " (applies at once)")
}

; ------------------------------ sounds: button clicks ------------------------------
; click sounds: sfx\click.wav, on.wav, off.wav (SoundPlay, asynchronous)
Sfx(name) {
    static warned := Map()
    if cfg["sfx"] != "1"
        return
    if FileExist(f := A_ScriptDir "\sfx\" name ".wav") {
        try SoundPlay(f)
    } else if !warned.Has(name) {                        ; silence, and one line in the log file
        warned[name] := 1
        try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  sfx: missing " name ".wav`n", LOGFILE, "UTF-8"
    }
}

; setting stored as "MM:SS"
StepTime(key, d, lo, hi, def) {
    sec := Min(hi, Max(lo, MinSec(cfg[key], def) + d))
    cfg[key] := Format("{}:{:02}", sec // 60, Mod(sec, 60))
    IniWrite cfg[key], INI, "raid", key
    Log("setting " key " = " cfg[key] " (applies at once)")
}

; a key in a space separated list setting (spread = "5 4 e r x")
ToggleList(key, k) {
    list := ""
    found := false
    for s in StrSplit(Trim(cfg[key]), " ") {
        if s = ""
            continue
        if s = k
            found := true
        else
            list .= (list = "" ? "" : " ") s
    }
    if !found
        list .= (list = "" ? "" : " ") k
    cfg[key] := list
    IniWrite list, INI, "raid", key
    Log("setting " key " = " list " (applies at once)")
}

; ------------------------------ Modes tabs Raid / Speed Raid / Infinity (HUD 2.0 steps 7-9): two columns of rows ------------------------------
; click on a greyed-out row: nothing changes, one line goes to the log file (not to the log panel)
LockClick(key, why, *) {
    try FileAppend FormatTime(, "dd.MM HH:mm:ss") "." Format("{:03}", A_MSec) "  ui: locked click " key " (" why ")`n", LOGFILE, "UTF-8"
}

; Seg item 1 = Group Finder, 2 = Create room (raidCreate)
PickRaidEntry(i, *) {
    v := i = 2 ? "1" : "0"
    if cfg["raidCreate"] = v
        return
    cfg["raidCreate"] := v
    IniWrite v, INI, "raid", "raidCreate"
    Log("setting raidCreate = " v " (applies at once)")
}

PageRaid2() {
    cw := (CWD - 24) // 2, lx := CX, rx := CX + cw + 24, y0 := CY + 42
    solo := cfg["soloRaid"] = "1"
    SRow(lx, y0, cw, "Enabled", "Runs first in the plan", 46)
    Sw2(lx, y0, cw, cfg["raid"] = "1", "sw_raid", FlipKey.Bind("raid"))
    rk := RAIDS.Has(cfg["raidName"]) ? cfg["raidName"] : "divine"
    rt := RaidShort(rk)
    SRow(lx, y0 + RH2, cw, "Raid", "Found in Group Finder by name", PickW(rt))
    a := Pick(lx, y0 + RH2, cw, rt, "pick_raid", PickRaid)
    items := []
    for k in StrSplit(Trim(RAIDS_READY), " ")
        if k != "" && RAIDS.Has(k)
            items.Push([k, RaidShort(k)])
    Pop("pick_raid", a, 340, items, rk, PickRaid, 3)
    segItems := ["Group Finder", "Create room"]
    SRow(lx, y0 + RH2 * 2, cw, "Entry", "How the bot gets in", SegW(segItems))
    Seg(lx, y0 + RH2 * 2, cw, segItems, cfg["raidCreate"] = "1" ? 2 : 1, "seg_raidEntry", PickRaidEntry)
    SRow(lx, y0 + RH2 * 3, cw, "Solo (Friends Only)", "No queue, no waiting for people", 46)
    Sw2(lx, y0 + RH2 * 3, cw, solo, "sw_soloRaid", FlipKey.Bind("soloRaid"))
    why := "off while Solo"
    SRow(rx, y0, cw, "PARTY wait before Start", "Seconds", 150, solo ? why : "")
    Stp2(rx, y0, cw, StpFmt(Num("startDelay", 10), "s"), StepCfg.Bind("startDelay", -1, 0, 30, 10), StepCfg.Bind("startDelay", 1, 0, 30, 10), "startDelay", solo)
    SRow(rx, y0 + RH2, cw, "Early start at bonus", "Party bonus that starts it", 150, solo ? why : "")
    Stp2(rx, y0 + RH2, cw, StpFmt(Num("startBonus", 110), "%"), StepCfg.Bind("startBonus", -10, 0, 300, 110), StepCfg.Bind("startBonus", 10, 0, 300, 110), "startBonus", solo)
    if solo {
        Hit(rx, y0, cw, RH2 - 1, "lk_startDelay", LockClick.Bind("startDelay", "solo on"))
        Hit(rx, y0 + RH2, cw, RH2 - 1, "lk_startBonus", LockClick.Bind("startBonus", "solo on"))
    }
    rm := Min(55, Max(0, Num("raidMin", 0)))           ; 12.11: half-hour time zones - the raid starts at xx:30 there
    SRow(rx, y0 + RH2 * 2, cw, "Raid starts at", "Minute of the hour, xx:00 by default", 140)
    Stp2(rx, y0 + RH2 * 2, cw, Format("xx:{:02}", rm), StepCfg.Bind("raidMin", -5, 0, 55, 0), StepCfg.Bind("raidMin", 5, 0, 55, 0), "raidMin")
    TxP("The fight is played by the game's Auto button. The bot keeps it on.", "ui", 12, C.dim, rx + 2, y0 + RH2 * 3 + 10, cw - 4, 40)
}

PageSpeed2() {
    cw := (CWD - 24) // 2, lx := CX, rx := CX + cw + 24, y0 := CY + 42
    SRow(lx, y0, cw, "Enabled", "Second in the plan", 46)
    Sw2(lx, y0, cw, cfg["speed"] = "1", "sw_speed", FlipKey.Bind("speed"))
    SRow(lx, y0 + RH2, cw, "Switch loadout", "Same switch as General > Loadouts: Speed Raid uses loadout 3", 46)
    Sw2(lx, y0 + RH2, cw, cfg["loadouts"] = "1", "sw_loadouts_speed", FlipKey.Bind("loadouts"))
    TxP("Every 30 minutes the bot opens the modes menu, picks Speed Raid and the lowest character that has not been used this week (used characters are dimmed).`n`nThere is no combo: the bot opens with E R X Z and then presses 5 4 3 2 1 as they come off cooldown.`n`nSpeed Raid has priority over Infinity but not over the hourly raid. It is not started in the last 8 minutes of the hour.`n`nIt resets once a week and used characters become free again. The author recommends weekends, when the rewards are x2. When all characters are used, the bot waits for the weekly reset.", "ui", 12, C.dim, rx + 2, y0 + 8, cw - 4, 280)
}

; Infinity: "Auto if enemies stuck" is a switch + a stepper; the switch remembers the last non-zero value in [ui] infAutoLast
InfAutoLast() {
    try {
        v := Integer(IniRead(INI, "ui", "infAutoLast", "15000"))
        return v > 0 ? v : 15000
    } catch
        return 15000
}

InfAutoSet(v) {
    cfg["infAuto"] := String(v)
    IniWrite v, INI, "raid", "infAuto"
    if v > 0
        IniWrite v, INI, "ui", "infAutoLast"
    Log("setting infAuto = " v " (applies at once)")
}

InfAutoStep(d, *) => InfAutoSet(Min(60000, Max(0, Num("infAuto", 15000) + d)))

InfAutoFlip(*) => InfAutoSet(Num("infAuto", 15000) > 0 ? 0 : InfAutoLast())

StepSpread(d, *) => StepCfg("spreadMs", d, 1000, 20000, 7000)

PageInfinity2() {
    cw := (CWD - 24) // 2, lx := CX, rx := CX + cw + 24, y0 := CY + 42
    ga := cfg["infGameAuto"] = "1"                        ; the game's Auto fights: the AOE settings are greyed out
    lkInf := cfg["dungeon"] = "1" || cfg["xdim"] = "1"    ; Dimension / Extreme replace Infinity (nothing is written to the ini)
    SRow(lx, y0, cw, "Enabled", "Third in the plan", 46, lkInf ? "Off while Dimension or Extreme is on" : "")
    Sw2(lx, y0, cw, cfg["infinity"] = "1", "sw_infinity", FlipKey.Bind("infinity"), lkInf)
    SRow(lx, y0 + RH2, cw, "Game Auto", "The game's Auto fights, the bot keeps it on", 46)
    Sw2(lx, y0 + RH2, cw, ga, "sw_infGameAuto", FlipKey.Bind("infGameAuto"))
    SRow(lx, y0 + RH2 * 2, cw, "Leave Infinity after", "Then enters again; 0 = off", 150)
    Stp2(lx, y0 + RH2 * 2, cw, StpFmt(Num("infRunMin", 0), "min"), StepCfg.Bind("infRunMin", -1, 0, 59, 0), StepCfg.Bind("infRunMin", 1, 0, 59, 0), "infRunMin")
    why := "Off while Game Auto is on"
    sp := Num("spreadMs", 7000)
    SRow(rx, y0, cw, "Pause between AOE", "The author recommends 7 s", 150, ga ? why : "")
    Stp2(rx, y0, cw, Format("{:g} s", sp / 1000), StepSpread.Bind(-500), StepSpread.Bind(500), "spreadMs", ga)
    ia := Num("infAuto", 15000)
    SRow(rx, y0 + RH2, cw, "Auto if stuck", "Presses AUTO when the enemy count stands still", 210, ga ? why : "")
    Stp2(rx, y0 + RH2, cw - 60, ia = 0 ? "off" : Format("{:g} s", ia / 1000), InfAutoStep.Bind(-5000), InfAutoStep.Bind(5000), "infAuto", ga || ia = 0)
    Sw2(rx, y0 + RH2, cw, ia > 0, "sw_infAuto", InfAutoFlip, ga)
    y1 := y0 + RH2 * 3
    Tx("Big AOE skills", "ui", 14, 1, ga ? C.idle : C.text, lx, y1 + 7, CWD, 20, 0, ga ? 150 : 255)
    TxP(ga ? why : "Blue skills are the big area attacks. The bot presses them one at a time with a pause, so their effects do not overlap. All other skills are pressed as soon as they are ready.", "ui", 11, ga ? C.idle : C.dim, lx, y1 + 28, CWD, 30, ga ? 200 : 255)
    nk := SKILL_KEYS.Length
    cwc := (CWD - (nk - 1) * 8) // nk
    for i, k in SKILL_KEYS
        if !ga                                             ; skillsOff is ignored here: a skill switched off earlier must not stay greyed out for ever
            Chip(CX + (i - 1) * (cwc + 8), y1 + 66, cwc, 32, StrUpper(k), InStr(" " cfg["spread"] " ", " " k " "), "sp_" k, ToggleList.Bind("spread", k))
        else
            ChipOff(CX + (i - 1) * (cwc + 8), y1 + 66, cwc, 32, StrUpper(k))
}

; ------------------------------ Modes tabs Dimension / Extreme (HUD 2.0 steps 10-11) ------------------------------
PickDimMethodI(i, *) => PickDimMethod(String(i))
PickXdimI(i, *) => PickXdim(String(i))

PageDimension2() {
    cw := (CWD - 24) // 2, lx := CX, rx := CX + cw + 24, y0 := CY + 42
    lk := cfg["xdim"] = "1"                                   ; Extreme on: the plain Dimension is greyed out (nothing is written to the ini)
    why := "Off while Extreme is on"
    dk := DimKindUi()
    SRow(lx, y0, cw, "Enabled", "Replaces Infinity", 46, lk ? why : "")
    Sw2(lx, y0, cw, cfg["dungeon"] = "1", "sw_dungeon", FlipKey.Bind("dungeon"), lk)
    if lk
        Hit(lx, y0, cw, RH2 - 1, "lk_dungeon", LockClick.Bind("dungeon", "extreme on"))
    dt := DimShort(dk)
    SRow(lx, y0 + RH2, cw, "Dimension", "Giant has a built-in run, others use your recording", PickW(dt), lk ? why : "")
    a := Pick(lx, y0 + RH2, cw, dt, "pick_dim", PickDimName, lk)
    items := []
    for k in DIM_ORDER
        items.Push([k, DimShort(k)])
    if !lk
        Pop("pick_dim", a, 400, items, dk, PickDimName, 4)
    segItems := ["1", "2", "3", "4", "5"]
    sl := IsInteger(cfg["dimMethod"]) && cfg["dimMethod"] >= 1 && cfg["dimMethod"] <= 5 ? Integer(cfg["dimMethod"]) : 1
    SRow(lx, y0 + RH2 * 2, cw, "Slot", "Which saved run is played; each slot keeps its own", SegW(segItems), lk ? why : "")
    Seg(lx, y0 + RH2 * 2, cw, segItems, sl, "seg_dimSlot", PickDimMethodI, lk)
    SRow(lx, y0 + RH2 * 3, cw, "Start delay", "Wait this long before the run", 150, lk ? why : "")
    Stp2(lx, y0 + RH2 * 3, cw, Format("{:g} s", Round(Num("dimShift", 0) / 1000, 1)), StepCfg.Bind("dimShift", -100, 0, 5000, 0), StepCfg.Bind("dimShift", 100, 0, 5000, 0), "dimShift", lk)
    SRow(lx, y0 + RH2 * 4, cw, "Keep fighting", "Finishes the enemies that are left after the run", 46, lk ? why : "")
    Sw2(lx, y0 + RH2 * 4, cw, cfg["dimFight"] = "1", "sw_dimFight", FlipKey.Bind("dimFight"), lk)
    rk := lk || dk = "giant"                                  ; Giant waits for the giants on screen, not a timer
    SRow(lx, y0 + RH2 * 5, cw, "Wait after REPLAY", "Seconds before the run starts again", 150, lk ? why : dk = "giant" ? "Not used by Giant" : "")
    Stp2(lx, y0 + RH2 * 5, cw, StpFmt(Num("dimReplayWait", 15), "s"), StepCfg.Bind("dimReplayWait", -1, 1, 60, 15), StepCfg.Bind("dimReplayWait", 1, 1, 60, 15), "dimReplayWait", rk)
    rt := FrzGet("route" dk cfg["dimMethod"], DimRoute.Bind(dk))
    rec := rt.Length ? rt.Length " steps · " Round(rt[rt.Length][1] / 1000, 1) " s" : "No recording"
    SRow(rx, y0, cw, "Recording", rec, 196, , lk)
    by := y0 + (RH2 - 34) // 2
    Btn(rx + cw - 196, by, 96, 34, "Recorder", "dim_edit", DimEdit, true, "", lk)
    Btn(rx + cw - 94, by, 94, 34, "Folder", "dim_dir", (*) => OpenPath(DimDir(DimKindUi())), false, "", lk)
    ; the character of the run (compact): picture, name, fruit
    cy2 := y0 + RH2 + 8, ix := rx + 14
    Glass(rx, cy2, cw, 228)
    Tx("CHARACTER", "ui", 11, 1, C.dim, ix, cy2 + 10, 200, 16)
    iy := cy2 + 32
    ic := IMGDIR DIM_CHAR.icon
    if FileExist(ic)
        DrawPng(ic, ix, iy, 64, 64)
    else {
        FillRR(ix, iy, 64, 64, 12, C.field)
        Tx("?", "head", 24, 1, C.dim, ix, iy, 64, 64, 1)
    }
    Tx(DIM_CHAR.name != "" ? DIM_CHAR.name : "Not filled in yet", "head", 15, 1, C.text, ix + 78, iy, cw - 106, 24)
    TxP(DIM_CHAR.text != "" ? DIM_CHAR.text : "Which character, skills and loadout the run was recorded with.", "ui", 11, C.dim, ix + 78, iy + 28, cw - 106, 36)
    TxP(DIM_CHAR.more, "ui", 11, C.text, ix, iy + 74, cw - 28, 52)
    fy := iy + 132
    fi := IMGDIR DIM_CHAR.fruitIcon
    if FileExist(fi)
        DrawPng(fi, ix, fy, 48, 48)
    Tx(DIM_CHAR.fruitName, "head", 13, 1, C.text, ix + 62, fy, cw - 90, 20)
    TxP(DIM_CHAR.fruitText, "ui", 11, C.dim, ix + 62, fy + 22, cw - 90, 44)
}

DimKindUi() => DIMS.Has(cfg["dimName"]) ? cfg["dimName"] : "giant"
DimShort(k) => StrReplace(DIMS[k][1], " Dimension")

PageXdim2() {
    cw := (CWD - 24) // 2, lx := CX, rx := CX + cw + 24, y0 := CY + 42
    lk := cfg["xdim"] != "1"                                  ; Extreme off: its settings are greyed out
    why := "Turn Extreme on first"
    SRow(lx, y0, cw, "Enabled", "Replaces Dimension, enters from the lobby", 46)
    Sw2(lx, y0, cw, cfg["xdim"] = "1", "sw_xdim", FlipKey.Bind("xdim"))
    segItems := ["Easy", "Normal", "Nightmare", "Extreme"]
    SRow(lx, y0 + RH2, CWD, "Difficulty", lk ? why : "Which Extreme card the bot picks", SegW(segItems))
    Seg(lx, y0 + RH2, CWD, segItems, IsInteger(cfg["xdimPick"]) ? Min(4, Max(1, Integer(cfg["xdimPick"]))) : 1, "seg_xdim", PickXdimI, lk)
    SRow(lx, y0 + RH2 * 2, cw, "Wait after Start", "Seconds for the map to load", 150, lk ? why : "")
    Stp2(lx, y0 + RH2 * 2, cw, StpFmt(Num("xdimWait", 15), "s"), StepCfg.Bind("xdimWait", -1, 5, 60, 15), StepCfg.Bind("xdimWait", 1, 5, 60, 15), "xdimWait", lk)
    TxP("Each map keeps its own run (dimension\extreme_<map>). Record it while that map is played.", "ui", 11, C.dim, lx + 2, y0 + RH2 * 3 + 8, cw - 4, 40)
    l := FrzGet("xcyc", XdimCycle), mp := FrzGet("xpos0", XdimPos), id := l[mp]
    SRow(rx, y0, cw, "Today's map", "Day " mp " of " l.Length ". Move it if the bot counts wrong", 140, lk ? why : "")
    Stp2(rx, y0, cw, XdimName(id), XdimShift.Bind(-1), XdimShift.Bind(1), "xdmap", lk)
    has := FileExist(DimDir("xdim", true) "log.txt") ? "recorded" : "not recorded yet"
    SRow(rx, y0 + RH2 * 2, cw, "Recording", XdimName(id) ": " has ". Next: " XdimName(FrzGet("xmap1", XdimMap.Bind(1))) ", " XdimName(FrzGet("xmap2", XdimMap.Bind(2))) ", " XdimName(FrzGet("xmap3", XdimMap.Bind(3))), 196, , lk)
    by := y0 + RH2 * 2 + (RH2 - 34) // 2
    Btn(rx + cw - 196, by, 96, 34, "Recorder", "xd_edit", DimEditK.Bind("xdim"), true, "", lk)
    Btn(rx + cw - 94, by, 94, 34, "Folder", "xd_dir", (*) => OpenPath(A_ScriptDir "\dimension"), false, "", lk)
    if FileExist(A_ScriptDir "\dimension\extreme\log.txt")
        TxP("Your old run is in dimension\extreme: copy it into extreme_" id " if it is this map.", "ui", 11, C.dim, rx + 2, y0 + RH2 * 3 + 8, cw - 4, 40)
}

; < > on the Extreme page: today's map is one place back / forward in the list (the anchor moves to today)
XdimShift(d, *) {
    global xdimMapNow
    p := XdimPos(d)
    if xdimMapNow != ""                                   ; a run is on: its RETRY replays switch to the fixed map too
        xdimMapNow := XdimCycle()[p]
    IniWrite p, INI, "raid", "xdimAnchorPos"
    IniWrite XdimGameDay(), INI, "raid", "xdimAnchorDay"
    Log("setting Extreme today's map = " XdimName(XdimCycle()[p]) " (" p "/" XdimCycle().Length ")")
    UiRender(true)
}

; PNG from a file, scaled into (x, y, w, h); loaded once
DrawPng(file, x, y, w, h) {
    static cache := Map()
    if !cache.Has(file) {
        DllCall("gdiplus\GdipCreateBitmapFromFile", "wstr", file, "ptr*", &bmp := 0)
        cache[file] := bmp
    }
    if cache[file]
        DllCall("gdiplus\GdipDrawImageRectI", "ptr", gr, "ptr", cache[file], "int", x, "int", y, "int", w, "int", h)
}

DimEdit(*) => DimEditK(DimKindUi())
DimEditK(k, *) {
    DirCreate DimDir(k, true)                              ; Extreme: today's map, not the one of the last run
    try Run '"' A_AhkPath '" "' A_ScriptDir '\tools\Recorder2.ahk" "' RTrim(DimDir(k, true), "\") '"'   ; no trailing \ before the quote (\" would escape it)
    catch as e
        Log("Recorder did not start: " e.Message)
}

; Stats page (HUD 2.0): 4 tiles "today", Rewards table, All time table, Reset. Ini numbers are read at most once per 5 s
PageStats() {
    global statCache, statCacheT
    if A_TickCount - statCacheT > 5000 || !statCache.Count {
        statCacheT := A_TickCount
        sc := Map()
        for k in ["raids", "speedRuns", "infRuns", "dimRuns"]
            sc["d_" k] := StatDay(k)
        for k in ["raidsTotal", "speedRunsTotal", "infRunsTotal", "dimRunsTotal", "restartsTotal"]
            sc[k] := IniRead(INI, "stats", k, "0")
        sc["gemsDay"] := DaySum(GEM_KEYS), sc["gemsAll"] := TotalSum(GEM_KEYS)
        sc["tokDay"] := DaySum(TOKEN_KEYS), sc["tokAll"] := TotalSum(TOKEN_KEYS)
        statCache := sc
    }
    sc := statCache
    ; tiles
    tw := (CWD - 36) // 4
    for i, t in [["raids", "Raids today"], ["speedRuns", "Speed Raids today"], ["infRuns", "Infinity today"], ["dimRuns", "Dimension today"]] {
        x := CX + (i - 1) * (tw + 12)
        Glass(x, CY, tw, 84)
        Tx(StatNum(sc["d_" t[1]]), "mono", 28, 1, C.text, x + 16, CY + 8, tw - 32, 40)
        Tx(t[2], "ui", 12, 0, C.dim, x + 16, CY + 52, tw - 32, 20)
    }
    ; Rewards: this run / today / total (gems and tokens of all modes together)
    ty := CY + 96, c0 := 180, cw := (CWD - 40 - c0) // 3
    Glass(CX, ty, CWD, 114)
    Tx("REWARDS", "ui", 11, 1, C.dim, CX + 20, ty + 12, c0, 18)
    for j, h in ["THIS RUN", "TODAY", "TOTAL"]
        Tx(h, "ui", 11, 1, C.dim, CX + 20 + c0 + (j - 1) * cw, ty + 12, cw - 12, 18, 2)
    FillRR(CX + 20, ty + 34, CWD - 40, 1, 1, C.ov, 26)
    cur := runTokens && (runKind = "raid" || runKind = "speed") ? "  +" runTokens : ""
    rows := [["Gems", StatNum(SessSum(GEM_KEYS)), sc["gemsDay"], sc["gemsAll"]],
             ["Tokens", StatNum(SessSum(TOKEN_KEYS)) cur, sc["tokDay"], sc["tokAll"]]]
    for i, r in rows {
        ry := ty + 40 + (i - 1) * 32
        Tx(r[1], "ui", 14, 1, C.text, CX + 20, ry, c0, 30)
        Tx(r[2], "mono", 15, 1, C.hi, CX + 20 + c0, ry, cw - 12, 30, 2)
        Tx(StatNum(r[3]), "mono", 15, 1, C.text, CX + 20 + c0 + cw, ry, cw - 12, 30, 2)
        Tx(StatNum(r[4]), "mono", 15, 1, C.text, CX + 20 + c0 + 2 * cw, ry, cw - 12, 30, 2)
        if i = 1
            FillRR(CX + 20, ry + 31, CWD - 40, 1, 1, C.ov, 20)
    }
    ; All time
    ay := ty + 114 + 12, a0 := 110, aw := (CWD - 40 - a0) // 5
    Glass(CX, ay, CWD, 82)
    Tx("ALL TIME", "ui", 11, 1, C.dim, CX + 20, ay + 12, a0, 18)
    heads := ["RAIDS", "SPEED RAIDS", "INFINITY", "DIMENSION", "ROBLOX RESTARTS"]
    keys := ["raidsTotal", "speedRunsTotal", "infRunsTotal", "dimRunsTotal", "restartsTotal"]
    FillRR(CX + 20, ay + 34, CWD - 40, 1, 1, C.ov, 26)
    Tx("Total", "ui", 14, 1, C.text, CX + 20, ay + 42, a0, 30)
    for j, h in heads {
        Tx(h, "ui", 11, 1, C.dim, CX + 20 + a0 + (j - 1) * aw, ay + 12, aw - 12, 18, 2)
        Tx(StatNum(sc[keys[j]]), "mono", 15, 1, C.text, CX + 20 + a0 + (j - 1) * aw, ay + 42, aw - 12, 30, 2)
    }
    ; Reset: first click arms (red, 4 s), second click wipes
    by := ay + 82 + 14, bw := 220
    armed := statsArm && A_TickCount - statsArm < 4000
    if armed
        FillRR(CX, by, bw, 36, 12, "D83A3A")
    else {
        FillRR(CX, by, bw, 36, 12, C.field)
        StrokeRR(CX, by, bw, 36, 12, "E5484D", 130)
    }
    if IsHot("statsreset")
        FillRR(CX, by, bw, 36, 12, C.ov, 22)
    Tx(armed ? "Click again to confirm" : "Reset statistics", "ui", 14, 1, armed ? "FFFFFF" : "FF8A8A", CX, by, bw, 36, 1)
    Hit(CX, by, bw, 36, "statsreset", StatsReset)
    Tx(armed ? "Wipes today, all time and this run. Settings stay." : "Click twice within 4 s.", "ui", 12, 0, C.dim, CX + bw + 16, by, CWD - bw - 16, 36)
}

; number with thin grouping: 396540 -> 396 540
StatNum(v) => RegExReplace(String(v), "\B(?=(\d{3})+(?!\d))", " ")

; two clicks within 4 s: wipes every counter (today, all time, this run) - the Speed Raid timer and other settings stay
StatsReset() {
    global statsArm, statCacheT
    if !statsArm || A_TickCount - statsArm > 4000 {
        statsArm := A_TickCount
        SetTimer(StatsDisarm, -4000)                     ; the red button goes out exactly after 4 s
        Log("statistics reset: first click, click again within 4 s to confirm")
        return
    }
    if A_TickCount - statsArm < 600                      ; a quick double click must not wipe at once
        return
    SetTimer(StatsDisarm, 0)
    statsArm := 0
    IniDelete INI, "stats"
    for k in sess
        sess[k] := 0
    statCacheT := 0
    Log("statistics reset")
}

StatsDisarm() {
    global statsArm
    statsArm := 0
    UiInvalidate()
}

; Settings page (HUD 2.0): theme tiles, then two columns of rows (sound/music/files | compact window)
PageSettings() {
    Tx("THEME", "ui", 11, 1, C.dim, CX, CY, 200, 18)
    n := THEME_ORDER.Length, gap := 8, sw := 78
    cur := FrzGet("theme", ThemeName)
    for i, name in THEME_ORDER {
        t := THEMES[name]
        x := CX + (i - 1) * (sw + gap), y := CY + 24
        id := "th_" name
        FillRR(x, y, sw, 76, 14, t.bg)
        GradRR(x + 8, y + 8, sw - 16, 26, 9, t.acc, 255, t.acc2, 255)
        FillRR(x + 8, y + 40, (sw - 16) // 2, 6, 3, t.hi)
        FillRR(x + 8, y + 50, sw - 16, 6, 3, t.card)
        StrokeRR(x, y, sw, 76, 14, name = cur ? C.hi : C.ov, name = cur ? 255 : 36, name = cur ? 2 : 1)
        if IsHot(id)
            FillRR(x, y, sw, 76, 14, C.ov, 18)
        Tx(THEME_TITLES.Get(name, StrUpper(SubStr(name, 1, 1)) SubStr(name, 2)), "ui", 9, 1, name = cur ? C.hi : C.dim, x, y + 58, sw, 16, 1)
        if name = "nocturne"                               ; the author's default
            Tx("Author's pick", "ui", 10, 1, C.hi, x, y + 80, sw, 14, 1)
        Hit(x, y, sw, 76, id, SetTheme.Bind(name))
    }
    cw := (CWD - 24) // 2, lx := CX, rx := CX + cw + 24, y0 := CY + 150
    Tx("SOUND AND MUSIC", "ui", 11, 1, C.dim, lx, y0 - 22, cw, 18)
    SRow(lx, y0, cw, "Button sounds", "A short click when you press a button", 60)
    Sw2(lx, y0, cw, cfg["sfx"] = "1", "sw_sfx", FlipKey.Bind("sfx"))
    SRow(lx, y0 + RH2, cw, "Music", "Quiet loop while the window is open", 60)
    Sw2(lx, y0 + RH2, cw, cfg["music"] = "1", "sw_music", FlipKey.Bind("music"))
    fy := y0 + 2 * RH2 + 28
    Tx("FILES", "ui", 11, 1, C.dim, lx, fy - 22, cw, 18)
    SRow(lx, fy, cw, "Open files", "Log, ini, screenshots", 232)
    by := fy + (RH2 - 34) // 2
    Btn(lx + cw - 232, by, 68, 34, "Log", "f_log", OpenPath.Bind(LOGFILE))
    Btn(lx + cw - 232 + 76, by, 80, 34, "raid.ini", "f_ini", OpenPath.Bind(INI))
    Btn(lx + cw - 232 + 164, by, 68, 34, "Shots", "f_shots", OpenPath.Bind(SHOTDIR))
    Tx("COMPACT WINDOW", "ui", 11, 1, C.dim, rx, y0 - 22, cw, 18)
    SRow(rx, y0, cw, "Compact mode", "Narrow window beside the game", 60)
    Sw2(rx, y0, cw, skin = "compact", "sw_compact", SetSkin.Bind(skin = "compact" ? "full" : "compact"))
    SRow(rx, y0 + RH2, cw, "Size", "", 150)
    Stp2(rx, y0 + RH2, cw, StpFmt(Round(cScale * 100), "%"), StepCScale.Bind(-0.1), StepCScale.Bind(0.1), "cScale")
    SRow(rx, y0 + 2 * RH2, cw, "Opacity", "", 150)
    Stp2(rx, y0 + 2 * RH2, cw, StpFmt(Round(cAlpha * 100 / 255), "%"), StepCAlpha.Bind(-25), StepCAlpha.Bind(25), "cAlpha")
    SRow(rx, y0 + 3 * RH2, cw, "Compact look", "", 160)
    Seg(rx, y0 + 3 * RH2, cw, ["Dark", "Light"], cTheme = "light" ? 2 : 1, "clook", SetCLook)
    TxP("Custom colours: add  bg= card= acc= acc2= hi=  (6-digit hex) under [theme] in raid.ini. Clicking a preset clears them.", "ui", 11, C.dim, CX, CY + 394, CWD, 28)
}

; Compact look segment: switch only when the other one is clicked
SetCLook(i, *) {
    if (i = 2) != (cTheme = "light")
        ThemeToggle()
}

; Music in the full skin: same idea as MusicTick in ui_compact.ahk (WMPlayer, 1% volume), but for skin = full.
; Plays only while the window is visible; stops for the compact skin (MusicTick plays there) and when music = 0.
MusicTickFull() {
    static wmpF := 0, lastF := ""
    wantF := false
    try wantF := skin = "full" && cfg["music"] = "1" && !running && DllCall("IsWindowVisible", "ptr", g.Hwnd) && !DllCall("IsIconic", "ptr", g.Hwnd)
    if !wantF {                                          ; skin != full, minimised, hidden, running or music off: stop at once (compact MusicTick plays alone)
        if wmpF
            try wmpF.controls.stop()
        wmpF := 0
        return
    }
    stF := 0
    try stF := wmpF ? wmpF.playState : 0
    if !(stF = 0 || stF = 1 || stF = 8 || stF = 10)
        return
    listF := []
    Loop Files A_ScriptDir "\music\*.m4a"
        listF.Push(A_LoopFileFullPath)
    if !listF.Length
        return
    pickF := listF[Random(1, listF.Length)]
    Loop 3
        if (pickF := listF[Random(1, listF.Length)]) != lastF
            break
    try {
        if !wmpF
            wmpF := ComObject("WMPlayer.OCX")
        wmpF.settings.volume := 1
        wmpF.URL := pickF
        wmpF.controls.play()
        lastF := pickF
        Log("music(full): " pickF)
    } catch as e {
        Log("music(full): " e.Message " - off")
        cfg["music"] := "0"
    }
}

; ------------------------------ HUD 2.0 frame (full window: sidebar | header + page + log) ------------------------------
FillBox(x, y, w, h, hex, a := 255) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillRectangle", "ptr", gr, "ptr", br, "float", x, "float", y, "float", w, "float", h)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

; one soft glow of C.g1 at the top left of the content (stacked translucent ellipses, no blur), drawn once and cached
DrawBackdrop2() {
    global uiBack2, uiBack2Key, gr
    key := C.bg C.g1 C.lite UI_K
    if !uiBack2 || uiBack2Key != key {
        if uiBack2
            DllCall("gdiplus\GdipDisposeImage", "ptr", uiBack2)
        cv := Canvas(PW, PH, C.bg)
        real := gr
        gr := cv[2]
        DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", UI_K, "float", UI_K, "int", 0)
        Glow(330, 0, 600, 330, C.g1, 255)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", gr)
        gr := real
        uiBack2 := cv[1]
        uiBack2Key := key
    }
    DllCall("gdiplus\GdipResetWorldTransform", "ptr", gr)
    DllCall("gdiplus\GdipDrawImageI", "ptr", gr, "ptr", uiBack2, "int", 0, "int", 0)
    DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", UI_K, "float", UI_K, "int", 0)
}

PageTitle2() => Map("home", "Home", "modes", "Modes", "connect", "Connect", "stats", "Stats", "settings", "Settings", "setup", "Setup").Get(curPage, "Home")

; sidebar x 0..190: logo, five pages, then Setup and Sound at the bottom. Active item: translucent plate + a strip of C.lin on the left.
DrawSidebar2() {
    FillBox(0, 0, 190, GH, C.sb)
    FillBox(189, 0, 1, GH, C.ov, 26)
    Glow(35, 31, 30, 30, C.acc, 60)
    GradRR(18, 14, 34, 34, 11, C.hi, 255, C.acc2, 255)
    Tx("AD Bot", "head", 21, 1, C.text, 62, 8, 122, 30)
    Tx("v" APP_VERSION, "mono", 9, 0, C.dim, 62, 36, 124, 14)
    ny := NavY(curPage)
    if ny >= 0 {                                         ; the plate and the strip of the active item slide to the new one (220 ms)
        ay := AnimTarget("navY", ny, 220)
        FillRR(12, ay, 166, 40, 10, C.ov, C.lite ? 34 : 30)
        FillRR(12, ay + 7, 4, 26, 2, C.lin)
    }
    y := 68
    for it in [["home", "Home", 0xE80F], ["modes", "Modes", 0xE8FD], ["connect", "Connect", 0xE71B], ["stats", "Stats", 0xE9D2], ["settings", "Settings", 0xE713]] {
        NavItem2(it[1], it[2], it[3], y, curPage = it[1], SetPage.Bind(it[1]))
        y += 42
    }
    if UpdateAvail() {                                   ; 14.11: a newer build is on GitHub (update.ahk)
        hot := IsHot("update")
        GradRR(12, y + 10, 166, 36, 12, "3DD68C", hot ? 255 : 215, "1FA866", hot ? 255 : 215)
        Tx("UPDATE", "ui", 14, 1, "06210F", 12, y + 10, 166, 36, 1)
        Hit(12, y + 10, 166, 36, "update", UpdateRun)
    }
    NavItem2("setup", "Setup", SetupFails() ? 0xE7BA : 0xE73E, GH - 18 - 40 - 42, curPage = "setup", SetPage.Bind("setup"), SetupFails())
    NavItem2("sound", "Sound", cfg["sfx"] = "1" ? 0xE767 : 0xE74F, GH - 18 - 40, false, FlipKey.Bind("sfx"), 0, true)
}

NavItem2(name, label, glyph, y, on, fn, badge := 0, eq := false) {
    nid := "nav_" name
    hot := IsHot(nid)
    if !on && hot                                        ; the plate of the active item is drawn by DrawSidebar2 (it slides)
        FillRR(12, y, 166, 40, 10, C.ov, 12)
    fg := on ? C.hi : hot ? C.text : C.dim
    na := on || hot ? 255 : 200
    Tx(Chr(glyph), "icon", 17, 0, fg, 24, y, 22, 40, 1, na)
    Tx(label, "ui", 15, on, fg, 54, y, 90, 40, 0, na)
    if badge > 0 {
        FillRR(146, y + 11, 20, 18, 9, "F5B942")
        Tx(String(badge), "ui", 11, 1, "2B1D00", 146, y + 11, 20, 18, 1)
    }
    if eq {                                              ; static equalizer bars; sound off: a slash over the speaker and "OFF"
        if cfg["sfx"] != "1" {
            DllCall("gdiplus\GdipCreatePen1", "uint", Col(fg), "float", 2, "int", 2, "ptr*", &pen := 0)
            DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", 26, "float", y + 29, "float", 42, "float", y + 11)
            DllCall("gdiplus\GdipDeletePen", "ptr", pen)
            Tx("OFF", "ui", 10, 1, C.idle, 134, y, 32, 40, 2)
        } else
            for i, hgt in [5, 12, 8]
                FillRR(150 + (i - 1) * 5, y + 27 - hgt, 3, hgt, 1, C.hi)
    }
    Hit(12, y, 166, 40, nid, fn)
}

; header y 0..62: page title, status chip, Roblox dot, session clock, START / STOP, minimise, close. Empty parts drag the window.
DrawHeader2() {
    FillBox(190, 61, GW - 190, 1, C.ov, 22)
    Tx(PageTitle2(), "head", 24, 1, C.text, 212, 0, 112, 62)
    stopping := busy && !running
    st := running ? "Running" : stopping ? "Stopping" : "Stopped"
    sub := (uiStatus = st || uiStatus = "stopped") ? "" : uiStatus
    w1 := TxW(st, "ui", 12, 1)
    w2 := sub != "" ? TxW(sub, "ui", 12, 0) + 8 : 0
    cw := Min(250, 28 + w1 + w2 + 14)
    FillRR(330, 17, cw, 28, 14, C.field)
    StrokeRR(330, 17, cw, 28, 14, C.ov, 30)
    Dot(341, 26, 10, running ? "3DD68C" : stopping ? "F5B942" : C.idle)
    Tx(st, "ui", 12, 1, C.text, 358, 17, w1 + 10, 28)
    if sub != ""
        Tx(sub, "ui", 12, 0, C.dim, 358 + w1 + 8, 17, Max(10, cw - 28 - w1 - 8 - 12), 28)
    roblox := WinExist(GAME) != 0
    rx := 330 + cw + 14                                  ; follows the chip (max 250 wide)
    Dot(rx, 26, 10, roblox ? "3DD68C" : C.idle)
    Tx("Roblox", "ui", 12, 0, roblox ? C.text : C.idle, rx + 15, 17, 52, 28)
    fight := running && A_TickCount - lastFight < FIGHT_STICKY
    Dot(rx + 68, 26, 10, fight ? C.hi : C.idle)
    Tx("Fight", "ui", 12, 0, fight ? C.text : C.idle, rx + 83, 17, 38, 28)
    clk := SessClockTxt()
    Tx(running || clk = "--:--" ? "SESSION" : "LAST SESSION", "ui", 9, 1, C.dim, 696, 9, 90, 14, 2)
    Tx(clk, "mono", 18, 1, C.text, 696, 22, 90, 30, 2)
    gx := 794, gy := 11
    if running
        GradRR(gx, gy, 120, 40, 20, "EF5A6F", 255, "B8283F", 255)
    else
        GradRR(gx, gy, 120, 40, 20, C.lite ? C.hi : C.acc, 255, C.acc2, 255)
    if IsHot("run")
        FillRR(gx, gy, 120, 40, 20, "FFFFFF", 30)
    Tx(running ? "STOP" : "START", "ui", 14, 1, "FFFFFF", gx, gy, 94, 40, 1)
    Tx(running ? "F2" : "F1", "mono", 10, 1, "FFFFFF", gx + 92, gy, 24, 40, 1, 190)
    Hit(gx, gy, 120, 40, "run", ToggleRun)
    for b in [["min", 924, 0xE921], ["close", 956, 0xE8BB]] {
        if IsHot(b[1])
            FillRR(b[2], 16, 30, 30, 8, b[1] = "close" ? "E5484D" : C.ov, b[1] = "close" ? 200 : 30)
        Tx(Chr(b[3]), "icon", 11, 0, C.text, b[2], 16, 30, 30, 1)
        Hit(b[2], 16, 30, 30, b[1], b[1] = "min" ? (() => g.Minimize()) : (() => ExitApp()))
    }
}

; key hints above the log, right aligned
DrawKeys2() {
    y := GH - 14 - LOGH - 26
    x := CX + CWD - 284
    x += KeyCap(x, y, "F1") + 6
    Tx("Start", "ui", 12, 0, C.dim, x, y, 44, 24)
    x += 56
    x += KeyCap(x, y, "F2") + 6
    Tx("Stop", "ui", 12, 0, C.dim, x, y, 44, 24)
    x += 52
    x += KeyCap(x, y, "F3") + 6
    Tx("Restart", "ui", 12, 0, C.dim, x, y, 60, 24)
}

; log panel: last 4 lines (uiLog, filled by UiLogPush), the newest at the bottom; the time stamp in C.hi
DrawLog2() {
    y := GH - 14 - LOGH
    FillRR(CX, y, CWD, LOGH, 12, C.field, 215)
    StrokeRR(CX, y, CWD, LOGH, 12, C.ov, 26)
    n := uiLog.Length
    if n = 0 {
        Tx("Nothing yet. Press F1 to start.", "mono", 12, 0, C.idle, CX + 14, y + 8 + 3 * 20, CWD - 28, 20)
        return
    }
    rows := Min(4, n)
    cw := TxW("0000000000", "mono", 12, 0) / 10          ; width of one monospace character
    Loop rows {
        i := n - rows + A_Index
        ry := y + 8 + (4 - rows + A_Index - 1) * 20
        line := uiLog[i], last := i = n
        fg := last ? C.text : C.dim
        if RegExMatch(line, "^\d\d:\d\d:\d\d  ") {
            Tx(SubStr(line, 1, 8), "mono", 12, 0, C.hi, CX + 14, ry, cw * 9, 20, 0, last ? 255 : 190)
            Tx(SubStr(line, 11), "mono", 12, 0, fg, CX + 14 + cw * 10, ry, CWD - 28 - cw * 10, 20)
        } else
            Tx(LTrim(line), "mono", 12, 0, fg, CX + 14 + cw * 10, ry, CWD - 28 - cw * 10, 20)
    }
}

; ------------------------------ Modes page (HUD 2.0 step 6): tab row + settings widgets ------------------------------
; Tab row on top; General is drawn by PageGeneral, the other tabs by their own page (two columns of rows under the tab row)
PageModesTab() {
    global CX
    ModesTabs()
    if pgKind = "tab"                                    ; tab change: only the body under the tab row slides
        CX := CX0 + PgDx()
    t := InStr(" raid speed inf dim xdim ", " " curTab " ") ? curTab : "general"
    switch t {
        case "general": PageGeneral()
        case "raid":    PageRaid2()
        case "speed":   PageSpeed2()
        case "inf":     PageInfinity2()
        case "dim":     PageDimension2()
        case "xdim":    PageXdim2()
    }
}

; tab row: name + small dot (mode on), active tab underlined with C.lin
ModesTabs() {
    FillRR(CX, CY + 33, CWD, 1, 1, C.ov, 34)
    x := CX, ux := 0, uw := 0
    for t in [["general", "General", ""], ["raid", "Raid", "raid"], ["speed", "Speed Raid", "speed"], ["inf", "Infinity", "infinity"], ["dim", "Dimension", "dungeon"], ["xdim", "Extreme", "xdim"]] {
        id := "tab_" t[1]
        on := (curTab = t[1]) || (curTab = "" && t[1] = "general")
        tw := TxW(t[2], "ui", 14, 1)
        w := tw + 28 + (t[3] != "" ? 13 : 0)
        if IsHot(id) && !on
            FillRR(x, CY + 2, w, 31, 8, C.ov, 10)
        Tx(t[2], "ui", 14, 1, on ? C.hi : IsHot(id) ? C.text : C.dim, x + 14, CY, tw + 6, 33)
        if t[3] != "" {
            en := cfg[t[3]] = "1"
            if t[1] = "inf"
                en := en && cfg["dungeon"] != "1" && cfg["xdim"] != "1"
            else if t[1] = "dim"
                en := en && cfg["xdim"] != "1"
            if en
                Dot(x + 14 + tw + 6, CY + 13, 7, "3DD68C")
            else
                Dot(x + 14 + tw + 6, CY + 13, 7, C.idle, 150)
        }
        if on
            ux := x + 6 - CX, uw := w - 12                   ; underline: drawn after the loop, it slides (220 ms)
        Hit(x, CY, w, 34, id, SetTab.Bind(t[1]))
        x += w + 2
    }
    if uw {
        ax := AnimTarget("tabX", ux, 220), aw := AnimTarget("tabW", uw, 220)
        FillRR(CX + ax, CY + 31, aw, 3, 1, C.lin)
    }
}

; Modes > General: two columns of rows
PageGeneral() {
    cw := (CWD - 24) // 2, lx := CX, rx := CX + cw + 24, y0 := CY + 42
    sec := MinSec(cfg["infStop"], 57 * 60 + 30)
    SRow(lx, y0, cw, "Leave for the raid at", "Minute:second of the hour when the bot leaves Infinity or Dimension", 140)
    Stp2(lx, y0, cw, StpFmt(sec, "time"), StepTime.Bind("infStop", -30, 600, 3480, 57 * 60 + 30), StepTime.Bind("infStop", 30, 600, 3480, 57 * 60 + 30), "infStop")
    SRow(lx, y0 + RH2, cw, "Loadouts", "Switch the loadout by mode through the Bag: raid 1, Infinity or Dimension 2, Speed Raid 3", 46)
    Sw2(lx, y0 + RH2, cw, cfg["loadouts"] = "1", "sw_loadouts", FlipKey.Bind("loadouts"))
    ev := Num("raidEvery", 1)
    SRow(rx, y0, cw, "Raid every", "Hours between raids", 140)
    Stp2(rx, y0, cw, StpFmt(ev, "h"), StepCfg.Bind("raidEvery", -1, 1, 24, 1), StepCfg.Bind("raidEvery", 1, 1, 24, 1), "raidEvery")
    TxP("Priority is fixed: Raid, then Speed Raid, then one of Infinity / Dimension / Extreme.", "ui", 12, C.dim, rx + 2, y0 + RH2 + 10, cw - 4, 40)
}

; ---- Modes widgets (HUD 2.0). Controls sit on the right edge of a row of width w and height RH2. ----

; row: label + small caption on the left, bottom line. cw = width kept free for the control. lk <> "": greyed out, lk is shown as the reason
; gray: greyed out but the caption stays (lk replaces the caption with the reason)
SRow(x, y, w, label, sub, cw := 150, lk := "", gray := false) {
    off := lk != "" || gray
    Tx(label, "ui", 14, 1, off ? C.idle : C.text, x, y + 4, w - cw - 16, 20, 0, off ? 150 : 255)
    TxP(lk != "" ? lk : sub, "ui", 11, off ? C.idle : C.dim, x, y + 24, w - cw - 16, 28, off ? 200 : 255)
    FillRR(x, y + RH2 - 1, w, 1, 1, C.ov, 26)
}

; switch: the ball slides and the colour fades (160 ms) when the state changes. lk: greyed out, no clicks
Sw2(x, y, w, on, id, fn, lk := false) {
    sx := x + w - 46, sy := y + (RH2 - 26) // 2
    if lk {
        FillRR(sx, sy, 46, 26, 13, C.off, 120)
        Dot(sx + 3, sy + 3, 20, "C4CADB", 90)
        return
    }
    sv := AnimTarget("sw|" id, on ? 1 : 0, 160)          ; 0 = off, 1 = on
    if sv >= 1 {
        GradRR(sx, sy, 46, 26, 13, C.acc, 255, C.acc2, 255)
        StrokeRR(sx, sy, 46, 26, 13, C.hi, 90)
    } else if sv <= 0 {
        FillRR(sx, sy, 46, 26, 13, C.field)
        StrokeRR(sx, sy, 46, 26, 13, C.ov, 40)
    } else {
        FillRR(sx, sy, 46, 26, 13, C.field)
        StrokeRR(sx, sy, 46, 26, 13, C.ov, 40)
        GradRR(sx, sy, 46, 26, 13, C.acc, Round(255 * sv), C.acc2, Round(255 * sv))
        StrokeRR(sx, sy, 46, 26, 13, C.hi, Round(90 * sv))
    }
    if IsHot(id)
        FillRR(sx, sy, 46, 26, 13, C.ov, 22)
    Dot(sx + 3 + 20 * sv, sy + 3, 20, sv >= 1 ? "FFFFFF" : sv <= 0 ? "C4CADB" : Blend("C4CADB", "FFFFFF", sv))
    Hit(sx - 8, y + 4, 62, RH2 - 8, id, fn)
}

; - value + ; val is the finished text (see StpFmt)
Stp2(x, y, w, val, fnDn, fnUp, id, lk := false) {
    bx := x + w - 140, by := y + (RH2 - 32) // 2, a := lk ? 120 : 255
    FillRR(bx, by, 140, 32, 10, C.field, a)
    StrokeRR(bx, by, 140, 32, 10, C.ov, lk ? 14 : 30)
    if !lk {
        if IsHot("dn_" id)
            FillRR(bx + 1, by + 1, 32, 30, 9, C.ov, 22)
        if IsHot("up_" id)
            FillRR(bx + 107, by + 1, 32, 30, 9, C.ov, 22)
        Hit(bx, by, 34, 32, "dn_" id, fnDn)
        Hit(bx + 106, by, 34, 32, "up_" id, fnUp)
    }
    Tx(Chr(0x2212), "mono", 16, 1, lk ? C.idle : C.hi, bx, by, 34, 32, 1, a)
    Tx(val, "mono", 13, 1, lk ? C.idle : C.text, bx + 34, by, 72, 32, 1, a)
    Tx("+", "mono", 16, 1, lk ? C.idle : C.hi, bx + 106, by, 34, 32, 1, a)
}

; value text for Stp2: time (seconds -> MM:SS), % , s, h, min (0 = off), off0 (0 = off), anything else as is
StpFmt(v, fmt) {
    switch fmt {
        case "time": return Format("{:02}:{:02}", v // 60, Mod(v, 60))
        case "%":    return v " %"
        case "s":    return v " s"
        case "h":    return v " h"
        case "min":  return v = 0 ? "off" : v " min"
        case "off0": return v = 0 ? "off" : v
    }
    return String(v)
}

; segments: items = array of labels, sel = number of the active one, fn is called as fn(i). Width of the control: SegW
SegW(items) {
    w := 6
    for t in items
        w += Ceil(TxW(t, "ui", 13, 1)) + 24
    return w
}

Seg(x, y, w, items, sel, id, fn, lk := false) {
    tw := SegW(items), sx := x + w - tw, sy := y + (RH2 - 34) // 2, a := lk ? 120 : 255
    FillRR(sx, sy, tw, 34, 10, C.field, a)
    StrokeRR(sx, sy, tw, 34, 10, C.ov, lk ? 14 : 30)
    sgx := sx + 3
    for i, t in items {
        iw := Ceil(TxW(t, "ui", 13, 1)) + 24, on := i = sel && !lk
        if on {
            GradRR(sgx, sy + 3, iw, 28, 8, C.acc, 255, C.acc2, 255)
            StrokeRR(sgx, sy + 3, iw, 28, 8, C.hi, 70)
        } else if IsHot(id "_" i) && !lk
            FillRR(sgx, sy + 3, iw, 28, 8, C.ov, 14)
        Tx(t, "ui", 13, 1, on ? "FFFFFF" : lk ? C.idle : C.dim, sgx, sy + 3, iw, 28, 1, a)
        if !lk
            Hit(sgx, sy + 3, iw, 28, id "_" i, fn.Bind(i))
        sgx += iw
    }
}

; button with the value and a chevron; returns the position for the pop-up {x, y (below the button), r (right edge)}
PickW(text) => Ceil(TxW(text, "ui", 13, 1)) + 44

Pick(x, y, w, text, id, fn, lk := false) {
    pw := PickW(text), px := x + w - pw, py := y + (RH2 - 34) // 2, open := popOpen = id, a := lk ? 120 : 255
    FillRR(px, py, pw, 34, 10, C.field, a)
    StrokeRR(px, py, pw, 34, 10, open ? C.hi : C.ov, open ? 160 : lk ? 14 : 30)
    if IsHot(id) && !lk
        FillRR(px, py, pw, 34, 10, C.ov, 12)
    Tx(text, "ui", 13, 1, lk ? C.idle : C.text, px + 14, py, pw - 36, 34, 0, a)
    Tx(Chr(open ? 0xE70E : 0xE70D), "icon", 10, 0, lk ? C.idle : C.hi, px + pw - 26, py, 16, 34, 1, a)
    if !lk
        Hit(px, py, pw, 34, id, PopToggle.Bind(id))
    return {x: px, y: py + 34, r: px + pw}
}

; asks for the pop-up list of Pick `id` (drawn later by DrawPop). items = [[key, label], ...]; fn(key) is called on a click; sel = key of the active one
Pop(id, anchor, w, items, sel, fn, cols := 3) {
    global popDraw
    if popOpen != id
        return
    px := Max(CX, anchor.r - w)
    popDraw := {x: px, y: anchor.y + 4, w: w, items: items, sel: sel, fn: fn, cols: cols}
}

PopPick(fn, key, *) {
    global popOpen
    popOpen := ""
    fn.Call(key)
}

NoClick(*) {
}

; the pop-up: last thing in the frame. A hit over the whole window comes first, so a click outside the list closes it
DrawPop() {
    if !IsObject(popDraw)
        return
    p := popDraw
    pv := AnimTarget("pop|" popOpen, 1, 140, 0)          ; appears: 6 px down (from above) and the shadow fades in, 140 ms
    py := p.y - 6 * (1 - pv)
    Hit(0, 0, GW, GH, "pop_bg", ClosePop)
    n := p.items.Length, cols := p.cols, rows := Ceil(n / cols)
    cwid := (p.w - 20 - (cols - 1) * 6) // cols, h := 20 + rows * 30 + (rows - 1) * 6
    Loop 5
        FillRR(p.x - A_Index, py - A_Index + 8, p.w + 2 * A_Index, h + 2 * A_Index, 12 + A_Index, "000000", Round(22 * pv))
    FillRR(p.x, py, p.w, h, 12, C.sb)
    StrokeRR(p.x, py, p.w, h, 12, C.ov, 70)
    Hit(p.x, py, p.w, h, "pop_body", NoClick)
    for i, it in p.items {
        col := Mod(i - 1, cols), row := (i - 1) // cols
        Chip(p.x + 10 + col * (cwid + 6), py + 10 + row * 36, cwid, 30, it[2], it[1] = p.sel, "pop_" it[1], PopPick.Bind(p.fn, it[1]))
    }
}

; UiShots only: widgets over the free part of General (Seg, Pick + Pop, locked rows)
UiShotDemo() {
    cw := (CWD - 24) // 2, lx := CX, rx := CX + cw + 24, y0 := CY + 42 + RH2 * 3
    items := ["Group Finder", "Create room"]
    SRow(lx, y0, cw, "Entry (demo)", "how the bot gets into a raid", SegW(items))
    Seg(lx, y0, cw, items, 1, "demo_seg", (*) => 0)
    SRow(lx, y0 + RH2, cw, "Solo (demo)", "no queue", 46)
    Sw2(lx, y0 + RH2, cw, true, "demo_sw", (*) => 0)
    SRow(lx, y0 + RH2 * 2, cw, "Early start at bonus", "", 140, "Needs Friends Only off")
    Stp2(lx, y0 + RH2 * 2, cw, StpFmt(110, "%"), (*) => 0, (*) => 0, "demo_stp", true)
    SRow(rx, y0, cw, "Raid (demo)", "found in Group Finder by name", PickW("Divine"))
    a := Pick(rx, y0, cw, "Divine", "demo", (*) => 0)
    SRow(rx, y0 + RH2, cw, "Locked switch (demo)", "", 46, "Locked while Extreme is on")
    Sw2(rx, y0 + RH2, cw, true, "demo_sw2", (*) => 0, true)
    items2 := []
    for k in StrSplit(Trim(RAIDS_READY), " ")
        items2.Push([k, RaidShort(k)])
    Pop("demo", a, 340, items2, "divine", (*) => 0, 3)
}

; Connect page (HUD 2.0): Private server and Discord, each card has status, a masked value, and buttons.
; Edit opens the small editor window (EditServerLink / EditWebhook); the report interval is changed right here
PageConnect() {
    gap := 14, pw := (CWD - gap) // 2, ch := 324
    link := uiShotNoLinks ? "" : FrzGet("link", PrivateLink)
    hook := uiShotNoLinks ? "" : FrzGet("hook", WebhookUrl)
    ; --- Private server ---
    x := CX, y := CY, iw := pw - 40
    Glass(x, y, pw, ch)
    Tx("Private server", "head", 16, 1, C.text, x + 20, y + 16, iw, 26)
    TxP("The bot joins this server when it restarts Roblox, so you always farm alone.", "ui", 12, C.dim, x + 20, y + 50, iw, 40)
    linkOk := link != "" && RegExMatch(link, "i)roblox\.com|^roblox://")
    ConnStatus(x + 20, y + 98, iw, link = "" ? "Empty - public server after a restart" : linkOk ? "Link saved" : "Not a Roblox link", linkOk ? "3DD68C" : link = "" ? "F5B942" : "E5484D")
    ConnField(x + 20, y + 128, iw, link = "" ? "https://www.roblox.com/share?code=..." : LinkShort(link), link != "")
    TxP("Edit pastes or changes the link. Join opens it in Roblox.", "ui", 11, C.dim, x + 20, y + 176, iw, 20)
    ConnNoteDraw("srv", x + 20, y + 238, iw)
    bw := (iw - 10) // 2
    Btn(x + 20, y + ch - 64, bw, 44, "Edit", "conn_srv_edit", EditServerLink)
    Btn(x + 20 + bw + 10, y + ch - 64, bw, 44, "Join", "conn_srv_join", ConnJoin, true, , link = "")
    ; --- Discord ---
    x := CX + pw + gap
    hookOk := hook != "" && WebhookOk(hook)
    Glass(x, y, pw, ch)
    Tx("Discord", "head", 16, 1, C.text, x + 20, y + 16, iw, 26)
    TxP("The bot posts a short status report with a screenshot to your channel.", "ui", 12, C.dim, x + 20, y + 50, iw, 40)
    ConnStatus(x + 20, y + 98, iw, hook = "" ? "Not set" : hookOk ? "Webhook saved" : "Not a Discord webhook", hookOk ? "3DD68C" : hook = "" ? "F5B942" : "E5484D")
    ConnField(x + 20, y + 128, iw, hook = "" ? "https://discord.com/api/webhooks/..." : HookMask(hook), hook != "")
    mn := Min(240, Max(0, FrzGet("hookmin", HookMin)))
    SRow(x + 20, y + 176, iw, "Report every", "0 = only problems", 140)
    Stp2(x + 20, y + 176, iw, mn " min", StepHookMin.Bind(-5), StepHookMin.Bind(5), "hookMin")
    ConnNoteDraw("hook", x + 20, y + 238, iw)
    Btn(x + 20, y + ch - 64, bw, 44, "Edit", "conn_hook_edit", EditWebhook)
    Btn(x + 20 + bw + 10, y + ch - 64, bw, 44, "Send test", "conn_hook_test", ConnTest, true, , !hookOk)
    TxP("Both are optional. The bot works without them.", "ui", 12, C.dim, CX + 4, CY + ch + 12, CWD - 8, 20)
}

; dot + status text
ConnStatus(x, y, w, text, col) {
    Dot(x, y + 6, 10, col)
    Tx(text, "ui", 12, 0, C.text, x + 18, y, w - 18, 22)
}

; read-only box with the value (filled = real value, otherwise a dim hint)
ConnField(x, y, w, text, filled) {
    FillRR(x, y, w, 36, 10, C.field)
    StrokeRR(x, y, w, 36, 10, C.ov, 30)
    Tx(text, "mono", 12, 0, filled ? C.text : C.idle, x + 12, y, w - 24, 36)
}

ConnNoteDraw(k, x, y, w) {
    if connNoteK = k && A_TickCount - connNoteT < 4000
        Tx(connNote, "ui", 12, 1, C.hi, x, y, w, 18)
}

ConnSay(k, text) {
    global connNote, connNoteK, connNoteT
    connNote := text, connNoteK := k, connNoteT := A_TickCount
    SetTimer(ConnNoteOff, -4000)                         ; redraw when the note expires
}

ConnNoteOff() {
    UiInvalidate()
}

; roblox.com/share?code=8d0a16... (no https://www., cut to fit)
LinkShort(link) {
    s := RegExReplace(link, "i)^https?://(www\.)?", "")
    return StrLen(s) > 38 ? SubStr(s, 1, 36) "…" : s
}

; the token is never shown: …/webhooks/<id>/••••••••
HookMask(url) {
    if RegExMatch(url, "i)/api/webhooks/(\d+)/", &m)
        return "…/webhooks/" m[1] "/••••••••"
    return "••••••••"
}

HookMin() {
    v := Trim(IniRead(INI, "raid", "webhookMin", "30"))
    return IsInteger(v) ? Integer(v) : 30
}

; 0-240 min, step 5; the ini is only written on a click (an older bigger value stays until then)
StepHookMin(d, *) {
    v := Min(240, Max(0, Min(240, HookMin()) + d))
    IniWrite v, INI, "raid", "webhookMin"
    Log("setting webhookMin = " v)
}

; Join on the Connect page: opens the saved private server link (Roblox asks to open the game)
ConnJoin(*) {
    v := PrivateLink()
    if v = "" {
        ConnSay("srv", "No link yet - press Edit.")
        Log("join: no private server link saved")
        return
    }
    if !RegExMatch(v, "i)roblox\.com|^roblox://") {
        ConnSay("srv", "This is not a Roblox link.")
        Log("join: the saved link is not a Roblox link")
        return
    }
    Log("opening the private server link")
    try Run(ProtoLink(v))
    catch as e {
        Log("join: could not open the link: " e.Message)
        return
    }
    ConnSay("srv", "Opening Roblox...")
}

; Send test on the Connect page: a message with a game screenshot to the saved webhook
ConnTest(*) {
    url := WebhookUrl()
    if url = "" || !WebhookOk(url) {
        ConnSay("hook", "Save a valid webhook first (Edit).")
        Log("Discord test: no valid webhook saved")
        return
    }
    Log("Discord test: sending")
    try WebhookPost("**AD Bot** test - if you see this, it works. " WebhookStatus(), Screenshot("discord"))
    catch as e {
        Log("Discord test failed: " e.Message)
        ConnSay("hook", "Test failed - see the log.")
        return
    }
    ConnSay("hook", "Test sent - look in your Discord channel.")
}
