local builder = require("SdkProjectBuilder.Modules.Modules")

--////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
--////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Main "main.lua"

Module "Ahri.Main" "Ahri/Ahri.lua"
Module "Ahri.CharmTracker" "Ahri/CharmTracker.lua"
Module "Ahri.LastAutoTracker" "Ahri/LastAutoTracker.lua"

-- Module "Yone.Main" "Yone/Yone.lua

Module "Xerath.BuffManager" "Xerath/BuffManager.lua"
Module "Xerath.Main" "Xerath/Xerath.lua"

Module "Syndra.Main" "Syndra/Syndra.lua"
Module "Syndra.Constants" "Syndra/Constants.lua"
Module "Syndra.OrbManager" "Syndra/OrbManager.lua"

Module "Taliyah.Main" "Taliyah/Taliyah.lua"
Module "Taliyah.QTracker" "Taliyah/QTracker.lua"

Module "Common.Utils" "Common/Utils.lua"
Module "Common.Geometry" "Common/Geometry.lua"
Module "Common.SpellLockManager" "Common/SpellLockManager.lua"
Module "Common.NearestEnemyTracker" "Common/NearestEnemyTracker.lua"
Module "Common.TapManager" "Common/TapManager.lua"
Module "Common.LevelTracker" "Common/LevelTracker.lua"
Module "Common.Debug" "Common/Debug.lua"
Module "Common.DreamLoader" "Common/DreamLoader.lua"

builder.SetupSdkModules(builder.Args)

--[[
    (Optional)

    Adds a new dependency for pulling in DreamApi, which abstracts away the plaform
    specific loading of DreamTS and/or DreamPred (only loads what you tell it to).
]]
-- Example of using dependency to allow cross-platform usage of dream ts and/or dream pred
local dream_modules = require("DreamApi.Modules.Modules") -- not required
dream_modules.SetupModules(builder.Args)
