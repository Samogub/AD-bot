#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 2                                    ; F8 while its own replay runs must get a 2nd thread to stop it
; Recorder / replayer with an editor window, for mapping a new flow (e.g. a dungeon run).
; Records keyboard (every key down and up, so holds like W are kept), mouse movement (raw deltas - works while the
; camera is turned with the right button held), mouse buttons and wheel. Every step is a row in the list and can be
; changed before or during a replay (the replay reads the list as it goes).
;   F7  start / stop recording (a new recording). A screenshot is taken at mouse down and key down (max one per 1.5 s).
;   F8  replay from the selected row (from the top if nothing is selected). F8 again or F9 = stop at once.
;   F10 while replaying: "here!" - stops and selects the row that was playing, so you can give it more Wait.
; Window: Step = play only the selected rows; Edit row (or double-click / Enter) = edit the selected row;
; + Key press = one "key press" row (key + hold ms); + Wait row = a pause; Wait ms = pause before the step;
; on Load a key down + key up of the same key right after each other become one key press row (file changes on Save); Speed % = all waits faster or slower;
; Save writes log.txt. The last recording is opened at start (or the folder given as the first argument).
; Folder: tools\rec\<date_time>\log.txt + 001.png, 002.png ... (opened with a folder, e.g. from the bot: F7 records into that folder)
; log.txt line: seconds since start (7.468), kind, a, b, pixel colour, screenshot number
;   kinds: mm (mouse moved by a, b px), ld lu (left button down/up), rd ru (right), up dn (wheel) - a, b = x, y;
;   kd ku (key down/up) - a = key code vkXXscYYY (layout independent), b = key name;
;   kp (key press) - same a, b; 5th column = hold ms. Its time is the press moment; the next row's time
;   already includes the hold (same as an old kd + ku pair).
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetDefaultMouseSpeed 0

ROOT := A_ScriptDir "\rec\"
GAME := "ahk_exe RobloxPlayerBeta.exe"
recMs := 0, curRow := 0, markRow := 0
rec := false, playing := false, dir := "", n := 0, shotAt := 0, held := Map(), lastAt := 0
steps := []                                               ; {w: wait ms before the step, k, a, b, c: colour, s: screenshot}
mdx := 0, mdy := 0

; ---- window ----
gw := Gui("+AlwaysOnTop", "Recorder")
gw.BackColor := "12101C"                                  ; dark theme as in the promo video
gw.SetFont("s9 cDDDDDD", "Segoe UI")
; row 1: record / replay
Btn("w58", "Rec F7", (*) => ToggleRec())
Btn("x+4 w62", "Play F8", (*) => TogglePlay())
Btn("x+4 w62", "Stop F9", (*) => StopPlay())
Btn("x+4 w44", "Step", (*) => PlaySelected())
f10 := Btn("x+4 w66", "Here F10", (*) => MarkHere())
gw.AddText("x+10 yp+5", "Speed %")
spd := gw.AddEdit("x+4 yp-3 w40 Number Background0A0613 cDDDDDD", "100")
onTop := gw.AddCheckbox("x+8 yp+3 Checked -Theme Background12101C cDDDDDD", "On top")
onTop.OnEvent("Click", (*) => WinSetAlwaysOnTop(onTop.Value, gw))
; own header labels (the system header is white): same x as the columns 40 / 70 / 70 / 110 / 110 / 70
gw.SetFont("s9 c8F88AA", "Segoe UI")
gw.AddText("xm+6 y+8 w34 h16", "#")
gw.AddText("xm+46 yp w58 h16 Right", "Time s")
gw.AddText("xm+116 yp w58 h16 Right", "Wait ms")
gw.AddText("xm+188 yp w100 h16", "Action")
gw.AddText("xm+298 yp w100 h16", "Key")
gw.AddText("xm+406 yp w58 h16 Right", "Hold ms")
gw.SetFont("s9 cDDDDDD", "Consolas")
lv := gw.AddListView("xm y+2 w500 r22 -Hdr Background12101C cDDDDDD", ["#", "Time s", "Wait ms", "Action", "Key", "Hold ms"])
gw.SetFont("s9 cDDDDDD", "Segoe UI")
lv.ModifyCol(1, 40), lv.ModifyCol(2, "70 Right"), lv.ModifyCol(3, "70 Right"), lv.ModifyCol(4, 110), lv.ModifyCol(5, 110), lv.ModifyCol(6, "70 Right")
lv.OnEvent("DoubleClick", (ctl, row) => row && EditRow(row))   ; edit a row: double-click (or Enter)
lv.OnEvent("Click", LvClick)                              ; 6.11: own double-click check too - NM_DBLCLK did not reach us for the user
lv.OnNotify(-12, LvDraw)                                  ; NM_CUSTOMDRAW: purple selected row, striped rows
; row 2: timing - the "Wait ms" of a row is how long the replay waits before doing it
Btn("xm w84", "Wait +100 ms", (*) => AddSleep(100))
Btn("x+4 w84", "Wait -100 ms", (*) => AddSleep(-100))
Btn("x+4 w78", "+ Wait row", (*) => InsertPause())
Btn("x+4 w78", "+ Key press", (*) => InsertKey())
Btn("x+4 w56", "Edit row", (*) => (r := lv.GetNext()) ? EditRow(r) : Say("select a row first"))   ; 6.11: double-click does not open it for the user
Btn("x+4 w48", "Delete", (*) => DeleteRows())
Btn("x+4 w48", "Save", (*) => Save())
OnMessage(0x200, HoverTip)                                ; WM_MOUSEMOVE: what F10 does
status := gw.AddText("xm w500", "")
gw.OnEvent("Close", (*) => ExitApp())
gw.Show("x" (A_ScreenWidth - 540) " y40")
argDir := A_Args.Length && DirExist(A_Args[1]) ? RTrim(A_Args[1], "\") "\" : ""
if argDir != "" {                                         ; opened from the bot: its Dimension run
    if !Load(argDir)
        dir := argDir                                     ; no log.txt yet: F7 / Save still go into this folder
} else
    OpenLast()

; ---- input capture ----
gu := Gui()
rid := Buffer(16, 0)
NumPut("ushort", 1, "ushort", 2, "uint", 0x100, "ptr", gu.Hwnd, rid)     ; generic desktop / mouse, RIDEV_INPUTSINK
DllCall("RegisterRawInputDevices", "ptr", rid, "uint", 1, "uint", 16)
OnMessage(0x00FF, RawIn)
SetTimer(FlushMove, 25)

ih := InputHook("V")
ih.KeyOpt("{All}", "N")                                   ; notify on every key, without blocking it
ih.OnKeyDown := KeyDown
ih.OnKeyUp := KeyUp
ih.Start()

F7:: ToggleRec()
F8:: TogglePlay()
F9:: StopPlay()
F10:: MarkHere()

~LButton:: Mouse("ld")
~LButton up:: Mouse("lu")
~RButton:: Mouse("rd")
~RButton up:: Mouse("ru")
~WheelUp:: Mouse("up")
~WheelDown:: Mouse("dn")

Say(s) => status.Value := s

; flat dark button (a Text control: real buttons cannot be coloured)
Btn(opt, label, fn) {
    b := gw.AddText(opt " h24 0x200 Center Background2A2540 cDDDDDD", label)
    b.OnEvent("Click", fn)
    return b
}

HoverTip(wParam, lParam, msg, hwnd) {
    static shown := false
    over := hwnd = f10.Hwnd
    if over && !shown
        ToolTip "F10 during a replay: stop and select the row that was playing,`nso you can give it more Wait."
    else if !over && shown
        ToolTip
    shown := over
}

; NM_CUSTOMDRAW of the list: selected row purple (also when the list has no focus), odd rows a bit lighter. Colours are BGR.
LvDraw(ctl, l) {
    stage := NumGet(l, A_PtrSize * 3, "uint")
    if stage = 1                                              ; CDDS_PREPAINT -> ask for every item
        return 0x20
    if stage != 0x10001                                       ; CDDS_ITEMPREPAINT only
        return 0
    row := NumGet(l, A_PtrSize * 5 + 16, "uptr")
    if SendMessage(0x102C, row, 2, ctl) & 2 {                 ; LVM_GETITEMSTATE, LVIS_SELECTED
        NumPut("uint", NumGet(l, A_PtrSize * 6 + 16, "uint") & ~0x11, l, A_PtrSize * 6 + 16)   ; drop CDIS_SELECTED / FOCUS: our colours win
        NumPut("uint", 0xFFFFFF, "uint", 0x70243A, l, A_PtrSize * 8 + 16)
    } else
        NumPut("uint", 0xDDDDDD, "uint", Mod(row, 2) ? 0x1F1316 : 0x1C1012, l, A_PtrSize * 8 + 16)
    return 0
}

; ---- recording ----
RawIn(wParam, lParam, msg, hwnd) {
    global mdx, mdy
    Critical
    if !rec
        return
    hdr := A_PtrSize * 2 + 8, size := 0
    DllCall("GetRawInputData", "ptr", lParam, "uint", 0x10000003, "ptr", 0, "uint*", &size, "uint", hdr)
    buf := Buffer(size)
    if DllCall("GetRawInputData", "ptr", lParam, "uint", 0x10000003, "ptr", buf, "uint*", &size, "uint", hdr) = -1
        return
    if NumGet(buf, 0, "uint") != 0 || NumGet(buf, hdr, "ushort") & 1       ; not a mouse / absolute position
        return
    mdx += NumGet(buf, hdr + 12, "int"), mdy += NumGet(buf, hdr + 16, "int")
}

; collected movement -> one step (every 25 ms while the mouse moves)
FlushMove() {
    global mdx, mdy
    if rec && (mdx || mdy)
        Push("mm", mdx, mdy)
    mdx := 0, mdy := 0
}

ToggleRec() {
    global rec, dir, n, held, lastAt, steps, recMs
    if playing
        return
    rec := !rec
    if rec {
        dir := argDir != "" ? argDir : ROOT FormatTime(, "yyyyMMdd_HHmmss") "\"   ; from the bot: the new run replaces its log.txt
        DirCreate dir
        n := 0, lastAt := A_TickCount, held := Map(), steps := [], recMs := 0
        lv.Delete()
        Say("REC... (F7 = stop)")
    } else {
        Save()
        Say("REC stopped: " steps.Length " steps, " n " screenshots -> " dir)
    }
}

Mouse(kind) {
    Critical
    if !rec
        return
    MouseGetPos &x, &y, &win
    try if WinGetPID("ahk_id " win) = ProcessExist()          ; clicks on our own window (Rec F7 to stop) are not part of the run
        return
    Add(kind, x, y, kind = "lu" || kind = "ru" ? "" : PixelGetColor(x, y), kind = "ld" || kind = "rd")
}

KeyDown(ih, vk, sc) {
    Critical
    name := GetKeyName(Format("vk{:x}sc{:x}", vk, sc)), code := Format("vk{:02X}sc{:03X}", vk, sc)
    if !rec || name ~= "^F[789]$" || held.Has(code)         ; held: ignore auto-repeat
        return
    held[code] := true
    Add("kd", code, name, "", true)
}

KeyUp(ih, vk, sc) {
    Critical
    name := GetKeyName(Format("vk{:x}sc{:x}", vk, sc)), code := Format("vk{:02X}sc{:03X}", vk, sc)
    if !rec || name ~= "^F[789]$" || !held.Has(code)
        return
    held.Delete(code)
    Add("ku", code, name)
}

Add(kind, a, b := "", col := "", shot := false) {
    global n, shotAt
    FlushMove()                                               ; keep the order: movement before this event
    num := ""
    if shot && (kind != "kd" || A_TickCount - shotAt > 1500) {    ; mouse downs always, key downs throttled
        shotAt := A_TickCount
        n += 1
        num := Format("{:03}", n)
    }
    Push(kind, a, b, col, num)                                ; time of the event itself, before the slow screenshot
    if num != ""
        QueueShot(dir num ".png")
}

; 8.11: the screenshot (~0.3 s) used to be taken inside the Critical key / mouse handler: the input hooks were blocked each time,
; and in a long recording (130+ rows, 20+ screenshots) Windows dropped the hook - nothing more was recorded. Now it runs
; from a timer, one at a time, so the handlers return at once.
shotQ := [], shooting := false
QueueShot(file) {
    shotQ.Push(file)
    SetTimer(DoShots, -10)
}

DoShots() {
    global shooting
    if shooting
        return
    shooting := true
    while shotQ.Length
        SaveRegion(shotQ.RemoveAt(1), 0, 0, A_ScreenWidth, A_ScreenHeight)
    shooting := false
}

Push(kind, a, b := "", col := "", num := "") {
    global lastAt
    st := {w: A_TickCount - lastAt, k: kind, a: a, b: b, c: col, s: num, h: 0}
    lastAt := A_TickCount
    steps.Push(st)
    global recMs
    recMs += st.w
    lv.Add("Vis", steps.Length, Row(st, recMs)*)
    if rec && Mod(steps.Length, 25) = 0                       ; a long recording is kept on disk as it goes (log.partial.txt)
        SetTimer(SavePartial, -50)
}

SavePartial() {
    if !rec || dir = ""
        return
    try FileDelete dir "log.partial.txt"
    try FileAppend LogText(), dir "log.partial.txt"
}

; key text of a key step: Latin letter / digit from the vk code whatever the layout, else the recorded name
KeyLabel(st) {
    if RegExMatch(st.a, "i)^vk([0-9A-F]{2})", &m) && ((v := Integer("0x" m[1])) >= 0x30 && v <= 0x39 || v >= 0x41 && v <= 0x5A)
        return Chr(v)
    return st.b
}

; list columns of a step (after "#"): time s, wait ms, action, key, hold ms; at = ms from the start
Row(st, at) {
    names := Map("mm", "mouse move", "ld", "left down", "lu", "left up", "rd", "right down", "ru", "right up",
        "up", "wheel up", "dn", "wheel down", "kd", "key down", "ku", "key up", "kp", "key press", "wait", "WAIT")
    if st.k = "kd" || st.k = "ku" || st.k = "kp"
        label := KeyLabel(st)
    else if st.k = "wait"
        label := ""
    else
        label := st.a "," st.b                                ; mm: dx,dy; clicks and wheel: x,y
    return [Format("{:.1f}", at / 1000), st.w, names.Has(st.k) ? names[st.k] : st.k, label, st.k = "kp" ? st.h : ""]
}

Fill() {
    lv.Opt("-Redraw")
    lv.Delete()
    at := 0
    for i, st in steps {
        at += st.w
        lv.Add(, i, Row(st, at)*)
        if st.k = "kp"
            at += st.h                                        ; the next row's time includes the hold
    }
    lv.Opt("+Redraw")
}

; ---- replay ----
StopPlay() {
    global playing
    playing := false
}

TogglePlay() {
    if playing {
        StopPlay()
        return
    }
    from := lv.GetNext()
    Play(from ? from : 1, steps.Length)
}

PlaySelected() {
    r := 0, list := []
    while r := lv.GetNext(r)
        list.Push(r)
    if list.Length
        Play(list[1], list[list.Length])
}

MarkHere() {
    global markRow
    if !playing
        return
    markRow := curRow
    StopPlay()
}

Play(from, to) {
    global playing, curRow, markRow
    if rec || playing || !steps.Length
        return
    playing := true
    if WinExist(GAME)
        WinActivate GAME                                     ; keys go to the game, not to this window
    Sleep 300
    down := Map()
    i := from
    ; times are kept against the replay start, not added up from Sleep: Sleep 20 really sleeps ~31 ms (15.6 ms timer),
    ; so holds like W came out ~1.5x longer. With a 1 ms timer each step is within a few ms of the recording.
    DllCall("winmm\timeBeginPeriod", "uint", 1)
    t0 := A_TickCount, due := 0
    while playing && i <= to && i <= steps.Length {
        st := steps[i], curRow := i                          ; read now: rows edited during the replay count
        sp := Max(10, Integer("0" spd.Value))
        due += st.w * 100 / sp
        while playing && A_TickCount - t0 < due - 1          ; short sleeps, so a stop is noticed at once
            Sleep Min(10, due - (A_TickCount - t0))
        lv.Modify(0, "-Select")
        lv.Modify(i, "Select Vis")
        Say("playing " i " / " to)
        if !playing
            break
        if st.k = "kp" {                                     ; key press: down, hold on the same clock, up
            Send "{" st.a " down}"
            down[st.a] := true
            due += st.h * 100 / sp
            while playing && A_TickCount - t0 < due - 1
                Sleep Min(10, due - (A_TickCount - t0))
            Send "{" st.a " up}"
            if down.Has(st.a)
                down.Delete(st.a)
        } else
            Do(st, down)
        i++
    }
    for k in down                                            ; stopped in the middle: release everything still held
        Send "{" k " up}"
    Click "Left Up"
    Click "Right Up"
    DllCall("winmm\timeEndPeriod", "uint", 1)
    playing := false
    if markRow {                                             ; F10: show the row, ready for Sleep +100 ms
        lv.Modify(0, "-Select")
        lv.Modify(markRow, "Select Vis Focus")
        lv.Focus()
        Say("F10 at row " markRow " - press Wait +100 ms (or select a row a bit higher), then Save")
        markRow := 0
    } else
        Say(i > to ? "replay finished" : "replay stopped at row " i)
}

Do(st, down) {
    switch st.k {
        case "kd":
            Send "{" st.a " down}"
            down[st.a] := true
        case "ku":
            Send "{" st.a " up}"
            if down.Has(st.a)
                down.Delete(st.a)
        case "wait", "kp":                                   ; wait: only time; kp is played in Play (needs its clock)
        case "mm":
            DllCall("mouse_event", "uint", 1, "int", Integer(st.a), "int", Integer(st.b), "uint", 0, "ptr", 0)   ; relative move
        default:
            x := Integer(st.a), y := Integer(st.b)
            MouseMove x + 6, y + 6, 0                          ; Roblox needs mouse movement before a click or wheel
            Sleep 40
            MouseMove x, y, 0
            Sleep 60
            switch st.k {
                case "ld": Click "Left Down"
                case "lu": Click "Left Up"
                case "rd": Click "Right Down"
                case "ru": Click "Right Up"
                case "up": Send "{WheelUp}"
                case "dn": Send "{WheelDown}"
            }
    }
}

; ---- editing ----
; a wait row before the selected row: everything after it comes that much later
InsertPause() {
    if playing
        return
    r := lv.GetNext() || steps.Length + 1                 ; nothing selected: at the end
    ; 8.11: own dialog owned by the window - an InputBox opened behind the always-on-top Recorder, so the button "did nothing"
    dlg := Gui("+Owner" gw.Hwnd " +AlwaysOnTop", "Add wait")
    dlg.SetFont("s9", "Segoe UI")
    dlg.AddText(, (r > steps.Length ? "Wait at the end" : "Wait before row " r) ", ms (1000 = 1 s):")
    fw := dlg.AddEdit("w120 Number", "1000")
    dlg.AddButton("xm w90 Default", "OK").OnEvent("Click", Ok)
    dlg.AddButton("x+4 w90", "Cancel").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    dlg.Show()

    Ok(*) {
        ms := Integer("0" fw.Value)
        dlg.Destroy()
        if playing || !ms || r > steps.Length + 1
            return
        steps.InsertAt(r, {w: ms, k: "wait", a: "", b: "", c: "", s: "", h: 0})
        Fill()
        lv.Modify(0, "-Select")
        lv.Modify(r, "Select Vis")
        Say("wait " ms " ms added as row " r " (Save to keep it)")
    }
}

; longer / shorter wait before the selected rows: everything after them moves too
AddSleep(ms) {
    list := Selected()
    if !list.Length {
        Say("select a row first")
        return
    }
    for r in list
        steps[r].w := Max(0, steps[r].w + ms)
    Fill()
    for r in list
        lv.Modify(r, "Select")
    lv.Modify(list[1], "Vis")
    Say("wait " (ms > 0 ? "+" : "") ms " ms on " list.Length " row(s) (Save to keep it)")
}

; one key press step (kp: key down, hold, key up) before the selected row
InsertKey() {
    r := lv.GetNext()
    if !r || playing
        return
    dlg := Gui("+Owner" gw.Hwnd " +AlwaysOnTop", "Add key press")
    dlg.SetFont("s9", "Segoe UI")
    dlg.AddText("Section", "Type")
    ft := dlg.AddDropDownList("x+4 w150 Choose1", ["Press (down + up)", "Key down only", "Key up only"])
    dlg.AddText("xs", "Key")
    fk := dlg.AddEdit("x+4 w70", "q")
    ht := dlg.AddText("x+14", "Hold ms")
    fh := dlg.AddEdit("x+4 w120 Number", "100")
    ft.OnEvent("Change", (*) => (ht.Enabled := fh.Enabled := ft.Value = 1))   ; hold only for a press; down / up rows let one key stay held across others
    dlg.AddButton("xs w90 Default", "OK").OnEvent("Click", Ok)
    dlg.AddButton("x+4 w90", "Cancel").OnEvent("Click", (*) => dlg.Destroy())
    dlg.OnEvent("Escape", (*) => dlg.Destroy())
    dlg.Show()

    Ok(*) {
        name := Trim(fk.Value)
        if !name || !GetKeyVK(name) {
            MsgBox "Unknown key: " name, "Recorder", 0x30
            return
        }
        if playing || r > steps.Length
            return
        code := Format("vk{:02X}sc{:03X}", GetKeyVK(name), GetKeySC(name)), nm := GetKeyName(name)
        kind := ["kp", "kd", "ku"][ft.Value]
        steps.InsertAt(r, {w: 0, k: kind, a: code, b: nm, c: "", s: "", h: kind = "kp" ? Integer("0" fh.Value) : 0})
        dlg.Destroy()
        Fill()
        lv.Modify(r, "Select Vis")
        Say("1 " Map("kp", "press", "kd", "key down", "ku", "key up")[kind] " added before row " r + 1 " (Save to keep it)")   ; ft is destroyed by now
    }
}

Selected() {
    r := 0, list := []
    while r := lv.GetNext(r)
        list.Push(r)
    return list
}

; two clicks on the same row within the system double-click time = edit it
LvClick(ctl, row) {
    static lastT := 0, lastR := 0
    if row && row = lastR && A_TickCount - lastT <= DllCall("GetDoubleClickTime") {
        lastT := 0
        EditRow(row)
        return
    }
    lastT := A_TickCount, lastR := row
}

#HotIf WinActive("ahk_id " gw.Hwnd) && lv.Focused
Enter:: (r := lv.GetNext()) && EditRow(r)
#HotIf

EditRow(r) {
    static lastAt := 0
    if A_TickCount - lastAt < 600 || WinExist("Row ahk_class AutoHotkeyGUI ahk_pid " ProcessExist())   ; one dialog: Click and DoubleClick may both fire
        return
    lastAt := A_TickCount
    if r < 1 || r > steps.Length
        return
    st := steps[r], key := st.k = "kd" || st.k = "ku" || st.k = "kp"
    ed := Gui("+Owner" gw.Hwnd " +AlwaysOnTop", "Row " r)
    ed.SetFont("s9", "Segoe UI")
    ed.AddText("w90", "Wait ms")
    fw := ed.AddEdit("x+4 w90 Number", st.w)
    orig := key ? KeyLabel(st) : ""                           ; latin letter from the vk code (st.b may be mangled)
    wt := st.k = "wait"                                       ; a wait row has only its Wait ms
    fa := "", fb := "", fh := ""
    if !wt {
        ed.AddText("xm w90", key ? "Key (e.g. w, Space)" : st.k = "mm" ? "dx" : "X")
        fa := ed.AddEdit("x+4 w90", key ? orig : st.a)
    }
    if !key && !wt {
        ed.AddText("xm w90", st.k = "mm" ? "dy" : "Y")
        fb := ed.AddEdit("x+4 w90", st.b)
    }
    if st.k = "kp" {
        ed.AddText("xm w90", "Hold ms")
        fh := ed.AddEdit("x+4 w90 Number", st.h)
    }
    ed.AddButton("xm w90 Default", "OK").OnEvent("Click", Ok)
    ed.AddButton("x+4 w90", "Cancel").OnEvent("Click", (*) => ed.Destroy())
    ed.Show()

    Ok(*) {
        try {
            st.w := Integer("0" fw.Value)
            if key {
                name := Trim(fa.Value)
                if name != orig {                             ; rebuild the code only when the key text was changed
                    if !GetKeyVK(name)
                        throw Error("unknown key: " name)
                    st.a := Format("vk{:02X}sc{:03X}", GetKeyVK(name), GetKeySC(name)), st.b := GetKeyName(name)
                }
                if st.k = "kp"
                    st.h := Integer("0" fh.Value)
            } else if !wt
                st.a := Integer(fa.Value), st.b := Integer(fb.Value)
        } catch as e {
            MsgBox e.Message, "Recorder", 0x30
            return
        }
        Fill()
        lv.Modify(r, "Select Vis")
        ed.Destroy()
        Say("row " r " changed (Save to keep it)")
    }
}

DeleteRows() {
    list := Selected()
    if !list.Length || playing
        return
    Loop list.Length
        steps.RemoveAt(list[list.Length - A_Index + 1])
    Fill()
    if steps.Length                                          ; stay at the place of the deleted row (the next one, or the last)
        lv.Modify(Min(list[1], steps.Length), "Select Vis Focus")
    Say(list.Length " rows deleted (Save to keep it)")
}

; ---- files ----
Save() {
    global dir
    if !steps.Length
        return
    if dir = "" {                                             ; nothing opened yet: a new folder instead of a silent no-op
        dir := ROOT FormatTime(, "yyyyMMdd_HHmmss") "\"
        DirCreate dir
    }
    try FileDelete dir "log.txt"
    FileAppend LogText(), dir "log.txt"
    try FileDelete dir "log.partial.txt"
    lv.Modify(0, "-Select")
    lv.Modify(1, "Select Vis Focus")
    Say("saved: " dir "log.txt")
}

; the whole list as log.txt text
LogText() {
    t := 0, out := "; recording " A_ScreenWidth "x" A_ScreenHeight "`n"
    for st in steps {
        t += st.w                                             ; t = the moment of the step (for kp: the press)
        out .= Format("{:.3f}", t / 1000) "," st.k "," st.a "," StrReplace(st.b, ",", "Comma") "," (st.k = "kp" ? st.h : st.c) "," st.s "`n"   ; key name "," would split the line
        if st.k = "kp"
            t += st.h                                         ; the next row's time already includes the hold
    }
    return out
}

Load(folder) {
    global dir, steps
    if !FileExist(folder "\log.txt")
        return false
    dir := RTrim(folder, "\") "\", steps := [], prev := 0
    for line in StrSplit(FileRead(dir "log.txt"), "`n", "`r") {
        p := StrSplit(line, ",")
        if p.Length < 3 || SubStr(line, 1, 1) = ";"
            continue
        t := Number(StrReplace(p[1], ",", ".")) * 1000
        h := 0, col5 := p.Length > 4 ? p[5] : ""
        if p[2] = "kp"
            h := IsInteger(col5) ? Integer(col5) : 100, col5 := ""
        steps.Push({w: Round(Max(0, t - prev)), k: p[2], a: p[3], b: p.Length > 3 ? p[4] : "", c: col5, s: p.Length > 5 ? p[6] : "", h: h})
        prev := t + h
    }
    ; merge simple pairs: key down X, then at once key up X (no screenshot on the up) -> one kp row, same timing
    merged := [], cnt := 0, i := 1
    while i <= steps.Length {
        st := steps[i]
        if st.k = "kd" && i < steps.Length && steps[i + 1].k = "ku" && steps[i + 1].a = st.a && steps[i + 1].s = "" {
            merged.Push({w: st.w, k: "kp", a: st.a, b: st.b, c: "", s: st.s, h: steps[i + 1].w})
            cnt += 1, i += 2
        } else
            merged.Push(st), i += 1
    }
    steps := merged
    Fill()
    Say("opened: " dir " (" steps.Length " steps, " cnt " key presses merged)")
    return true
}

OpenLast() {
    last := ""
    Loop Files ROOT "*", "D"
        last := A_LoopFilePath
    if last != ""
        Load(last)
}

; screen region -> PNG (GDI + GDI+); returns 0 when saved
SaveRegion(file, sx, sy, w, h) {
    try {
        sdc := DllCall("GetDC", "ptr", 0, "ptr")
        mdc := DllCall("CreateCompatibleDC", "ptr", sdc, "ptr")
        hbm := DllCall("CreateCompatibleBitmap", "ptr", sdc, "int", w, "int", h, "ptr")
        old := DllCall("SelectObject", "ptr", mdc, "ptr", hbm, "ptr")
        DllCall("BitBlt", "ptr", mdc, "int", 0, "int", 0, "int", w, "int", h, "ptr", sdc, "int", sx, "int", sy, "uint", 0x40CC0020)
        DllCall("SelectObject", "ptr", mdc, "ptr", old)
        DllCall("DeleteDC", "ptr", mdc)
        DllCall("ReleaseDC", "ptr", 0, "ptr", sdc)
        if !DllCall("GetModuleHandle", "str", "gdiplus", "ptr")
            DllCall("LoadLibrary", "str", "gdiplus")
        si := Buffer(24, 0)
        NumPut("uint", 1, si)
        DllCall("gdiplus\GdiplusStartup", "ptr*", &token := 0, "ptr", si, "ptr", 0)
        DllCall("gdiplus\GdipCreateBitmapFromHBITMAP", "ptr", hbm, "ptr", 0, "ptr*", &bmp := 0)
        clsid := Buffer(16)
        DllCall("ole32\CLSIDFromString", "wstr", "{557CF406-1A04-11D3-9A73-0000F81EF32E}", "ptr", clsid)
        res := DllCall("gdiplus\GdipSaveImageToFile", "ptr", bmp, "wstr", file, "ptr", clsid, "ptr", 0)
        DllCall("gdiplus\GdipDisposeImage", "ptr", bmp)
        DllCall("gdiplus\GdiplusShutdown", "ptr", token)
        DllCall("DeleteObject", "ptr", hbm)
        return res
    }
    return -1
}
