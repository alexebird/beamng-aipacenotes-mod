local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local M = {}

local function normalAlignPoints(point)
  if not point then return nil, nil, nil end

  local prevPoint = point.prev
  local currentPoint = point
  local nextPoint = point.next

  return prevPoint, currentPoint, nextPoint
end

local function forwardNormalVec(point)
  local prevPoint, currentPoint, nextPoint = normalAlignPoints(point)
  if prevPoint and nextPoint then
    local normVec = re_util.calculateForwardNormal(prevPoint.pos, nextPoint.pos)
    return vec3(normVec.x, normVec.y, normVec.z)
  elseif currentPoint and nextPoint then
    local normVec = re_util.calculateForwardNormal(currentPoint.pos, nextPoint.pos)
    return vec3(normVec.x, normVec.y, normVec.z)
  elseif prevPoint and currentPoint then
    local normVec = re_util.calculateForwardNormal(prevPoint.pos, currentPoint.pos)
    return vec3(normVec.x, normVec.y, normVec.z)
  else
    return nil
  end
end

M.normalAlignPoints = normalAlignPoints
M.forwardNormalVec = forwardNormalVec

return M
