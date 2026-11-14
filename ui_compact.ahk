; ui_compact.ahk - compact skin of the main window (style "Wireframe HUD"). Included from ui.ahk.
; Same window, same hits array, same setters as the full skin; UiRender calls CompactRender() when skin = "compact".
; State: [ui] skin = full|compact, [ui] cOpen = open groups (space separated).

CMP_W := 320                               ; logical width of the compact window
CMP_TOP := 104                             ; y of the first group header (header, goal line, timers above)
CMP_GROUPS := [["modes", "MODES"], ["raid", "RAID"], ["infinity", "INFINITY"], ["dimension", "DIMENSION"], ["system", "SYSTEM"]]
; [ui] cScale (1.0-2.0) scales the compact window only, [ui] cAlpha (150-255) is its opacity while the bot is stopped
cScale := IsNumber(IniRead(INI, "ui", "cScale", "1.30")) ? Min(2, Max(1, Number(IniRead(INI, "ui", "cScale", "1.30")))) : 1.30
cAlpha := IsInteger(IniRead(INI, "ui", "cAlpha", "255")) ? Min(255, Max(150, Integer(IniRead(INI, "ui", "cAlpha", "255")))) : 255
CK() => UI_K * cScale
CMP_BG := "050505", CMP_GRAY := "888888", CMP_VAL := "E8E8E8", CMP_RED := "9B111E"

; ------------------------------ light / dark theme ------------------------------
; The light theme is the dark one with every grey turned over (black <-> white, like the video; red accents and gold stay).
; Switching wipes the new look over the old one along a golden diagonal (THEME_MS).
cTheme := IniRead(INI, "ui", "cTheme", "dark") = "light" ? "light" : "dark"
themeV := cTheme = "light" ? 1.0 : 0.0                  ; 0 dark .. 1 light, animated by ThemeTick
themeFrom := themeV, themeAt := 0
tmap := false                                            ; Col() maps colours to the light palette while true
THEME_MS := 750

TCol(hex) {
    static cache := Map()
    if cache.Has(hex)
        return cache[hex]
    v := Integer("0x" hex), r := (v >> 16) & 255, g0 := (v >> 8) & 255, b := v & 255
    if Max(r, g0, b) - Min(r, g0, b) > 60                ; a real colour (red accents, gold): kept
        return cache[hex] := hex
    k := 1 - (r + g0 + b) / 765                           ; dark -> light, light -> dark
    c := Round(255 * k)                                   ; plain grey, no tint: white background, near-black text
    return cache[hex] := Format("{:02X}{:02X}{:02X}", c, c, c)
}

ThemeK() {
    global themeV
    if themeAt {
        u := Min(1, (A_TickCount - themeAt) / THEME_MS)
        e := u < 0.5 ? 4 * u ** 3 : 1 - (-2 * u + 2) ** 3 / 2   ; ease in-out
        themeV := themeFrom + ((cTheme = "light" ? 1 : 0) - themeFrom) * e
    }
    return themeV
}

ThemeToggle(*) {
    global cTheme, themeFrom, themeAt
    themeFrom := ThemeK()
    cTheme := cTheme = "light" ? "dark" : "light"
    themeAt := A_TickCount
    IniWrite cTheme, INI, "ui", "cTheme"
    Log("ui theme = " cTheme)
    SetTimer(ThemeTick, 15)
}

ThemeTick() {
    global themeAt, themeV
    if A_TickCount - themeAt >= THEME_MS {
        themeAt := 0, themeV := cTheme = "light" ? 1.0 : 0.0
        SetTimer(ThemeTick, 0)
    }
    UiRender()
}

; header button: a sun (dark theme, click -> light) that turns into a moon (light theme, click -> dark)
ThemeIcon(cx, cy, k) {
    a := Round(255 * (1 - k))
    if a > 0
        Loop 8 {
            ang := (A_Index - 1) * 0.785 + k * 1.5
            CLine(cx + Cos(ang) * 6.5, cy + Sin(ang) * 6.5, cx + Cos(ang) * 9, cy + Sin(ang) * 9, a)
        }
    Dot(cx - 4.5, cy - 4.5, 9, k < 0.5 ? "FFD36A" : CMP_VAL)
    if k > 0
        Dot(cx - 4.5 + 3.5 * k, cy - 4.5 - 2.5 * k, 9 * k, CMP_BG)
}

; ------------------------------ music ------------------------------
; compact skin + [raid] music=1: a random track from music\ at 1% volume; a new random one each time the skin opens
; and when a track ends. Windows Media Player COM plays m4a without extra codecs.
SetTimer MusicTick, 2000
MusicTick() {
    static wmp := 0, last := ""
    want := false
    try want := skin = "compact" && cfg["music"] = "1" && DllCall("IsWindowVisible", "ptr", g.Hwnd)   ; g may not exist yet at startup
    if !want {
        if wmp
            try wmp.controls.stop()
        wmp := 0
        return
    }
    st := 0
    try st := wmp ? wmp.playState : 0
    if !(st = 0 || st = 1 || st = 8 || st = 10)          ; only undefined / stopped / ended / ready start a new track (not 9 = loading)
        return
    files := []
    Loop Files A_ScriptDir "\music\*.m4a"
        files.Push(A_LoopFileFullPath)
    if !files.Length
        return
    intro := A_ScriptDir "\music\PHANTOM ROAD (128kbit_AAC).m4a"
    first := IniRead(INI, "state", "musicIntro", "0") != "1" && FileExist(intro)
    if first
        f := intro
    else
        Loop 3                                           ; not the same track twice in a row
            if (f := files[Random(1, files.Length)]) != last
                break
    try {
        if !wmp
            wmp := ComObject("WMPlayer.OCX")
        wmp.settings.volume := 1
        wmp.URL := f
        wmp.controls.play()
        last := f
        if first {
            IniWrite "1", INI, "state", "musicIntro"
            Log("music: first launch -> PHANTOM ROAD")
        }
    } catch as e {
        Log("music: " e.Message " - off")
        cfg["music"] := "0"
    }
}

; ------------------------------ skin switch ------------------------------
SetSkin(s) {
    global skin, fading
    skin := s = "compact" ? "compact" : "full"
    IniWrite skin, INI, "ui", "skin"
    Log("ui skin = " skin)
    anim := skin = "compact" && !running && DllCall("IsWindowVisible", "ptr", g.Hwnd)   ; full -> compact: the same fade + unfold as at start
    if anim
        CompactFadePrep(), fading := true
    SkinSize()
    UiRender(true)
    if anim
        CompactFadeStart()
}

; compact -> full skin, straight on the Dimension page (SetSkin does not touch curPage)
OpenDimFull() {
    SetPage("m_dim")
    SetSkin("full")
    Log("ui: compact -> full, Dimension page")
}

; window size for the current skin; compact has square corners (no region), full keeps the round one
SkinSize() {
    global PW, PH
    if skin = "compact" {
        CompactFold("")
        PW := Round(CMP_W * CK()), PH := Round(CompactHeight() * CK())
        g.Move(, , PW, PH)
        DllCall("SetWindowRgn", "ptr", g.Hwnd, "ptr", 0, "int", 1)
    } else {
        PW := Round(GW * UI_K), PH := Round(GH * UI_K)
        g.Move(, , PW, PH)
        DllCall("SetWindowRgn", "ptr", g.Hwnd, "ptr", DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", PW + 1, "int", PH + 1, "int", Round(28 * UI_K), "int", Round(28 * UI_K), "ptr"), "int", 1)
    }
    CompactFit()
    ApplyAlpha()
}

; window opacity: compact is slightly transparent, full stays opaque (not while the fade-in runs)
ApplyAlpha() {
    if fading
        return
    if skin = "compact" && cAlpha < 255 {
        g.Opt("+E0x80000")
        DllCall("SetLayeredWindowAttributes", "ptr", g.Hwnd, "uint", 0, "uchar", cAlpha, "uint", 2)
    } else {
        DllCall("SetLayeredWindowAttributes", "ptr", g.Hwnd, "uint", 0, "uchar", 255, "uint", 2)
        g.Opt("-E0x80000")
    }
}

StepCScale(d) {
    global cScale
    cScale := Round(Min(2, Max(1, cScale + d)), 2)
    IniWrite Format("{:.2f}", cScale), INI, "ui", "cScale"
    Log("setting cScale = " Format("{:.2f}", cScale) " (applies at once)")
    SkinSize()
    UiRender(true)
}

StepCAlpha(d) {
    global cAlpha
    cAlpha := Min(255, Max(150, cAlpha + d))
    IniWrite cAlpha, INI, "ui", "cAlpha"
    Log("setting cAlpha = " cAlpha " (applies at once)")
    ApplyAlpha()
}

; keep the (resized) window inside the work area of the monitor it is on
CompactFit() {
    g.GetPos(&x, &y, &w, &h)
    l := 0, t := 0, r := A_ScreenWidth, b := A_ScreenHeight
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
        if x + w // 2 >= ml && x + w // 2 < mr && y + h // 2 >= mt && y + h // 2 < mb {
            l := ml, t := mt, r := mr, b := mb
            break
        }
    }
    nx := Max(l, Min(x, r - w)), ny := Max(t, Min(y, b - h))
    if nx != x || ny != y
        g.Move(nx, ny)
}

; "Compact mode" switch on the Appearance page (drawn like ToggleRow)
SkinRow(x, y, w) {
    id := "skin_compact"
    on := skin = "compact"
    if IsHot(id)
        FillRR(x, y, w, 52, 12, C.ov, 12)
    Tx("Compact mode", "ui", 14, 1, on ? C.text : C.dim, x + 12, y + 6, w - 90, 22)
    Tx("Small window with folding groups", "ui", 11, 0, C.dim, x + 12, y + 28, w - 90, 18)
    DrawSwitch(x + w - 60, y + 13, on)
    Hit(x, y, w, 52, id, SetSkin.Bind(on ? "full" : "compact"))
}

; ------------------------------ groups ------------------------------
xOpen := false                                           ; the Extreme Dimension sub-group inside DIMENSION (not saved)
XdimFold(*) {
    global xOpen
    xOpen := !xOpen
    SkinSize()
    UiRender(true)
}

CompactOpen(name) => InStr(cOpen, " " name " ") > 0

CompactToggle(name) {
    global cOpen, pickOpen, pickK
    pickOpen := false, pickK := 0.0                         ; folding a group closes the raid picker
    if CompactOpen(name)
        cOpen := StrReplace(cOpen, " " name " ", " ")
    else {
        parts := StrSplit(Trim(RegExReplace(cOpen " " name, "\s+", " ")), " ")
        while parts.Length > 2                               ; max 2 open groups: the oldest one closes
            parts.RemoveAt(1)
        cOpen := " "
        for p in parts
            cOpen .= p " "
        CompactFold(name)
    }
    cOpen := " " Trim(RegExReplace(cOpen, "\s+", " ")) " "
    IniWrite Trim(cOpen), INI, "ui", "cOpen"
    Log("ui group " name " " (CompactOpen(name) ? "open" : "closed"))
    SkinSize()
    UiRender(true)
}

; work area height (logical px) of the monitor the window is on
CompactMaxH() {
    g.GetPos(&x, &y, &w, &h)
    bt := 0, bb := A_ScreenHeight
    Loop MonitorGetCount() {
        MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
        if x + w // 2 >= ml && x + w // 2 < mr {
            bt := mt, bb := mb
            break
        }
    }
    return (bb - bt) / CK()
}

; too tall for the monitor: fold the open groups (not "keep") until it fits
CompactFold(keep) {
    global cOpen
    maxH := CompactMaxH()
    for gp in CMP_GROUPS {
        if CompactHeight() <= maxH
            break
        if gp[1] != keep && CompactOpen(gp[1])
            cOpen := StrReplace(cOpen, " " gp[1] " ", " ")
    }
}

CompactRowH(r) => r.k = "cap" ? 18 : r.k = "chips" ? 26 : 24

CompactHeight() {
    h := CMP_TOP
    for gp in CMP_GROUPS {
        h += 26
        if CompactOpen(gp[1]) {
            for r in CompactRows(gp[1])
                h += CompactRowH(r)
            h += 4
        }
    }
    return h + 10 + 30 + 12
}

; time left to the Infinity exit (infStop) in this hour
CInfLeft() {
    if cfg["infinity"] != "1" || cfg["raid"] = "1" && !RaidNextOk()
        return "—"
    s := StopSec() - SecOfHour()
    return s > 0 ? Format("{:02}:{:02}", s // 60, Mod(s, 60)) : "—"
}

; ------------------------------ row descriptors ------------------------------
CT(key, label, off := false, id := "") => {key: key, label: label, off: off, id: id != "" ? id : "t_" key}
CTog(a, b := "") => {k: "tog", a: a, b: b}
CCap(label) => {k: "cap", label: label}

CStep(label, key, step, lo, hi, div, unit, def, off := false) {
    val := Round(Num(key, def) / div, div = 1 ? 0 : div = 100 ? 2 : 1) (unit = "" ? "" : " " unit)
    return {k: "step", label: label, val: val, id: key, off: off
        , dn: StepCfg.Bind(key, -step, lo, hi, def), up: StepCfg.Bind(key, step, lo, hi, def)}
}

CTime(label, key, step, lo, hi, def) {
    sec := MinSec(cfg[key], def)
    return {k: "step", label: label, val: Format("{:02}:{:02}", sec // 60, Mod(sec, 60)), id: key, off: false
        , dn: StepTime.Bind(key, -step, lo, hi, def), up: StepTime.Bind(key, step, lo, hi, def)}
}

; greyed out and not clickable (a locked row keeps its place)
CLockRow(r) {
    switch r.k {
        case "tog":
            r.a.off := true
            if IsObject(r.b)
                r.b.off := true
        case "chips":
            for it in r.items
                it[4] := true
        case "step":
            r.off := true
        case "btns":
            r.lock := true
    }
}

CompactRows(name) {
    rows := []
    switch name {
        case "modes":
            rows.Push(CTog(CT("raid", "RAID"), CT("speed", "SPEED")))
            rows.Push(CTog(CT("infinity", "INFINITY", cfg["dungeon"] = "1" || cfg["xdim"] = "1"), CT("dungeon", "DIMENSION", cfg["xdim"] = "1")))
            rows.Push(CTog(CT("loadouts", "LOADOUTS"), CT("xdim", "EXTREME")))
        case "raid":
            solo := cfg["soloRaid"] = "1"
            rows.Push({k: "pick", label: "RAID", kind: "raid"})
            rows.Push(CTog(CT("raidCreate", "CREATE ROOM")))      ; own room through Create instead of Group Finder (for raids nobody queues)
            rows.Push(CStep("RAID EVERY", "raidEvery", 1, 1, 6, 1, "h", 1))
            rows.Push(CStep("RAID AT XX:", "raidMin", 5, 0, 55, 1, "", 0))   ; minute when the raid starts (half-hour time zones: 30)
            if cfg["bossAuto"] = "1"                         ; the game's Auto fights: walking, turning and reset settings are unused
                rows.Push(CTog(CT("soloRaid", "SOLO")))
            else {
                rows.Push(CTog(CT("soloRaid", "SOLO"), CT("resetNo5", "RESET NO 5", !SkillOn("5"))))
                rows.Push(CTog(CT("resetThird", "RESET 3RD")))
                rows.Push(CStep("SENSITIVITY", "camSens", 1, 1, 200, 100, "", 36))
                rows.Push(CStep("WALK TO BOSS", "raidWalk", 500, 0, 8000, 1000, "s", 3000))
                rows.Push(CStep("SPEED WALK", "speedWalk", 500, 0, 10000, 1000, "s", 2000))
                rows.Push(CStep("RESPAWN WALK", "respawnWalk", 500, 0, 10000, 1000, "s", 3000))
                rows.Push(CStep("WALK OTHER", "respawnWalkOther", 500, 0, 10000, 1000, "s", 0))
            }
            rows.Push(CStep("PARTY WAIT", "startDelay", 1, 0, 30, 1, "s", 10, solo))
            rows.Push(CStep("EARLY START", "startBonus", 10, 0, 300, 1, "%", 110, solo))
            if cfg["bossAuto"] != "1"
                rows.Push(CStep("CAMERA TURN", "respawnTurn", 5, 35, 155, 1, "°", 95))
        case "infinity":
            ga := cfg["infGameAuto"] = "1"                   ; the game's Auto fights: AOE settings are locked
            rows.Push(CTog(CT("infGameAuto", "GAME AUTO")))
            rows.Push(CStep("RUN TIME", "infRunMin", 1, 0, 59, 1, "min", 0))   ; leave Infinity after this many minutes and enter again (0 = off)
            rows.Push(CStep("AOE PAUSE", "spreadMs", 500, 1000, 20000, 1000, "s", 7000, ga))
            rows.Push(CStep("AUTO IF STUCK", "infAuto", 5000, 0, 60000, 1000, "s", 15000, ga))
            rows.Push(CCap("BIG AOE SKILLS"))
            items := []
            for k in SKILL_KEYS
                items.Push([StrUpper(k), InStr(" " cfg["spread"] " ", " " k " ") > 0, ToggleList.Bind("spread", k), !SkillOn(k) || ga, "sp_" k])
            rows.Push({k: "chips", items: items})
        case "dimension":
            rows.Push(CTog(CT("dungeon", "DIM ON", false, "t2_dungeon"), CT("dimFight", "KEEP FIGHT")))
            rows.Push({k: "pick", label: "DIMENSION", kind: "dim"})        ; the list of every Dimension (drop-up, like the raid picker)
            rows.Push(CStep("START DELAY", "dimShift", 100, 0, 5000, 1000, "s", 0))
            rows.Push({k: "chips", items: [["SLOT 1", !InStr("2345", cfg["dimMethod"]), PickDimMethod.Bind("1"), false, "dm_1"], ["SLOT 2", cfg["dimMethod"] = "2", PickDimMethod.Bind("2"), false, "dm_2"]]})
            rows.Push({k: "chips", items: [["SLOT 3", cfg["dimMethod"] = "3", PickDimMethod.Bind("3"), false, "dm_3"], ["SLOT 4", cfg["dimMethod"] = "4", PickDimMethod.Bind("4"), false, "dm_4"], ["SLOT 5", cfg["dimMethod"] = "5", PickDimMethod.Bind("5"), false, "dm_5"]]})
            rows.Push({k: "btns", items: [["EDIT RUN", DimEdit], ["FOLDER", (*) => OpenPath(DimDir(DimKindUi()))]]})
            if cfg["xdim"] = "1"                              ; Extreme on: the plain Dimension is greyed out (like Infinity under Dimension)
                for r0 in rows
                    CLockRow(r0)
            rows.Push({k: "sub", t: CT("xdim", "EXTREME DIM"), open: xOpen})
            if xOpen {
                n0 := rows.Length
                rows.Push({k: "chips", items: [["EASY", cfg["xdimPick"] = "1", PickXdim.Bind("1"), false, "xd_1"], ["NORMAL", cfg["xdimPick"] = "2", PickXdim.Bind("2"), false, "xd_2"], ["NIGHTMARE", cfg["xdimPick"] = "3", PickXdim.Bind("3"), false, "xd_3"], ["EXTREME", cfg["xdimPick"] = "4", PickXdim.Bind("4"), false, "xd_4"]]})
                rows.Push(CStep("WAIT AFTER START", "xdimWait", 1, 5, 60, 1, "s", 15))
                xm := XdimMap()                               ; today's map, < > fix it (each map has its own run)
                rows.Push({k: "step", label: "TODAY'S MAP", val: StrUpper(xm) " " XdimPos(), id: "xdmap", off: false
                    , dn: XdimShift.Bind(-1), up: XdimShift.Bind(1)})
                rows.Push({k: "cap", label: (FileExist(DimDir("xdim", true) "log.txt") ? "RUN RECORDED" : "NO RUN YET") " · NEXT: " StrUpper(XdimMap(1))})
                rows.Push({k: "btns", pre: "x", items: [["EDIT RUN", DimEditK.Bind("xdim")], ["FOLDER", (*) => OpenPath(A_ScriptDir "\dimension")]]})
                if cfg["xdim"] != "1"                         ; Extreme off: its settings are greyed out
                    Loop rows.Length - n0
                        CLockRow(rows[n0 + A_Index])
            }
            rows.Push({k: "act", label: "CHARACTER & STATS", fn: OpenDimFull})
        case "system":
            rows.Push(CTime("LEAVE AT", "infStop", 30, 600, 3480, 57 * 60 + 30))   ; all modes: the second of the hour when the bot leaves for the raid
            rows.Push(CTog(CT("sfx", "SOUNDS"), CT("music", "MUSIC")))
            rows.Push({k: "step", label: "SIZE", val: Format("{:.2f}x", cScale), id: "cscale", off: false
                , dn: StepCScale.Bind(-0.05), up: StepCScale.Bind(0.05)})
            rows.Push({k: "step", label: "OPACITY", val: Round(cAlpha / 255 * 100) "%", id: "calpha", off: false
                , dn: StepCAlpha.Bind(-5), up: StepCAlpha.Bind(5)})
            rows.Push({k: "btns", items: [["LOG", OpenPath.Bind(LOGFILE)], ["INI", OpenPath.Bind(INI)], ["SHOTS", OpenPath.Bind(SHOTDIR)]]})
            rows.Push({k: "btns", items: [["SERVER LINK", EditServerLink], ["DISCORD", EditWebhook]]})
            rows.Push({k: "act", label: "FULL UI", fn: SetSkin.Bind("full")})
    }
    return rows
}

; ------------------------------ drawing primitives ------------------------------
CRect(x, y, w, h, hex, a := 255) {
    DllCall("gdiplus\GdipCreateSolidFill", "uint", Col(hex, a), "ptr*", &br := 0)
    DllCall("gdiplus\GdipFillRectangle", "ptr", gr, "ptr", br, "float", x, "float", y, "float", w, "float", h)
    DllCall("gdiplus\GdipDeleteBrush", "ptr", br)
}

CLine(x1, y1, x2, y2, a := 255) {
    DllCall("gdiplus\GdipCreatePen1", "uint", Col("FFFFFF", a), "float", 1, "int", 2, "ptr*", &pen := 0)
    DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", x1, "float", y1, "float", x2, "float", y2)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
}

CFrame(x, y, w, h, hex, a := 255) {
    DllCall("gdiplus\GdipCreatePen1", "uint", Col(hex, a), "float", 1, "int", 2, "ptr*", &pen := 0)
    DllCall("gdiplus\GdipDrawRectangle", "ptr", gr, "ptr", pen, "float", x + 0.5, "float", y + 0.5, "float", w - 1, "float", h - 1)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
}

CDots(x1, x2, y) {
    if x2 - x1 < 6
        return
    DllCall("gdiplus\GdipCreatePen1", "uint", Col("FFFFFF", 50), "float", 1, "int", 2, "ptr*", &pen := 0)
    DllCall("gdiplus\GdipSetPenDashStyle", "ptr", pen, "int", 2)
    DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", x1, "float", y, "float", x2, "float", y)
    DllCall("gdiplus\GdipDeletePen", "ptr", pen)
}

; letter-spaced mono text (GDI+ has no tracking): one glyph at a time; returns the x where the text ends
LTx(text, px, hex, x, y, w, h, sp := 1, align := 0, bold := 0, a := 255, glow := false) {
    static adv := Map(), pt := Buffer(8)
    key := px "|" bold
    if !adv.Has(key)
        adv[key] := TxW("MM", "mono", px, bold) - TxW("M", "mono", px, bold)
    st := adv[key] + sp
    n := StrLen(text)
    tw := n * st - sp
    x0 := align = 1 ? x + (w - tw) / 2 : align = 2 ? x + w - tw : x
    ; white neon: always when glow (an open group), else while the mouse is anywhere on this row of the compact window
    ; (StarTick repaints every 200 ms, so it follows the mouse)
    if !glow && skin = "compact" && DllCall("IsWindowVisible", "ptr", g.Hwnd) {
        DllCall("GetCursorPos", "ptr", pt)
        DllCall("ScreenToClient", "ptr", g.Hwnd, "ptr", pt)
        kc := CK(), mx := NumGet(pt, 0, "int") / kc, my := NumGet(pt, 4, "int") / kc
        glow := mx >= 0 && mx < CMP_W && my >= y - 3 && my < y + h + 3
    }
    Loop n {
        ch := SubStr(text, A_Index, 1)
        if ch = " "
            continue
        gx := x0 + (A_Index - 1) * st
        Tx(ch, "mono", px, bold, hex, gx, y, st + 4, h, 0, a)
        if glow {
            for o in [[-1, 0], [1, 0], [0, -1], [0, 1]]      ; soft halo around the glyph
                Tx(ch, "mono", px, bold, "FFFFFF", gx + o[1], y + o[2], st + 4, h, 0, Round(70 * a / 255))
            Tx(ch, "mono", px, bold, "FFFFFF", gx, y, st + 4, h, 0, Round(210 * a / 255))
        }
    }
    return x0 + tw
}

; ------------------------------ frame ------------------------------
CompactRender() {
    global gr, uiBmp, tmap
    kc := CK()
    if PH != Round(CompactHeight() * kc) || PW != Round(CMP_W * kc)
        SkinSize()
    k := ThemeK()
    if k <= 0 || k >= 1 {
        tmap := k >= 1
        cv := CompactPaint()
    } else {                                              ; switching: the light frame is wiped over the dark one along a golden diagonal
        tmap := false
        cv := CompactPaint()
        tmap := true
        lt := CompactPaint()
        tmap := false
        gr := cv[2]
        DllCall("gdiplus\GdipResetWorldTransform", "ptr", gr)
        pos := -30 * kc + (PW + PH + 60 * kc) * k
        DllCall("gdiplus\GdipCreateTexture", "ptr", lt[1], "int", 0, "ptr*", &tb := 0)
        pts := Buffer(32)
        NumPut("float", 0, "float", 0, "float", pos, "float", 0, "float", pos - PH, "float", PH, "float", 0, "float", PH, pts)
        DllCall("gdiplus\GdipFillPolygon", "ptr", gr, "ptr", tb, "ptr", pts, "int", 4, "int", 0)
        DllCall("gdiplus\GdipDeleteBrush", "ptr", tb)
        DllCall("gdiplus\GdipDeleteGraphics", "ptr", lt[2])
        DllCall("gdiplus\GdipDisposeImage", "ptr", lt[1])
        for w in [[18, 35], [8, 90], [2.5, 240]] {         ; the golden edge: soft glow, then a bright core
            DllCall("gdiplus\GdipCreatePen1", "uint", Col("FFD36A", w[2]), "float", w[1] * kc, "int", 2, "ptr*", &pen := 0)
            DllCall("gdiplus\GdipDrawLine", "ptr", gr, "ptr", pen, "float", pos, "float", 0, "float", pos - PH, "float", PH)
            DllCall("gdiplus\GdipDeletePen", "ptr", pen)
        }
        Loop 6 {                                          ; sparks riding the edge
            u := Mod(A_Index * 0.173 + k * 2.3, 1)
            Dot(pos - PH * u - 3 * kc + Sin(A_TickCount / 90 + A_Index) * 6 * kc, PH * u - 3 * kc, 6 * kc, "FFF4C8", 220)
        }
    }
    tmap := false
    hbm := ToHbm(cv)
    gr := 0
    if uiBmp
        DllCall("DeleteObject", "ptr", uiBmp)
    uiBmp := hbm
    UiBlit()
}

; one full frame of the compact window in the current palette (tmap); returns the canvas
CompactPaint() {
    global gr, hits
    kc := CK()
    cv := Canvas(PW, PH, CMP_BG)
    gr := cv[2]
    DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", kc, "float", kc, "int", 0)
    hits := []
    W := CMP_W, H := PH / kc
    GRY := CMP_GRAY, VAL := CMP_VAL, RED := CMP_RED
    if tmap                                               ; light: a thin gold rim (the video's golden glow)
        CFrame(1, 1, W - 2, H - 2, "E0A93C", 110)
    CFrame(0, 0, W, H, "FFFFFF", 140)
    ; header (drag area: empty parts of y < 62 start a window drag in UiClick)
    LTx("AD/BOT", 10, GRY, 12, 8, 120, 16, 2)
    if !UpdateAvail()                                        ; the UPDATE pill takes this place
        Tx("v" APP_VERSION " PUBLIC VERSION", "mono", 10, 0, GRY, W - 228, 8, 160, 16, 2)
    else {                                       ; 14.11: a newer build is on GitHub (update.ahk)
        CRect(W - 150, 5, 84, 20, "3DD68C", IsHot("update") ? 255 : 200)
        Tx("UPDATE", "ui", 11, 1, "06210F", W - 150, 5, 84, 20, 1)
        Hit(W - 150, 5, 84, 20, "update", UpdateRun)
    }
    for b in [["min", W - 58], ["close", W - 32]] {         ; same actions as the full UI window buttons
        if IsHot(b[1])
            CRect(b[2], 4, 22, 20, "FFFFFF", 20)
        if b[1] = "min"
            CLine(b[2] + 6, 16, b[2] + 16, 16)
        else {
            CLine(b[2] + 6, 9, b[2] + 16, 19)
            CLine(b[2] + 6, 19, b[2] + 16, 9)
        }
        Hit(b[2], 4, 22, 20, b[1], b[1] = "min" ? (() => g.Minimize()) : (() => ExitApp()))
    }
    if IsHot("theme")                                        ; light / dark switch
        CRect(93, 4, 22, 20, "FFFFFF", 20)
    ThemeIcon(104, 14, ThemeK())
    Hit(93, 4, 22, 20, "theme", ThemeToggle)
    CRect(12, 28, W - 24, 1, "FFFFFF", 50)
    ; goal line
    Dot(12, 45, 10, "444444")                                ; window is shown only while stopped: last run state
    gk := GoalKey()
    tag := gk = "raid" ? "RAID" : gk = "speed" ? "SPD" : gk = "infinity" ? "INF" : gk = "dungeon" ? "DIM" : "IDLE"
    LTx(tag, 22, VAL, 30, 34, 170, 32, 2, 0, 1)
    LTx("RUN " SessRuns(), 10, GRY, W - 112, 38, 100, 24, 1, 2)
    ; progress line: Infinity time against infStop
    CRect(12, 70, W - 24, 1, "FFFFFF", 64)
    if runGoal = "infinity"
        CRect(12, 70, Round((W - 24) * Min(1, SecOfHour() / Max(1, StopSec()))), 1, "FFFFFF")
    ; timers
    for i, t in [["RAID", dRaid], ["SPD", dSpeed]] {
        tcx := 12 + (i - 1) * 99
        Tx(t[1], "mono", 10, 0, GRY, tcx, 76, 36, 20)
        Tx(t[2], "mono", 10, 1, VAL, tcx + 34, 76, 62, 20)
    }
    CRect(12, 100, W - 24, 1, "FFFFFF", 50)
    ; groups
    y := CMP_TOP
    for gp in CMP_GROUPS {
        open := CompactOpen(gp[1])
        id := "cg_" gp[1]
        if IsHot(id)
            CRect(0, y, W, 26, "FFFFFF", 12)
        LTx(gp[2], 11, open ? VAL : GRY, 12, y, 200, 26, 2, 0, 0, 255, open)
        Tx(open ? "[-]" : "[+]", "mono", 11, 1, RED, W - 48, y, 36, 26, 2)
        Hit(0, y, W, 26, id, CompactToggle.Bind(gp[1]))
        y += 26
        if open {
            for r in CompactRows(gp[1]) {
                CompactRow(r, y)
                y += CompactRowH(r)
            }
            y += 4
        }
        CRect(12, y - 1, W - 24, 1, "FFFFFF", 50)
    }
    ; bottom: START / STOP and the switch back to the full window
    by := y + 10, bw := W - 24 - 30 - 6
    CFrame(12, by, bw, 30, "FFFFFF", IsHot("run") ? 255 : 170)
    LTx(running ? "STOP" : "START", 12, VAL, 12, by, bw, 30, 4, 1, 1)
    Hit(12, by, bw, 30, "run", ToggleRun)
    sx := W - 12 - 30
    CFrame(sx, by, 30, 30, "FFFFFF", IsHot("skin_full") ? 255 : 170)
    for ly in [9, 14, 19]
        CRect(sx + 8, by + ly, 14, 1, "FFFFFF")
    Hit(sx, by, 30, 30, "skin_full", SetSkin.Bind("full"))
    if pickK > 0
        CompactPickOverlay(W, by)
    ; corner brackets
    CRect(0, 0, 10, 2, "FFFFFF"), CRect(0, 0, 2, 10, "FFFFFF")
    CRect(W - 10, H - 2, 10, 2, "FFFFFF"), CRect(W - 2, H - 10, 2, 10, "FFFFFF")
    return cv
}

CompactRow(r, y) {
    global pickY
    W := CMP_W
    switch r.k {
        case "tog":
            CToggle(r.a, 22, y)
            if IsObject(r.b)
                CToggle(r.b, 166, y)
        case "sub":
            ; the whole row right of the EXTREME DIM checkbox text folds the sub-group (lit on hover, like a group header)
            static adv := TxW("MM", "mono", 10, 0) - TxW("M", "mono", 10, 0)
            fx := 18 + Min(140, 16 + StrLen(r.t.label) * (adv + 1) + 10)
            if IsHot("xd_open")
                CRect(fx, y + 1, W - fx, 22, "FFFFFF", 12)
            CToggle(r.t, 22, y)
            Tx(r.open ? "[-]" : "[+]", "mono", 11, 1, CMP_RED, W - 48, y, 36, 24, 2)
            Hit(fx, y, W - fx, 24, "xd_open", XdimFold)
        case "cap":
            LTx(r.label, 9, CMP_GRAY, 22, y, 280, 18, 1, 0, 0, 160)
        case "step":
            a := r.off ? 100 : 255
            ex := LTx(r.label, 10, CMP_GRAY, 22, y, 170, 24, 1, 0, 0, a)
            vx := W - 12 - 120
            CDots(ex + 6, vx - 4, y + 17)
            hl := !r.off && IsHot("dn_" r.id), hr := !r.off && IsHot("up_" r.id)
            Tx("‹", "mono", 12, 0, hl ? CMP_VAL : CMP_GRAY, vx, y, 18, 24, 1, a)
            Tx(r.val, "mono", 11, 1, CMP_VAL, vx + 18, y, 84, 24, 1, a)
            Tx("›", "mono", 12, 0, hr ? CMP_VAL : CMP_GRAY, vx + 102, y, 18, 24, 1, a)
            if !r.off {
                Hit(vx, y, 60, 24, "dn_" r.id, r.dn)
                Hit(vx + 60, y, 60, 24, "up_" r.id, r.up)
            }
        case "chips":
            n := r.items.Length
            cw := (296 - (n - 1) * 4) / n
            for i, it in r.items {
                ccx := 12 + (i - 1) * (cw + 4)
                lock := it[4]
                CFrame(ccx, y + 3, cw, 20, "FFFFFF", lock ? 30 : it[2] ? 255 : 77)
                if IsHot(it[5]) && !lock
                    CRect(ccx, y + 3, cw, 20, "FFFFFF", 14)
                Tx(it[1], "mono", 11, it[2], it[2] && !lock ? CMP_RED : CMP_GRAY, ccx, y + 3, cw, 20, 1, lock ? 100 : 255)
                if !lock
                    Hit(ccx, y + 3, cw, 20, it[5], it[3])
            }
        case "btns":
            n := r.items.Length
            bw := (296 - (n - 1) * 6) / n
            lk := r.HasProp("lock") && r.lock
            for i, it in r.items {
                bx := 12 + (i - 1) * (bw + 6)
                id := "cb_" (r.HasProp("pre") ? r.pre : "") it[1]
                CFrame(bx, y + 2, bw, 20, "FFFFFF", lk ? 30 : IsHot(id) ? 255 : 90)
                LTx(it[1], 10, lk ? CMP_GRAY : CMP_VAL, bx, y + 2, bw, 20, 2, 1, 0, lk ? 100 : 255)
                if !lk
                    Hit(bx, y + 2, bw, 20, id, it[2])
            }
        case "pick":
            pickY := y
            LTx(r.label, 10, CMP_GRAY, 22, y, 80, 24, 1)
            bx := 96, bw := W - 12 - bx
            CFrame(bx, y + 2, bw, 20, "FFFFFF", IsHot("pick_" r.kind) || pickOpen && pickKind = r.kind ? 255 : 120)
            Tx(r.kind = "dim" ? StrUpper(DimShort(DimKindUi())) : RaidShort(cfg["raidName"]), "mono", 11, 1, CMP_RED, bx + 6, y + 2, bw - 30, 20, 0)
            Tx(pickOpen ? "v" : "^", "mono", 11, 1, CMP_VAL, bx + bw - 22, y + 2, 18, 20, 1)
            Hit(bx, y + 2, bw, 20, "pick_" r.kind, PickShow.Bind(r.kind))
        case "act":
            id := "act_" r.label
            if IsHot(id)
                CRect(0, y, W, 24, "FFFFFF", 12)
            LTx(r.label, 10, CMP_VAL, 22, y, 200, 24, 2)
            Tx("›", "mono", 12, 0, CMP_VAL, W - 30, y, 18, 24, 1)
            Hit(0, y, W, 24, id, r.fn)
    }
}

;------------------------------ raid picker ------------------------------
; Drop-up list over the lower part of the window: grows from the bottom edge upwards (ease-out, about 0.25 s).
; While it is open a full-window hit closes it, so a click anywhere else does not reach the rows under it.
PickToggle(*) {
    global pickOpen
    pickOpen := !pickOpen
    SetTimer(PickStep, 15)
}

PickStep() {
    global pickK
    pickK := pickOpen ? Min(1, pickK + 0.1) : Max(0, pickK - 0.14)
    if pickK = (pickOpen ? 1 : 0)
        SetTimer(PickStep, 0)
    UiRender()
}

; which list the drop-up shows: "raid" or "dim"
PickShow(kind, *) {
    global pickKind
    pickKind := kind
    PickToggle()
}

PickChoose(k, *) {
    if pickKind = "dim"
        PickDimName(k)
    else
        PickRaid(k)
    PickToggle()
}

CompactPickOverlay(W, by) {
    kk := 1 - (1 - pickK) ** 3
    keys := [], rh := 22
    dim := pickKind = "dim"
    if dim
        keys := DIM_ORDER
    else
        for k in RAIDS
            keys.Push(k)
    cols := dim ? 2 : 1, per := Ceil(keys.Length / cols), cwid := (W - 24) / cols      ; Dimensions: two columns (14 names do not fit in one)
    full := per * rh + 8
    bot := by - 6
    hh := Round(Min(full, bot - 30) * kk)
    top := bot - hh
    CRect(10, top, W - 20, hh, CMP_BG)
    CFrame(10, top, W - 20, hh, "FFFFFF", 200)
    if pickOpen
        Hit(0, 0, W, bot + 40, "pick_close", PickToggle)
    for i, k in keys {
        ry := top + 4 + Mod(i - 1, per) * rh, rx := 12 + ((i - 1) // per) * cwid
        if ry + rh > bot - 2 || ry + rh > top + hh
            continue
        on := (dim ? DimKindUi() : cfg["raidName"]) = k, id := "pk_" k
        if IsHot(id) && pickOpen
            CRect(rx, ry, cwid, rh, "FFFFFF", 16)
        if on
            CRect(rx + 4, ry + 8, 5, 5, CMP_RED)
        LTx(StrUpper(dim ? DimShort(k) : RaidShort(k)), 10, on ? CMP_VAL : CMP_GRAY, rx + 16, ry, cwid - 20, rh, 1)
        if pickOpen
            Hit(rx, ry, cwid, rh, id, PickChoose.Bind(k))
    }
}

; "■ NAME" (on) / "□ NAME" (off, dimmed); locked items are not clickable
CToggle(t, x, y) {
    on := cfg[t.key] = "1" && !t.off
    id := t.id
    static adv10 := TxW("MM", "mono", 10, 0) - TxW("M", "mono", 10, 0)
    bw := Min(140, 16 + StrLen(t.label) * (adv10 + 1) + 10)     ; the highlight and the click area: the text, not the whole half row
    if !t.off && IsHot(id)
        CRect(x - 4, y + 1, bw, 22, "FFFFFF", 14)
    CFrame(x, y + 7, 10, 10, "FFFFFF", t.off ? 30 : on ? 255 : 77)
    if on
        CRect(x + 3, y + 10, 4, 4, CMP_RED)
    LTx(t.label, 10, on ? CMP_VAL : CMP_GRAY, x + 16, y, 122, 24, 1, 0, 0, t.off ? 100 : 255)
    if !t.off
        Hit(x - 4, y, bw, 24, id, FlipKey.Bind(t.key))
}

; ------------------------------ fade-in of the compact window (bot stopped only) ------------------------------
fadeA := 0, fading := false
pickKind := "raid"
pickOpen := false, pickK := 0.0, pickY := 0                  ; raid picker (RAID group): drop-up list that slides up from the bottom

; what the bot is doing / did last: the mode it entered, else the goal of the run
GoalKey() => lastEntered != "" ? lastEntered : runGoal

CompactFadePrep() {
    g.Opt("+E0x80000")                                       ; layered, fully transparent until shown
    DllCall("SetLayeredWindowAttributes", "ptr", g.Hwnd, "uint", 0, "uchar", 0, "uint", 2)
}

CompactFadeStart() {
    global fadeA, fading
    fadeA := 0, fading := true
    SetTimer(CompactFadeStep, 20)
}

CompactFadeStep() {
    global fadeA, fading
    fadeA += 20                                              ; about 13 steps of 20 ms
    if running || fadeA >= cAlpha || skin != "compact" || !DllCall("IsWindowVisible", "ptr", g.Hwnd) {
        SetTimer(CompactFadeStep, 0)
        fading := false
        if skin = "compact"
            g.Move(, , , PH)                                 ; full height again
        ApplyAlpha()                                         ; ends at cAlpha
        return
    }
    k := 1 - (1 - fadeA / cAlpha) ** 3                       ; ease-out
    g.Move(, , , Round(PH * (0.35 + 0.65 * k)))              ; unfolds downwards while it fades in
    DllCall("SetLayeredWindowAttributes", "ptr", g.Hwnd, "uint", 0, "uchar", fadeA, "uint", 2)
}

; ------------------------------ hotbar, style "Monoline" (compact skin, bot running) ------------------------------
; Solid black strip (no alpha: the bot reads the screen colours), 1px faint border, fixed size, not scaled by UI_K.
; Click-through like the old mini bar. Drawn with GDI+ into a bitmap and BitBlt, redrawn only when its content changes.
HB_W := 600, HB_H := 24
sumG := 0                                   ; session summary window (summary.ahk); here so UiClick / UiPaint can read it early
hb := 0, hbW := HB_W, hbKey := "", hbBmp := 0
hbPulse := 0                                ; toggled by UiTick (500 ms)
runGoal := ""                               ; goal of the running bot, set by Target()

HotbarShow() {
    global hb, hbW, hbKey
    if !hb {
        hb := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 -DPIScale")
        hb.BackColor := "000000"
    }
    hbW := Min(HB_W, GAME_W - 40)
    hb.Show("x" ((GAME_W - hbW) // 2) " y24 w" hbW " h" HB_H " NoActivate")
    DllCall("SetWindowRgn", "ptr", hb.Hwnd, "ptr", DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", hbW + 1, "int", HB_H + 1, "int", 24, "int", 24, "ptr"), "int", 1)
    hbKey := ""
    MiniUpdate()
}

HotbarHide() {
    if hb
        hb.Hide()
}

HotbarDraw(raidT, speedT, status) {
    global hbKey, hbBmp, gr
    if !hb || !running
        return
    pulse := hbPulse
    goal := cfg["fightOnly"] = "1" ? "fight" : GoalKey()
    gt := goal = "raid" ? "Raid" : goal = "speed" ? "Speed" : goal = "infinity" ? "Inf" : goal = "dungeon" ? "Dim" : goal = "fight" ? "Fight" : "Idle"
    head := gt " · run " SessRuns()
    key := pulse "|" head "|" raidT "|" speedT "|" status "|" hbW
    if key != hbKey || !hbBmp {
        hbKey := key
        real := gr
        cv := Canvas(hbW, HB_H, "000000")
        gr := cv[2]
        StrokeRR(0, 0, hbW, HB_H, 12, "FFFFFF", 51)
        Dot(12, 8, 8, "9B111E", pulse ? 255 : 110)
        x := 28
        Tx(head, "title", 11, 0, "DDDDDD", x, 0, 220, HB_H)
        x += TxW(head, "title", 11, 0) + 14
        if raidT != "" {
            t := "raid " raidT
            Tx(t, "title", 11, 0, "777777", x, 0, 120, HB_H)
            x += TxW(t, "title", 11, 0) + 14
        }
        if speedT != "" {
            t := "spd " speedT
            Tx(t, "title", 11, 0, "777777", x, 0, 120, HB_H)
            x += TxW(t, "title", 11, 0) + 14
        }
        rw := TxW("F2 · F3", "title", 11, 0)
        Tx("F2 · F3", "title", 11, 0, "666666", hbW - 14 - rw, 0, rw + 6, HB_H, 2)
        if hbW - 14 - rw - 12 - x > 20
            Tx(status, "title", 11, 0, "DDDDDD", x, 0, hbW - 14 - rw - 12 - x, HB_H)   ; cut with an ellipsis (StrFmt trimming)
        hbmNew := ToHbm(cv)
        gr := real
        if hbBmp
            DllCall("DeleteObject", "ptr", hbBmp)
        hbBmp := hbmNew
    }
    HotbarBlit()
}

; copy the cached bar onto its window (also called from WM_PAINT with the paint hdc)
HotbarBlit(hdc := 0) {
    if !hbBmp
        return
    own := !hdc
    if own
        hdc := DllCall("GetDC", "ptr", hb.Hwnd, "ptr")
    mdc := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", hbBmp, "ptr")
    DllCall("BitBlt", "ptr", hdc, "int", 0, "int", 0, "int", hbW, "int", HB_H, "ptr", mdc, "int", 0, "int", 0, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", old)
    DllCall("DeleteDC", "ptr", mdc)
    if own
        DllCall("ReleaseDC", "ptr", hb.Hwnd, "ptr", hdc)
}
