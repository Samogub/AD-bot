; summary.ahk - session counters and the summary window shown after Stop (F2 / STOP button).
; Window: HUD 2.0 card (rounded, theme colours C.*, head/ui/mono fonts), drawn into a bitmap; a click anywhere closes it.

sessStart := 0, sessMs := 0, sessFrom := "", sessTo := ""
sumBmp := 0, sumPW := 0, sumPH := 0

SessRuns() => sess["raids"] + sess["speedRuns"] + sess["infRuns"] + sess["dimRuns"]

SessBegin() {
    global sessStart, sessMs, sessFrom, sessTo
    sessStart := A_TickCount, sessMs := 0, sessFrom := A_Now, sessTo := ""
    SummaryHide()
}

SessEnd() {
    global sessStart, sessMs, sessTo
    if sessStart
        sessMs := A_TickCount - sessStart
    sessStart := 0, sessTo := A_Now
}

SessDur(ms) {
    m := ms // 60000
    return (m // 60) "h " Format("{:02}", Mod(m, 60)) "m"
}

SessLogLine() => "RUN SUMMARY: raid " sess["raids"] " (gems " sess["raidGems"] ", tokens " sess["raidTokens"] ")"
    . ", speed " sess["speedRuns"] " (gems " sess["speedGems"] ", tokens " sess["speedTokens"] ")"
    . ", Infinity " sess["infRuns"] ", Dimension " sess["dimRuns"] " (gems " sess["dimGems"] ")"
    . ", Roblox restarts " sess["restarts"] ", session " SessDur(sessMs)

; per hour, "—" for a session shorter than 1 h
PerHour(n) => sessMs >= 3600000 ? String(Round(n / (sessMs / 3600000))) : "—"

SummaryHide() {
    if sumG
        sumG.Hide()
}

; draws the card (HUD 2.0 look, colours C.* of the active theme) into sumBmp; used by SummaryShow and "shots summary"
SummaryDraw() {
    global sumBmp, sumPW, sumPH, gr
    W := 360, H := 326
    SK := CK() * 1.2 * 0.85                              ; follows the HUD SIZE setting; 1.2 (text was small), then -15%
    sumPW := Round(W * SK), sumPH := Round(H * SK)
    real := gr
    cv := Canvas(sumPW, sumPH, C.bg)
    gr := cv[2]
    DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", SK, "float", SK, "int", 0)
    FillRR(0, 0, W, H, 16, C.sb)
    GradRR(0, 0, W, H, 16, C.g1, 140, C.g1, 0, true)
    StrokeRR(0, 0, W, H, 16, C.lin, 110)
    ; header: title, session length, start - end
    Dot(18, 23, 8, C.on)
    Tx("Session", "head", 18, 1, C.text, 32, 14, 150, 26)
    Tx(SessDur(sessMs), "mono", 14, 1, C.hi, W - 146, 14, 130, 26, 2)
    from := sessFrom != "" ? FormatTime(sessFrom, "HH:mm") : "--:--", to := sessTo != "" ? FormatTime(sessTo, "HH:mm") : "--:--"
    Tx(from " - " to, "mono", 11, 0, C.dim, 32, 40, 200, 18)
    FillRR(16, 66, W - 32, 1, 0.5, C.lin, 60)
    ; table: right edges of the number columns
    cols := [["Runs", 168], ["Gems", 224], ["Tokens", 280], ["Gems/h", 336]]
    Tx("MODE", "ui", 10, 1, C.dim, 28, 74, 80, 18)
    for cc in cols
        Tx(StrUpper(cc[1]), "ui", 10, 1, C.dim, cc[2] - 56, 74, 56, 18, 2)
    rows := [["Raids", sess["raids"], sess["raidGems"], sess["raidTokens"]]
           , ["Speed Raids", sess["speedRuns"], sess["speedGems"], sess["speedTokens"]]
           , ["Infinity", sess["infRuns"], "", ""]
           , ["Dimension", sess["dimRuns"], sess["dimGems"], ""]]
    y := 94
    for r in rows {
        FillRR(16, y, W - 32, 28, 10, C.field, 190)
        StrokeRR(16, y, W - 32, 28, 10, C.lin, 28)
        Tx(r[1], "ui", 12, 1, C.text, 28, y, 90, 28)
        vals := [String(r[2]), r[3] = "" ? "—" : String(r[3]), r[4] = "" ? "—" : String(r[4]), r[3] = "" ? "—" : PerHour(r[3])]
        for i, cc in cols
            Tx(vals[i], "mono", 12, i = 1, vals[i] = "—" ? C.dim : (i = 1 ? C.hi : i = 4 ? C.on : C.text), cc[2] - 56, y, 56, 28, 2)
        y += 32
    }
    ; tiles: total gems, total tokens, Roblox restarts
    gems := sess["raidGems"] + sess["speedGems"] + sess["dimGems"], toks := sess["raidTokens"] + sess["speedTokens"]
    tiles := [["Gems", String(gems), PerHour(gems) " /h"], ["Tokens", String(toks), PerHour(toks) " /h"], ["Restarts", String(sess["restarts"]), "Roblox"]]
    y += 4
    for i, t in tiles {
        x := 16 + (i - 1) * 112
        FillRR(x, y, 104, 62, 12, C.card, 255)
        GradRR(x, y, 104, 62, 12, C.g1, 110, C.g1, 0, true)
        StrokeRR(x, y, 104, 62, 12, C.lin, 70)
        Tx(StrUpper(t[1]), "ui", 10, 1, C.dim, x + 12, y + 6, 80, 16)
        Tx(t[2], "head", 20, 1, C.hi, x + 12, y + 20, 84, 26)
        Tx(t[3], "mono", 10, 0, C.dim, x + 12, y + 44, 84, 14)
    }
    Tx("CLICK ANYWHERE TO CLOSE", "ui", 9, 0, C.dim, 16, H - 22, W - 32, 14, 1, 190)
    hbmNew := ToHbm(cv)
    gr := real
    if sumBmp
        DllCall("DeleteObject", "ptr", sumBmp)
    sumBmp := hbmNew
}

SummaryShow() {
    global sumG, sumPW, sumPH
    if !sumG {
        sumG := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
        sumG.BackColor := C.bg
    }
    SummaryDraw()
    DllCall("SetWindowRgn", "ptr", sumG.Hwnd, "ptr", DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", sumPW + 1, "int", sumPH + 1, "int", Round(32 * sumPW / 360), "int", Round(32 * sumPW / 360), "ptr"), "int", 1)
    ; next to the main window (right side, else left), on its monitor
    g.GetPos(&gx, &gy, &gw, &gh)
    sx := 0, sy := 0
    if gx <= -30000 {                                    ; main window minimised: centre on the Roblox monitor
        cx := A_ScreenWidth // 2, cy := A_ScreenHeight // 2
        try {
            WinGetPos(&wx, &wy, &ww, &wh, GAME)
            cx := wx + ww // 2, cy := wy + wh // 2
        }
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
            if cx >= ml && cx < mr && cy >= mt && cy < mb {
                sx := ml + (mr - ml - sumPW) // 2, sy := mt + (mb - mt - sumPH) // 2
                break
            }
        }
    } else {
        sx := gx + gw + 8, sy := gy
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &ml, &mt, &mr, &mb)
            if gx + gw // 2 >= ml && gx + gw // 2 < mr {
                if sx + sumPW > mr
                    sx := Max(ml, gx - sumPW - 8)
                sy := Max(mt, Min(gy, mb - sumPH))
                break
            }
        }
    }
    sumG.Show("x" sx " y" sy " w" sumPW " h" sumPH " NoActivate")
    SumBlit()
    Log("session summary shown")
}

SumBlit(hdc := 0) {
    if !sumBmp
        return
    own := !hdc
    if own
        hdc := DllCall("GetDC", "ptr", sumG.Hwnd, "ptr")
    mdc := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
    old := DllCall("SelectObject", "ptr", mdc, "ptr", sumBmp, "ptr")
    DllCall("BitBlt", "ptr", hdc, "int", 0, "int", 0, "int", sumPW, "int", sumPH, "ptr", mdc, "int", 0, "int", 0, "uint", 0x00CC0020)
    DllCall("SelectObject", "ptr", mdc, "ptr", old)
    DllCall("DeleteDC", "ptr", mdc)
    if own
        DllCall("ReleaseDC", "ptr", sumG.Hwnd, "ptr", hdc)
}
