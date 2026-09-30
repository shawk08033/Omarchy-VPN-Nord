import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "shaunhawk.nordvpn"
  ipcTarget: "shaunhawk.nordvpn"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: (bar && bar.fontFamily) ? bar.fontFamily : Style.font.family
  readonly property color iconColor: nord.unavailable ? urgent : (nord.active ? foreground : dim)
  readonly property color barIconColor: nord.unavailable
    ? Qt.darker(barForeground, 1.2)
    : (nord.active ? barForeground : Qt.darker(barForeground, 1.55))
  readonly property string toggleHint: nord.active ? "Disconnect" : "Connect"
  readonly property string tooltipCountry: nord.locationText !== "" ? " (" + nord.locationText + ")" : ""

  property bool updatingCountryPicker: false
  // Seed DNS boxes once from NordVPN (or again only after a preset click).
  // Never rewrite them while the user is typing.
  property bool dnsAllowSeed: true

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Service { id: nord; settings: root.settings }

  function persistSetting(key, value) {
    if (!root.bar || !root.bar.shell || typeof root.bar.shell.updateEntryInline !== "function") return
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    entry[key] = value
    root.settings = entry
    root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function seedDnsFields() {
    if (!root.dnsAllowSeed) return
    dns1Field.text = nord.dnsServers[0] || ""
    dns2Field.text = nord.dnsServers[1] || ""
    dns3Field.text = nord.dnsServers[2] || ""
    root.dnsAllowSeed = false
  }

  function applyCustomDns() {
    nord.setDnsServers([
      String(dns1Field.text || "").trim(),
      String(dns2Field.text || "").trim(),
      String(dns3Field.text || "").trim()
    ])
  }

  function applyDnsPreset(preset) {
    root.dnsAllowSeed = true
    nord.setDnsPreset(preset)
  }

  onOpenedChanged: if (opened) {
    nord.refresh()
    nord.refreshSettings()
  }

  Connections {
    target: nord
    function onDnsServersChanged() { root.seedDnsFields() }
    function onCountryChanged() {
      if (countryPicker.value !== nord.country) {
        root.updatingCountryPicker = true
        countryPicker.value = nord.country
        root.updatingCountryPicker = false
      }
    }
    function onAutoConnectCountryChanged() {
      autoConnectCountryPicker.value = nord.autoConnectCountry
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰦝"
    foreground: root.barIconColor
    tooltipText: "NordVPN — " + nord.heroMeta + root.tooltipCountry
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) nord.refresh()
      else if (buttonCode === Qt.MiddleButton) nord.toggle()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(900))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: countryPicker.popupOpen
        || autoConnectCountryPicker.popupOpen
        || dns1Field.activeFocus
        || dns2Field.activeFocus
        || dns3Field.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (dns1Field.activeFocus || dns2Field.activeFocus || dns3Field.activeFocus)
          return
        if (t === "r" || t === "R") nord.refresh()
        else if (t === "c" || t === "C") nord.toggle()
      }

      Flickable {
        id: panelScroll
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height

        Column {
          id: column
          width: panelScroll.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "NordVPN"
            meta: nord.heroMeta
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: nord.unavailable ? 0.5 : (nord.active ? 1.0 : 0.6)
            iconComponent: Component {
              Text {
                text: "󰦝"
                color: root.iconColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                id: powerSwitch
                checked: nord.active
                busy: nord.busy || nord.unavailable
                interactive: !nord.unavailable
                foreground: hero.foreground
                onToggled: nord.toggle()
                PanelToolTip {
                  visible: powerSwitch.containsMouse
                  text: root.toggleHint
                  fontFamily: hero.fontFamily
                }
              }
            }
          }

          Text {
            visible: nord.actionStatus !== "" || nord.lastError !== "" || nord.settingsError !== ""
            width: parent.width
            text: nord.actionStatus !== ""
              ? nord.actionStatus
              : (nord.lastError !== "" ? nord.lastError : nord.settingsError)
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader {
              text: "NETWORK"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Text {
              width: parent.width
              text: "Public IP: " + nord.publicIpLine
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Text {
              width: parent.width
              visible: nord.connected && nord.ip !== "" && nord.ip !== nord.publicIp
              text: "NordVPN IP: " + nord.ip
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Text {
              width: parent.width
              text: "Tailscale: " + nord.tailscaleLine
              color: nord.tailscaleConnected ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Text {
              width: parent.width
              visible: nord.tailscaleDetailLine !== ""
              text: nord.tailscaleDetailLine
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Row {
              width: parent.width
              spacing: Style.space(8)
              Text {
                width: parent.width - tailscaleSwitch.width - Style.space(8)
                text: "Allow Tailscale with NordVPN"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
              }
              ToggleSwitch {
                id: tailscaleSwitch
                checked: nord.allowTailscale
                busy: nord.settingsBusy
                interactive: !nord.unavailable
                foreground: root.foreground
                onToggled: {
                  var enabled = !checked
                  nord.setAllowTailscale(enabled)
                  root.persistSetting("allowTailscale", enabled)
                }
              }
            }
            Text {
              width: parent.width
              text: nord.allowTailscale
                ? (nord.tailscaleAllowlisted
                  ? "Allowlisted 100.64.0.0/10 + UDP 41641"
                  : "Applying Tailscale allowlist…")
                : "Off: NordVPN may block Tailscale while connected"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader {
              text: "SERVER"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            SearchableDropdown {
              id: countryPicker
              width: parent.width
              showLabel: false
              placeholderText: "Search countries..."
              fontFamily: root.fontFamily
              options: nord.countries
              value: nord.country
              onChanged: function(v) {
                if (!root.updatingCountryPicker) nord.setCountry(v)
              }
            }
            Text {
              width: parent.width
              visible: nord.server !== "" || nord.ip !== ""
              text: {
                var parts = []
                if (nord.server !== "") parts.push(nord.server)
                if (nord.ip !== "") parts.push(nord.ip)
                return parts.join(" · ")
              }
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader {
              text: "AUTO-CONNECT"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Row {
              width: parent.width
              spacing: Style.space(8)
              Text {
                width: parent.width - autoConnectSwitch.width - Style.space(8)
                text: "Reconnect on startup"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                wrapMode: Text.WordWrap
                verticalAlignment: Text.AlignVCenter
              }
              ToggleSwitch {
                id: autoConnectSwitch
                checked: Model.settingEnabled(nord.vpnSettings["auto-connect"])
                busy: nord.settingsBusy
                interactive: !nord.unavailable
                foreground: root.foreground
                onToggled: nord.setAutoconnect(!checked)
              }
            }
            SearchableDropdown {
              id: autoConnectCountryPicker
              width: parent.width
              showLabel: false
              placeholderText: "Preferred country (optional)..."
              fontFamily: root.fontFamily
              options: nord.countries
              value: nord.autoConnectCountry
              onChanged: function(v) {
                nord.autoConnectCountry = v
                root.persistSetting("autoConnectCountry", v)
                if (Model.settingEnabled(nord.vpnSettings["auto-connect"]))
                  nord.setAutoconnect(true)
              }
            }
            Text {
              width: parent.width
              text: nord.autoConnectCountry === ""
                ? "Empty country: NordVPN picks the fastest server when auto-connecting."
                : "Auto-connect will use the selected country."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader {
              text: "DNS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Row {
              id: dnsRow
              width: parent.width
              spacing: Style.space(6)
              readonly property int count: 4
              readonly property real cellWidth: (width - spacing * (count - 1)) / count
              readonly property bool piholeSelected: nord.dnsServers.length > 0
                && nord.piholeDns !== ""
                && nord.dnsServers[0] === nord.piholeDns

              Button {
                width: dnsRow.cellWidth
                text: "Off"
                selected: nord.dnsMode === "off"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                enabled: !nord.unavailable && !nord.settingsBusy
                onClicked: root.applyDnsPreset("off")
              }
              Button {
                width: dnsRow.cellWidth
                text: "Cloudflare"
                selected: nord.dnsMode === "cloudflare"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                enabled: !nord.unavailable && !nord.settingsBusy
                onClicked: root.applyDnsPreset("cloudflare")
              }
              Button {
                width: dnsRow.cellWidth
                text: "Google"
                selected: nord.dnsMode === "google"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                enabled: !nord.unavailable && !nord.settingsBusy
                onClicked: root.applyDnsPreset("google")
              }
              Button {
                width: dnsRow.cellWidth
                text: "Pi-hole"
                selected: dnsRow.piholeSelected
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                enabled: !nord.unavailable && !nord.settingsBusy
                onClicked: {
                  if (nord.piholeDns !== "") dns1Field.text = nord.piholeDns
                  root.applyDnsPreset("pihole")
                }
              }
            }

            Text {
              width: parent.width
              text: nord.dnsServers.length > 0
                ? "Current: " + nord.dnsServers.join(", ")
                : "Current: NordVPN default DNS"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            TextField {
              id: dns1Field
              width: parent.width
              foreground: root.foreground
              font.family: root.fontFamily
              placeholderText: nord.piholeDns !== ""
                ? ("Primary DNS (Pi-hole: " + nord.piholeDns + ")")
                : "Primary DNS / Pi-hole IPv4"
              onAccepted: applyCustomDns()
            }
            TextField {
              id: dns2Field
              width: parent.width
              foreground: root.foreground
              font.family: root.fontFamily
              placeholderText: "Secondary DNS (optional)"
              onAccepted: applyCustomDns()
            }
            TextField {
              id: dns3Field
              width: parent.width
              foreground: root.foreground
              font.family: root.fontFamily
              placeholderText: "Tertiary DNS (optional)"
              onAccepted: applyCustomDns()
            }

            Button {
              width: parent.width
              text: "Apply custom DNS"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              enabled: !nord.unavailable && !nord.settingsBusy
              onClicked: applyCustomDns()
            }

            Text {
              width: parent.width
              text: "Pi-hole / LAN DNS is allowlisted automatically before apply so it stays reachable over NordVPN. Set the Pi-hole address in widget settings (piholeDns), then use the Pi-hole button or Apply. Custom DNS disables Threat Protection."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
          }

          Item {
            width: 1
            height: Style.space(8)
          }
        }
      }
    }
  }
}
