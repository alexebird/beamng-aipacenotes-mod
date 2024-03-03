local C = {}
local logTag = 'aipacenotes-transcripts'

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

function C:init(missionDir)
  self.fname = re_util.cutsFile(missionDir)
  self.cuts = {}
end

function C:load()
  if not self.fname  then
    log('W', logTag, 'load: cuts fname is nil')
    return false
  end

  self.cuts = {}

  for line in io.lines(self.fname) do
    local obj = jsonDecode(line)
    table.insert(self.cuts, obj)
  end

  log('I', logTag, 'loaded '..tostring(#self.cuts)..' cuts')
end

function C:drawDebugCuts(mouseInfo)
  for i,point in ipairs(self.points) do
    local pos = point.pos
    debugDrawer:drawSphere(
      (pos),
      0.5,
      ColorF(1,0,0,0.5)
    )
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
