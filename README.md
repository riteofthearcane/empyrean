Inside the `Builder` directory, run `python3 process.py` to generate the compiled `SampleProject.lua` file at the root directory. There will also exist a `squished.lua` file in the `Builder\Output` folder that is the combined source file before being compiled.


To add a new file as part of Lua source:
- Create new file
- Add it to `modules.lua` file (inside `Builder` directory) as a module (e.g. `Module "SampleProject.Menu" "Menu.lua"`)


To get the initialize all submodules:
```bat
git submodule update --init --recursive
```


To update all submodules:
```bat
REM grab latest commits from server
git submodule update --recursive --remote

REM above command will set current branch to detached HEAD. set back to master.
git submodule foreach git checkout master

REM now do pull to fast-forward to latest commit
git submodule foreach git pull origin master
```


Recommended vscode settings (`.vscode\settings.json`):
```json
{
    "Lua.runtime.version": "LuaJIT",
    "files.exclude" : {
        "Builder/SdkProjectBuilder/PlatformBinaries/*": true
    }
}
```
