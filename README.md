# Game Voice Reader

Read any text on screen out loud: hold a key, draw a box around the text, and a natural
Microsoft Edge voice reads it. Made for games and apps where you can't select or copy
the text, and it handles mixed Italian and English.

- Windows' built-in OCR, nothing to install for text recognition
- Edge's free Natural voices (default: *Ava Multilingual*, which reads Italian and English)
- Starts speaking in a fraction of a second and never steals focus from the game
- Fixes common OCR mistakes before reading, such as `II` → `Il` and `Al` → `AI`

## Requirements

- Windows 10 or 11
- [AutoHotkey v2](https://www.autohotkey.com/)
- [Python 3](https://www.python.org/) (3.12 or newer, no extra packages needed)
- Microsoft Edge

## Setup

1. Download or clone this repository.
2. If Python isn't installed at `%LOCALAPPDATA%\Programs\Python\Python314\`, change
   `PythonExe` at the top of `Game Voice Reader - No Pause.ahk` to your `pythonw.exe`.
3. Run `Game Voice Reader - No Pause.ahk`.
4. An Edge window opens with a blue button. Click it once: Edge only lets a page speak
   after a click. The window then minimizes itself and you'll see *Voce pronta*.

## Controls

| Key | Action |
| --- | --- |
| Hold **F4** | Move the mouse to size the box, release to read |
| **Click** while holding F4 | Save the box (shown in blue) |
| Tap **F4** | Read the saved box again |
| **Right click** while holding F4 | Cancel |
| **F6** | Stop reading |
| **F9** | Quit |

## Settings

All settings are at the top of `Game Voice Reader - No Pause.ahk`:

| Setting | What it does |
| --- | --- |
| `WebRate` | Reading speed: `"1"` is normal, `"1.2"` is 20% faster, `"0.9"` slower |
| `WebVoice` | Part of the Edge voice name, e.g. `"Ava Multilingual"` or `"Isabella"` |
| `WebMinimize` | Minimize the voice page after the click (`false` keeps it open) |
| `Fixes` | OCR corrections applied before reading (regular expressions) |
| `Backend` | How the text is spoken (see below) |

### Reading methods (`Backend`)

- `"webspeech"` (default): a local page in Edge speaks with Edge's own voices. Fastest,
  and nothing switches windows.
- `"browser"`: the original method. It writes the text to `page.txt`, reloads it in an
  off-screen Edge window and starts Edge's Read Aloud (Ctrl+Shift+U). No Python needed.
- `"edgetts"`: plays the voices directly with [edge-tts](https://github.com/rany2/edge-tts)
  and `ffplay`, with no Edge window. Needs `pip install edge-tts` and FFmpeg. Its connection
  can be slow (2–10 s) on some networks.

## Troubleshooting

- **Nothing is read:** check `tts_log.txt` next to the script. It logs each read with the
  delay before the voice started, plus any errors.
- **Wrong voice:** if the log says `voice NOT FOUND`, change `WebVoice` to part of a voice
  name listed in Edge's Read Aloud voice menu.
- **Silent after the window minimizes:** set `WebMinimize := false`.

## How it works

`Game Voice Reader - No Pause.ahk` handles the box and the OCR, cleans up the text and writes
it to `request.txt`. `speech_server.py` serves `speech.html` on `127.0.0.1` and passes each
new request to the page, which reads it aloud with the Web Speech API. Everything stays on
your PC except the voice itself, which Edge fetches from Microsoft.

## Credits

- **OCR:** the text recognition is done by the
  [OCR library for AutoHotkey v2](https://github.com/Descolada/OCR) by **Descolada**, a
  wrapper around the Windows OCR engine, based on earlier work by malcev. It is included
  unchanged in `Lib/OCR.ahk` under its MIT License (`Lib/LICENSE-OCR.txt`). Thank you!
- **Voices:** Microsoft Edge Natural voices.

## License

[MIT](LICENSE) © 2026 Nirma. `Lib/OCR.ahk` keeps its own MIT License © 2023 Descolada.
