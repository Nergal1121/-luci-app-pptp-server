-- Убрана неиспользуемая зависимость
mp = Map("pptpd", _("PPTP VPN Server"), _("Point-to-Point Tunneling Protocol Server"))

-- Секция основного сервиса
s = mp:section(NamedSection, "pptpd", "vpn", _("PPTP Service"))
s.anonymous = true  -- Исправлено: anonymouse -> anonymous

s:option(Flag, "enabled", _("Enable Service"))

localip = s:option(Value, "localip", _("Server IP Address"))
localip.datatype = "ip4addr"
localip.description = _("Local IP address of the VPN server"))

remoteip = s:option(Value, "remoteip", _("Client IP Range"))
remoteip.datatype = "iprange"  -- Более точная валидация
remoteip.description = _("IP address range for VPN clients (e.g. 192.168.100.100-200)"))

-- Секция пользователей
logins = mp:section(TypedSection, "login", _("PPTP Users"))
logins.addremove = true
logins.anonymous = true  -- Исправлено: anonymouse -> anonymous

username = logins:option(Value, "username", _("Username"))
username.datatype = "string"

password = logins:option(Value, "password", _("Password"))
password.datatype = "string"
password.password = true  -- Добавлено: отображение пароля звёздочками

-- Автоматическая настройка фаервола при сохранении
function mp.on_after_save(self)  -- Изменено на on_after_save для более предсказуемого поведения
    require "luci.model.uci"
    require "luci.sys"

    local cursor = luci.model.uci.cursor()
    local have_pptp_rule = false
    local have_gre_rule = false

    cursor:foreach('firewall', 'rule',
        function (section)
            if section.name == 'pptp-rule' then
                have_pptp_rule = true
            elseif section.name == 'gre-rule' then
                have_gre_rule = true
            end
        end
    )

    if not have_pptp_rule then
        cursor:section('firewall', 'rule', 'pptp-rule', {
            name = 'pptp-rule',
            target = 'ACCEPT',
            src = 'wan',
            proto = 'tcp',
            dest_port = '1723'
        })
    end

    if not have_gre_rule then
        cursor:section('firewall', 'rule', 'gre-rule', {
            name = 'gre-rule',
            target = 'ACCEPT',
            src = 'wan',
            proto = '47'  -- Исправлено: протокол вместо порта
        })
    end

    cursor:save('firewall')
    cursor:commit('firewall')
    luci.sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
end

-- Улучшенная функция проверки статуса
function get_pptpd_status()
    local sys = require "luci.sys"
    local enabled = sys.init.enabled("pptpd")
    local running = sys.process.info("pidof pptpd") and true or false
    
    return {
        running = running,
        enabled = enabled,
        status_text = running and _("PPTPD is running") or _("PPTPD is stopped"),
        enabled_text = enabled and _("Enabled on startup") or _("Disabled on startup")
    }
end

-- Секция статуса и управления
status_section = mp:section(SimpleSection)
status_section.template = "pptp-server/status"  -- Использование шаблона для статуса

-- Кнопки управления
ctrl_section = mp:section(Table, {{}})
ctrl_section.anonymous = true

local status = get_pptpd_status()

-- Кнопки запуска/остановки
if not status.running then
    start_btn = ctrl_section:option(Button, "_start", _("Start Service"))
    start_btn.inputstyle = "apply"
    function start_btn.write()
        luci.sys.init.start("pptpd")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptp-server"))
    end
else
    stop_btn = ctrl_section:option(Button, "_stop", _("Stop Service"))
    stop_btn.inputstyle = "remove"
    function stop_btn.write()
        luci.sys.init.stop("pptpd")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptp-server"))
    end
end

-- Кнопки автозапуска
if status.enabled then
    disable_btn = ctrl_section:option(Button, "_disable", _("Disable Autostart"))
    disable_btn.inputstyle = "reset"
    function disable_btn.write()
        luci.sys.init.disable("pptpd")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptp-server"))
    end
else
    enable_btn = ctrl_section:option(Button, "_enable", _("Enable Autostart"))
    enable_btn.inputstyle = "apply"
    function enable_btn.write()
        luci.sys.init.enable("pptpd")
        luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptp-server"))
    end
end

return mp
