local s = require "luci.sys"
local net = require"luci.model.network".init()
local ifaces = s.net:devices()
local m, s, o
m = Map("luci-app-pptp-server", translate("PPTP VPN Server"))
m.description = translate("Simple, quick and convenient PPTP VPN, universal across the platform")
m.template = "pptpd/index"

s = m:section(TypedSection, "service")
s.anonymous = true

o = s:option(DummyValue, "pptpd_status", translate("Current Condition"))
o.template = "pptpd/status"
o.value = translate("Collecting data...")

o = s:option(Flag, "enabled", translate("Enable VPN Server"))
o.rmempty = false

o = s:option(Value, "localip", translate("Server IP"), translate("VPN Server IP address, it not required."))
o.datatype = "ipaddr"
o.placeholder = translate("192.168.1.2")
o.rmempty = true
o.default = "192.168.1.2"

o = s:option(Value, "remoteip", translate("Client IP"), translate("VPN Client IP address, it not required."))
o.placeholder = translate("192.168.1.10-20")
o.rmempty = true
o.default = "192.168.1.10-20"

--[[
o = s:option(Value, "dns", translate("DNS IP address"), translate("This will be sent to the client, it not required."))
o.placeholder = translate("192.168.1.1")
o.datatype = "ipaddr"
o.rmempty = true
o.default = "192.168.1.1"
]]--

o = s:option(Flag, "mppe", translate("Enable MPPE Encryption"), translate("Allows 128-bit encrypted connection."))
o.rmempty = false

-- Статус сервиса
local pid = luci.util.exec("/usr/bin/pgrep pptpd")

function pptpd_process_status()
    local status = "PPTPD is not running now and "
    
    if pid ~= "" then
        status = "PPTPD is running with the PID " .. pid .. " and "
    end
    
    if nixio.fs.access("/etc/rc.d/S60pptpd") then
        status = status .. "it's enabled on the startup"
    else
        status = status .. "it's disabled on the startup"
    end
    
    return { { status = status } }
end

t = m:section(Table, pptpd_process_status())
t.anonymous = true
t:option(DummyValue, "status", translate("Service Status"))

-- Кнопки управления
if pid == "" then
    start = t:option(Button, "_start", translate("Start"))
    start.inputstyle = "apply"
    function start.write(self, section)
        luci.util.exec("/etc/init.d/pptpd start")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/settings"))
    end
else
    stop = t:option(Button, "_stop", translate("Stop"))
    stop.inputstyle = "reset"
    function stop.write(self, section)
        luci.util.exec("/etc/init.d/pptpd stop")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/settings"))
    end
end

if nixio.fs.access("/etc/rc.d/S60pptpd") then
    disable = t:option(Button, "_disable", translate("Disable from startup"))
    disable.inputstyle = "remove"
    function disable.write(self, section)
        luci.util.exec("/etc/init.d/pptpd disable")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/settings"))
    end
else
    enable = t:option(Button, "_enable", translate("Enable on startup"))
    enable.inputstyle = "apply"
    function enable.write(self, section)
        luci.util.exec("/etc/init.d/pptpd enable")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/settings"))
    end
end
return m
