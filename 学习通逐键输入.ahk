#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
#MaxThreadsPerHotkey 1
A_IconTip := "学习通逐键输入"

; ================== 可调参数 ==================
START_KEY   := "F9"    ; 开始：把剪贴板内容逐键打进当前输入框
STOP_KEY    := "F10"   ; 紧急停止
CHUNK       := 30      ; 一次发多少个字符
CHUNK_GAP   := 15      ; 每块之间停几毫秒
LINE_GAP    := 60      ; 每次回车后停几毫秒
START_DELAY := 250     ; 按下热键后等几毫秒再开始
TAB_SPACES  := 4       ; Tab 换成几个空格；写 0 表示保留 Tab 原样
BEEP        := true    ; 开始/结束时是否响一声
TIP         := false   ; 是否弹托盘气泡（默认关，气泡会抢焦点）
GUARD_BROWSER := true  ; true = 只在浏览器是前台窗口时才输入
ALIGN_INDENT  := 0     ; 默认不改缩进；1/2 会选中或删除自动缩进，仅按需启用
VERIFY        := false ; 默认不回读、不自动删尾；高级功能会全选复制并可能删除文本
; ==============================================

global g_busy := false
global g_stop := false

for name in ["msedge.exe", "chrome.exe", "firefox.exe", "360se.exe", "360ChromeX.exe", "QQBrowser.exe", "SogouExplorer.exe", "brave.exe", "opera.exe", "vivaldi.exe"]
    try GroupAdd("Browsers", "ahk_exe " name)

Hotkey(START_KEY, TypeClipboard)
Hotkey(STOP_KEY, StopTyping)

StopTyping(*) {
    global g_busy, g_stop
    if g_busy
        g_stop := true
}

TypeClipboard(*) {
    global g_busy, g_stop, CHUNK, CHUNK_GAP, LINE_GAP, START_DELAY, TAB_SPACES, BEEP, TIP, GUARD_BROWSER, ALIGN_INDENT, VERIFY

    if g_busy
        return

    txt := A_Clipboard
    if (txt = "") {
        if BEEP
            SoundBeep(300, 150)
        if TIP
            TrayTip("剪贴板是空的，先复制要输入的内容。", "学习通逐键输入", 2)
        return
    }

    if GUARD_BROWSER {
        if !WinActive("ahk_group Browsers") {
            if BEEP
                SoundBeep(300, 150)
            return
        }
    }

    targetWindow := WinExist("A")

    if (TAB_SPACES > 0)
        txt := StrReplace(txt, "`t", Format("{:" TAB_SPACES "}", ""))
    txt := StrReplace(txt, "`r", "")
    if (SubStr(txt, -1) = "`n")
        txt := SubStr(txt, 1, -1)

    total := StrLen(txt)
    g_stop := false
    g_busy := true

    if BEEP
        SoundBeep(900, 50)
    Sleep START_DELAY

    for idx, line in StrSplit(txt, "`n") {
        if (g_stop || !WinActive("ahk_id " targetWindow)) {
            g_stop := true
            break
        }

        ; 第一行直接打；之后每行先回车，再把编辑器自动补的缩进选中，
        ; 让本行自己的缩进（或正文）把它覆盖掉 —— 否则缩进会逐行累积
        if (idx > 1) {
            Send "{Enter}"
            Sleep LINE_GAP
            if ALIGN_INDENT {
                Send "+{Home}"
                Sleep 12
                if (ALIGN_INDENT >= 2) {
                    Send "{Delete}"
                    Sleep 8
                }
            }
        }

        p := 1
        while (p <= StrLen(line) && !g_stop) {
            if !WinActive("ahk_id " targetWindow) {
                g_stop := true
                break
            }
            SendText(SubStr(line, p, CHUNK))
            p += CHUNK
            Sleep CHUNK_GAP
        }
    }

    ; ---- 回读校验：编辑器（如 ACE/CodeMirror）可能在行尾是 { 时自动补 }，
    ;      会堆在文末。这里全选复制比对，多出来的尾巴用退格删掉。 ----
    if (VERIFY && !g_stop && WinActive("ahk_id " targetWindow)) {
        savedClip := A_Clipboard
        A_Clipboard := ""
        Sleep 60
        Send "^a"
        Sleep 150
        Send "^c"
        Sleep 300
        got := A_Clipboard
        A_Clipboard := savedClip

        if (got != "" && got != txt) {
            extra := StrLen(got) - StrLen(txt)
            if (extra > 0 && SubStr(got, 1, StrLen(txt)) = txt) {
                Send "{End}"
                Sleep 80
                Loop extra {
                    Send "{Backspace}"
                    Sleep 15
                }
            } else {
                if BEEP {
                    SoundBeep(500, 90)
                    Sleep 60
                    SoundBeep(500, 90)
                    Sleep 60
                    SoundBeep(500, 90)
                }
            }
        }
    }

    g_busy := false
    if BEEP
        SoundBeep(g_stop ? 400 : 1200, 60)
    if TIP
        TrayTip(g_stop ? "已停止。" : Format("输入完成，共 {1} 个字符。", total), "学习通逐键输入", 1)
}
