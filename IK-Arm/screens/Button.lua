print"Loading Button (build 2)"
local utils = require"TheIncgi/Plasma-projects/IK-Arm/libs/utils"
local Json = require"TheIncgi/Plasma-projects/main/libs/Json"

local Button = class"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Button"
local _button_new = Button.new

local colorToJson = utils.colorToJson

function Button:new( ... )
  local obj = _button_new( self )
  local args = utils.kwargs({
    {x="number"},
    {y="number"},
    {width="number",nil,"wid","w"},
    {height="number",nil,"hei","h"},
    {textColor="table",{r=1,g=1,b=1}},
    {text="string",""},
    {fontSize="number", 60},
    {backgroundColor="table",{r=.05,g=.51,b=.72}},
    {highlightColor={"nil","table"}},
    {payload="string",""},
    {visible="boolean",true},
    {onClick={"function","nil"}, nil, "onPress"},
    {onRelease={"function","nil"},nil}
  },...)

  obj.id = false
  obj.x = args.x
  obj.y = args.y
  obj.width = args.width
  obj.height = args.height
  obj.textColor = args.textColor
  obj.text = args.text
  obj.fontSize = args.fontSize
  obj.backgroundColor = args.backgroundColor
  obj.highlightColor = args.highlightColor or utils.computeHighlight(args.backgroundColor)
  obj.payload = args.payload
  obj.visible = args.visible
  obj.onClick = args.onClick
  obj.onRelease = args.onRelease

  if obj.width < 0 then
    obj.width = -obj.width
    obj.x = obj.x - obj.width + 1
  end

  if obj.height < 0 then
    obj.height = -obj.height
    obj.y = obj.y - obj.height + 1
  end

  return obj
end

function Button:build()
  local obj = Json.static.JsonObject:new()
  obj:put("id",self.UUID)
  obj:put("x", self.x)
  obj:put("y", self.y)
  obj:put("width", self.width)
  obj:put("height", self.height)
  obj:put("text", self.text)
  obj:put("fontSize", self.fontSize)
  obj:put("type",2)
  obj:put("payload",self.payload)
  colorToJson(self.backgroundColor, "backgroundColor", obj)
  colorToJson(self.highlightColor or self.backgroundColor,  "highlightColor",  obj)
  colorToJson(self.textColor,       "color",           obj)
  return obj
end

return Button