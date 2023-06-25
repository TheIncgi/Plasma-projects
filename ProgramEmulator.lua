print("===== SETUP ======")
if _G.setup then
  _G.setup()
end

print("====== END SETUP ======")
local tick = 1
while _G.loop and (not _G.is_done or not _G.is_done() ) do
  print("======== TICK "..tick.." =========")
  _G.loop()
  tick = tick + 1
end
print"======== DONE ========"
