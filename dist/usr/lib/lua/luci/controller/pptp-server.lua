module("luci.controller.pptp-server", package.seeall)

function index()
    -- Проверяем наличие конфигурации PPTP-сервера
    if not nixio.fs.access("/etc/config/pptpd") then
        return
    end
    
    -- Создаем пункт меню в разделе "Сервисы"
    entry(
        {"admin", "vpn", "pptp-server"}, -- Путь в меню
        cbi("pptp-server/pptp-server"),       -- Файл CBI-модели
        _("PPTP Server"),                     -- Локализованное название
        80                                    -- Порядковый номер в меню
    ).dependent = true  -- Исправлено: страница должна перезагружаться при изменении зависимостей
end
