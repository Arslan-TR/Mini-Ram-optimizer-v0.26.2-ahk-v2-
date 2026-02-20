#Requires AutoHotkey v2.0
#SingleInstance Force

; Run as Admin for better effectiveness / Daha iyi etkinlik için Yönetici olarak çalıştır
if not A_IsAdmin {
    try {
        Run("*RunAs `"" A_ScriptFullPath "`"")
    } catch {
        MsgBox("Failed to run as administrator. RAM optimization may be limited.")
    }
    ExitApp()
}

; -- Settings / Ayarlar --
IniFile := A_ScriptDir "\RamOptimizer.ini"
CurrentTheme := IniRead(IniFile, "Settings", "Theme", "Dark")
AutoOptState := IniRead(IniFile, "Settings", "AutoOptimize", "0")
MiniModeState := IniRead(IniFile, "Settings", "MiniMode", "0")
AlwaysOnTopState := IniRead(IniFile, "Settings", "AlwaysOnTop", "0")

; -- GUI Setup / Arayüz Kurulumu --
; -Caption removes valid drag area and borders, +ThickFrame keeps resize borders working but invisible/thin?
; Actually, +Resize -Caption usually works for resizing.
MyGui := Gui("+Resize -Caption +MinSize240x40", "RAM Optimizer")
MyGui.MarginX := 10
MyGui.MarginY := 10

; Context Menu (Replaces Menu Bar) / Sağ Tık Menüsü (Menü Çubuğunun Yerine)
ContextMenu := Menu()
ThemeMenu := Menu()
ThemeMenu.Add("Dark", (*) => SetTheme("Dark"))
ThemeMenu.Add("Light", (*) => SetTheme("Light"))
ThemeMenu.SetIcon("Dark", "shell32.dll", 327)   ; Star icon for Dark
ThemeMenu.SetIcon("Light", "shell32.dll", 326) ; Flashlight icon for Light

ContextMenu.Add("Theme", ThemeMenu)
ContextMenu.Add("Mini Mode", ToggleMiniMode)
ContextMenu.Add("Auto-Optimize", ToggleAutoOpt)
ContextMenu.Add("Always on Top", ToggleAlwaysOnTop)
ContextMenu.Add("Exit", (*) => ExitApp())

; Set Icons / Simgeleri Ayarla
ContextMenu.SetIcon("Theme", "shell32.dll", 142)           ; Display icon
ContextMenu.SetIcon("Mini Mode", "shell32.dll", 287)       ; Small window icon
ContextMenu.SetIcon("Auto-Optimize", "shell32.dll", 239)   ; Speed/Run icon
ContextMenu.SetIcon("Always on Top", "shell32.dll", 209)     ; Pin icon
ContextMenu.SetIcon("Exit", "shell32.dll", 132)             ; Shutdown icon

; Attach Context Menu / Menüyü Ekle
MyGui.OnEvent("ContextMenu", ShowContextMenu)

; Dragging Handler / Sürükleme İşleyicisi
OnMessage(0x0201, WM_LBUTTONDOWN)
; Hover Handler / Üzerine Gelme İşleyicisi
OnMessage(0x0200, ShowTooltip)

; Controls (Saved to variables for resizing) / Kontroller (Yeniden boyutlandırma için değişkenlere kaydedildi)
StatsText := MyGui.Add("Text", "w150 Center vStatsText", "Analyzing Memory...")
MemBar := MyGui.Add("Progress", "w150 h20 cGreen vMemBar", 0)

; Buttons / Düğmeler
BtnOptimize := MyGui.Add("Button", "w150 h25 y+10 Default vBtnOptimize", "Optimize RAM Now")
BtnOptimize.OnEvent("Click", OptimizeRAM)

; Resize Event / Yeniden Boyutlandırma Olayı
MyGui.OnEvent("Size", GuiResize)

; Initialize State / Başlangıç Durumu
if (AlwaysOnTopState = "1") {
    ContextMenu.Check("Always on Top")
    MyGui.Opt("+AlwaysOnTop")
}

; Apply Initial Theme / Başlangıç Temasını Uygula
SetTheme(CurrentTheme)

if (MiniModeState = "1") {
    ContextMenu.Check("Mini Mode")
    BtnOptimize.Visible := false

    ; Add Optimize Now menu item for Mini Mode (Insert before Theme)
    try ContextMenu.Insert("Theme", "Optimize Now", OptimizeRAM)
    try ContextMenu.SetIcon("Optimize Now", "shell32.dll", 138)

    MyGui.Show("AutoSize")
} else {
    MyGui.Show()
}

; -- Timers / Zamanlayıcılar --
SetTimer(UpdateStats, 1000)
UpdateStats() ; Run once immediately

if (AutoOptState = "1") {
    ContextMenu.Check("Auto-Optimize")
    SetTimer(OptimizeRAM, 30 * 60 * 1000)
}

; -- Functions / Fonksiyonlar --

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    PostMessage(0xA1, 2, 0, MyGui.Hwnd) ; WM_NCLBUTTONDOWN
}

ShowContextMenu(*) {
    ContextMenu.Show()
}

GuiResize(thisGui, MinMax, Width, Height) {
    if (MinMax = -1) ; Minimized
        return

    ; Resize controls to fit width (keeping margins)
    NewWidth := Width - 20 ; 10 margin each side
    if (NewWidth < 100)
        return

    try {
        StatsText.Move(, , NewWidth)
        MemBar.Move(, , NewWidth)
        if (MiniModeState = "0")
            BtnOptimize.Move(, , NewWidth)
    }
}

ShowTooltip(wParam, lParam, msg, hwnd) {
    static PrevHwnd := 0
    if (hwnd = PrevHwnd)
        return
    PrevHwnd := hwnd

    ToolTip() ; Hide previous

    try {
        CtrlObj := GuiCtrlFromHwnd(hwnd)
        if !CtrlObj
            return

        if (CtrlObj = StatsText)
            ToolTip("Shows current RAM usage statistics.")
        else if (CtrlObj = MemBar)
            ToolTip("Visual representation of RAM usage.")
        else if (CtrlObj = BtnOptimize)
            ToolTip("Click to release unused RAM from all running processes.")

        SetTimer(RemoveToolTip, -3000)
    }
}

RemoveToolTip() {
    ToolTip()
}

ToggleAlwaysOnTop(*) {
    global AlwaysOnTopState
    AlwaysOnTopState := !AlwaysOnTopState

    if AlwaysOnTopState {
        MyGui.Opt("+AlwaysOnTop")
        ContextMenu.Check("Always on Top")
        IniWrite("1", IniFile, "Settings", "AlwaysOnTop")
    } else {
        MyGui.Opt("-AlwaysOnTop")
        ContextMenu.Uncheck("Always on Top")
        IniWrite("0", IniFile, "Settings", "AlwaysOnTop")
    }
}

SetTheme(ThemeName) {
    global CurrentTheme
    CurrentTheme := ThemeName

    ; Update Menu Checks
    ThemeMenu.Check("Dark")
    ThemeMenu.Check("Light")
    if (ThemeName = "Dark") {
        ThemeMenu.Check("Dark")
        ThemeMenu.Uncheck("Light")

        ; Apply Dark
        MyGui.BackColor := "1E1E1E"
        MyGui.SetFont("cWhite", "Segoe UI")
        StatsText.SetFont("cWhite")
        MemBar.Opt("Background333333")

        ; Enable Dark Titlebar/Borders for Windows 10/11 / Win 10/11 için Karanlık Başlık Çubuğu
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", MyGui.Hwnd, "Int", 20, "Int*", 1, "Int", 4)
    } else {
        ThemeMenu.Check("Light")
        ThemeMenu.Uncheck("Dark")

        ; Apply Light
        MyGui.BackColor := "White"
        MyGui.SetFont("cBlack", "Segoe UI")
        StatsText.SetFont("cBlack")
        MemBar.Opt("BackgroundSilver")

        ; Disable Dark Titlebar/Borders for Windows 10/11 / Win 10/11 için Karanlık Başlık Çubuğunu Kapat
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", MyGui.Hwnd, "Int", 20, "Int*", 0, "Int", 4)
    }

    ; Save Setting
    IniWrite(ThemeName, IniFile, "Settings", "Theme")
}

UpdateStats() {
    static MEMORYSTATUS := Buffer(64, 0)
    NumPut("UInt", 64, MEMORYSTATUS)

    ; GlobalMemoryStatusEx
    if DllCall("Kernel32.dll\GlobalMemoryStatusEx", "Ptr", MEMORYSTATUS) {
        Load := NumGet(MEMORYSTATUS, 4, "UInt")
        TotalPhys := NumGet(MEMORYSTATUS, 8, "UInt64")
        AvailPhys := NumGet(MEMORYSTATUS, 16, "UInt64")
        UsedPhys := TotalPhys - AvailPhys

        GB := 1024 * 1024 * 1024
        TotalGB := Round(TotalPhys / GB, 2)
        UsedGB := Round(UsedPhys / GB, 2)
        FreeGB := Round(AvailPhys / GB, 2)

        StatsText.Value := Format("Used: {1} GB / {2} GB ({3}%)", UsedGB, TotalGB, Load)
        MemBar.Value := Load

        ; Change color based on load
        if (Load > 80)
            MemBar.Opt("cRed")
        else if (Load > 60)
            MemBar.Opt("cYellow")
        else
            MemBar.Opt("cGreen")
    }
}

OptimizeRAM(*) {
    StatsText.Value := "Optimizing... Please Wait"
    BtnOptimize.Enabled := false

    FreedCount := 0
    ProcCount := 0

    ; Better approach: Iterate Processes / Daha iyi yaklaşım: İşlemleri Yinele
    for ProcessName in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process") {
        try {
            PID := ProcessName.ProcessId
            ; OpenProcess: PROCESS_QUERY_INFORMATION (0x0400) | PROCESS_SET_QUOTA (0x0100)
            hProcess := DllCall("OpenProcess", "UInt", 0x0500, "Int", 0, "UInt", PID, "Ptr")

            if hProcess {
                ; EmptyWorkingSet
                res := DllCall("psapi.dll\EmptyWorkingSet", "Ptr", hProcess)
                if res
                    FreedCount++

                DllCall("CloseHandle", "Ptr", hProcess)
                ProcCount++
            }
        }
    }

    UpdateStats()
    BtnOptimize.Enabled := true
    MsgBox("Optimization Complete!`nProcessed " ProcCount " applications.", "RAM Optimizer", "Iconi T2")
}

ToggleAutoOpt(*) {
    global AutoOptState
    AutoOptState := !AutoOptState

    if (AutoOptState) {
        ContextMenu.Check("Auto-Optimize")
        SetTimer(OptimizeRAM, 30 * 60 * 1000) ; 30 mins
        IniWrite("1", IniFile, "Settings", "AutoOptimize")
    } else {
        ContextMenu.Uncheck("Auto-Optimize")
        SetTimer(OptimizeRAM, 0) ; Off
        IniWrite("0", IniFile, "Settings", "AutoOptimize")
    }
}

ToggleMiniMode(*) {
    global MiniModeState
    MiniModeState := !MiniModeState

    if MiniModeState {
        ContextMenu.Check("Mini Mode")
        BtnOptimize.Visible := false

        ; Add Optimize Now menu item
        try ContextMenu.Insert("Theme", "Optimize Now", OptimizeRAM)
        try ContextMenu.SetIcon("Optimize Now", "shell32.dll", 138)

        MyGui.Show("AutoSize") ; Shrink to fit
        IniWrite("1", IniFile, "Settings", "MiniMode")
    } else {
        ContextMenu.Uncheck("Mini Mode")
        BtnOptimize.Visible := true

        ; Remove Optimize Now menu item
        try ContextMenu.Delete("Optimize Now")

        MyGui.Show("AutoSize") ; Restore
        IniWrite("0", IniFile, "Settings", "MiniMode")
    }
}
