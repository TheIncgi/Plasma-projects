# Plasma-projects
 
# Loader
## Progress:

https://github.com/users/TheIncgi/projects/2/views/1

### Features
 - coroutines
 - metatables
 - standard lua `table`, `string`, `math`, and `bit32` libraries
 - `pairs`, `ipairs`
 - 5.3's `//` idiv op
 - Bitwise operators `~`, `<<`, `|`, `&`, `>>`, `>>>` (bit not, shift left, or, and shift right, logical shift right)\
 - Auto pauses each tick, adjustable # of ops per tick (based on internal loops mostly) 
 - When doing formatting like `("%2d:%d"):format(hour, min)` the first `()` can be skipped like this:
   `"%2d:%d":format(hour, min)`

### Planned features
 - Support for `+=` `-=` `/=` `*=` `~=`, `<<=`, `|=`, `&=`, `>>=`, `>>>=`
 - Support for `[=[foo]=]` style strings (might have already done this one..)
 - Custom searchers/loaders
 - debug library
 - stack trace

## Usage
[This is the file](https://github.com/TheIncgi/Plasma-projects/blob/main/libs/Load.lua)\
There's a huge amount of code here, but don't worry, the usage is pretty simple. \
This code is designed to run in a `Lua Program` node in plasma (but you could run it elsewhere if you wanted) \
and it basically just get's copied and pasted.

### Loading a program to run

func: `Loader.run()` *todo, single word name*

#### Inputs

| Pin | Type | Description |
|-----|------|-------------|
| 1   | Str  | Source code |

### Enabling `require`

#### Inputs
call `Net.sourceCode()` on network module completion
| Pin | Type | Description |
|-----|------|-------------|
| 1   | Str  | Source code from network module |

#### Outputs
| Pin | Type | Description |
|-----|------|-------------|
| 1   | Str  | URL to `githubusercontent` |

#### Err handling
TODO 
return `error"ioexception"` for now

### Running the tests
Note: These steps from [.github/workflows/test_runner.yml](https://github.com/TheIncgi/Plasma-projects/blob/d7c587b8922a23a2d910aa03486907d357cd957a/.github/workflows/test_runner.yml#L33-L48) show steps for linux.

Tests rely on another library of mine [That's No Moon](https://github.com/TheIncgi/Thats-No-Moon)
1. Download the code from the repo and unzip
2. Linux: `export UNIT_TEST_LIB_PATH="<path/to>/thats-no-moon"` \
   Windows: `SET UNIT_TEST_LIB_PATH="<path/to>/thats-no-moon"`
3. Install Lua5.2 if needed
4. Navigate to the root of this project
5. `lua TestLauncher.lua` (`lua52` on my machine, check the executable)

### Running tests with vs code
I'm using `Local Lua Debugger` by **Tom Blind** and `Lua` by **keyring**

in your launch.json be sure to add in the env var for the test lib.\
You could change `"file"` to point at `TestLauncher.lua` if you prefer.\
(Also, second config entry might not do anything..)
```json
{
    // Use IntelliSense to learn about possible attributes.
    // Hover to view descriptions of existing attributes.
    // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
    "version": "0.2.0",
    "configurations": [
        {
            "name": "Debug Lua Interpreter",
            "type": "lua-local",
            "request": "launch",
            "program": {
                "lua": "lua52.exe",
                "file": "${file}"
            },
            "env": {
                "UNIT_TEST_LIB_PATH": "C:/Users/****/GitHub/That-s-No-Moon-"
            }
        },
        {
            "name": "Debug Custom Lua Environment",
            "type": "lua-local",
            "request": "launch",
            "program": {
                "command": "command"
            },
            "args": []
        }
    ]
}
```

Note: In some unusual cases an error may be thrown by the debugger in which clearing the breakpoints may fix it.

## Todo/check?:

Error in standard lua
```lua
t = {}
for t.x = 1, 10 do
``` 

Metatable events
```lua
t = {}
setmetatable(t, {
    __index = function(t,k) .... end
})
```

```lua
x = 10
y = 11
t = {
    x, var = 100, y, --not assignment set in table declaration
    foo = function()
        return x, y --commas ok again here
    end
}
```