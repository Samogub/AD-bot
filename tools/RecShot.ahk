#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Off                                       ; two shots at once must not ask "replace the running copy?"
; Recorder v2 helper: saves the screen as the PNG given as the 1st argument, then exits. A separate process, so the
; ~0.3 s PNG save does not hold up the recording (Recorder2.ahk QueueShot).
if A_Args.Length
    SaveRegion(A_Args[1], 0, 0, A_ScreenWidth, A_ScreenHeight)
ExitApp

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
