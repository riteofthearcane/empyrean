local Args = {
    Platform = os.getenv("_SDK_PLATFORM_"),
    IsMockLoaded = os.getenv("_SDK_IS_MOCK_ENABLED_") == "true"
}

local function SetupSdkModules(args)
    local sdk_modules = require("LeagueSDK.Modules.Modules")
    sdk_modules.SetupModules(args)
end

return {
    Args = Args,
    SetupSdkModules = SetupSdkModules,
}
