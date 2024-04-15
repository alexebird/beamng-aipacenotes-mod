local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local M = {}

local function normalAlignPoints(point)
  if not point then return nil, nil end

  local fromPoint = nil
  local toPoint = nil

  if point.next then
    fromPoint = point
    toPoint = point.next
  elseif point.prev then
    toPoint = point.prev
    fromPoint = point
  else
    toPoint = point + vec3(1,0,0)
  end

  return fromPoint, toPoint
end

local function forwardNormalVec(point)
  local fromPoint, toPoint = normalAlignPoints(point)
  if fromPoint and toPoint then
    local normVec = re_util.calculateForwardNormal(fromPoint.pos, toPoint.pos)
    return vec3(normVec.x, normVec.y, normVec.z)
  else
    return nil
  end
end

M.normalAlignPoints = normalAlignPoints
M.forwardNormalVec = forwardNormalVec

return M
