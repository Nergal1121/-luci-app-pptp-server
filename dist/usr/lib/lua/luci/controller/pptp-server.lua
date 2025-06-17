module("luci.controller.pptpd", package.seeall)

function index()
    -- Проверяем наличие исполняемого файла pptpd
    if not nixio.fs.access("/usr/sbin/pptpd") then
        return
    end

    -- Создаем меню VPN
    entry({"admin", "vpn"}, firstchild(), _("VPN"), 45).dependent = false
    
    -- Основной пункт меню PPTP VPN
    entry({"admin", "vpn", "pptpd"}, 
          alias("admin", "vpn", "pptpd", "settings"),
          _("PPTP VPN Server"), 48).dependent = true
          
    -- Настройки сервиса
    entry({"admin", "vpn", "pptpd", "settings"}, 
          cbi("pptpd/settings"), 
          _("General Settings"), 10).leaf = true
          
    -- Управление пользователями
    entry({"admin", "vpn", "pptpd", "users"}, 
          cbi("pptpd/users"), 
          _("User Management"), 20).leaf = true
          
    -- Онлайн пользователи
    entry({"admin", "vpn", "pptpd", "online"}, 
          cbi("pptpd/online"), 
          _("Online Users"), 30).leaf = true
          
    -- Статус сервиса (AJAX)
    entry({"admin", "vpn", "pptpd", "status"}, 
          call("action_status")).leaf = true
          
    -- Действия с сервисом
    entry({"admin", "vpn", "pptpd", "service"}, 
          post("action_service")).leaf = true
          
    -- Страница статуса сервиса с управлением
    entry({"admin", "vpn", "pptpd", "service_status"},
          template("pptpd/service_status"),
          _("Service Status"), 40)
end

-- Возвращает расширенный статус сервиса
function action_status()
    local sys = require "luci.sys"
    local fs = require "nixio.fs"
    
    local pid = sys.exec("pgrep -x pptpd"):gsub("%s+", "")
    local enabled = fs.access("/etc/rc.d/S60pptpd")
    local running = pid ~= ""
    
    local status_text
    if running then
        status_text = translatef("PPTPD is running (PID: %s)", pid)
    else
        status_text = translate("PPTPD is stopped")
    end
    
    if enabled then
        status_text = status_text .. ", " .. translate("autostart enabled")
    else
        status_text = status_text .. ", " .. translate("autostart disabled")
    end
    
    local data = {
        running = running,
        enabled = enabled,
        pid = pid,
        status_text = status_text
    }
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(data)
end

-- Обработка действий с сервисом
function action_service()
    local action = luci.http.formvalue("action")
    local sys = require "luci.sys"
    
    if action == "start" then
        sys.call("/etc/init.d/pptpd start >/dev/null 2>&1")
    elseif action == "stop" then
        sys.call("/etc/init.d/pptpd stop >/dev/null 2>&1")
    elseif action == "restart" then
        sys.call("/etc/init.d/pptpd restart >/dev/null 2>&1")
    elseif action == "enable" then
        sys.call("/etc/init.d/pptpd enable >/dev/null 2>&1")
    elseif action == "disable" then
        sys.call("/etc/init.d/pptpd disable >/dev/null 2>&1")
    end
    
    -- Задержка для применения изменений
    sys.call("sleep 1")
    
    luci.http.redirect(luci.dispatcher.build_url("admin/vpn/pptpd/service_status"))
end

-- Получение списка онлайн пользователей
function get_online_users()
    local fs = require "nixio.fs"
    local util = require "luci.util"
    local users = {}
    
    -- Чтение информации о подключенных пользователях
    if fs.access("/var/run/pptp-vpn.status") then
        for line in io.lines("/var/run/pptp-vpn.status") do
            local ifname, username, ip = line:match("^(%S+)%s+(%S+)%s+(%S+)")
            if ifname and username and ip then
                users[#users+1] = {
                    interface = ifname,
                    username = username,
                    ip = ip
                }
            end
        end
    end
    
    return users
end

-- Функция для страницы статуса (добавлена из первого скрипта)
function service_status()
    local sys = require "luci.sys"
    local fs = require "nixio.fs"
    
    local pid = sys.exec("pgrep -x pptpd"):gsub("%s+", "")
    local enabled = fs.access("/etc/rc.d/S60pptpd")
    
    local status = {
        running = pid ~= "",
        enabled = enabled,
        pid = pid
    }
    
    return status
end
