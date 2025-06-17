module("luci.controller.pptpd", package.seeall)

function index()
    if not nixio.fs.access("/etc/config/pptpd") then
        return
    end

    entry({"admin", "vpn"}, firstchild(), "VPN", 45).dependent = false
    entry({"admin", "vpn", "pptpd"}, alias("admin", "vpn", "pptpd", "settings"), _("PPTP VPN Server"), 48)
    entry({"admin", "vpn", "pptpd", "settings"}, cbi("pptpd/settings"), _("General Settings"), 10).leaf = true
    entry({"admin", "vpn", "pptpd", "users"}, cbi("pptpd/users"), _("Users Manager"), 20).leaf = true
    entry({"admin", "vpn", "pptpd", "online"}, cbi("pptpd/online"), _("Online Users"), 30).leaf = true
    entry({"admin", "vpn", "pptpd", "status"}, call("action_status"), _("Status"), 40).leaf = true
end

function action_status()
    local sys = require "luci.sys"
    local uci = require "luci.model.uci".cursor()
    
    local status = {
        running = (sys.call("pgrep pptpd >/dev/null") == 0),
        enabled = sys.init.enabled("pptpd")
    }
    
    luci.template.render("pptpd/status", {status=status})
end
