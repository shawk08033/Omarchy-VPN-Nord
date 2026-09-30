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
  property string customDns1: ""
  property string customDns2: ""
  property string customDns3: ""
  property bool syncingDnsFields: false

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

  function syncDnsFields() {
    root.syncingDnsFields = true
    root.customDns1 = nord.dnsServers[0] || ""
    root.customDns2 = nord.dnsServers[1] || ""
    root.customDns3 = nord.dnsServers[2] || ""
    root.syncingDnsFields = false
  }

  function applyCustomDns() {
    nord.setDnsServers([root.customDns1, root.customDns2, root.customDns3])
  }

  onOpenedChanged: if (opened) {
    nord.refresh()
    nord.refreshSettings()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Connections {
    target: nord
    function onDnsServersChanged() { root.syncDnsFields() }
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
    tooltipText: "NordVPN — " + nord.statusText + root.tooltipCountry
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
            meta: nord.locationText !== "" ? nord.statusText + " · " + nord.locationText : nord.statusText
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
              text: "TAILSCALE"
              foreground: root.foreground
              fontFamily: root.fontFamily
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
                  ? "Allowlisted 100.64.0.0/10 and UDP 41641 so Tailscale can stay up."
                  : "Applying Tailscale allowlist…")
                : "Off: NordVPN may block Tailscale traffic while connected."
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

              Button {
                width: dnsRow.cellWidth
                text: "Off"
                selected: nord.dnsMode === "off"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                enabled: !nord.unavailable && !nord.settingsBusy
                onClicked: nord.setDnsPreset("off")
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
                onClicked: nord.setDnsPreset("cloudflare")
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
                onClicked: nord.setDnsPreset("google")
              }
              Button {
                width: dnsRow.cellWidth
                text: "Custom"
                selected: nord.dnsMode === "custom"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                enabled: !nord.unavailable
                onClicked: dns1Field.forceActiveFocus()
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
              placeholderText: "Primary DNS (IPv4)"
              text: root.customDns1
              onTextChanged: if (!root.syncingDnsFields) root.customDns1 = text
              onAccepted: applyCustomDns()
            }
            TextField {
              id: dns2Field
              width: parent.width
              foreground: root.foreground
              font.family: root.fontFamily
              placeholderText: "Secondary DNS (optional)"
              text: root.customDns2
              onTextChanged: if (!root.syncingDnsFields) root.customDns2 = text
              onAccepted: applyCustomDns()
            }
            TextField {
              id: dns3Field
              width: parent.width
              foreground: root.foreground
              font.family: root.fontFamily
              placeholderText: "Tertiary DNS (optional)"
              text: root.customDns3
              onTextChanged: if (!root.syncingDnsFields) root.customDns3 = text
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
              text: "Custom DNS disables NordVPN Threat Protection. Up to three IPv4 servers."
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
