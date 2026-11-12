# Cortana

A private, stateless chat interface for the models already installed on this PC.
No Python, Node, or build step — just Windows and your local llama-swap stack.

## Start

Double-click **`Cortana.cmd`** (or the **Cortana** shortcut on the Desktop).

The launcher will:

1. Start the local AI stack (llama-swap on `127.0.0.1:8080`) if it is not already running.
2. Start a tiny local server on `127.0.0.1` (port 8790, or the next free port).
3. Open the chat UI in your default browser.

A small console window stays open — close it to stop the app. To quit from the UI, use
**Settings → Quit Cortana**.

For a feature-by-feature walkthrough, see **[HOW TO USE.md](HOW%20TO%20USE.md)** or click the
**?** button in the app.

## Features

- **Internet killswitch** in the header: one click disables every active network adapter,
  so nothing can reach the internet while you chat. Local models keep working.
  A Windows administrator prompt appears for each toggle. Click the pill again to restore.
- **Live connection badge** — Online / Offline / Blocked — and a toast when the internet
  comes back.
- **Public IP chip** — click **Show IP** to see your current public address, ISP/org, city,
  and local adapter addresses. Handy for confirming a VPN or PeerBlock is active.
- **Reasoning toggle** — turn model thinking off for instant replies, or on for deeper
  answers. Works with llama-swap models (no new model required); a quick switch sits
  under the composer, and the full control is in Settings.
- **Attachments** — attach images/screenshots with the paperclip, paste a screenshot
  (`Ctrl+V`), or drag files onto the window. Images are sent to vision models; text/code
  files are inserted into the prompt. Up to 8 per message.
- **Message actions** — copy any reply, edit and resend your own messages, or regenerate
  the latest answer.
- **Live tokens/sec** while streaming, with final token count and speed under each reply.
- **Auto-discovers every llama-swap model** at `127.0.0.1:8080` (embedding and reranker
  models are hidden), plus LM Studio (`:1234`) if it is running.
- **Model guide** — one click shows which models are loaded now and ranks every local model
  for questions, reasoning, coding, search/RAG, writing, vision, speed, and long context.
  Scores are estimated guidance, not benchmarks.
- Puts **uncensored / abliterated models first** and marks them in the picker.
- Streaming markdown, collapsible **Reasoning**, temperature, system prompt
  (with a "Direct" preset), and a session-only extra OpenAI-compatible endpoint.
- Code blocks with copy buttons. Enter sends, Shift+Enter adds a line, Esc stops.

## Killswitch behavior

- It disables the adapters that were active at that moment and remembers their names, so
  restoring re-enables exactly those adapters.
- Loopback (`127.0.0.1`) is never touched, so the UI and local AI keep working.
- The switch **stays on if you close the app or console window** — that is the point of a
  killswitch. Reopen the app and click **Blocked** to restore internet, or enable the
  adapter from Windows network settings.
- The only file written is `%LOCALAPPDATA%\Cortana\killswitch.json`, containing the
  adapter names and on/off state. It never contains conversation data.
- If you are already offline, the app tells you there is nothing to block.
- The killswitch needs an administrator account; if the UAC prompt is dismissed, nothing
  changes.

## Nothing is recorded

- Messages and attachments live only in the tab's memory. No `localStorage`, cookies,
  IndexedDB, or history.
- The local server writes no request logs.
- Responses are served with `no-store`, so nothing is cached to disk.
- Closing or reloading the tab erases the conversation.
- Chat and model traffic stays on `127.0.0.1`. The **only** external request is the public-IP
  check, and only when you click **Show IP** — it contacts an IP lookup service
  (`ipwho.is` with an `ipify.org` fallback). No message or file is ever uploaded.

llama-swap and llama.cpp may keep their own runtime logs; the interface neither writes nor
reads them. llama-swap unloads models according to the `ttl` in its config.

## Notes

- **Reasoning:** works with llama-swap models. Off sends `enable_thinking:false` through the
  chat template so replies start almost immediately. `qwen-fast` and `qwen-4b` are already
  configured as no-thinking variants. Some models may not expose reasoning — the switch then
  shows **n/a**.
- **Screenshots/images:** use a vision model. Most Qwen models in this stack include a vision
  projector (`qwen`, `qwen-fast`, `qwen-27b`, `qwen-9b`, `qwen-4b`, `coder`, `lfm-omni`);
  `flint`, `qwen-flash` and `architect` are text-only but still work with text-file
  attachments. PNG screenshots are kept as PNG; large images are resized to 1600 px before
  sending.
- **Attachments:** max 8 per message, 20 MB per image, 2 MB per text file (long text is
  truncated to ~28,000 characters). PDFs and Office documents are not supported yet —
  attach a screenshot or extracted text instead.
- **Public IP:** if the check fails, VPN/PeerBlock/firewall may be blocking it. Local IPs are
  still shown. The lookup is manual so the app makes no surprise internet calls.
- "Uncensored" depends on the model you run. This UI adds no filters of its own; the
  **Direct preset** in Settings is a system prompt, not a model modification.
- If a model runtime is not detected, make sure its server is running and that CORS is
  enabled. llama.cpp/llama-swap allow `127.0.0.1` by default; LM Studio needs CORS enabled.
- Tested on Windows with llama-swap at `127.0.0.1:8080` and the models in
  `E:\offline-archive\models`.

## Files

| File | Purpose |
| --- | --- |
| `index.html` | The whole interface (HTML, CSS, JS — self-contained). |
| `server.ps1` | Tiny localhost server, llama-swap startup, IP lookup, and graceful shutdown. |
| `killswitch.ps1` | Elevated adapter toggle used by the killswitch. |
| `logo.ico` / `logo.png` | App icon used by the desktop shortcut and browser tab. |
| `logo-source.jpg` | Original generated artwork. |
| `README.md` | Short overview. |
| `HOW TO USE.md` | Full feature-by-feature guide (also in the app via **?**). |
| `Cortana.cmd` | One-click launcher. |
