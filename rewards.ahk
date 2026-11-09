; rewards.ahk - REWARDS panel (Speed Raid, Dimension, new Raid screen): the gem card and the raid-token card are found by
; their icons (img\card_gem.png / card_gem_2.png / card_token.png, the icon above the number), the white number at the
; card's bottom-left is read by OCR. Own OCR files (OCR3_*), so nothing clashes with the counter OCR or ReadLootNumber.

OCR3_IN  := A_Temp "\adbot031_ocr3.png"
OCR3_OUT := A_Temp "\adbot031_ocr3.txt"
CARD_BOX := [700, 330, 1700, 560]                ; where the cards can be (they move with the card order, up to 5 cards)
tokFromScreen := false                            ; raid tokens of this run were read from the results: the in-fight counter must not be added
dimHandled := false                              ; Dimension results screen already handled (cleared when the route starts)
rwPendingAt := 0                                 ; Dimension: background OCR of the gem number started at this tick
OCR5_IN  := A_Temp "\adbot031_ocr5.png"            ; results line (Time / Wave / PITY): own files, async, never shared with OCR3
OCR5_OUT := A_Temp "\adbot031_ocr5.txt"
RESULT_BOX := [840, 530, 540, 170]
rlPendingAt := 0                                 ; results line OCR started at this tick (0 = none pending)
rlKind := ""                                     ; "infinity" / "dimension"

; *60: the card background shows through the icon a little (7.11: the old *40 never matched the gem card, gems stayed 0 all day)
CardFind(name, &x, &y) => FindImg(name, &x, &y, CARD_BOX[1], CARD_BOX[2], CARD_BOX[3], CARD_BOX[4], "*60 *TransFF00FF")

; number area: 64x34 at the card's bottom-left, from the icon template position
CardRegion(x, y) => [x - 30, y + 56, 64, 34]

CardParse(txt) {
    if RegExMatch(txt, "\d[\d,]*", &m) && (n := Integer(StrReplace(m[0], ","))) > 0 && n < 1000000
        return n
    return 0
}

CardNumber(x, y) {
    b := CardRegion(x, y)
    if SaveRegion(OCR3_IN, b[1], b[2], b[3], b[4]) != 0
        return 0
    for opts in ["-White", "-White -Thresh 175"] {
        OcrCall(OCR3_IN, OCR3_OUT, opts)
        txt := ""
        try txt := FileRead(OCR3_OUT, "UTF-8")
        try FileDelete OCR3_OUT
        if (n := CardParse(txt))
            return n
    }
    return 0
}

; kind: "raid" / "speed". true = the panel was there (read or not), false = no gem card on the screen
RewardCards(kind) {
    global runTokens, tokFromScreen
    ; raid results (4.11): other icons than Speed - raid_*_icon.png match exactly, card_* do not; they sit 7,10 px left/up of card_*
    gemT := kind = "raid" ? "raid_gem_icon.png" : "card_gem.png", tokT := kind = "raid" ? "raid_token_icon.png" : "card_token.png"
    dx := kind = "raid" ? 7 : 0, dy := kind = "raid" ? 10 : 0
    if !CardFind(gemT, &gx, &gy)
        return false
    SetStatus("results: reading rewards")
    ParkMouse()
    Sleep 1200                                           ; the cards are drawn one by one
    gems := 0, tokens := 0
    Loop 3 {
        if A_Index > 1
            Sleep 800
        if !gems && CardFind(gemT, &gx, &gy)
            gems := CardNumber(gx + dx, gy + dy)
        if !tokens && CardFind(tokT, &tx, &ty)
            tokens := CardNumber(tx + dx, ty + dy)
        if gems && tokens
            break
    }
    title := kind = "speed" ? "Speed Raid" : RaidTitle()
    pre := kind = "speed" ? "speed" : "raid"
    if gems
        Stat(pre "Gems", gems)
    if tokens {
        Stat(pre "Tokens", tokens)
        if kind = "raid"
            runTokens := 0, tokFromScreen := true         ; counted from the screen, the in-fight counter is not added
    }
    Log(title ": gems " (gems ? gems : "?") ", tokens " (tokens ? tokens : "?")
        . (gems && tokens ? "" : " (a card or number was not found - see the shot)"))
    return true
}

; Dimension results: the number area is saved first, the OCR runs in the background (RETRY must not wait for it)
DimCardsStart() {
    global rwPendingAt
    found := false
    Loop 10 {                                            ; the cards may still be drawn: up to 1 s
        ; 9.11: since 6.11 the gem icon on the Dimension results looks different (the old card_gem.png never matched there): own template first
        if found := CardFind("card_gem_dim.png", &gx, &gy) || CardFind("card_gem.png", &gx, &gy)
            break
        Sleep 100
    }
    if !found {
        Log("  Dimension: gem card not found on the results")
        static shots := 0
        if ++shots <= 2                                  ; 9.11: gems stayed 0 for days - the shot shows what the results look like now
            Screenshot("dim_cards")
        ResultLineStart("dimension")                     ; time and pity are still worth reading
        return
    }
    b := CardRegion(gx, gy)
    try FileDelete OCR3_OUT
    if SaveRegion(OCR3_IN, b[1], b[2], b[3], b[4]) = 0 {
        OcrCall(OCR3_IN, OCR3_OUT, "-White", false)
        rwPendingAt := A_TickCount
    } else
        Log("  Dimension: could not save the gem number area")
    ResultLineStart("dimension")                         ; queued after the gem number (the OCR server takes requests one at a time, in order)
}

; Results line (Time / Wave / PITY): the area is saved now, OCR runs in the background (OCR server queue, own files OCR5_*),
; ResultLinePoll() picks the answer on later ticks. Nothing here waits.
ResultLineStart(kind) {
    global rlPendingAt, rlKind
    if rlPendingAt && A_TickCount - rlPendingAt < 20000
        return                                           ; the previous read is still on its way
    try FileDelete OCR5_OUT
    if SaveRegion(OCR5_IN, RESULT_BOX[1], RESULT_BOX[2], RESULT_BOX[3], RESULT_BOX[4]) = 0 {
        OcrCall(OCR5_IN, OCR5_OUT, "-Scale 2", false)
        rlPendingAt := A_TickCount, rlKind := kind
    } else
        Log("  result line (" kind "): could not save the area")
}

ResultLinePoll() {
    global rlPendingAt, rlKind
    if !rlPendingAt
        return
    if FileExist(OCR5_OUT) {
        txt := ""
        try txt := FileRead(OCR5_OUT, "UTF-8")
        try FileDelete OCR5_OUT
        kind := rlKind, rlPendingAt := 0
        tm := RegExMatch(txt, "i)Ti\s*me:?\s*(\d+)[:.](\d\d)", &mt) ? Format("{:02}:{}", mt[1], mt[2]) : ""
        if kind = "infinity" {
            if RegExMatch(txt, "i)Wave:?\s*(\d+)", &mw)
                Log("Infinity results: time " (tm != "" ? tm : "?") ", wave " mw[1])
        } else {
            pity := RegExMatch(txt, "i)PITY\s*(\d+)\s*/\s*(\d+)", &mp) ? mp[1] "/" mp[2] : ""
            if tm = "" && pity = ""
                Log("  result line (Dimension): no time or pity read")
            else {
                Log("Dimension run: time " (tm != "" ? tm : "?") (pity != "" ? ", pity " pity : ""))
                if pity != "" && Integer(mp[1]) >= 48
                    Log("  accessory pity near: " pity)
            }
        }
    } else if A_TickCount - rlPendingAt > 20000 {
        Log("  result line OCR: no answer")
        rlPendingAt := 0
    }
}

RewardsPoll() {
    global rwPendingAt
    ResultLinePoll()                                     ; Time / Wave / PITY line, also in the background
    if !rwPendingAt
        return
    if FileExist(OCR3_OUT) {
        txt := ""
        try txt := FileRead(OCR3_OUT, "UTF-8")
        try FileDelete OCR3_OUT
        rwPendingAt := 0
        if (n := CardParse(txt)) {
            Stat("dimGems", n)
            Log("Dimension: gems " n)
        } else
            Log("  Dimension: gems could not be read")
    } else if A_TickCount - rwPendingAt > 20000 {
        Log("  Dimension: gem number OCR gave no answer in 20 s")
        rwPendingAt := 0
    }
}
