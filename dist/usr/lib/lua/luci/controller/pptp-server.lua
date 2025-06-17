module("luci.controller.pptp-server", package.seeall) 
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
local pid = luci.util.exec("/usr/bin/pgrep pptpd")

function pptpd_process_status()
  local status = "PPTPD is not running now and "

  if pid ~= "" then
      status = "PPTPD is running with the PID " .. pid .. "and "
  end

  if nixio.fs.access("/etc/rc.d/S60pptpd") then
    status = status .. "it's enabled on the startup"
  else
    status = status .. "it's disabled on the startup"
  end

  local status = { status=status }
  local table = { pid=status }
  return table
end

t = mp:section(Table, pptpd_process_status())
t.anonymous = true

t:option(DummyValue, "status", translate("PPTPD status"))

if pid == "" then
  start = t:option(Button, "_start", translate("Start"))
  start.inputstyle = "apply"
  function start.write(self, section)
        message = luci.util.exec("/etc/init.d/pptpd start 2>&1")
        luci.util.exec("sleep 4")
        luci.http.redirect(
                luci.dispatcher.build_url("admin", "services", "pptp-server") .. "?message=" .. message
        )
  end
else
  stop = t:option(Button, "_stop", translate("Stop"))
  stop.inputstyle = "reset"
  function stop.write(self, section)
        luci.util.exec("/etc/init.d/pptpd stop")
        luci.util.exec("sleep 4")
        luci.http.redirect(
                luci.dispatcher.build_url("admin", "services", "pptp-server")
        )
  end
end

if nixio.fs.access("/etc/rc.d/S60pptpd") then
  disable = t:option(Button, "_disable", translate("Disable from startup"))
  disable.inputstyle = "remove"
  function disable.write(self, section)
        luci.util.exec("/etc/init.d/pptpd disable")
        luci.util.exec("sleep 1")
        luci.http.redirect(
                luci.dispatcher.build_url("admin", "services", "pptp-server")
        )
  end
else
  enable = t:option(Button, "_enable", translate("Enable on startup"))
  enable.inputstyle = "apply"
  function enable.write(self, section)
        luci.util.exec("/etc/init.d/pptpd enable")
        luci.util.exec("sleep 1")
        luci.http.redirect(
                luci.dispatcher.build_url("admin", "services", "pptp-server")
        )
  end
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
