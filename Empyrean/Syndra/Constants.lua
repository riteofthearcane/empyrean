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
        speed = 2500    , -- e cone pulse speed
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
        ["SRU_ChaosMinionSuper"] = true,
        ["SRU_OrderMinionSuper"] = true,
        ["HA_ChaosMinionSuper"] = true,
        ["HA_OrderMinionSuper"] = true,
        ["SRU_ChaosMinionRanged"] = true,
        ["SRU_OrderMinionRanged"] = true,
        ["HA_ChaosMinionRanged"] = true,
        ["HA_OrderMinionRanged"] = true,
        ["SRU_ChaosMinionMelee"] = true,
        ["SRU_OrderMinionMelee"] = true,
        ["HA_ChaosMinionMelee"] = true,
        ["HA_OrderMinionMelee"] = true,
        ["SRU_ChaosMinionSiege"] = true,
        ["SRU_OrderMinionSiege"] = true,
        ["HA_ChaosMinionSiege"] = true,
        ["HA_OrderMinionSiege"] = true,
        ["SRU_Krug"] = true,
        ["SRU_KrugMini"] = true,
        ["TestCubeRender"] = true,
        ["SRU_RazorbeakMini"] = true,
        ["SRU_Razorbeak"] = true,
        ["SRU_MurkwolfMini"] = true,
        ["SRU_Murkwolf"] = true,
        ["SRU_Gromp"] = true,
        ["Sru_Crab"] = true,
        ["SRU_Red"] = true,
        ["SRU_Blue"] = true,
        ["EliseSpiderling"] = true,
        ["HeimerTYellow"] = true,
        ["HeimerTBlue"] = true,
        ["MalzaharVoidling"] = true,
        ["ShacoBox"] = true,
        ["YorickGhoulMelee"] = true,
        ["YorickBigGhoul"] = true
        -- ["ZyraThornPlant"] = true,
        -- ["ZyraGraspingPlant"] = true,
        -- ["VoidGate"] = true,
        -- ["VoidSpawn"] = true
    },
    E_PUSH_SPEED = 2000,
    E_ORB_CONTACT_RANGE = 800,
    E_ENEMY_CONTACT_RANGE = 700,
    E_ENEMY_PUSH_DIST = 450,
    E_ENEMY_PUSH_MAX_RANGE = 850,
    GetEAngle = function()
        return myHero:GetSpell((SDK.Enums.SpellSlot.E)):GetName() == "SyndraE" and 56 or 84
    end
}
