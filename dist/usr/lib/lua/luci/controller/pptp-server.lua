module("luci.controller.pptp-server", package.seeall)

function index()
    local has_vpn = false
    local has_pptp = nixio.fs.access("/etc/config/pptpd")
    
    -- Проверяем наличие PPTP
    if has_pptp then
        has_vpn = true
    end
    
    -- Здесь можно добавить проверки других VPN
    -- if nixio.fs.access("/etc/config/openvpn") then
    --     has_vpn = true
    -- end
    
    -- Создаём раздел VPN только если есть хотя бы один VPN-сервис
    if has_vpn then
        -- Создаем родительский раздел VPN
        entry({"admin", "vpn"}, firstchild(), _("VPN"), 45)
            .dependent = false
            .acl_depends = { "luci-app-pptp-server" }
            .index = true
        
        -- Добавляем PPTP только если он установлен
        if has_pptp then
            entry({"admin", "vpn", "pptp-server"}, 
                 cbi("pptp-server/pptp-server"), 
                 _("PPTP VPN Server"), 10).dependent = true
            
            entry({"admin", "vpn", "pptp-server", "status"}, 
                 call("action_status")).leaf = true
        end
    end
end

-- Функция для получения статуса сервиса
function action_status()
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()
    
    local status = {
        running = (sys.call("pidof pptpd >/dev/null") == 0),
        enabled = sys.init.enabled("pptpd"),
        clients = {}
    }
    
    -- Получаем информацию о подключенных клиентах
    local leasefile = uci:get("pptpd", "pptpd", "leasefile") or "/tmp/pptpd.leases"
    if nixio.fs.access(leasefile) then
        for line in io.lines(leasefile) do
            local ip, client = line:match("^(%S+)%s+(%S+)")
            if ip and client then
                table.insert(status.clients, {
                    ip = ip,
                    name = client
                })
            end
        end
    end
    
    luci.http.prepare_content("application/json")
    luci.http.write_json(status)
end

-- Дополнительные функции управления сервисом
function start_pptpd()
    luci.sys.init.start("pptpd")
end

function stop_pptpd()
    luci.sys.init.stop("pptpd")
end

function enable_pptpd()
    luci.sys.init.enable("pptpd")
end

function disable_pptpd()
    luci.sys.init.disable("pptpd")
end
