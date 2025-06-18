m = Map("pptpd", translate("PPTP VPN Server"))
m.description = translate("Simple, quick and convenient PPTP VPN, universal across the platform")

s = m:section(TypedSection, "login", translate("Users Manager"))
s.addremove = true
s.anonymous = true
s.template = "cbi/tblsection"

-- Поле "Enabled" (Включено)
o = s:option(Flag, "enabled", translate("Enabled"))
o.rmempty = false

-- Поле "Client Name" (Имя клиента)
o = s:option(Value, "client", translate("Client Name"))  -- Используем option "client"
o.placeholder = translate("Optional client identifier")
o.rmempty = true
o.datatype = "string"

-- Поле User name (Имя пользователя)
o = s:option(Value, "username", translate("User name"))
o.placeholder = translate("User name")
o.rmempty = true

-- Поле Password (Пароль)
o = s:option(Value, "password", translate("Password"))
o.rmempty = true
o.password = true  -- Скрываем ввод пароля

-- Поле IP address (IP-адрес)
o = s:option(Value, "ipaddress", translate("IP address"))
o.placeholder = translate("Automatically")
o.datatype = "ipaddr"
o.rmempty = true

return m
