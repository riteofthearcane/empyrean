---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

SDK.EventManager:RegisterCallback(SDK.Enums.Events.OnDraw, function()
    local Vector = SDK.Libs.Vector
    local start_time = 65
    local end_time = 25 * 60 + 5
    local switch_time = 15* 60 + 5
    local interval = 30
    if SDK.Game:GetTime() < start_time or SDK.Game:GetTime() > end_time then
        return
    end
    local diff = SDK.Game:GetTime() - start_time
    local wave_time = diff - math.floor(diff / interval) * interval
    local wave_num = math.floor(diff / interval)
    local wave_label = ''
    if SDK.Game:GetTime() < switch_time then
        local remainder = math.fmod(wave_num + 1, 3)
        if remainder == 1 then
            wave_label = 'Not cannon 1'
        elseif remainder == 2 then
            wave_label = 'Not cannon 2'
        else
            wave_label = 'Cannon 3'
        end
    else
        local remainder = math.fmod(wave_num + 1, 2)
        if remainder == 1 then
            wave_label = 'Not cannon 1'
        else
            wave_label = 'Cannon 2'
        end
    end
    local text = wave_label .. '    time: ' .. math.floor(wave_time)
    SDK.Renderer:DrawText(text, 50, Vector(1920, 150, 0), SDK.Libs.Color.GetD3DColor(255,255,255,255))
end)
