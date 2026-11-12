# How to use Cortana

A complete guide to every feature. The same guide is built into the app — click the
**?** button in the top bar, the **How to use this app** link on the welcome screen, or
**Settings → How to use — feature guide**.

---

## 1. Start the app

Double-click **`Cortana.cmd`** or the **Cortana** shortcut on your Desktop.

The launcher:

1. Starts the local AI stack (llama-swap on port 8080) if it is not already running.
2. Starts a small local server on `127.0.0.1` (port 8790, or the next free port).
3. Opens the interface in your default browser.

A console window stays open while the app runs. Use **Settings → Quit Cortana** or close
that console window to stop the server.

No Python, Node, or internet connection is needed for chat.

---

## 2. Pick a model

Use the dropdown in the top bar.

- Every llama-swap model is discovered automatically from `127.0.0.1:8080`
  (embedding and reranker models are hidden).
- LM Studio (`127.0.0.1:1234`) is also detected if its server is running.
- Uncensored / abliterated models are marked and selected first.
- Click the **refresh arrows** (or **Settings → Rescan**) after changing a model in
  `llama-swap\config.yaml`.

**Vision models:** image attachments require a vision-capable model. Most Qwen models in this
stack include a vision projector; `flint`, `qwen-flash` and `architect` are text-only but
still work with text and code files.

The model list is also shown as quick-pick chips on the welcome screen.

**Model guide:** click the bar-chart button in the top bar. It shows the models currently
loaded in llama-swap and ranks every discovered chat model for **Overall**, **Questions**,
**Reasoning**, **Coding**, **Search & RAG**, **Writing**, **Vision**, **Speed**, and **Long
context**. Each row has a **Use** button. Scores are estimates from model family, size,
context, and specialization — not measured benchmarks. The `embed` and `rerank` support
models are listed separately because they power library search, not chat.

---

## 3. Chat

Type in the box at the bottom and press **Enter**.

| Key | Action |
| --- | --- |
| `Enter` | Send |
| `Shift` + `Enter` | New line |
| `Esc` | Stop the reply, close a panel, or cancel an edit |
| `Ctrl` + `Enter` | Save an edit |

- **Stop:** press `Esc` or the square stop button while a reply is streaming.
- **New chat:** the **+** button in the top bar. This clears the current conversation.
- Replies stream live and support Markdown, lists, tables, links, and code blocks.

---

## 4. Attachments and screenshots

Three ways to attach:

1. Click the **paperclip** next to the message box.
2. Paste a screenshot with `Ctrl` + `V`.
3. Drag files anywhere onto the window.

Attached files appear above the composer. Click **×** on one to remove it before sending.

- **Images** are resized to 1600 px and sent to vision models.
- **Text/code files** are read locally and inserted into the prompt with their filename.
- Limits: 8 attachments per message, 20 MB per image, 2 MB per text file.
- Long text is truncated to about 28,000 characters.
- PDFs and Office documents are not supported yet — attach a screenshot or extracted text.

Attachments exist only in this tab. Nothing is uploaded anywhere.

---

## 5. Reasoning vs. instant replies

Thinking models such as Qwen 3 can spend time reasoning before answering. You can turn that
off:

- Quick toggle: the **Reasoning on/off** pill under the composer.
- Full control: **Settings → Reasoning**.

When off, the app sends `enable_thinking: false` through llama-swap's chat template. The model
skips its reasoning phase and starts answering immediately. When on, the model may think
first and its reasoning appears in a collapsible **Reasoning** block above the answer.

- No new model is required. Models `qwen-fast` and `qwen-4b` are already configured as
  no-thinking variants in llama-swap.
- The setting applies to the next reply, not one already streaming.
- With reasoning off, replies can start in a fraction of a second once the model is loaded.

---

## 6. Tokens and speed

The bar under the composer shows:

- **Live** approximate tokens and tokens/second while streaming (marked with `~`).
- The **exact** token count and speed when the reply finishes, e.g. `128 tok · 41 tok/s`.
- Time to first token when you hover the token count under a reply.

Each assistant reply also shows its own token count in the hover actions.

---

## 7. Copy, edit, regenerate

Hover over a message to see its actions (always visible on touch screens).

- **Copy** copies the reply text. Code blocks have their own **copy** button in the header.
- **Edit** appears on your own messages. Change the text and click **Save & resend**:
  everything after that message is replaced and the model answers the edited version.
  `Ctrl` + `Enter` saves, `Esc` cancels.
- **Regenerate** re-runs the latest answer without changing your message.

Edits and regenerations use the same model, attachments, system prompt, temperature, and
reasoning setting.

---

## 8. Internet killswitch

Click the **Online / Blocked** pill in the top bar.

1. Confirm the warning.
2. Windows asks for administrator permission.
3. Every active network adapter is disabled.

The local interface and the AI stack keep working because loopback (`127.0.0.1`) is never
touched.
While it is on, the app shows **Blocked** and refuses IP lookups.

**Important:** the killswitch stays on if you quit the app or close the console. That is
intentional. To restore internet, reopen Cortana and click **Blocked**, or re-enable the
adapter from Windows network settings. If you are already offline, the app tells you there is
nothing to block.

The helper remembers exactly which adapters were on, so restoring returns the machine to its
previous state. The only file it writes is
`%LOCALAPPDATA%\Cortana\killswitch.json` (adapter names + on/off state, never chat data).

---

## 9. Online status and your IP

The header pill shows:

- **Online** — internet is reachable.
- **Offline** — no internet connection.
- **Blocked** — the killswitch is on.

A toast appears when the connection returns or drops.

Click **Show IP** to check:

- Public IP address
- ISP / organization
- City and country
- Local adapter addresses

This is useful for confirming that a VPN is active (the ISP should match the VPN) or that
PeerBlock/firewall is blocking traffic (the check fails).

The IP check is **manual** — the app makes no external request until you click it. It contacts
`ipwho.is`, with `ipify.org` as a fallback. On narrow windows the button is hidden; use
**Settings → Connection → Check IP**.

If the check fails, local IPs still appear. A failure usually means a VPN killswitch,
PeerBlock, firewall, or no internet.

---

## 10. Settings

| Setting | What it does |
| --- | --- |
| **System prompt** | Optional instructions for the model. **Direct preset** fills in a no-nonsense prompt. |
| **Temperature** | 0 = focused and repeatable, higher = more creative. Default 0.8. |
| **Reasoning** | Turn the model's thinking phase on or off. |
| **Context window** | Ollama only; llama-swap sets context in `config.yaml` (2k–32k shown). |
| **Add endpoint** | Connect any OpenAI-compatible local server by URL. |
| **Connection** | Check the public IP and see local adapter addresses. |
| **Detected sources** | Shows llama-swap / LM Studio status; **Rescan** refreshes it. |
| **How to use** | Opens this guide. |
| **Quit Cortana** | Stops the local server. |

Settings are session-only; reopening the app starts from the defaults.

---

## 11. Privacy

- Messages and attachments live only in the browser tab's memory.
- No history, cookies, `localStorage`, IndexedDB, or chat logs.
- The server writes no request logs.
- Responses are served with `no-store`, so nothing is cached to disk.
- Closing or reloading the tab erases the conversation.
- Chat and model traffic stays on `127.0.0.1`.
- The only external request is the manual IP check.
- The killswitch's state file contains adapter names and on/off state only.

llama-swap and llama.cpp may keep their own runtime logs; the interface neither writes nor
reads them. llama-swap unloads models according to the `ttl` in its config.

---

## 12. Troubleshooting

**No models found**
Start the local AI stack — `E:\ai\AI Launcher.vbs` or
`E:\ai\_system\scripts\start-swap-hidden.ps1` — then click the refresh arrows or
**Settings → Rescan**.

**An image request fails**
The selected model may not support vision. Switch to `qwen`, `qwen-9b` or `qwen-4b` (vision)
or attach the content as text.

**The IP check fails**
A VPN killswitch, PeerBlock, firewall, or no internet may be blocking it. Local IPs still
show in Settings. Turning off the killswitch restores access.

**The killswitch is still on**
Reopen the app and click **Blocked** to restore adapters, or enable the adapter in Windows
network settings.

**LM Studio is missing**
Make sure its local server is running and CORS is enabled.

**llama-swap was detected before but not now**
The stack may have stopped. Run `E:\ai\AI Launcher.vbs` or `start-swap-hidden.ps1`, then
rescan. Check `E:\ai\_system\logs\llama-swap.log` if it still does not appear.

**The reasoning toggle says n/a**
That endpoint is not llama-swap or Ollama, so the app has no reasoning control for it.

---

## 13. Files in this folder

| File | Purpose |
| --- | --- |
| `Cortana.cmd` | One-click launcher. |
| `index.html` | The entire interface. |
| `server.ps1` | Local server, llama-swap startup, IP lookup, shutdown. |
| `killswitch.ps1` | Elevated network-adapter toggle. |
| `logo.ico` / `logo.png` | App and shortcut icon. |
| `logo-source.jpg` | Original logo artwork. |
| `README.md` | Short overview. |
| `HOW TO USE.md` | This guide. |

The **Cortana** shortcut on your Desktop points at `Cortana.cmd` and uses
`logo.ico`.
