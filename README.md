[QUICK DOWNLOAD](https://github.com/DonBananas/Game-Text-Speaker/archive/refs/heads/main.zip)

# Game Text Speaker

**Reads aloud any text on your screen: games first, but also apps, images, videos and
subtitles. Made for people with low vision.**

Hold a key, draw a box around the text, and a natural-sounding voice reads it to you.
It works in Italian and English, even when both are mixed in the same text.

## Who it's for

- People with **low vision** or **reading difficulties** such as dyslexia
- Anyone who finds small text, long dialogue or fast subtitles tiring to read

## Why not just use a screen reader?

Screen readers like Narrator or NVDA read the text that apps *tell* them about. Games, and
many other programs, draw their text as pictures, so a screen reader sees nothing.
Game Text Speaker reads what is actually **visible on the screen**, so it works where
screen readers can't:

- 🎮 **Games:** dialogue, menus, quests, item descriptions, subtitles
- 🎬 **Videos:** burned-in subtitles and captions
- 🖼️ **Images:** photos, screenshots, comics, scanned pages, image-only PDFs
- 🌐 **Websites and apps** that block copying or hide text inside images

It never takes focus away from your game, and it starts speaking in a fraction of a second.

## Features

- Windows' built-in OCR, so nothing extra to install for text recognition
- Edge's free Natural voices (default: *Ava Multilingual*, which reads Italian and English)
- **Saved box:** save the area where a game shows its dialogue, then just tap a key to read
  it each time
- Adjustable reading speed and voice
- Fixes common OCR mistakes before reading, such as `II` → `Il` and `Al` → `AI`

## Requirements

- Windows 10 or 11
- [AutoHotkey v2](https://www.autohotkey.com/)
- [Python 3](https://www.python.org/) (3.12 or newer, no extra packages needed)
- Microsoft Edge (already included in Windows)

## Setup

1. Download this repository: click the green **Code** button, then **Download ZIP**, and
   unzip it anywhere.
2. If Python isn't installed at `%LOCALAPPDATA%\Programs\Python\Python314\`, change
   `PythonExe` at the top of `Game Text Speaker.ahk` to your `pythonw.exe`.
3. Double-click `Game Text Speaker.ahk`.
4. An Edge window opens with a big blue button. Click it once: Edge only lets a page speak
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

**Good to know:** you draw the box with the mouse, so you need to be able to see roughly
where the text is. For text that always appears in the same place, like game dialogue,
save the box once and then only tap F4.

## Settings

All settings are at the top of `Game Text Speaker.ahk`. Open it with Notepad, change the
value, save, and restart the script.

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
- `"browser"`: writes the text to `page.txt`, reloads it in an off-screen Edge window and
  starts Edge's Read Aloud (Ctrl+Shift+U). No Python needed.
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

`Game Text Speaker.ahk` handles the box and the OCR, cleans up the text and writes it to
`request.txt`. `speech_server.py` serves `speech.html` on `127.0.0.1` and passes each new
request to the page, which reads it aloud with the Web Speech API. Everything stays on your
PC except the voice itself, which Edge fetches from Microsoft.

## Credits

- **OCR:** the text recognition is done by the
  [OCR library for AutoHotkey v2](https://github.com/Descolada/OCR) by **Descolada**, a
  wrapper around the Windows OCR engine, based on earlier work by malcev. It is included
  unchanged in `Lib/OCR.ahk` under its MIT License (`Lib/LICENSE-OCR.txt`). Thank you!
- **Voices:** Microsoft Edge Natural voices.

## License

[MIT](LICENSE) © 2026 Nirma. `Lib/OCR.ahk` keeps its own MIT License © 2023 Descolada.
