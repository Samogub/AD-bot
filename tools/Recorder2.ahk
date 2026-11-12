#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreadsPerHotkey 2                                    ; F8 while its own replay runs must get a 2nd thread to stop it
; Recorder v2 - records, edits and replays a run (keyboard, mouse movement, mouse buttons, wheel), and shares it as one file.
;   F7 start / stop recording    F8 replay (from the selected row)    F9 stop    F10 while replaying: stop and select the row that was playing
; Roblox sensitivity (top, same number as in the Roblox settings and in the bot, raid.ini camSens): saved in the run. A run recorded
; with another sensitivity is scaled when it is played, so the camera turns by the same angle. Old files without it play as they are.
; Export = the run as one file runs\<name>.adrun (send it to a friend), Import = open such a file here (Save to keep it).
; A run is a folder with log.txt (the bot plays it). Folder given as the first argument = opened from the bot (F7 records into it).
; log.txt line: seconds since start, kind, a, b, (colour, kept empty), screenshot number
;   kinds: mm (mouse moved by a, b), ld lu (left button down/up), rd ru (right), up dn (wheel) - a, b = x, y;
;   kd ku (key down/up) - a = key code vkXXscYYY (layout independent), b = key name; kp (key press) - same, 5th column = hold ms.
; The list is filled by a timer, never inside the key / mouse handlers: a slow handler makes Windows drop the hook (the old recorder
; stopped recording at ~130-370 rows because of that).
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SetDefaultMouseSpeed 0

ROOT := A_ScriptDir "\rec\"
RUNS := A_ScriptDir "\..\runs\"
INI := A_ScriptDir "\..\raid.ini"
GAME := "ahk_exe RobloxPlayerBeta.exe"
OPS := " kd ku kp mm up dn ld lu rd ru wait "
rec := false, playing := false, dir := "", held := Map(), lastAt := 0, shotAt := 0, shots := 0
steps := [], shown := 0, recMs := 0, curRow := 0, markRow := 0, mdx := 0, mdy := 0
recSens := "", carryX := 0, carryY := 0                   ; recSens: sensitivity the run was recorded with ("" = this PC now, "0" = an old file without it)
mySens := ReadSens()                                      ; Roblox sensitivity x100 (0.36 = 36)
shotQ := [], shooting := false

; ---- window ----
gw := Gui("+AlwaysOnTop", "Recorder v2")
gw.BackColor := "12101C"
gw.SetFont("s9 cDDDDDD", "Segoe UI")
Btn("w84", "Rec  F7", (*) => ToggleRec())
Btn("x+4 w84", "Play  F8", (*) => TogglePlay())
Btn("x+4 w84", "Stop  F9", (*) => StopPlay())
Btn("x+4 w84", "Here  F10", (*) => MarkHere())
Btn("x+4 w84", "Selected", (*) => PlaySelected())
gw.AddText("xm y+10", "Roblox sensitivity")
sensEd := gw.AddEdit("x+6 yp-3 w54 Background0A0613 cDDDDDD", FmtSens(mySens))
sensEd.OnEvent("LoseFocus", (*) => CommitSens())
gw.AddText("x+14 yp+3", "Speed %")
spd := gw.AddEdit("x+6 yp-3 w44 Number Background0A0613 cDDDDDD", "100")
info := gw.AddText("xm y+6 w520 c8F88AA", "")
lv := gw.AddListView("xm y+6 w520 r18 Background12101C cDDDDDD", ["#", "Time s", "Wait ms", "Action", "Key", "Hold ms"])
lv.ModifyCol(1, 40), lv.ModifyCol(2, "70 Right"), lv.ModifyCol(3, "70 Right"), lv.ModifyCol(4, 110), lv.ModifyCol(5, 110), lv.ModifyCol(6, "70 Right")
lv.OnEvent("DoubleClick", (ctl, row) => row && EditRow(row))
lv.OnEvent("Click", LvClick)                              ; own double-click check: NM_DBLCLK did not always reach us
Btn("xm y+6 w78", "Wait -100", (*) => AddSleep(-100))
Btn("x+4 w78", "Wait +100", (*) => AddSleep(100))
Btn("x+4 w70", "+ Wait", (*) => InsertPause())
Btn("x+4 w70", "+ Key", (*) => InsertKey())
Btn("x+4 w60", "Edit", (*) => (r := lv.GetNext()) ? EditRow(r) : Say("select a row first"))
Btn("x+4 w60", "Delete", (*) => DeleteRows())
Btn("xm y+6 w84", "Save", (*) => Save())
Btn("x+4 w84", "Export", (*) => ExportRun())
Btn("x+4 w84", "Import", (*) => ImportRun())
Btn("x+4 w84", "Folder", (*) => Run('explorer.exe "' (dir != "" ? RTrim(dir, "\") : ROOT) '"'))
Btn("x+4 w96", "Run = my sens", (*) => TagRun())
shotsCb := gw.AddCheckbox("x+14 yp+4 -Theme Background12101C cDDDDDD", "Screenshots")
status := gw.AddText("xm y+8 w520", "")
gw.OnEvent("Close", (*) => ExitApp())
gw.Show("x" (A_ScreenWidth - 560) " y40")
argDir := A_Args.Length && DirExist(A_Args[1]) ? RTrim(A_Args[1], "\") "\" : ""
if argDir != "" {                                         ; opened from the bot: its Dimension run
    if !Load(argDir)
        dir := argDir                                     ; no log.txt yet: F7 / Save still go into this folder
} else
    OpenLast()
UpdateInfo()

; ---- input capture ----
gu := Gui()
rid := Buffer(16, 0)
NumPut("ushort", 1, "ushort", 2, "uint", 0x100, "ptr", gu.Hwnd, rid)     ; generic desktop / mouse, RIDEV_INPUTSINK
DllCall("RegisterRawInputDevices", "ptr", rid, "uint", 1, "uint", 16)
OnMessage(0x00FF, RawIn)
SetTimer(FlushMove, 25)
SetTimer(Drain, 250)

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

#HotIf WinActive("ahk_id " gw.Hwnd) && lv.Focused
Enter:: (r := lv.GetNext()) && EditRow(r)
#HotIf

Say(s) => status.Value := s

; flat dark button (a Text control: real buttons cannot be coloured)
Btn(opt, label, fn) {
    b := gw.AddText(opt " h24 0x200 Center Background2A2540 cDDDDDD", label)
    b.OnEvent("Click", fn)
    return b
}

; ---- Roblox sensitivity ----
ReadSens() {
    v := Trim(IniRead(INI, "raid", "camSens", ""))            ; no default: 36 is the author's sensitivity, not yours (0 = not set yet)
    return IsInteger(v) && v >= 1 && v <= 200 ? Integer(v) : 0
}
FmtSens(n) => n ? Format("{:.2f}", n / 100) : ""

; the field -> mySens and raid.ini camSens (the bot uses the same number); 0.36 or 36 both work
CommitSens() {
    global mySens
    v := Trim(StrReplace(sensEd.Value, ",", "."))
    if IsNumber(v) {
        n := Number(v) < 3 ? Round(Number(v) * 100) : Round(Number(v))
        if n >= 1 && n <= 200 && n != mySens {
            mySens := n
            try IniWrite(n, INI, "raid", "camSens")
        }
    }
    sensEd.Value := FmtSens(mySens)
    UpdateInfo()
}

; how much a recorded mouse move is multiplied here (1 = recorded with this sensitivity, or an old file without it)
MoveFactor() => recSens = "" || recSens = "0" || !mySens ? 1 : Integer(recSens) / mySens

MoveBy(dx, dy) {
    global carryX, carryY
    f := MoveFactor()
    if Abs(f - 1) > 0.005 {
        fx := dx * f + carryX, fy := dy * f + carryY
        dx := Round(fx), dy := Round(fy)
        carryX := fx - dx, carryY := fy - dy                  ; the rounding left over goes into the next move: the total turn stays right
    }
    DllCall("mouse_event", "uint", 1, "int", dx, "int", dy, "uint", 0, "ptr", 0)
}

UpdateInfo() {
    if !mySens
        info.Value := "Type your Roblox sensitivity (Roblox Settings > Camera) in the field above before recording."
    else if recSens = ""
        info.Value := "A new recording is saved with sensitivity " FmtSens(mySens) "."
    else if recSens = "0"
        info.Value := "Sensitivity of this run is unknown (old file): it is played as it is."
    else if Abs(MoveFactor() - 1) > 0.005
        info.Value := "Recorded at " FmtSens(Integer(recSens)) ", yours is " FmtSens(mySens) ": mouse moves are scaled x" Round(MoveFactor(), 2) "."
    else
        info.Value := "Recorded at " FmtSens(Integer(recSens)) " - the same as yours."
    if SubStr(k := KindOfDir(dir), 1, 5) = "xdim_"            ; Extreme: which map this run is for
        info.Value := "Extreme map: " StrUpper(SubStr(k, 6)) ". " info.Value
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
    Critical                                                  ; a handler must not run Push in the middle of this one (the same move twice)
    if rec && (mdx || mdy)
        Push("mm", mdx, mdy)
    mdx := 0, mdy := 0
}

ToggleRec() {
    global rec, dir, shots, held, lastAt, steps, recMs, recSens, shown
    if playing
        return
    CommitSens()
    if !rec && !mySens {                                      ; a run recorded without the real sensitivity turns the camera wrong for everybody
        Say("Set your Roblox sensitivity first, then press F7")
        MsgBox("Type your Roblox sensitivity (Roblox Settings > Camera > Camera Sensitivity) in the field at the top, then press F7.`n`nThe run is saved with it, so it plays right on other PCs.", "Recorder", "Icon! 4096")
        return
    }
    rec := !rec
    if rec {
        recSens := String(mySens)                             ; a new recording is made with this sensitivity (the field may change while recording)
        dir := argDir != "" ? argDir : ROOT FormatTime(, "yyyyMMdd_HHmmss") "\"   ; from the bot: the new run replaces its log.txt
        DirCreate dir
        if FileExist(dir "log.txt")                           ; the run that is there stays (an accidental F7 F7 must not wipe it)
            FileCopy dir "log.txt", dir "log.before_rec_" FormatTime(, "yyyyMMdd_HHmmss") ".txt", 1
        shots := 0, lastAt := A_TickCount, held := Map(), steps := [], recMs := 0, shown := 0
        lv.Delete()
        UpdateInfo()
        Say("REC...  (F7 = stop)")
    } else {
        Fill()
        Save()
        Say("REC stopped: " steps.Length " steps -> " dir)
    }
}

Mouse(kind) {
    Critical
    if !rec
        return
    MouseGetPos &x, &y, &win
    try if WinGetPID("ahk_id " win) = ProcessExist()          ; clicks on our own window (Rec F7 to stop) are not part of the run
        return
    Add(kind, x, y, kind = "ld" || kind = "rd")
}

KeyDown(ih, vk, sc) {
    Critical
    name := GetKeyName(Format("vk{:x}sc{:x}", vk, sc)), code := Format("vk{:02X}sc{:03X}", vk, sc)
    if !rec || name ~= "^F(7|8|9|10)$" || held.Has(code)         ; held: ignore auto-repeat
        return
    held[code] := true
    Add("kd", code, name, true)
}

KeyUp(ih, vk, sc) {
    Critical
    name := GetKeyName(Format("vk{:x}sc{:x}", vk, sc)), code := Format("vk{:02X}sc{:03X}", vk, sc)
    if !rec || name ~= "^F(7|8|9|10)$" || !held.Has(code)
        return
    held.Delete(code)
    Add("ku", code, name)
}

Add(kind, a, b := "", shot := false) {
    global shots, shotAt
    FlushMove()                                               ; keep the order: movement before this event
    num := ""
    if shot && shotsCb.Value && (kind != "kd" || A_TickCount - shotAt > 1500) {    ; mouse downs always, key downs throttled
        shotAt := A_TickCount
        shots += 1
        num := Format("{:03}", shots)
    }
    Push(kind, a, b, num)
    if num != ""
        QueueShot(dir num ".png")
}

; a screenshot (~0.3 s) runs from a timer, one at a time, never inside a handler
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

Push(kind, a, b := "", num := "") {
    global lastAt, recMs
    st := {w: A_TickCount - lastAt, k: kind, a: a, b: b, c: "", s: num, h: 0, t: 0}
    lastAt := A_TickCount
    recMs += st.w
    st.t := recMs
    steps.Push(st)
    if Mod(steps.Length, 25) = 0                              ; a long recording is kept on disk as it goes (log.partial.txt)
        SetTimer(SavePartial, -50)
}

; new steps -> the list, in one go every 250 ms (not inside the handlers)
Drain() {
    global shown
    Critical                                                  ; F7-stop (Fill) must not run in the middle of it
    if !rec || shown >= steps.Length
        return
    lv.Opt("-Redraw")
    while shown < steps.Length {
        shown += 1
        lv.Add(, shown, Row(steps[shown], steps[shown].t)*)
    }
    lv.Opt("+Redraw")
    lv.Modify(shown, "Vis")
}

SavePartial() {
    if !rec || dir = ""
        return
    try FileDelete dir "log.partial.txt"
    try FileAppend LogText(), dir "log.partial.txt"
}

; ---- list ----
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
    list := Selected()
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
    global playing, curRow, markRow, carryX, carryY
    if rec || playing || !steps.Length
        return
    CommitSens()
    playing := true
    curRow := from                                            ; F10 in the first moments marks this row, not an old one
    carryX := 0, carryY := 0
    if WinExist(GAME)
        WinActivate GAME                                      ; keys go to the game, not to this window
    Sleep 300
    down := Map()
    i := from
    ; times are kept against the replay start, not added up from Sleep (Sleep 20 really sleeps ~31 ms): with a 1 ms timer
    ; each step is within a few ms of the recording
    DllCall("winmm\timeBeginPeriod", "uint", 1)
    t0 := A_TickCount, due := 0
    while playing && i <= to && i <= steps.Length {
        st := steps[i], curRow := i                           ; read now: rows edited during the replay count
        sp := Max(10, Integer("0" spd.Value))
        due += st.w * 100 / sp
        while playing && A_TickCount - t0 < due - 1           ; short sleeps, so a stop is noticed at once
            Sleep Min(10, due - (A_TickCount - t0))
        lv.Modify(0, "-Select")
        lv.Modify(i, "Select Vis")
        Say("playing " i " / " to)
        if !playing
            break
        if st.k = "kp" {                                      ; key press: down, hold on the same clock, up
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
    for k in down                                             ; stopped in the middle: release everything still held
        Send "{" k " up}"
    Click "Left Up"
    Click "Right Up"
    DllCall("winmm\timeEndPeriod", "uint", 1)
    playing := false
    if markRow {                                              ; F10: show the row, ready for Wait +100
        lv.Modify(0, "-Select")
        lv.Modify(markRow, "Select Vis Focus")
        lv.Focus()
        Say("F10 at row " markRow " - press Wait +100 (or select a row a bit higher), then Save")
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
        case "wait", "kp":                                    ; wait: only time; kp is played in Play (needs its clock)
        case "mm":
            MoveBy(Integer(st.a), Integer(st.b))
        default:
            if st.k = "up" || st.k = "dn" {                   ; wheel: a tiny move there and back (net 0). An absolute MouseMove to the recorded x, y turned the camera
                DllCall("mouse_event", "uint", 1, "int", 3, "int", 0, "uint", 0, "ptr", 0)
                Sleep 40
                DllCall("mouse_event", "uint", 1, "int", -3, "int", 0, "uint", 0, "ptr", 0)
                Sleep 60
                Send st.k = "up" ? "{WheelUp}" : "{WheelDown}"
                return
            }
            x := Integer(st.a), y := Integer(st.b)
            MouseMove x + 6, y + 6, 0                         ; Roblox needs mouse movement before a click
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
    r := lv.GetNext() || steps.Length + 1                     ; nothing selected: at the end
    dlg := Gui("+Owner" gw.Hwnd " +AlwaysOnTop", "Add wait")  ; own dialog owned by the window: an InputBox opened behind the always-on-top Recorder
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
        steps.InsertAt(r, {w: ms, k: "wait", a: "", b: "", c: "", s: "", h: 0, t: 0})
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

; one key step (press = down, hold, up; or down only / up only) before the selected row
InsertKey() {
    r := lv.GetNext()
    if !r || playing {
        Say("select a row first")
        return
    }
    dlg := Gui("+Owner" gw.Hwnd " +AlwaysOnTop", "Add key")
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
        steps.InsertAt(r, {w: 0, k: kind, a: code, b: nm, c: "", s: "", h: kind = "kp" ? Integer("0" fh.Value) : 0, t: 0})
        dlg.Destroy()
        Fill()
        lv.Modify(r, "Select Vis")
        Say("key row added before row " r + 1 " (Save to keep it)")
    }
}

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
    if steps.Length                                           ; stay at the place of the deleted row (the next one, or the last)
        lv.Modify(Min(list[1], steps.Length), "Select Vis Focus")
    Say(list.Length " rows deleted (Save to keep it)")
}

; ---- files ----
Save() {
    global dir, recSens
    if !steps.Length
        return
    CommitSens()
    if dir = "" {                                             ; nothing opened yet: a new folder instead of a silent no-op
        dir := ROOT FormatTime(, "yyyyMMdd_HHmmss") "\"
        DirCreate dir
    }
    if recSens = ""
        recSens := String(mySens)                             ; recorded here: from now on the file says with which sensitivity
    try FileDelete dir "log.txt"
    FileAppend LogText(), dir "log.txt"
    try FileDelete dir "log.partial.txt"
    UpdateInfo()
    lv.Modify(0, "-Select")
    lv.Modify(1, "Select Vis Focus")
    Say("saved: " dir "log.txt")
}

; forgot to set the sensitivity before recording: mark the opened run as recorded at the one in the field (no new recording needed)
TagRun() {
    global recSens
    CommitSens()
    if !steps.Length || playing || rec
        return
    if !mySens {
        Say("Type your Roblox sensitivity in the field first")
        return
    }
    if MsgBox("Mark this run as recorded at sensitivity " FmtSens(mySens) "?`n`nUse it only when it was recorded at exactly this sensitivity.", "Recorder", "YesNo Icon? 4096") != "Yes"
        return
    recSens := String(mySens)
    Save()
}

; the whole list as log.txt text
LogText() {
    t := 0, out := "; recording " A_ScreenWidth "x" A_ScreenHeight "`n"
    s := recSens = "" ? mySens : recSens                      ; opened from a file: its own sensitivity stays (an edit does not change who recorded it)
    if s != "0"
        out .= "; sens " s "`n"
    for st in steps {
        t += st.w                                             ; t = the moment of the step (for kp: the press)
        out .= Format("{:.3f}", t / 1000) "," st.k "," st.a "," StrReplace(st.b, ",", "Comma") "," (st.k = "kp" ? st.h : st.c) "," st.s "`n"   ; key name "," would split the line
        if st.k = "kp"
            t += st.h                                         ; the next row's time already includes the hold
    }
    return out
}

; log text -> {steps, sens}; sens "0" = the file has no "; sens" line
ParseLog(txt) {
    list := [], prev := 0
    for line in StrSplit(txt, "`n", "`r") {
        p := StrSplit(line, ",")
        if p.Length < 3 || SubStr(line, 1, 1) = ";" || !InStr(OPS, " " p[2] " ") || !IsNumber(Trim(p[1]))
            continue
        t := Number(Trim(p[1])) * 1000
        h := 0, col5 := p.Length > 4 ? p[5] : ""
        if p[2] = "kp"
            h := IsInteger(col5) ? Integer(col5) : 100, col5 := ""
        list.Push({w: Round(Max(0, t - prev)), k: p[2], a: p[3], b: p.Length > 3 ? p[4] : "", c: col5, s: p.Length > 5 ? p[6] : "", h: h, t: 0})
        prev := t + h
    }
    ; merge simple pairs: key down X, then at once key up X (no screenshot on the up) -> one kp row, same timing
    merged := [], i := 1
    while i <= list.Length {
        st := list[i]
        if st.k = "kd" && i < list.Length && list[i + 1].k = "ku" && list[i + 1].a = st.a && list[i + 1].s = "" {
            merged.Push({w: st.w, k: "kp", a: st.a, b: st.b, c: "", s: st.s, h: list[i + 1].w, t: 0})
            i += 2
        } else
            merged.Push(st), i += 1
    }
    return {steps: merged, sens: RegExMatch(txt, "m)^; sens (\d+)", &m) ? m[1] : "0"}
}

Load(folder) {
    global dir, steps, recSens
    if !FileExist(folder "\log.txt")
        return false
    dir := RTrim(folder, "\") "\"
    r := ParseLog(FileRead(dir "log.txt"))
    steps := r.steps, recSens := r.sens
    Fill()
    Say("opened: " dir " (" steps.Length " steps)")
    return true
}

OpenLast() {
    last := ""
    Loop Files ROOT "*", "D"
        last := A_LoopFilePath
    if last != ""
        Load(last)
}

; the kind of run a folder belongs to (dimension\giant3 -> giant, ...\extreme -> xdim), "" for a folder of the Recorder itself
KindOfDir(d) {
    if RegExMatch(RTrim(d, "\"), "i)\\extreme_([a-z0-9]+)$", &m)   ; Extreme: one run per map (extreme_curse -> xdim_curse)
        return "xdim_" StrLower(m[1])
    if RegExMatch(RTrim(d, "\"), "i)\\(giant|halloween|death|extreme)\d*$", &m)
        return m[1] = "extreme" ? "xdim" : StrLower(m[1])
    return ""
}

; ---- export / import: one shareable file ----
ExportRun() {
    gw.Opt("+OwnDialogs")
    if !steps.Length || rec || playing {
        Say("nothing to export")
        return
    }
    CommitSens()
    k := KindOfDir(dir)
    DirCreate RUNS
    f := FileSelect("S16", RUNS (k != "" ? k : "run") "_" FormatTime(, "yyyyMMdd") ".adrun", "Export run", "Run (*.adrun)")
    if f = ""
        return
    if !(f ~= "i)\.adrun$")
        f .= ".adrun"
    try FileDelete f
    FileAppend "; adrun 1`n" (k != "" ? "; kind " k "`n" : "") LogText(), f
    Say("exported: " f)
    try Run('explorer.exe /select,"' f '"')
}

ImportRun() {
    global steps, recSens
    if rec || playing
        return
    gw.Opt("+OwnDialogs")
    f := FileSelect(1, RUNS, "Import run", "Run (*.adrun; *.txt)")
    if f = ""
        return
    try txt := FileRead(f)
    catch {
        Say("cannot read the file")
        return
    }
    r := ParseLog(txt)
    if r.steps.Length < 3 {
        Say("this is not a run file")
        return
    }
    k := KindOfDir(dir), warn := ""
    if k != "" && RegExMatch(txt, "m)^; kind (\w+)", &m) && m[1] != k && !(m[1] = "xdim" && SubStr(k, 1, 5) = "xdim_")   ; an old Extreme export: map unknown
        warn .= "This run is for '" m[1] "', the open folder is '" k "'.`n"
    if RegExMatch(txt, "m)^; recording (\d+)x(\d+)", &sz) && (sz[1] != A_ScreenWidth || sz[2] != A_ScreenHeight)
        warn .= "It was recorded on a " sz[1] "x" sz[2] " screen, yours is " A_ScreenWidth "x" A_ScreenHeight ": clicks may land in the wrong place.`n"
    if warn != "" && MsgBox(warn "`nImport anyway?", "Import run", "YesNo Icon! 262144") != "Yes"
        return
    if dir != "" && FileExist(dir "log.txt")
        FileCopy dir "log.txt", dir "log.before_import_" FormatTime(, "yyyyMMdd_HHmmss") ".txt", 1   ; the run that was here before stays
    steps := r.steps, recSens := r.sens
    Fill()
    UpdateInfo()
    Say("imported " steps.Length " steps - Save to keep it (the old run: log.before_import_*.txt)")
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
