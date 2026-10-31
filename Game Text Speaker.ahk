#Requires AutoHotkey v2
#include .\Lib\OCR.ahk
InstallKeybdHook 1, 1
#UseHook 1

CoordMode "Mouse", "Screen"
CoordMode "ToolTip", "Screen"
SetTitleMatchMode 2

; =====================================================================
;  KEYS - change them here. Write the key name between the quotes.
;  Examples:  "F8"  "CapsLock"  "Numpad0"  "Insert"  "Pause"  "q"
;             "XButton1" / "XButton2" = side buttons on the mouse
;             "MButton"               = clicking the mouse wheel
;  ReadKey must be a single key. StopKey and QuitKey can also be
;  combinations: "^s" = Ctrl+S, "!q" = Alt+Q, "+F6" = Shift+F6.
;  All key names: https://www.autohotkey.com/docs/v2/KeyList.htm
; =====================================================================
global ReadKey := "F4"   ; hold to draw the box, release to read
global StopKey := "F6"   ; stop reading
global QuitKey := "F9"   ; close Game Text Speaker

; --- SETTINGS ---
; How the text is spoken (Backend):
; "webspeech" = a local page in Edge speaks with Edge's own voices: no reloading and no
;               window switching (click the page once each time you start the script)
; "browser"   = Edge window with Read Aloud (Ctrl+Shift+U) - tested and reliable, no Python
; "edgetts"   = Natural voices with no window, but the edge-tts connection can be slow (2-10 s)
global Backend := "webspeech"
global WebVoice := "Ava Multilingual"            ; part of the Edge voice name, e.g. "Isabella"
global WebRate := "1.1"                          ; reading speed: "1" normal, "1.2" faster, "0.9" slower
global WebPort := 8765                           ; local port for the voice page (change only if busy)
global WebMinimize := true                       ; minimize the voice page after the click
global Voice := "en-US-AvaMultilingualNeural"   ; voice for "edgetts"
global Rate := "+0%"                             ; speed for "edgetts", e.g. "+15%"
; Where Python is installed (pythonw.exe runs it without a console window)
global PythonExe := EnvGet("LOCALAPPDATA") "\Programs\Python\Python314\pythonw.exe"
global BrowserReloadWait := 400                  ; "browser" only: wait after reloading (ms)

; Fixes for common OCR mistakes (regular expressions, applied in order)
global Fixes := [
    ["(*UCP)\bII(?=\s+\p{Ll})", "Il"],               ; "II gatto" -> "Il gatto" (not "second")
    ["(*UCP)(?<=[\p{L},;:]\s)Al\b(?!')", "AI"],      ; "the Al said" -> "the AI said" (not at sentence start)
    ["(?<=\s)\|(?=\s)", "I"],                        ; a lone "|" -> "I"
]

global filePath := A_ScriptDir "\page.txt"
global helperPid := 0
SetupKeys()
StartBackend()
OnExit(StopHelper)
; -----------------------

global w := 1200, h := 400, minsize := 5, step := 21, toRun := 0, toSay := "", hbuffer := 0, bX := 0, bY := 0, bW := 0, bH := 0, cX := 0, cY := 0

Loop {
	if toRun == 0
	{
		hbuffer := 8
		Suspend 1
		KeyWait ReadKey , "D"
		MouseGetPos(&x, &y)
		cX := x
		cY := y
		toRun := 1
	}
	else if toRun == 1
	{
		Suspend 0
		if (hbuffer > 0)
			hbuffer := hbuffer - 1
		else
			MouseGetPos(&x, &y)

		w := x-cX
		h := y-cY

		inArea := 0
		if (Abs(x-bX) < bW//2) && (Abs(y-bY) < bH//2) || hbuffer > 0
			inArea := 1

		x := x-w//2
		y := y-h//2

		if (bH != 0)
		{
			if (inArea)
			{
				x := bX
				y := bY
				h := bH
				w := bW
				Highlight(bX-bW//2, bY-bH//2, bW, bH, "Red")
			}
			else
			{
				Highlight(bX-bW//2, bY-bH//2, bW, bH, "Blue")
				Highlight(x-w//2, y-h//2, w, h, "Red")
			}
		}
		else
		{
			Highlight(x-w//2, y-h//2, w, h, "Red")
		}

		if GetKeyState("LButton", "P")
		{
			if (!inArea)
			{
				bX := x
				bY := y
				bH := h
				bW := w
			}
			else
			{
				bX := 0
				bY := 0
				bH := 0
				bW := 0
			}
		}

		if !GetKeyState(ReadKey, "P") || GetKeyState("LButton", "P")
		{
			if hbuffer > 0
			{
				prevClip := ClipboardAll()
				A_Clipboard := ""
				Send "^c"
				; ClipWait instead of a fixed Sleep: 20 ms was sometimes not enough
				if ClipWait(0.1)
					toSay := A_Clipboard
				A_Clipboard := prevClip
			}

			Highlight(-100, -100, 0, 0, "Red")

			if StrLen(toSay) <= 0
				toSay := ReadArea(x-w//2, y-h//2, w, h)

			if StrLen(toSay) > 0
			{
                PlayAllText(CleanText(toSay))
				toSay := ""
                toRun := 0
                Sleep 200
			}
			else
			{
				ToolTip "No text found, try again."
				SetTimer () => ToolTip(), -1500
				toRun := 0
				Sleep 200
			}
			Suspend 1
		}
		else if GetKeyState("RButton")
		{
			toRun := 0
			Highlight(-100, -100, 0, 0, "Red")
			Sleep 1200
		}
		Sleep 25
	}
}

; Registers StopKey and QuitKey and checks that all three key names are valid,
; so a typo gives a clear message instead of a key that silently does nothing.
SetupKeys() {
	if (GetKeyName(ReadKey) == "" || ReadKey ~= "i)^[LR]Button$") {
		MsgBox 'ReadKey := "' ReadKey '" is not a key Game Text Speaker can use.`n`n'
			. 'Use a single key such as "F4", "CapsLock" or "XButton1" (left and right click are already used while drawing the box).`n`n'
			. 'Change it at the top of "' A_ScriptName '".', "Game Text Speaker", "Icon!"
		ExitApp
	}
	for name, key in Map("StopKey", StopKey, "QuitKey", QuitKey) {
		action := name == "StopKey" ? StopHotkey : QuitHotkey
		try {
			; "S" keeps the key working while the script pauses its other hotkeys.
			Hotkey key, action, "S"
		} catch {
			MsgBox name ' := "' key '" is not a valid key.`n`n'
				. 'Use a key such as "F6", or a combination such as "^s" (Ctrl+S).`n`n'
				. 'Change it at the top of "' A_ScriptName '".', "Game Text Speaker", "Icon!"
			ExitApp
		}
	}
}

QuitHotkey(*) => ExitApp()

StopHotkey(*) {
	global toRun := 0
	StopReading()
	ToolTip "Reading stopped."
	SetTimer () => ToolTip(), -2000
}

; OCR of the area. An error or an empty result must not stop the script:
; try once more, zoomed in further and in grayscale.
ReadArea(x, y, w, h) {
	if (w < 4 || h < 4)
		return ""
	scale := h < 60 ? 3 : 2
	try {
		text := OCR.FromRect(x, y, w, h,, scale).Text
		if StrLen(Trim(text)) > 0
			return text
	}
	try return OCR.FromRect(x, y, w, h,, {scale: scale + 1, grayscale: 1}).Text
	return ""
}

CleanText(text) {
	text := StrReplace(text, "`r", "")
	text := RegExReplace(text, "(*UCP)(\p{Ll})-\n(\p{Ll})", "$1$2")  ; words split across lines
	text := StrReplace(text, "`n", " ")
	for fix in Fixes
		text := RegExReplace(text, fix[1], fix[2])
	return RegExReplace(text, " {2,}", " ")
}

StartBackend() {
	global Backend, helperPid
	if (Backend == "webspeech") {
		if !FileExist(PythonExe) {
			MsgBox "Python not found:`n" PythonExe "`n`nUsing the Edge window method instead.", "Game Text Speaker", "Icon!"
			Backend := "browser"
		} else {
			try FileDelete A_ScriptDir "\request.txt"
			try FileDelete A_ScriptDir "\voice_ready.flag"
			Loop 5 {   ; pages left over from a previous run
				if !WinExist("Game Text Speaker ahk_exe msedge.exe")
					break
				WinClose
				WinWaitClose(, , 2)
			}
			Run Format('"{1}" "{2}\speech_server.py" --dir "{2}" --port {3} --parent {4}'
				, PythonExe, A_ScriptDir, WebPort, DllCall("GetCurrentProcessId")), A_ScriptDir, "Hide", &helperPid
			Sleep 300
			Run Format('msedge.exe --new-window --autoplay-policy=no-user-gesture-required '
				. '--disable-features=CalculateNativeWinOcclusion --disable-backgrounding-occluded-windows '
				. '"http://127.0.0.1:{1}/?voice={2}&rate={3}"', WebPort, StrReplace(WebVoice, " ", "%20"), WebRate)
			ToolTip "Click the blue button on the Edge page to turn on the voice."
			SetTimer WaitVoiceReady, 250
			return
		}
	}
	if (Backend == "edgetts") {
		if !FileExist(PythonExe) {
			MsgBox "Python not found:`n" PythonExe "`n`nUsing the Edge window method instead.", "Game Text Speaker", "Icon!"
			Backend := "browser"
		} else {
			try FileDelete A_ScriptDir "\request.txt"
			Run Format('"{1}" "{2}\tts_helper.py" --dir "{2}" --voice "{3}" --rate "{4}" --parent {5}'
				, PythonExe, A_ScriptDir, Voice, Rate, DllCall("GetCurrentProcessId")), A_ScriptDir, "Hide", &helperPid
			return
		}
	}
	if !FileExist(filePath)
		FileAppend " ", filePath, "UTF-8"
	; These options stop Edge from "freezing" hidden or off-screen windows
	; (they only work if Edge was not already open).
	Run 'msedge.exe --new-window --disable-features=CalculateNativeWinOcclusion --disable-backgrounding-occluded-windows "file:///' filePath '"'
	; A non-maximized window didn't work, so we maximize it ourselves.
	if WinWait(EdgeWin(), , 10)
		WinMaximize EdgeWin()
}

; The page reports the click: remove the message and minimize the page.
WaitVoiceReady() {
	flag := A_ScriptDir "\voice_ready.flag"
	if !FileExist(flag)
		return
	SetTimer WaitVoiceReady, 0
	try FileDelete flag
	if WebMinimize && WinExist("Game Text Speaker ahk_exe msedge.exe")
		WinMinimize
	ToolTip "Voice ready. Hold " ReadKey " to read, " StopKey " stops, " QuitKey " quits."
	SetTimer () => ToolTip(), -1500
}

StopHelper(*) {
	if helperPid
		try ProcessClose helperPid
	if (Backend == "webspeech")
		try WinClose "Game Text Speaker ahk_exe msedge.exe"
}

EdgeWin() => "page.txt ahk_exe msedge.exe"

SendRequest(text) {
	tmp := A_ScriptDir "\request.tmp"
	try FileDelete tmp
	FileAppend text, tmp, "UTF-8"
	FileMove tmp, A_ScriptDir "\request.txt", 1   ; atomic move
}

StopReading() {
	if (Backend != "browser") {
		SendRequest("")
		return
	}
	if WinExist(EdgeWin()) && ActivateEdge()
	{
		prevWin := WinGetID("A")
		Send "^+u" ; Press Ctrl+Shift+U again to stop the current reading
		Sleep 50
		try WinActivate prevWin
	}
}

PlayAllText(textToPlay) {
	if (Backend != "browser") {
		SendRequest(textToPlay)
		return
	}
	try FileDelete filePath
	FileAppend textToPlay, filePath, "UTF-8"

	prevWin := WinGetID("A")

	; Find the Edge window (only Edge, not other windows with "page.txt" in the title)
	if !WinExist(EdgeWin())
	{
		ToolTip "Edge window not found."
		SetTimer () => ToolTip(), -2000
		return
	}
	; Move the window off screen and bring it to the front
	if WinGetMinMax(EdgeWin()) != 1
		WinMaximize EdgeWin()
	WinMove(-10000, -10000, 800, 600, EdgeWin())
	if !ActivateEdge()
		return

	; Reload the page to load the new text
	Send "{F5}"
	Sleep BrowserReloadWait

	; Start reading aloud
	Send "^+u"
	Sleep 50

	; Go straight back to the game
	try WinActivate prevWin
}

; Windows sometimes refuses to switch windows: check and retry,
; otherwise F5 and Ctrl+Shift+U would end up in the game.
ActivateEdge() {
	Loop 3 {
		WinActivate EdgeWin()
		if WinWaitActive(EdgeWin(), , 0.3)
			return true
	}
	ToolTip "Edge did not come to the front, try again."
	SetTimer () => ToolTip(), -2000
	return false
}

Highlight(x?, y?, w?, h?, color?, showTime:=0, d:=2) {
	static guis := []
	if IsSet(color) && (color == "Res")
		showTime := 500
	else if !IsSet(x) {
        for _, r in guis
            r.Destroy()
        guis := []
		return
    }
    if !guis.Length {
        Loop 4
            guis.Push(Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x08000000"))
    }
	Loop 4 {
		i:=A_Index
		, x1:=(i=2 ? x+w : x-d)
		, y1:=(i=3 ? y+h : y-d)
		, w1:=(i=1 or i=3 ? w+2*d : d)
		, h1:=(i=2 or i=4 ? h+2*d : d)
		guis[i].BackColor := color
		guis[i].Show("NA x" . x1 . " y" . y1 . " w" . w1 . " h" . h1)
	}
	if showTime > 0 {
		Sleep(showTime)
		Highlight()
	} else if showTime < 0
		SetTimer(Highlight, -Abs(showTime))
}
