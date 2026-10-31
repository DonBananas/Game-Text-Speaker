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

; --- CONFIGURAZIONE ---
; "webspeech" = pagina locale in Edge che parla con le voci di Edge: niente ricarica né
;               cambio di finestra (al primo avvio bisogna cliccare una volta sulla pagina)
; "browser"   = finestra di Edge e Leggi ad alta voce (Ctrl+Shift+U) - testato e affidabile
; "edgetts"   = voci Natural senza finestra, ma la connessione di edge-tts è lenta (2-10 s)
global Backend := "webspeech"
global WebVoice := "Ava Multilingual"            ; parte del nome della voce di Edge
global WebRate := "1.1"                            ; velocità per "webspeech", es. "1.15"
global WebPort := 8765
global WebMinimize := true                       ; riduci a icona la pagina dopo il clic
global Voice := "en-US-AvaMultilingualNeural"   ; voce per "edgetts"
global Rate := "+0%"                             ; velocità per "edgetts", es. "+15%"
global PythonExe := EnvGet("LOCALAPPDATA") "\Programs\Python\Python314\pythonw.exe"
global BrowserReloadWait := 400                  ; solo per "browser": attesa dopo F5 (ms)

; Correzioni degli errori tipici dell'OCR (espressioni regolari, applicate in ordine)
global Fixes := [
    ["(*UCP)\bII(?=\s+\p{Ll})", "Il"],               ; "II gatto" -> "Il gatto" (non "secondo")
    ["(*UCP)(?<=[\p{L},;:]\s)Al\b(?!')", "AI"],      ; "the Al said" -> "the AI said" (non a inizio frase)
    ["(?<=\s)\|(?=\s)", "I"],                        ; "|" isolato -> "I"
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
				; ClipWait invece di uno Sleep fisso: 20 ms a volte non bastavano
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

; OCR dell'area. Un errore o un risultato vuoto non deve bloccare lo script:
; si riprova una volta ingrandendo di più e in scala di grigi.
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
	text := RegExReplace(text, "(*UCP)(\p{Ll})-\n(\p{Ll})", "$1$2")  ; parole spezzate a fine riga
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
			Loop 5 {   ; pagine rimaste da un avvio precedente
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
	; Le opzioni disattivano il "congelamento" delle finestre nascoste/fuori schermo
	; (funzionano solo se Edge non era già aperto).
	Run 'msedge.exe --new-window --disable-features=CalculateNativeWinOcclusion --disable-backgrounding-occluded-windows "file:///' filePath '"'
	; La finestra in modalità finestra non funzionava: la massimizziamo da soli.
	if WinWait(EdgeWin(), , 10)
		WinMaximize EdgeWin()
}

; La pagina segnala il clic: togliamo il messaggio e la riduciamo a icona.
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
	FileMove tmp, A_ScriptDir "\request.txt", 1   ; spostamento atomico
}

StopReading() {
	if (Backend != "browser") {
		SendRequest("")
		return
	}
	if WinExist(EdgeWin()) && ActivateEdge()
	{
		prevWin := WinGetID("A")
		Send "^+u" ; Preme di nuovo Ctrl+Shift+U per fermare la lettura in corso
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

	; Trova la finestra di Edge (solo Edge, non altre finestre con "page.txt" nel titolo)
	if !WinExist(EdgeWin())
	{
		ToolTip "Edge window not found."
		SetTimer () => ToolTip(), -2000
		return
	}
	; FORZIAMO LA FINESTRA FUORI SCHERMO E IN PRIMO PIANO
	if WinGetMinMax(EdgeWin()) != 1
		WinMaximize EdgeWin()
	WinMove(-10000, -10000, 800, 600, EdgeWin())
	if !ActivateEdge()
		return

	; Aggiorniamo la pagina per caricare il nuovo testo
	Send "{F5}"
	Sleep BrowserReloadWait

	; Facciamo partire la lettura ad alta voce
	Send "^+u"
	Sleep 50

	; Torniamo subito al gioco
	try WinActivate prevWin
}

; Windows a volte rifiuta di cambiare finestra: controlliamo e riproviamo,
; altrimenti F5 e Ctrl+Shift+U finirebbero nel gioco.
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
