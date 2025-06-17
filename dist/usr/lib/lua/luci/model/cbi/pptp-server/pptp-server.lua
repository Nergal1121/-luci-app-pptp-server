-- Подключаем необходимые библиотеки
local uci = require "luci.model.uci".cursor()
local sys = require "luci.sys"
local util = require "luci.util"
local init = require "luci.sys.init"

-- Основной объект карты конфигурации
mp = Map("pptpd", 
    translate("PPTP VPN Server"), 
    translate("Configure Point-to-Point Tunneling Protocol (PPTP) server")
)

-- Раздел основного сервиса
local s = mp:section(NamedSection, "pptpd", "vpn", translate("Service Settings"))
s.anonymous = true  -- Исправлена опечатка: было 'anonymouse'

-- Опция включения сервиса
local enabled = s:option(Flag, "enabled", translate("Enable Service"))
enabled.default = "0"
enabled.rmempty = false

-- Локальный IP-адрес сервера
local localip = s:option(Value, "localip", translate("Server IP"))
localip.datatype = "ip4addr"
localip.placeholder = "192.168.100.1"

-- Диапазон IP для клиентов
local remoteip = s:option(Value, "remoteip", translate("Client IP Range"))
remoteip.datatype = "string"
remoteip.placeholder = "192.168.100.2-100"

-- Раздел для учетных записей
local logins = mp:section(TypedSection, "login", translate("PPTP Accounts"))
logins.addremove = true
logins.anonymous = false  -- Показывать заголовки секций
logins.template = "cbi/tblsection"  -- Шаблон для табличного вида

-- Поле имени пользователя
local username = logins:option(Value, "username", translate("Username"))
username.datatype = "string"
username.placeholder = "user1"

-- Поле пароля (скрытый ввод)
local password = logins:option(Value, "password", translate("Password"))
password.password = true  -- Исправлено: скрывать ввод пароля
password.datatype = "string"

-- Функция для проверки состояния сервиса
local function get_service_status()
    local pid = util.exec("pgrep -x pptpd"):match("%d+")
    local running = pid and true or false
    local enabled = init.enabled("pptpd")
    
    return {
        running = running,
        enabled = enabled,
        pid = pid
    }
end

-- Раздел статуса сервиса
local status_section = mp:section(SimpleSection)
status_section.template = "pptp-server/status"  -- Использовать кастомный шаблон

-- Обработчик сохранения (добавляет правила фаервола)
function mp.on_save(self)
    local has_pptp_rule = false
    local has_gre_rule = false
    
    -- Поиск существующих правил
    uci:foreach("firewall", "rule",
        function(s)
            if s.name == "pptp_server_rule" then
                has_pptp_rule = true
            elseif s.name == "gre_server_rule" then
                has_gre_rule = true
            end
        end
    )
    
    -- Добавление недостающих правил
    if not has_pptp_rule then
        uci:section("firewall", "rule", "pptp_server_rule", {
            name = "pptp_server_rule",
            proto = "tcp",
            dest_port = "1723",
            target = "ACCEPT",
            src = "wan"
        })
    end
    
    if not has_gre_rule then
        uci:section("firewall", "rule", "gre_server_rule", {
            name = "gre_server_rule",
            proto = "gre",
            target = "ACCEPT",
            src = "wan"
        })
    end
    
    -- Сохранение и применение изменений
    if not has_pptp_rule or not has_gre_rule then
        uci:save("firewall")
        uci:commit("firewall")
        sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
    end
end

-- Кнопки управления сервисом
local control = status_section:option(Button)
control.template = "pptp-server/control"  -- Кастомный шаблон для кнопок

-- Обработчики действий
function control.start(self)
    sys.init.start("pptpd")
    luci.http.redirect(luci.dispatcher.build_url("admin/services/pptp-server"))
end

function control.stop(self)
    sys.init.stop("pptpd")
    luci.http.redirect(luci.dispatcher.build_url("admin/services/pptp-server"))
end

function control.enable(self)
    sys.init.enable("pptpd")
    luci.http.redirect(luci.dispatcher.build_url("admin/services/pptp-server"))
end

function control.disable(self)
    sys.init.disable("pptpd")
    luci.http.redirect(luci.dispatcher.build_url("admin/services/pptp-server"))
end

return mp
