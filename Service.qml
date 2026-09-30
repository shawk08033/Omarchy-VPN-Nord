import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

Item {
  id: root

  property var settings: ({})
  property string autoConnectCountry: String(setting("autoConnectCountry", "")).trim()
  property bool allowTailscale: true

  onSettingsChanged: {
    root.autoConnectCountry = String(setting("autoConnectCountry", "")).trim()
    root.allowTailscale = setting("allowTailscale", true) !== false
  }

  Component.onCompleted: {
    root.allowTailscale = setting("allowTailscale", true) !== false
    root.refreshSettings()
  }
  property string connectionState: "Unknown"
  property string country: ""
  property string city: ""
  property string server: ""
  property string ip: ""
  property var countries: []
  property bool countriesLoaded: false
  property int _desired: -1
  property string actionStatus: ""
  property string lastError: ""
  property string settingsError: ""
  property var vpnSettings: ({})
  property var dnsServers: []
  property string dnsMode: "off"
  property bool tailscaleAllowlisted: false
  property string _statusOutput: ""
  property string _countriesOutput: ""
  property string _settingsOutput: ""
  property string _syncedAutoConnectCountry: ""
  property bool _settingsInitialized: false
  property bool _settingsRefreshPending: false
  property var _allowlistQueue: []
  property bool _allowlistSyncing: false

  readonly property bool connected: connectionState === "Connected"
  readonly property bool transitioning: connectionState === "Connecting"
    || connectionState === "Reconnecting"
    || connectionState === "Disconnecting"
  readonly property bool unavailable: connectionState === "Unavailable"
  readonly property bool active: _desired === -1 ? connected : (_desired === 1)
  readonly property bool busy: statusProcess.running
    || countriesProcess.running
    || controlProcess.running
    || setCountryProcess.running
  readonly property bool settingsBusy: settingsProcess.running
    || setSettingProcess.running
    || dnsProcess.running
    || allowlistProcess.running
    || _allowlistSyncing
  readonly property string statusText: Model.statusText(connectionState)
  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 5, 2, 60)
  readonly property string locationText: {
    if (city !== "" && country !== "") return city + ", " + country
    return country || server || ""
  }

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    return Math.max(min, Math.min(max, n))
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
    if (!countriesLoaded && !countriesProcess.running) countriesProcess.running = true
  }

  function refreshSettings() {
    if (settingsProcess.running) {
      _settingsRefreshPending = true
      return
    }
    settingsProcess.running = true
  }

  function toggle() {
    if (controlProcess.running) return
    _desired = (connected || transitioning) ? 0 : 1
    if (_desired === 1 && root.allowTailscale) root.ensureTailscaleAllowlist()
    controlProcess.command = _desired === 1 ? ["nordvpn", "connect"] : ["nordvpn", "disconnect"]
    controlProcess.running = true
  }

  function enqueueAllowlist(command) {
    if (!command || !command.length) return
    root._allowlistQueue.push(command)
    root.drainAllowlistQueue()
  }

  function drainAllowlistQueue() {
    if (allowlistProcess.running || root._allowlistQueue.length === 0) {
      if (!allowlistProcess.running && root._allowlistQueue.length === 0)
        root._allowlistSyncing = false
      return
    }
    root._allowlistSyncing = true
    allowlistProcess.command = root._allowlistQueue.shift()
    allowlistProcess.running = true
  }

  function ensureTailscaleAllowlist() {
    if (!root.allowTailscale) return
    if (!root.tailscaleAllowlisted)
      root.enqueueAllowlist(["nordvpn", "allowlist", "add", "subnet", Model.TAILSCALE_SUBNET])
    if (!Model.hasTailscalePort(root._settingsOutput + JSON.stringify(root.vpnSettings)))
      root.enqueueAllowlist(["nordvpn", "allowlist", "add", "port", Model.TAILSCALE_PORT, "protocol", "UDP"])
  }

  function clearTailscaleAllowlist() {
    root.enqueueAllowlist(["nordvpn", "allowlist", "remove", "subnet", Model.TAILSCALE_SUBNET])
    root.enqueueAllowlist(["nordvpn", "allowlist", "remove", "port", Model.TAILSCALE_PORT, "protocol", "UDP"])
  }

  function setAllowTailscale(enabled) {
    root.allowTailscale = !!enabled
    if (root.allowTailscale) root.ensureTailscaleAllowlist()
    else root.clearTailscaleAllowlist()
  }

  function syncTailscaleAllowlist() {
    if (!root._settingsInitialized || !root.allowTailscale) return
    if (root.tailscaleAllowlisted
      && Model.hasTailscalePort(root._settingsOutput + JSON.stringify(root.vpnSettings)))
      return
    root.ensureTailscaleAllowlist()
  }

  function setCountry(value) {
    if (!value || setCountryProcess.running) return
    if (root.allowTailscale) root.ensureTailscaleAllowlist()
    setCountryProcess.command = ["nordvpn", "connect", value]
    setCountryProcess.running = true
  }

  function setAutoconnect(enabled) {
    if (setSettingProcess.running) return
    var argument = enabled ? "on" : "off"
    var command = ["nordvpn", "set", "autoconnect", argument]
    if (enabled && root.autoConnectCountry !== "") {
      var target = Model.autoConnectTarget(root.autoConnectCountry)
      if (target === "") {
        root.settingsError = "Invalid auto-connect country"
        root.actionStatus = root.settingsError
        actionStatusTimer.restart()
        return
      }
      root._syncedAutoConnectCountry = root.autoConnectCountry
      command.push(target)
    }
    var optimistic = Object.assign({}, root.vpnSettings)
    optimistic["auto-connect"] = enabled ? "enabled" : "disabled"
    root.vpnSettings = optimistic
    setSettingProcess.command = command
    setSettingProcess.running = true
  }

  function syncAutoConnectCountry() {
    var configured = root.autoConnectCountry
    if (!Model.settingEnabled(root.vpnSettings["auto-connect"]) || configured === "") return
    if (configured === root._syncedAutoConnectCountry || setSettingProcess.running) return
    if (Model.autoConnectTarget(configured) === "") return
    root._syncedAutoConnectCountry = configured
    root.setAutoconnect(true)
  }

  function setDnsOff() {
    if (dnsProcess.running) return
    dnsProcess.command = ["nordvpn", "set", "dns", "off"]
    dnsProcess.running = true
  }

  function setDnsServers(servers) {
    if (dnsProcess.running) return
    var normalized = Model.normalizeDnsServers(servers)
    if (!normalized.ok) {
      root.settingsError = normalized.error
      root.actionStatus = normalized.error
      actionStatusTimer.restart()
      return
    }
    dnsProcess.command = ["nordvpn", "set", "dns"].concat(normalized.servers)
    dnsProcess.running = true
  }

  function setDnsPreset(preset) {
    if (preset === "off") {
      root.setDnsOff()
      return
    }
    if (preset === "cloudflare") {
      root.setDnsServers(["1.1.1.1", "1.0.0.1"])
      return
    }
    if (preset === "google") {
      root.setDnsServers(["8.8.8.8", "8.8.4.4"])
      return
    }
  }

  function applyDnsFromSettings(rawSettings) {
    var value = rawSettings["dns"] || ""
    root.dnsServers = Model.parseDnsServers(value)
    root.dnsMode = Model.dnsMode(value)
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      root.refresh()
      root.refreshSettings()
    }
  }

  Timer {
    id: settleTimer
    property int ticks: 0
    interval: 1000
    repeat: true
    running: false
    onTriggered: {
      ticks += 1
      root.refresh()
      if (ticks >= 6) {
        ticks = 0
        running = false
        root._desired = -1
      }
    }
  }

  Timer {
    id: actionStatusTimer
    interval: 3500
    repeat: false
    onTriggered: {
      root.actionStatus = ""
      root.settingsError = ""
      root.lastError = ""
    }
  }

  Process {
    id: statusProcess
    command: ["nordvpn", "status"]
    stdout: StdioCollector {
      id: statusStdout
      waitForEnd: true
      onStreamFinished: root._statusOutput = text
    }
    onExited: function(exitCode) {
      var output = String(statusStdout.text || root._statusOutput || "").trim()
      if (exitCode === 0 && output !== "") {
        var parsed = Model.parseStatus(output)
        root.connectionState = parsed.state
        root.country = parsed.country
        root.city = parsed.city
        root.server = parsed.server
        root.ip = parsed.ip
        if (root._desired !== -1 && root.connected === (root._desired === 1)) root._desired = -1
      } else {
        root.connectionState = "Unavailable"
        root.country = ""
        root.city = ""
        root.server = ""
        root.ip = ""
      }
    }
  }

  Process {
    id: countriesProcess
    command: ["nordvpn", "countries"]
    stdout: StdioCollector {
      id: countriesStdout
      waitForEnd: true
      onStreamFinished: root._countriesOutput = text
    }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.countries = Model.parseCountries(countriesStdout.text || root._countriesOutput || "")
        root.countriesLoaded = root.countries.length > 0
      }
    }
  }

  Process {
    id: settingsProcess
    command: ["nordvpn", "settings"]
    stdout: StdioCollector { id: settingsStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        var raw = settingsStdout.text || ""
        root._settingsOutput = raw
        var parsed = Model.parseSettings(raw)
        root.vpnSettings = parsed
        root.tailscaleAllowlisted = Model.tailscaleAllowlisted(raw, parsed)
        root.applyDnsFromSettings(parsed)
        root.settingsError = ""
        root._settingsInitialized = true
        root.syncAutoConnectCountry()
        root.syncTailscaleAllowlist()
      } else {
        root.settingsError = "NordVPN settings unavailable"
        root._settingsInitialized = false
        root.actionStatus = root.settingsError
        actionStatusTimer.restart()
      }
      if (root._settingsRefreshPending) {
        root._settingsRefreshPending = false
        Qt.callLater(function() { root.refreshSettings() })
      }
    }
  }

  Process {
    id: allowlistProcess
    command: []
    stdout: StdioCollector { id: allowlistStdout; waitForEnd: true }
    stderr: StdioCollector { id: allowlistStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var output = String(allowlistStderr.text || allowlistStdout.text || "").trim()
      // NordVPN returns non-zero when the entry already exists; treat that as success.
      var already = /already|exists|is in allowlist/i.test(output)
      if (exitCode !== 0 && !already) {
        root.settingsError = Model.elide(output || "Could not update Tailscale allowlist")
        root.actionStatus = root.settingsError
        actionStatusTimer.restart()
        root._allowlistQueue = []
        root._allowlistSyncing = false
      }
      root.drainAllowlistQueue()
      if (!allowlistProcess.running && root._allowlistQueue.length === 0)
        root.refreshSettings()
    }
  }

  Process {
    id: setSettingProcess
    command: []
    stdout: StdioCollector { id: setSettingStdout; waitForEnd: true }
    stderr: StdioCollector { id: setSettingStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var output = String(setSettingStderr.text || setSettingStdout.text || "")
        root.settingsError = Model.elide(output || "NordVPN setting could not be changed")
        root.actionStatus = root.settingsError
        actionStatusTimer.restart()
      } else {
        root.actionStatus = "Setting updated"
        actionStatusTimer.restart()
      }
      root.refreshSettings()
    }
  }

  Process {
    id: dnsProcess
    command: []
    stdout: StdioCollector { id: dnsStdout; waitForEnd: true }
    stderr: StdioCollector { id: dnsStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        var output = String(dnsStderr.text || dnsStdout.text || "")
        root.settingsError = Model.elide(output || "Could not update DNS")
        root.actionStatus = root.settingsError
      } else {
        root.actionStatus = "DNS updated"
      }
      actionStatusTimer.restart()
      root.refreshSettings()
    }
  }

  Process {
    id: controlProcess
    command: []
    stdout: StdioCollector { id: controlStdout; waitForEnd: true }
    stderr: StdioCollector { id: controlStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var stdout = String(controlStdout.text || "")
      var stderr = String(controlStderr.text || "")
      if (exitCode !== 0) {
        root._desired = -1
        root.lastError = Model.elide(stderr || stdout || "NordVPN command failed")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        root.lastError = ""
        root.actionStatus = ""
      }
      settleTimer.ticks = 0
      settleTimer.restart()
    }
  }

  Process {
    id: setCountryProcess
    command: []
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { id: setCountryStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.elide(setCountryStderr.text || "Could not change NordVPN country")
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      }
      settleTimer.ticks = 0
      settleTimer.restart()
    }
  }
}
