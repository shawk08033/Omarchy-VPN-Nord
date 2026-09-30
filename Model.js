function countryLabel(name) {
  return String(name || "").trim().replace(/\s+/g, " ")
}

function parseCountries(raw) {
  var lines = String(raw || "").split("\n")
  var seen = {}
  var out = []
  for (var i = 0; i < lines.length; i++) {
    var country = lines[i].trim()
    if (country === "" || /^countries:?$/i.test(country) || seen[country]) continue
    seen[country] = true
    out.push({ value: country, label: countryLabel(country) })
  }
  out.sort(function(a, b) {
    return a.label < b.label ? -1 : (a.label > b.label ? 1 : 0)
  })
  return out
}

function parseStatus(raw) {
  var text = String(raw || "")
  function field(name) {
    var match = text.match(new RegExp("^" + name + "\\s*:\\s*(.+)$", "im"))
    return match ? match[1].trim() : ""
  }
  var status = field("Status")
  var normalized = status.toLowerCase()
  var state = normalized.indexOf("connected") === 0 ? "Connected"
    : normalized.indexOf("connecting") === 0 ? "Connecting"
    : normalized.indexOf("disconnecting") === 0 ? "Disconnecting"
    : normalized.indexOf("reconnecting") === 0 ? "Reconnecting"
    : normalized.indexOf("disconnected") === 0 ? "Disconnected"
    : status || "Unknown"
  return {
    state: state,
    country: field("Country"),
    city: field("City"),
    server: field("Server"),
    ip: field("IP") || field("Hostname")
  }
}

function parseSettings(raw) {
  var values = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*([^:]+):\s*(.*?)\s*$/)
    if (!match) continue
    var key = match[1].trim().toLowerCase().replace(/\s+/g, "-")
    values[key] = match[2].trim()
  }
  return values
}

// Tailscale uses CGNAT 100.64.0.0/10. NordVPN must allowlist that subnet
// (and usually UDP 41641) so both tunnels can stay up together.
var TAILSCALE_SUBNET = "100.64.0.0/10"
var TAILSCALE_PORT = "41641"

function hasTailscaleSubnet(rawOrSettings) {
  var text = typeof rawOrSettings === "string"
    ? rawOrSettings
    : JSON.stringify(rawOrSettings || {})
  return text.indexOf(TAILSCALE_SUBNET) !== -1
}

function hasTailscalePort(rawOrSettings) {
  var text = typeof rawOrSettings === "string"
    ? rawOrSettings
    : JSON.stringify(rawOrSettings || {})
  return new RegExp("\\b" + TAILSCALE_PORT + "\\b").test(text)
}

function tailscaleAllowlisted(rawSettingsText, parsedSettings) {
  var blob = String(rawSettingsText || "") + "\n" + JSON.stringify(parsedSettings || {})
  return hasTailscaleSubnet(blob)
}

function settingEnabled(value) {
  return /^(enabled|on|yes|true)$/i.test(String(value || "").trim())
}

function isIpv4(value) {
  var parts = String(value || "").trim().split(".")
  if (parts.length !== 4) return false
  for (var i = 0; i < parts.length; i++) {
    if (!/^\d{1,3}$/.test(parts[i])) return false
    var n = parseInt(parts[i], 10)
    if (n < 0 || n > 255) return false
  }
  return true
}

function parseDnsServers(value) {
  var raw = String(value || "").trim()
  if (raw === "" || /^(disabled|off|false|0)$/i.test(raw)) return []
  var parts = raw.split(/[,\s]+/)
  var out = []
  for (var i = 0; i < parts.length; i++) {
    var part = parts[i].trim()
    if (isIpv4(part) && out.indexOf(part) < 0) out.push(part)
  }
  return out.slice(0, 3)
}

function normalizeDnsServers(values) {
  var out = []
  for (var i = 0; i < values.length && out.length < 3; i++) {
    var part = String(values[i] || "").trim()
    if (part === "") continue
    if (!isIpv4(part)) return { ok: false, servers: [], error: "DNS servers must be IPv4 addresses" }
    if (out.indexOf(part) < 0) out.push(part)
  }
  if (out.length === 0) return { ok: false, servers: [], error: "Enter at least one DNS server" }
  return { ok: true, servers: out, error: "" }
}

function dnsMode(value) {
  var servers = parseDnsServers(value)
  if (servers.length === 0) return "off"
  if (servers.length === 2 && servers[0] === "1.1.1.1" && servers[1] === "1.0.0.1") return "cloudflare"
  if (servers.length === 2 && servers[0] === "8.8.8.8" && servers[1] === "8.8.4.4") return "google"
  return "custom"
}

function autoConnectTarget(value) {
  var target = String(value || "").trim()
  if (target === "") return ""
  if (/^[a-z]{2}(?:[0-9]+)?$/i.test(target)) return target.toLowerCase()
  var codes = {
    "argentina": "ar", "australia": "au", "austria": "at", "belgium": "be",
    "botswana": "bw", "brazil": "br", "bulgaria": "bg", "canada": "ca",
    "chile": "cl", "colombia": "co", "costa rica": "cr", "croatia": "hr",
    "cyprus": "cy", "czech republic": "cz", "denmark": "dk", "estonia": "ee",
    "finland": "fi", "france": "fr", "georgia": "ge", "germany": "de",
    "greece": "gr", "hong kong": "hk", "hungary": "hu", "iceland": "is",
    "india": "in", "indonesia": "id", "ireland": "ie", "israel": "il",
    "italy": "it", "japan": "jp", "latvia": "lv", "luxembourg": "lu",
    "malaysia": "my", "mexico": "mx", "moldova": "md", "netherlands": "nl",
    "new zealand": "nz", "nigeria": "ng", "norway": "no", "poland": "pl",
    "portugal": "pt", "romania": "ro", "serbia": "rs", "singapore": "sg",
    "slovakia": "sk", "slovenia": "si", "south africa": "za", "south korea": "kr",
    "spain": "es", "sweden": "se", "switzerland": "ch", "taiwan": "tw",
    "thailand": "th", "turkey": "tr", "ukraine": "ua",
    "united arab emirates": "ae", "united kingdom": "uk", "united states": "us",
    "vietnam": "vn"
  }
  if (codes[target.toLowerCase()]) return codes[target.toLowerCase()]
  return /^[a-z][a-z .'-]{1,63}$/i.test(target) ? target : ""
}

function statusText(state) {
  switch (String(state || "")) {
    case "Connected": return "Connected"
    case "Connecting": return "Connecting…"
    case "Reconnecting": return "Reconnecting…"
    case "Disconnecting": return "Disconnecting…"
    case "Disconnected": return "Disconnected"
    case "Unavailable": return "Unavailable"
    default: return "Checking…"
  }
}

function elide(text) {
  var value = String(text || "").replace(/\s+/g, " ").trim()
  return value.length > 140 ? value.substring(0, 137) + "…" : value
}

function parsePublicIp(raw) {
  var value = String(raw || "").replace(/\s+/g, "").trim()
  if (isIpv4(value)) return value
  // Accept a bare IPv6 address without validating every form.
  if (/^[0-9a-f:]+$/i.test(value) && value.indexOf(":") !== -1) return value
  return ""
}

function cleanDnsName(name) {
  return String(name || "").replace(/\.$/, "").trim()
}

function parseTailscaleStatus(raw) {
  var text = String(raw || "").trim()
  if (text === "") {
    return {
      ok: true,
      connected: false,
      state: "Stopped",
      hostname: "",
      dnsName: "",
      ip: "",
      ips: []
    }
  }
  try {
    var data = JSON.parse(text)
    var backendState = String(data.BackendState || "Unknown")
    var self = data.Self || {}
    var ips = []
    var source = self.TailscaleIPs || data.TailscaleIPs || []
    for (var i = 0; i < source.length; i++) {
      var ip = String(source[i] || "").trim()
      if (ip !== "" && ips.indexOf(ip) < 0) ips.push(ip)
    }
    var hostname = String(self.HostName || "").trim()
    var dnsName = cleanDnsName(self.DNSName)
    var connected = backendState === "Running"
    return {
      ok: true,
      connected: connected,
      state: backendState,
      hostname: hostname,
      dnsName: dnsName,
      ip: ips.length > 0 ? ips[0] : "",
      ips: ips
    }
  } catch (e) {
    return {
      ok: false,
      connected: false,
      state: "Unavailable",
      hostname: "",
      dnsName: "",
      ip: "",
      ips: []
    }
  }
}

function tailscaleSummary(info) {
  if (!info || !info.connected) {
    var state = info && info.state ? String(info.state) : "Stopped"
    if (state === "NeedsLogin") return "Needs login"
    if (state === "Stopped" || state === "") return "Not connected"
    return state
  }
  var parts = []
  if (info.hostname) parts.push(info.hostname)
  if (info.ip) parts.push(info.ip)
  else if (info.dnsName) parts.push(info.dnsName)
  return parts.length > 0 ? parts.join(" · ") : "Connected"
}
