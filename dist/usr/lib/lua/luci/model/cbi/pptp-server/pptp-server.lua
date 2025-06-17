mp = Map("pptpd", "PPTP Server", "")

s = mp:section(NamedSection, "pptpd", "vpn", "PPTP Service")
s.anonymous = true  -- Исправлено anonymouse -> anonymous

s:option(Flag, "enabled", translate("Enable"))

localip = s:option(Value, "localip", translate("Local IP"))
localip.datatype = "ip4addr"

remoteip = s:option(Value, "remoteip", translate("Remote IP"))
remoteip.datatype = "string"

logins = mp:section(TypedSection, "login", "PPTP Logins")
logins.addremove = true
logins.anonymous = true  -- Исправлено anonymouse -> anonymous

username = logins:option(Value, "username", translate("User name"))
username.datatype = "string"

password = logins:option(Value, "password", translate("Password"))
password.datatype = "string"

function mp.on_save(self)
    local cursor = luci.model.uci.cursor()
    local have_pptp_rule = false
    local have_gre_rule = false

    cursor:foreach('firewall', 'rule', function(section)
        if section.name == 'pptp' then
            have_pptp_rule = true
        elseif section.name == 'gre' then
            have_gre_rule = true
        end
    end)

    if not have_pptp_rule then
        local pptp_rule_name = cursor:add('firewall', 'rule')
        cursor:set('firewall', pptp_rule_name, 'name', 'pptp')
        cursor:set('firewall', pptp_rule_name, 'target', 'ACCEPT')
        cursor:set('firewall', pptp_rule_name, 'src', 'wan')
        cursor:set('firewall', pptp_rule_name, 'proto', 'tcp')
        cursor:set('firewall', pptp_rule_name, 'dest_port', 1723)
        cursor:save('firewall')
        cursor:commit('firewall')
    end

    if not have_gre_rule then
        local gre_rule_name = cursor:add('firewall', 'rule')
        cursor:set('firewall', gre_rule_name, 'name', 'gre')
        cursor:set('firewall', gre_rule_name, 'target', 'ACCEPT')
        cursor:set('firewall', gre_rule_name, 'src', 'wan')
        cursor:set('firewall', gre_rule_name, 'proto', 'gre')  -- Исправлено для протокола GRE
        cursor:save('firewall')
        cursor:commit('firewall')
    end
end

-- Улучшенная проверка статуса сервиса
function get_pptpd_status()
    local status = {
        running = (luci.sys.call("pidof pptpd >/dev/null") == 0),
        enabled = nixio.fs.access("/etc/rc.d/S60pptpd")
    }
    
    local msg = "PPTPD is "
    msg = msg .. (status.running and "running" or "not running")
    msg = msg .. " and "
    msg = msg .. (status.enabled and "enabled" or "disabled")
    msg = msg .. " on startup"
    
    return { status = msg }
end

t = mp:section(Table, get_pptpd_status())
t.anonymous = true
t:option(DummyValue, "status", translate("PPTPD status"))

local status = get_pptpd_status()

if not status.running then
    start = t:option(Button, "_start", translate("Start"))
    start.inputstyle = "apply"
    function start.write(self, section)
        local message = luci.util.exec("/etc/init.d/pptpd start 2>&1")
        luci.http.redirect(
            luci.dispatcher.build_url("admin", "vpn", "pptp-server") ..
            "?message=" .. luci.http.urlencode(message)
        )
    end
else
    stop = t:option(Button, "_stop", translate("Stop"))
    stop.inputstyle = "reset"
    function stop.write(self, section)
        luci.util.exec("/etc/init.d/pptpd stop")
        luci.http.redirect(
            luci.dispatcher.build_url("admin", "vpn", "pptp-server")
        )
    end
end

if status.enabled then
    disable = t:option(Button, "_disable", translate("Disable from startup"))
    disable.inputstyle = "remove"
    function disable.write(self, section)
        luci.util.exec("/etc/init.d/pptpd disable")
        luci.http.redirect(
            luci.dispatcher.build_url("admin", "vpn", "pptp-server")
        )
    end
else
    enable = t:option(Button, "_enable", translate("Enable on startup"))
    enable.inputstyle = "apply"
    function enable.write(self, section)
        luci.util.exec("/etc/init.d/pptpd enable")
        luci.http.redirect(
            luci.dispatcher.build_url("admin", "vpn", "pptp-server")
        )
    end
end

return mp
