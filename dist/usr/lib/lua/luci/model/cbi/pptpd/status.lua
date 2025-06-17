local m = Map("pptpd", translate("PPTPD Status"))
m.pageaction = false

local s = m:section(SimpleSection)
s.template = "pptpd/status"

return m
