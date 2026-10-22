local W=dofile("tests/wow.lua")
local EW=W.Load()
local function Encode(v)
  if type(v)=="string" then return string.format("%q",v) end
  if type(v)=="number" or type(v)=="boolean" then return tostring(v) end
  if type(v)~="table" then return "null" end
  local fields={}
  if #v>0 then
    for _,value in ipairs(v) do fields[#fields+1]=Encode(value) end
    return "["..table.concat(fields,",").."]"
  end
  for key,value in pairs(v) do fields[#fields+1]=Encode(key)..":"..Encode(value) end
  return "{"..table.concat(fields,",").."}"
end
EW.db=EW.LoadSettings({})
local states={}
for _,mode in ipairs({"normal","debt","cancel","uncertain"}) do
  local v=EW.View.Preview({previewMode=mode},100,{state="IDLE"})
  states[mode]=v
end
print(Encode({layout=EW.layout,colors=EW.colors,states=states}))
