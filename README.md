# Plasma-projects
 
# Todo:

## Tests:

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