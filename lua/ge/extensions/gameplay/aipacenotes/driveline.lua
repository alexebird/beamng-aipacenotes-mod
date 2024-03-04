local C = {}
local logTag = 'aipacenotes-transcripts'

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

function C:init(points)
  self.points = points
end

-- pos - structure should be {x=...,y=...,z=...}
-- function C:nearestPoint(pos)
--   return pos
-- end

function C:drawDebugDriveline()
  local clr = cc.recce_driveline_clr
  local alpha_shape = cc.recce_alpha

  for _,point in ipairs(self.points) do
    local pos = point.pos
    debugDrawer:drawSphere(
      (pos),
      0.5,
      ColorF(clr[1], clr[2], clr[3], alpha_shape)
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
