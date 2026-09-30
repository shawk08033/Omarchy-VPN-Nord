# NordVPN — Omarchy bar widget

Control the official NordVPN Linux client from the Omarchy Quattro bar.

Repository: https://github.com/shawk08033/Omarchy-VPN-Nord

## Features

- Connect / disconnect from the bar or popup
- Switch servers by country
- Toggle auto-connect (reconnect on OS startup), with an optional preferred country
- Set DNS: Off, Cloudflare, Google, or up to three custom IPv4 servers
- Keep Tailscale connected at the same time (allowlists `100.64.0.0/10` and UDP `41641`)
- Show current public IP and Tailscale hostname/IP when Tailscale is connected

## Requirements

- Omarchy with the Quickshell plugin system
- Official NordVPN Linux client on `PATH`
- Authenticated client with `nordvpnd` running:

  ```bash
  nordvpn status
  ```

The plugin shells out to `nordvpn` with argument arrays only. It does not
read credentials or edit NordVPN config files directly.

## Install

```bash
omarchy plugin add https://github.com/shawk08033/Omarchy-VPN-Nord.git --enable
```

If you already use another NordVPN bar widget, disable it first:

```bash
omarchy plugin disable io.github.guiestrela.nordvpn
```

Local development copy:

```bash
PLUGIN_ID="shaunhawk.nordvpn"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
rsync -a --delete --exclude .git ./ "$PLUGIN_DIR/"
omarchy plugin validate "$PLUGIN_DIR"
omarchy plugin enable "$PLUGIN_ID" right
omarchy-shell shell rescanPlugins
```

## Usage

| Action | Behavior |
| --- | --- |
| Left-click | Open / close the popup |
| Middle-click | Connect / disconnect |
| Right-click | Refresh status |
| `c` in popup | Connect / disconnect |
| `r` in popup | Refresh |

## Tailscale coexistence

With **Allow Tailscale with NordVPN** enabled (default), the plugin runs:

```bash
nordvpn allowlist add subnet 100.64.0.0/10
nordvpn allowlist add port 41641 protocol UDP
```

That runs when settings sync and again before connect/country switch, so Tailscale
can stay up while NordVPN is connected. Turn the toggle off to remove those
allowlist entries.

## Notes

- NordVPN’s CLI exposes **auto-connect** (start VPN after login/boot). Dropped
  tunnels are handled by the daemon; there is no separate “auto reconnect”
  switch beyond that plus Kill Switch in the NordVPN client itself.
- Setting custom DNS turns off Threat Protection in the NordVPN client.

## Remove

```bash
omarchy plugin remove shaunhawk.nordvpn --yes
```

## License

MIT — see [LICENSE](LICENSE).

Author: Shaun Hawk \<shaun@shaunhawk.com\>
