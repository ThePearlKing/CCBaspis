# Europa, Callisto, Jupiter, and Cashew

**Europa** carries requests over ComputerCraft Rednet. **Callisto** displays pages. **Jupiter** hosts them. They share a solar-system joke with Io and Ganymede. **Cashew** is the page format, joining Pistachio and Peanut in the snack cupboard.

## Host and visit

1. Attach a modem to each computer and open CCSacabam. The computers need modem connectivity; this is a Rednet network, not the public web.
2. On the host, open **Jupiter**. Press D to set a domain such as `workshop.cc`. Press R to choose a folder, initially `/Sites/welcome`. Press Enter to start.
3. On another computer, open **Callisto**, press G, and enter `europa://workshop.cc/`. A computer-ID address such as `europa://123/` works too.
4. Edit `/Sites/welcome/index.cashew` to change the site. Saved changes are served on the next request.

The host must stay running and signed in. Closing Jupiter unregisters its domain. One Jupiter server is supported per Europa module instance; use one per computer. Domains are Rednet hostnames, not registrations with a permanent DNS service. Another computer can impersonate a domain or sender: there is no network authentication or encryption. Files in the published folder are intentionally sent in readable form even if the local drive is encrypted.

Callisto uses Tab and Enter for links/buttons, arrows or the wheel to scroll, G or Ctrl+L for the address, H for home, Backspace for history when not editing, B to bookmark, and L to choose a bookmark. Bookmarks live on the personal drive. `file:///Sites/welcome/index.cashew` previews a local page without a modem. Remote pages cannot open `file://` links.

From Terminal:

```text
europa host workshop.cc /Sites/welcome
europa open europa://workshop.cc/
```

## Cashew pages

```html
<cashew title="Workshop">
  <h1>WELCOME</h1>
  <p>A tiny page, with a working button.</p>
  <input name="name" value="Traveller" />
  <button id="greet">Say hello</button>
  <p>{message}</p>
  <a href="about.cashew">About this site</a>
  <script type="pistachio">
    let message = "Ready."
    on greet
      set message = "Hello, " .. name .. "!"
    end
  </script>
</cashew>
```

Supported elements: `cashew`, `html`, `head`, `body`, `main`, `div`, `title`, `h1`, `h2`, `p`, `pre`, `a`, `button`, `input`, `label`, `br`, `hr`, and `script`. Attributes must be quoted; comments and common HTML entities work. Use block-level links and controls. This is a compact vertical layout language; it does not implement CSS, images, JavaScript, or full HTML inline layout. Normal text uses the terminal font; render-mode `h1` headings use the custom pixel banner font.

`input name="variable"` binds a Pistachio variable. A button invokes its `id` handler, or the handler in an `on` attribute. `{variable}` interpolates into text. Scripts must be inline Pistachio. External scripts and Lua are rejected. Page scripts cannot read/write local files or use `seal`/`unseal`. Their expressions and loops have operation and string-size limits. Local native `.pist` apps retain those capabilities.

Jupiter serves `.cashew`, `.pist`, `.peanut`, and `.txt` files, up to 32 KiB each. Folder URLs default to `index.cashew`. Dotfiles, parent traversal, invalid encoded paths, and other file types are refused. Pages are limited to 256 elements and 32 nested levels. Cashew is deliberately small; a desktop web page will not work unchanged.

## Lua API

```lua
local europa = require("europa")
local page, why = europa.fetch("europa://workshop.cc/")
assert(page, why)
print(page.status, page.mime)
print(page.body)
```

`fetch` returns `{status, body, mime, url, server}` or `nil, error`. `server` is present for a remote response. The request times out after five seconds once the recipient has been found. `open()` opens available modem peripherals; it leaves them open so other applications can share them.

To write a Lua web server:

```lua
local europa = require("europa")
local server = europa.start("workshop.cc", "/Sites/welcome")
while true do
  local event, sender, message, protocol = os.pullEventRaw()
  if event == "terminate" or event == "sacabam_close" then
    server.stop()
    break
  elseif event == "rednet_message" then
    server.receive(sender, message, protocol)
  end
end
```

The protocol is `ccsacabam.europa.v1`. Requests are `{kind="request", id=string, path=string}`. Responses echo `id` and add `kind="response", status, mime, body`. Callisto matches sender, protocol, and request ID, but these checks do not create a cryptographic identity. The server applies a per-sender rate limit of 10 requests per second.

See the official [Rednet API](https://tweaked.cc/module/rednet.html) for modem behavior and the [CraftOS-PC peripheral guide](https://www.craftos-pc.cc/docs/periphemu) for emulator modem attachment.
