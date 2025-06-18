local sys = require "luci.sys"  -- Исправили имя переменной для sys
local net = require "luci.model.network".init()
local ifaces = sys.net:devices()  -- Исправили s.net на sys.net
local m, section, o  -- Переименовали s в section для ясности
m = Map("luci-app-pptp-server", translate("PPTP VPN Server"))
m.description = translate("Simple, quick and convenient PPTP VPN, universal across the platform")
m.template = "pptpd/index"

section = m:section(TypedSection, "service")
section.anonymous = true

o = section:option(DummyValue, "pptpd_status", translate("Current Condition"))
o.template = "pptpd/status"
o.value = translate("Collecting data...")

o = section:option(Flag, "enabled", translate("Enable VPN Server"))
o.rmempty = false

o = section:option(Value, "localip", translate("Server IP"), translate("VPN Server IP address, it not required."))
o.datatype = "ipaddr"
o.placeholder = translate("192.168.1.2")
o.rmempty = true
o.default = "192.168.1.2"

o = section:option(Value, "remoteip", translate("Client IP"), translate("VPN Client IP address, it not required."))
o.placeholder = translate("192.168.1.10-20")
o.rmempty = true
o.default = "192.168.1.10-20"

o = section:option(Flag, "mppe", translate("Enable MPPE Encryption"), translate("Allows 128-bit encrypted connection."))
o.rmempty = false

-- Статус сервиса (исправленная версия)
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
local status_section = m:section(Table, {{}})  -- Исправили на создание таблицы с одной пустой строкой
status_section.anonymous = true

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
