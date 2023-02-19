import datetime
from enum import Enum

import os
import json
import shutil
import re
import time

from os.path import abspath

self_dir = os.path.dirname(os.path.realpath(__file__))

class Platform(Enum):
    FF15 = "FF15"
    Zenbot = "Zenbot"
    Bruhwalker = "Bruhwalker"
    Hanbot = "Hanbot"
    Mir = "Mir"
    Mock = "Mock"

ENUM_ARR = [p for p in Platform]

default_lua_path = self_dir + "\\PlatformBinaries\\JIT\\2.1b3\\luajit.exe"

def build_script(options : dict):
    INPUT_FILE = self_dir + '\\squish'

    CURRENT_PLATFORM = None

    print("Choose a platform to compile:")
    print("\n".join(f" {i + 1}. {p.name}" for i, p in enumerate(ENUM_ARR)))
    print()

    while True:
        try:
            PLAT_INPUT = int(input("> "))
            CURRENT_PLATFORM = ENUM_ARR[PLAT_INPUT - 1]
            break
        except:
            print("Re-enter")
        

    ADD_MOCK_API = options["IsMockApiEnabled"] if "IsMockApiEnabled" in options else False

    prepend_text = get_prepend_text(CURRENT_PLATFORM, options)

    import subprocess

    os.environ["_SDK_PLATFORM_"] = CURRENT_PLATFORM.value
    os.environ["_SDK_PROJECT_DIR_PATH_"] = abspath(options["project_path"]) + "\\"
    os.environ["_SDK_MODULES_FILE_PATH_"] = abspath(options["modules_path"])
    os.environ["_SDK_MODULES_DIR_PATH_"] = os.path.dirname(abspath(options["modules_path"])) + "\\"
    os.environ["_SDK_INTERMEDIATE_BUILD_PATH_"] = INPUT_FILE
    os.environ["_SDK_IS_MOCK_ENABLED_"] = str(ADD_MOCK_API).lower()
    os.environ["_SDK_DEPENDENCIES_DIR_PATH_"] = abspath(options["dependencies_path"]) + "\\"


    subprocess.call([default_lua_path, self_dir + '\\squish.lua'])

    default_replace = [
        ('package.preload', 'SCRIPT_LIB_FUNCS'),
    ]

    for platform in ENUM_ARR:
        default_replace.append((f'local __SDK__API__ = "{platform.value}"', f'local __SDK__API__ = "{CURRENT_PLATFORM.value}"'))
        default_replace.append((f'SDK.GetPlatform() == "{platform.value}"', 'true' if CURRENT_PLATFORM == platform else 'false'))
        default_replace.append((f'SDK.GetPlatform() ~= "{platform.value}"', 'false' if CURRENT_PLATFORM == platform else 'true'))

    if not ADD_MOCK_API:
        default_replace.append(('SDK.Mock = require("LeagueSDK.Api.Mock.SDK").Types', '-- REMOVED MOCK API'))

    data = None

    with open(INPUT_FILE, 'r') as reader:
        data = reader.read()

    for old, new in default_replace:
        data = data.replace(old, new)

    data = encode_strings(data)
    data = prepend_text + "\n" + data

    with open(options["squished_output_path"], 'w') as writer:
        writer.write(data)

    subprocess.call(get_build_process_args(platform, options, INPUT_FILE, options["compiled_output_path"]))

    if "squished_copy_output_path" in options:
        squished_copy_path =  options["squished_copy_output_path"][CURRENT_PLATFORM.value] if CURRENT_PLATFORM.value in options["squished_copy_output_path"] else ""

        if len(squished_copy_path.strip()) > 0:
            if squished_copy_path[0] == "\\":
                squished_copy_path = self_dir + squished_copy_path

            shutil.copyfile(options["squished_output_path"], squished_copy_path)

            print(f"Copied to {squished_copy_path}")


def get_build_process_args(platform : Platform, options: dict, input_file_path: str, compiled_output_file_path: str):
    luajit_path = self_dir + "\\PlatformBinaries\\JIT\\2.1b3\\luajit.exe"
    if platform == Platform.Zenbot:
        luajit_path = self_dir + "\\PlatformBinaries\\JIT\\Zenbot\\luajit.exe"

    return [luajit_path, "-b", input_file_path, compiled_output_file_path]


def encode_strings(data):
    def encode_str(str_to_encode):
        args = ','.join(str(ord(char)) + "*2" for char in str_to_encode if char != '"')
        return "___STRING({" + args + "})" 

    def re_match_encoder(match):
        return encode_str(match.group(1))

    def re_match_commenter(match):
        return '-- ' + match.group(0)

    statements_to_comment = [
        "local __ENCODE__ = function(a) return a end"
    ]

    for i, statement in enumerate(statements_to_comment):
        statements_to_comment[i] = re.escape(statement)

    data = re.sub("__ENCODE__\\((.*?)\\)", re_match_encoder, data)

    statements_to_comment.append("mock_assert\((.*?)")
    statements_to_comment.append("mock_error\((.*?)")

    for i, statement in enumerate(statements_to_comment):
        data = re.sub(statement, re_match_commenter, data)

    return data


def get_timezone_abbreviation():
    local_tz, _ = time.tzname
    return ''.join(word[0] for word in local_tz.split())


def get_prepend_text(platform : Platform, options: dict):
    timezone_abbreviation = get_timezone_abbreviation()
    date_string = datetime.datetime.now().strftime(f"%I:%M%p {timezone_abbreviation} on %b %d")

    return f"""
local _G = _G
local require = _G.require
local package = _G.package
local package_preload = package.preload

local string = _G.string
local ___CHAR = string.char

local function ___STRING(arr)
    local s = ""
    local div = (function() return 1 end)() * 2

    for i = 1, #arr do
        s = s .. ___CHAR(arr[i] / div)
    end

    return s
end

local PROJECT_DATE_STRING = "Updated @ {date_string}"

local SCRIPT_LIB_FUNCS = {{}}
local RESULTS = {{}}

local require = function(s)
    if SCRIPT_LIB_FUNCS[s] then
        if RESULTS[s] then
            return RESULTS[s]
        end
        local res = SCRIPT_LIB_FUNCS[s]()
        RESULTS[s] = res or -1
        return RESULTS[s]
    end

    return _G.require(s)
end
    """
