-- ---@type SDK_SDK
local SDK = require("LeagueSDK.LeagueSDK")

---@type SDK_AIHeroClient
local myHero = SDK.Player

return {
    Q = {
        type = "circular",
        range = 800,
        delay = 0.65,
        radius = 210,
        speed = math.huge
    },
    W = {
        type = "circular",
        range = 950,
        speed = math.huge,
        delay = 0.01,
        radius = 220,
        useHeroSource = true,
    },
    E = {
        type = "linear",
        speed = 2500, -- e cone pulse speed
        range = 1200,
        delay = 0.25,
        width = 200,
        collision = {
            ["Wall"] = true,
            ["Hero"] = false,
            ["Minion"] = false
        },
        debug = true
    },
    R_RANGE = 675,
    ORB_LIFETIME = 6,
    W_GRAB_RANGE = 925,
    W_TARGET_RANGE = 350,
    W_GRAB_OBJS = {
        ["sru_chaosminionsuper"] = true,
        ["sru_orderminionsuper"] = true,
        ["ha_chaosminionsuper"] = true,
        ["ha_orderminionsuper"] = true,
        ["sru_chaosminionranged"] = true,
        ["sru_orderminionranged"] = true,
        ["ha_chaosminionranged"] = true,
        ["ha_orderminionranged"] = true,
        ["sru_chaosminionmelee"] = true,
        ["sru_orderminionmelee"] = true,
        ["ha_chaosminionmelee"] = true,
        ["ha_orderminionmelee"] = true,
        ["sru_chaosminionsiege"] = true,
        ["sru_orderminionsiege"] = true,
        ["ha_chaosminionsiege"] = true,
        ["ha_orderminionsiege"] = true,
        ["sru_krug"] = true,
        ["sru_krugmini"] = true,
        ["testcuberender"] = true,
        ["sru_razorbeakmini"] = true,
        ["sru_razorbeak"] = true,
        ["sru_murkwolfmini"] = true,
        ["sru_murkwolf"] = true,
        ["sru_gromp"] = true,
        ["sru_crab"] = true,
        ["sru_red"] = true,
        ["sru_blue"] = true,
        ["elisespiderling"] = true,
        ["heimertyellow"] = true,
        ["heimertblue"] = true,
        ["malzaharvoidling"] = true,
        ["shacobox"] = true,
        ["yorickghoulmelee"] = true,
        ["yorickbigghoul"] = true
        -- ["zyrathornplant"] = true,
        -- ["zyragraspingplant"] = true,
        -- ["voidgate"] = true,
        -- ["voidspawn"] = true
    },
    E_PUSH_SPEED = 2000,
    E_ORB_CONTACT_RANGE = 800,
    E_ENEMY_CONTACT_RANGE = 700,
    E_ENEMY_PUSH_DIST = 450,
    E_ENEMY_PUSH_MAX_RANGE = 850,
    GetEAngle = function()
        return string.lower(myHero:GetSpell((SDK.Enums.SpellSlot.E)):GetName()) == "syndrae" and 56 or 84
    end,
    GetWDelay = function(src, dst)
        return math.sqrt(src:Distance(dst)) / 43
    end
}
