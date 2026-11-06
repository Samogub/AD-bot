; summary.ahk - session counters and the summary window shown after Stop (F2 / STOP button).
; Window: compact style A (black, thin white lines, corner brackets, JetBrains Mono, red accent), drawn into a bitmap.

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

SummaryShow() {
    global sumG, sumBmp, sumPW, sumPH, gr
    W := 340, H := 276
    SK := CK() * 1.2 * 0.85                              ; follows the HUD SIZE setting; 1.2 (text was small), then -15%
    sumPW := Round(W * SK), sumPH := Round(H * SK)
    if !sumG {
        sumG := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
        sumG.BackColor := CMP_BG
    }
    real := gr
    cv := Canvas(sumPW, sumPH, CMP_BG)
    gr := cv[2]
    DllCall("gdiplus\GdipScaleWorldTransform", "ptr", gr, "float", SK, "float", SK, "int", 0)
    GRY := CMP_GRAY, VAL := CMP_VAL
    CFrame(0, 0, W, H, "FFFFFF", 140)
    Dot(14, 15, 8, CMP_RED)
    LTx("SESSION", 11, VAL, 30, 8, 150, 22, 2)
    LTx("[CLOSE]", 10, CMP_RED, W - 90, 8, 76, 22, 1, 2)
    CRect(14, 32, W - 28, 1, "FFFFFF", 50)
    LTx(SessDur(sessMs), 10, VAL, 14, 38, 120, 20, 1)
    from := sessFrom != "" ? FormatTime(sessFrom, "HH:mm") : "--:--", to := sessTo != "" ? FormatTime(sessTo, "HH:mm") : "--:--"
    Tx(from " - " to, "mono", 10, 0, GRY, W - 134, 38, 120, 20, 2)
    ; table: right edges of the number columns
    cols := [["RUNS", 150], ["GEMS", 206], ["TOKENS", 266], ["GEMS/H", 326]]
    LTx("MODE", 9, GRY, 14, 66, 80, 18, 1, 0, 0, 170)
    for c in cols
        LTx(c[1], 9, GRY, c[2] - 56, 66, 56, 18, 1, 2, 0, 170)
    CRect(14, 86, W - 28, 1, "FFFFFF", 30)
    rows := [["RAID", sess["raids"], sess["raidGems"], sess["raidTokens"]]
           , ["SPEED", sess["speedRuns"], sess["speedGems"], sess["speedTokens"]]
           , ["INFINITY", sess["infRuns"], "", ""]
           , ["DIMENSION", sess["dimRuns"], sess["dimGems"], ""]]
    y := 92
    for r in rows {
        LTx(r[1], 10, GRY, 14, y, 90, 20, 1)
        vals := [String(r[2]), r[3] = "" ? "—" : String(r[3]), r[4] = "" ? "—" : String(r[4]), r[3] = "" ? "—" : PerHour(r[3])]
        for i, c in cols
            Tx(vals[i], "mono", 10, 0, vals[i] = "—" ? GRY : VAL, c[2] - 56, y, 56, 20, 2)
        y += 22
    }
    CRect(14, y + 2, W - 28, 1, "FFFFFF", 50)
    gems := sess["raidGems"] + sess["speedGems"] + sess["dimGems"], toks := sess["raidTokens"] + sess["speedTokens"]
    y += 8
    LTx("TOTAL GEMS", 10, GRY, 14, y, 120, 20, 1)
    Tx(String(gems), "mono", 11, 1, VAL, 140, y, 56, 20, 2)
    Tx(PerHour(gems) " /h", "mono", 10, 0, GRY, W - 134, y, 120, 20, 2)
    y += 22
    LTx("TOTAL TOKENS", 10, GRY, 14, y, 130, 20, 1)
    Tx(String(toks), "mono", 11, 1, VAL, 140, y, 56, 20, 2)
    Tx(PerHour(toks) " /h", "mono", 10, 0, GRY, W - 134, y, 120, 20, 2)
    y += 30
    LTx("ROBLOX RESTARTS", 10, GRY, 14, y, 190, 20, 1)
    Tx(String(sess["restarts"]), "mono", 11, 1, VAL, W - 74, y, 60, 20, 2)
    CRect(0, 0, 10, 2, "FFFFFF"), CRect(0, 0, 2, 10, "FFFFFF")
    CRect(W - 10, H - 2, 10, 2, "FFFFFF"), CRect(W - 2, H - 10, 2, 10, "FFFFFF")
    hbmNew := ToHbm(cv)
    gr := real
    if sumBmp
        DllCall("DeleteObject", "ptr", sumBmp)
    sumBmp := hbmNew
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
