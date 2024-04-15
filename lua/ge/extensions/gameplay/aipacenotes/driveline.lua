local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local snaproadNormals = require('/lua/ge/extensions/gameplay/aipacenotes/snaproad/normals')

local C = {}
local logTag = 'aipacenotes-driveline'

local startingMinDist = 4294967295

function C:init(missionDir)
  self.missionDir = missionDir
  self.points = nil

  self.radius = 10  -- set the radius to 10m always.
end

function C:setPoints(points)
  self.points = points
end

function C:load()
  local fname = re_util.drivelineFile(self.missionDir)
  local points = {}

  if not FS:fileExists(fname) then
    self.points = nil
    return false
  end

  for line in io.lines(fname) do
    local obj = jsonDecode(line)
    obj.pos = vec3(obj.pos)
    obj.quat = quat(obj.quat)
    obj.prev = nil
    obj.next = nil
    obj.id = nil
    obj.partition = nil
    table.insert(points, obj)
  end

  for i,point in ipairs(points) do
    point.id = i
    if i > 1 then
      point.prev = points[i-1]
    end
    if i < #points then
      point.next = points[i+1]
    end
  end

  for i,point in ipairs(points) do
    point.normal = snaproadNormals.forwardNormalVec(point)
  end

  log('I', logTag, 'loaded driveline with '..tostring(#points)..' points')
  self:setPoints(points)

  return true
end

function C:drawDebugDriveline()
  if not self.points then return end

  local clr = cc.recce_driveline_clr
  -- local alpha_shape = cc.recce_alpha
  local alpha_shape = 0.5

  local clr_shape = cc.clr_red
  local plane_radius = self.radius
  local midWidth = plane_radius * 2

  for _,point in ipairs(self.points) do
    local pos = point.pos
    debugDrawer:drawSphere(
      (pos),
      0.5,
      ColorF(clr[1], clr[2], clr[3], alpha_shape)
    )

    local side = point.normal:cross(vec3(0,0,1)) * (plane_radius - (midWidth / 2))

    -- this square prism is the intersection "plane" of the point.
    debugDrawer:drawSquarePrism(
      point.pos + side,
      point.pos + 0.25 * point.normal + side,
      Point2F(5, midWidth),
      Point2F(0, 0),
      ColorF(clr_shape[1], clr_shape[2], clr_shape[3], alpha_shape)
    )

  end
end

function C:findNearestPoint(srcPos)
  local minDist = startingMinDist
  local closestPoint = nil

  for _,point in ipairs(self.points) do
    local pos = vec3(point.pos)
    local dist = (pos - srcPos):length()
    if dist < minDist then
      minDist = dist
      closestPoint = point
    end
  end

  return closestPoint
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
