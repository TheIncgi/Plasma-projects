print"Loading Button (build 5)"
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
    {width="number",nil,"wid","w", "x2"},
    {height="number",nil,"hei","h", "y2"},
    {textColor="table",{r=1,g=1,b=1}},
    {text="string",""},
    {fontSize="number", 30},
    {backgroundColor="table",{r=.05,g=.51,b=.72}},
    {highlightColor={"nil","table"}},
    {payload="string",""},
    {visible="boolean",true},
    {onClick={"function","nil"}, nil, "onPress"},
    {onRelease={"function","nil"},nil},
    {UUID="number",nil,"uuid", "id"}
  },...)

  obj.id = args.UUID
  if args"width" == "x2" then
    obj.x = math.min(args.x, args.width)
    obj.width = math.abs(args.width - args.x)
  else
    obj.x = args.x
    obj.width = args.width
  end

  if args"height" == "y2" then
    obj.y = math.min(args.y, args.height)
    obj.height = math.abs(args.height - args.y)
  else
    obj.y = args.y
    obj.height = args.height
  end
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