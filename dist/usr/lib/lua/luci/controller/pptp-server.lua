module("luci.controller.pptp-server", package.seeall)

function index()
    local has_vpn = false
    
    -- Проверяем различные VPN-сервисы
    if nixio.fs.access("/etc/config/pptpd") then
        has_vpn = true
        -- PPTP-сервер
        entry({"admin", "vpn", "pptp-server"}, cbi("pptp-server/pptp-server"), _("PPTP VPN Server"), 80).dependent=false
    end
    
    -- Здесь можно добавить проверки других VPN (OpenVPN, IPSec и т.д.)
    -- if nixio.fs.access("/etc/config/openvpn") then ... end
    
    -- Создаём раздел VPN только если есть хотя бы один VPN-сервис
    if has_vpn then
        entry({"admin", "vpn"}, firstchild(), _("VPN"), 45).dependent = false
    end
end
