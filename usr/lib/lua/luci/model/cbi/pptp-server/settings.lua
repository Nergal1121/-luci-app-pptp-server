local sys = require "luci.sys"
local net = require "luci.model.network".init()
local ifaces = sys.net:devices()
local m, section, o

-- Используем конфиг pptpd
m = Map("pptpd", translate("PPTP VPN Server"))
m.description = translate("Simple, quick and convenient PPTP VPN, universal across the platform")

-- Секция с настройками сервера
section = m:section(NamedSection, "pptpd", "vpn", "PPTP Service")
section.anonymous = true

-- Элемент статуса
o = section:option(DummyValue, "status", translate("Current Condition"))
o.value = translate("Collecting data...")

-- Основные настройки
o = section:option(Flag, "enabled", translate("Enable VPN Server"))
o.rmempty = false
o.default = 1

-- Server IP с валидацией
o = section:option(Value, "localip", translate("Server IP"), 
                   translate("VPN Server IP address"))
o.datatype = "ip4addr"
o.placeholder = "172.16.100.1"
o.default = "172.16.100.1"
function o.validate(self, value)
    if not value:match("^%d+%.%d+%.%d+%.%d+$") then
        return nil, translate("Invalid IP address format")
    end
    return value
end

-- Client IP range с улучшенной валидацией
o = section:option(Value, "remoteip", translate("Client IP Range"), 
                   translate("VPN Client IP address range (e.g., 172.16.100.245-250)"))
o.placeholder = "172.16.100.245-250"
o.default = "172.16.100.245-250"
function o.validate(self, value)
    if not value:match("^%d+%.%d+%.%d+%.%d+%-%d+$") then
        return nil, translate("Invalid IP range format. Use: 192.168.1.100-200")
    end
    return value
end

-- DNS Server
o = section:option(Value, "dns", translate("DNS Server"),
                   translate("DNS server for VPN clients (optional)"))
o.datatype = "ip4addr"
o.placeholder = "8.8.8.8"
o.rmempty = true
function o.validate(self, value)
    if value ~= "" and not value:match("^%d+%.%d+%.%d+%.%d+$") then
        return nil, translate("Invalid DNS address format")
    end
    return value
end

-- WINS Server (для NetBIOS)
o = section:option(Value, "wins", translate("WINS Server"),
                   translate("WINS server for NetBIOS name resolution (optional)"))
o.datatype = "ip4addr"
o.placeholder = "192.168.1.1"
o.rmempty = true
function o.validate(self, value)
    if value ~= "" and not value:match("^%d+%.%d+%.%d+%.%d+$") then
        return nil, translate("Invalid WINS address format")
    end
    return value
end

-- MPPE Encryption
o = section:option(Flag, "mppe", translate("Enable MPPE Encryption"), 
                   translate("Allows 128-bit encrypted connection."))
o.rmempty = false
o.default = 1

-- Статус сервиса
local function get_pptpd_status()
    local pid = luci.util.exec("/usr/bin/pgrep pptpd") or ""
    local enabled = nixio.fs.access("/etc/rc.d/S60pptpd")
    
    local status_msg = "PPTPD is "
    status_msg = status_msg .. (pid ~= "" and "running" or "not running")
    status_msg = status_msg .. " and "
    status_msg = status_msg .. (enabled and "enabled" or "disabled")
    status_msg = status_msg .. " on startup"
    
    if pid ~= "" then
        status_msg = status_msg .. " (PID: " .. pid:gsub("\n", "") .. ")"
    end
    
    return status_msg, pid, enabled
end

-- Секция статуса
local status_section = m:section(Table, {{}})
status_section.anonymous = true
status_section.title = translate("Service Control")

-- Элемент статуса
local status_value = status_section:option(DummyValue, "status", translate("Service Status"))
status_value.rawhtml = true
function status_value.cfgvalue()
    local status_msg = get_pptpd_status()
    return "<strong>" .. status_msg .. "</strong>"
end

-- Кнопки управления
local status_msg, pid, enabled = get_pptpd_status()

if pid == "" then
    start = status_section:option(Button, "_start", translate("Start"))
    start.inputstyle = "apply"
    function start.write(self, section)
        luci.util.exec("/etc/init.d/pptpd start")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/settings"))
    end
else
    stop = status_section:option(Button, "_stop", translate("Stop"))
    stop.inputstyle = "reset"
    function stop.write(self, section)
        luci.util.exec("/etc/init.d/pptpd stop")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/settings"))
    end
end

if enabled then
    disable = status_section:option(Button, "_disable", translate("Disable from startup"))
    disable.inputstyle = "remove"
    function disable.write(self, section)
        luci.util.exec("/etc/init.d/pptpd disable")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/settings"))
    end
else
    enable = status_section:option(Button, "_enable", translate("Enable on startup"))
    enable.inputstyle = "apply"
    function enable.write(self, section)
        luci.util.exec("/etc/init.d/pptpd enable")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/settings"))
    end
end

return m
