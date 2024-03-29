print"Loading Text (build 6)"

local utils = require"TheIncgi/Plasma-projects/IK-Arm/libs/utils"
local Json = require"TheIncgi/Plasma-projects/main/libs/Json"

local Text = class"TheIncgi/Plasma-projects/IK-Arm/IK-Arm/screens/Text"
local colorToJson = utils.colorToJson

Text.LEFT = 0
Text.TOP = 0
Text.CENTER = 1
Text.RIGHT = 2
Text.BOTTOM = 2

local _text_new = Text.new
function Text:new( ... )
  local obj = _text_new( self )
  
  local args = utils.kwargs({
    {x="number"},
    {y="number"},
    {width="number",nil,"wid","w", "x2"},
    {height="number",nil,"hei","h", "y2"},
    {textColor="table",{r=1,g=1,b=1}},
    {text="string",""},
    {fontSize="number", 30},
    {vertAlign="number",1,"vAlign"},
    {horzAlign="number",1,"hAlign"},
    {visible="boolean",true},
    {UUID="number",nil,"uuid", "id"}
  },...)

  obj.UUID = args.UUID
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
  obj.highlightColor = args.highlightColor
  obj.hAlign = args.horzAlign
  obj.vAlign = args.vertAlign
  obj.visible = args.visible

  return obj
end

function Text:build()
  local obj = Json.static.JsonObject:new()
  obj:put("id",self.UUID)
  obj:put("x", self.x)
  obj:put("y", self.y)
  obj:put("width", self.width)
  obj:put("height", self.height)
  obj:put("text", self.text)
  obj:put("fontSize", self.fontSize)
  obj:put("horizontalAlignment", self.hAlign)
  obj:put("verticalAlignment", self.vAlign)
  obj:put("type",1)
  obj:put("payload","")
  colorToJson(self.textColor,       "color",           obj)
  return obj
end

return Text