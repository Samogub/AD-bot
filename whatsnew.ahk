; whatsnew.ahk - "What's new" card after an update (24.11, the user): what was added, changed, removed or fixed, each with one short line why.
; Shown once per build: the bot folder has build.txt (written by make_release.ps1) and whatsnew.txt; the card shows when that build was not
; seen yet ([ui] seenBuild in raid.ini). It closes only with the X at the top right (a click beside it does nothing), so it is not lost by accident.
; Working copies without build.txt never show it.
;
; whatsnew.txt (UTF-8), written for each release:
;   version 0.4.2
;   + Esper Raid | New limited raid: pick Esper in the raid list
;   ~ Raid with Auto | 2 s after Auto: 5, then E R X Z - stronger start
;   - Cursed Sage Raid | It left the game
;   ! Halloween in Group Finder | Hardcore stays off there - the game has none
; + new, ~ changed, - removed, ! fixed. Title | why (both short).

wnShow := false, wnItems := [], wnVer := ""

WhatsNewLoad() {
    global wnItems, wnVer
    wnItems := [], wnVer := ""
    try txt := FileRead(A_ScriptDir "\whatsnew.txt", "UTF-8")
    catch
        return false
    for ln in StrSplit(txt, "`n", "`r") {
        ln := Trim(ln)
        if RegExMatch(ln, "i)^version\s+(.+)$", &m)
            wnVer := Trim(m[1])
        else if RegExMatch(ln, "^([+~\-!])\s*(.+?)\s*(?:\|\s*(.*))?$", &m)
            wnItems.Push({kind: m[1], title: m[2], why: m[3]})
    }
    return wnItems.Length > 0
}

; at start: a build the player has not seen yet, with a list -> show the card
WhatsNewCheck() {
    global wnShow
    b := BuildLocal()
    if b = "" || IniRead(INI, "ui", "seenBuild", "") = b
        return
    if WhatsNewLoad()
        wnShow := true
    else
        IniWrite b, INI, "ui", "seenBuild"                 ; nothing to show for this build
}

WhatsNewClose(*) {
    global wnShow
    wnShow := false
    if (b := BuildLocal()) != ""
        IniWrite b, INI, "ui", "seenBuild"
    Log("ui: What's new closed")
}

; kind -> badge text and colour
WnBadge(kind) {
    switch kind {
        case "+": return ["NEW", "3FBF7F"]
        case "~": return ["CHANGED", C.acc]
        case "-": return ["REMOVED", "D2556A"]
    }
    return ["FIXED", "D9A441"]
}

; the card over the whole window. kf >= 0: a fixed animation point (snapshot test), else the live 0 -> 1 appear animation
DrawWhatsNew(kf := -1) {
    if !wnShow && kf < 0
        return
    k := kf >= 0 ? kf : AnimTarget("wn", 1, 320, 0)
    ke := 1 - (1 - k) ** 3                                 ; ease-out
    FillRR(0, 0, PW / UI_K, PH / UI_K, 0, "000000", Round(150 * ke))   ; dim the bot behind it
    Hit(0, 0, PW / UI_K, PH / UI_K, "wn_block", (*) => 0)  ; clicks beside the card do nothing (only the X closes it)
    n := wnItems.Length, rowH := 54
    w := 560, h := 92 + n * rowH + 18
    x := Floor((PW / UI_K - w) / 2), y := Max(40, Floor((PH / UI_K - h) / 2)) + Round(16 * (1 - ke))   ; PW / UI_K is a float: // would throw
    FillRR(x, y, w, h, 20, C.card, Round(250 * ke))
    StrokeRR(x, y, w, h, 20, C.ov, Round(46 * ke))
    GradRR(x + 24, y, w - 48, 3, 1, C.acc, Round(255 * ke), C.acc2, Round(255 * ke))   ; a thin accent line on top
    Tx("UPDATED", "ui", 11, 1, C.hi, x + 28, y + 22, 200, 16, 0, Round(255 * ke))
    Tx("What's new" (wnVer != "" ? " in " wnVer : ""), "head", 21, 1, C.text, x + 28, y + 40, w - 110, 30, 0, Round(255 * ke))
    ; the X: the only way to close it
    bx := x + w - 50, by := y + 18
    if IsHot("wn_x")
        FillRR(bx, by, 32, 32, 16, C.ov, 30)
    StrokeRR(bx, by, 32, 32, 16, C.ov, Round(60 * ke))
    Tx(Chr(0x2715), "ui", 15, 0, C.text, bx, by, 32, 32, 1, Round(255 * ke))
    Hit(bx, by, 32, 32, "wn_x", WhatsNewClose)
    iy := y + 88, bwMax := 0
    for it in wnItems                                      ; the titles start in one column, whatever the badge width
        bwMax := Max(bwMax, Ceil(TxW(WnBadge(it.kind)[1], "ui", 10, 1)) + 16)
    for i, it in wnItems {
        ki := kf >= 0 ? Min(1, Max(0, (kf - 0.15 * (i - 1) / Max(1, n)) / 0.85)) : AnimTarget("wn" i, 1, 320 + 70 * i, 0)   ; rows come in one after another
        ki := 1 - (1 - ki) ** 3, a := Round(255 * ki), dx := Round(12 * (1 - ki))
        bd := WnBadge(it.kind)
        bw := Ceil(TxW(bd[1], "ui", 10, 1)) + 16
        FillRR(x + 28 + dx, iy + 4, bw, 20, 10, bd[2], Round(40 * ki))
        StrokeRR(x + 28 + dx, iy + 4, bw, 20, 10, bd[2], Round(150 * ki))
        Tx(bd[1], "ui", 10, 1, bd[2], x + 28 + dx, iy + 4, bw, 20, 1, a)
        Tx(it.title, "ui", 14, 1, C.text, x + 40 + bwMax + dx, iy + 2, w - bwMax - 80, 22, 0, a)
        if it.why != ""
            TxP(it.why, "ui", 11, C.dim, x + 40 + bwMax + dx, iy + 24, w - bwMax - 80, 26, a)
        if i < n
            FillRR(x + 28, iy + rowH - 4, w - 56, 1, 0, C.ov, Round(18 * ki))
        iy += rowH
    }
}
