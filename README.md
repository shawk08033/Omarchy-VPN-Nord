# NordVPN — Omarchy bar widget

Control the official [NordVPN](https://nordvpn.com/) Linux client from the
[Omarchy](https://omarchy.org/) Quattro bar: connect, pick a country, manage
auto-connect and DNS, keep Tailscale online, and see your live public IP.

**Plugin ID:** `shaunhawk.nordvpn`  
**Repo:** https://github.com/shawk08033/Omarchy-VPN-Nord

## Features

- Connect / disconnect from the bar icon or popup switch
- Searchable country list for server switching
- Auto-connect on startup, with an optional preferred country
- DNS presets (Off, Cloudflare, Google) plus up to three custom IPv4 servers
- Tailscale coexistence (allowlists `100.64.0.0/10` and UDP `41641`)
- Live **Public IP** and **Tailscale** hostname / IP in the popup

## Requirements

- Omarchy with the Quickshell / Quattro plugin system
- Official NordVPN Linux client on `PATH`, logged in, with `nordvpnd` running:

  ```bash
  nordvpn status
  ```

- Optional: Tailscale on `PATH` for status display and coexistence

The plugin only runs official CLI commands (`nordvpn`, and `tailscale status`
/ `curl` for status). It does not read NordVPN credentials or edit NordVPN
config files directly. Commands are passed as argument arrays — user input is
not interpolated into a shell string.

## Install

```bash
omarchy plugin add https://github.com/shawk08033/Omarchy-VPN-Nord.git --enable
```

Place it on the bar if needed:

```bash
omarchy plugin enable shaunhawk.nordvpn right
# or
omarchy bar move shaunhawk.nordvpn --section right
```

If another NordVPN bar widget is already installed, disable or remove it first
to avoid duplicate icons:

```bash
omarchy plugin disable io.github.guiestrela.nordvpn
# or
omarchy plugin remove io.github.guiestrela.nordvpn --yes
```

## Usage

| Action | Behavior |
| --- | --- |
| Left-click | Open / close the popup |
| Middle-click | Connect / disconnect |
| Right-click | Refresh status |
| `c` in popup | Connect / disconnect |
| `r` in popup | Refresh |
| Escape | Close popup |

### Popup sections

- **NETWORK** — public IP, Tailscale status, and “Allow Tailscale with NordVPN”
- **SERVER** — searchable country picker
- **AUTO-CONNECT** — startup reconnect + optional country
- **DNS** — Off / Cloudflare / Google / custom IPv4 servers (Apply to save)

## Tailscale coexistence

With **Allow Tailscale with NordVPN** enabled (default), the plugin runs:

```bash
nordvpn allowlist add subnet 100.64.0.0/10
nordvpn allowlist add port 41641 protocol UDP
```

Those entries are applied when settings sync and again before connect or
country switch. Turn the toggle off to remove them.

## Settings

Widget settings (also editable from Omarchy’s plugin settings UI):

| Key | Default | Description |
| --- | --- | --- |
| `refreshIntervalSec` | `5` | Status / settings poll interval (2–60) |
| `autoConnectCountry` | `""` | Optional country name or code for auto-connect |
| `allowTailscale` | `true` | Allowlist Tailscale subnet/port alongside NordVPN |

## Validate (maintainers)

```bash
omarchy plugin validate .
```

## Remove

```bash
omarchy plugin remove shaunhawk.nordvpn --yes
```

## Notes

- NordVPN’s CLI **auto-connect** covers reconnect after login/boot. Dropped
  tunnels are handled by the daemon; use NordVPN’s own Kill Switch for hard
  network blocking when the VPN is down.
- Setting custom DNS disables NordVPN Threat Protection in the client.
- Public IP is fetched from `https://api.ipify.org` (shows the current egress
  IP, including the NordVPN exit IP when connected).

## License

MIT — see [LICENSE](LICENSE).

Copyright (c) 2026 Shaun Hawk \<shaun@shaunhawk.com\>
