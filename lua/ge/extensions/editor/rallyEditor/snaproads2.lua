local logTag = 'aipacenotes'
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')

local C = {}

function C:init()
  self.startingMinDist = 4294967295
  self.radius = 0.25
  self.handle_points = {}
  self.spline_points = {}
end

function C:getAllAiRoads()
  local objNames = scenetree.findClassObjects("DecalRoad")
  local roads = {}

  for _,objId in ipairs(objNames) do
    local road = scenetree.findObjectById(tonumber(objId))
    if road and not road:isHidden() and road.drivability > 0 then
      table.insert(roads, road)
    end
  end

  return roads
end

local function getNodes(object)
  local result = {}
  for i = 0, object:getNodeCount()-1 do
    local node = {pos = object:getNodePosition(i), width = object:getNodeWidth(i)}
    if object.getNodeDepth then
      node.depth = object:getNodeDepth(i)
    end
    if object.getNodeNormal then
      node.normal = object:getNodeNormal(i)
    end
    table.insert(result, node)
  end
  return result
end

function C:loadSnapRoad(road)
  local edgeCount = road:getEdgeCount()

  for index = 0, edgeCount - 1 do
    local currentMiddleEdge = road:getMiddleEdgePosition(index)
    table.insert(self.spline_points, currentMiddleEdge)
  end

  for i,node in ipairs(getNodes(road)) do
    local pos = node.pos
    table.insert(self.handle_points, pos)
  end
end

function C:loadSnapRoads()
  self.handle_points = {}
  self.spline_points = {}

  for _,road in ipairs(self:getAllAiRoads()) do
    self:loadSnapRoad(road)
    -- local aip_road = road:getDynDataFieldbyName("aip_road", "0")
    -- aip_road = tostring(aip_road)
    -- if aip_road == "1" or aip_road == "t" or aip_road == "true" then
    --   self:loadSnapRoad(road)
    -- end
  end

  log('I', logTag, 'snaproads loaded '..#self.spline_points..' spline_points and '..#self.handle_points..' handle_points')
end

function C:mouseOverSnapRoad(mouseInfo)
  if not mouseInfo then return nil end

  local minNoteDist = self.startingMinDist
  local closestWp = nil
  local sphereRadius = self.radius

  for _,node in ipairs(self.spline_points) do
    local pos = node
    local distNoteToCam = (pos - mouseInfo.camPos):length()
    local noteRayDistance = (pos - mouseInfo.camPos):cross(mouseInfo.rayDir):length() / mouseInfo.rayDir:length()
    if noteRayDistance <= sphereRadius then
      if distNoteToCam < minNoteDist then
        minNoteDist = distNoteToCam
        closestWp = node
      end
    end
  end

  return closestWp
end

function C:drawSnapRoads(mouseInfo, clr_override)
  local closest_snap_for_hover = self:mouseOverSnapRoad(mouseInfo)
  local clr = nil
  local alpha = nil

  for _,pos in pairs(self.spline_points) do
    if pos == closest_snap_for_hover then
      clr = clr_override or cc.snaproads_clr_hover
      alpha = cc.snaproads_alpha_hover
    -- elseif pos == snap_pos then
    --   clr = clr_blue
    else
      clr = clr_override or cc.snaproads_clr
      alpha = cc.snaproads_alpha
    end
    debugDrawer:drawSphere(
      (pos),
      self.radius,
      ColorF(clr[1],clr[2],clr[3], alpha)--,false)
    )
  end
end

-- use this in case you still want a point for orienting a normal
-- but it's the last point in the spline list.
local function extrapolateLine(point1, point2)
  -- Calculate direction vector from point1 to point2
  local dirVector = {
    x = point2.x - point1.x,
    y = point2.y - point1.y,
    z = point2.z - point1.z
  }

  -- Normalize the direction vector
  local length = math.sqrt(dirVector.x^2 + dirVector.y^2 + dirVector.z^2)
  local normVector = {
    x = dirVector.x / length,
    y = dirVector.y / length,
    z = dirVector.z / length
  }

  -- Calculate the new point (point3)
  local point3 = {
    point2.x + normVector.x * length,
    point2.y + normVector.y * length,
    point2.z + normVector.z * length
  }

  return vec3(point3)
end

local function findPosForNormal(snaps, closest_i)
  local posAfter = nil
  if closest_i and closest_i + 1 <= #snaps then
    posAfter = snaps[closest_i + 1]
  elseif #snaps >= 2 then
    posAfter = extrapolateLine(snaps[#snaps-1], snaps[#snaps])
  end

  return posAfter
end

function C:closestSnapPos(source_pos)
  -- local snaps = self.handle_points
  local snaps = self.spline_points

  local minDist = self.startingMinDist
  local closestPos = nil
  local closest_i = nil

  for i,node in ipairs(snaps) do
    local pos = node
    local distToMouse = (pos - source_pos):length()
    if distToMouse < minDist then
      minDist = distToMouse
      closestPos = node
      closest_i = i
    end
  end

  local posAfter = findPosForNormal(snaps, closest_i)

  return closestPos, posAfter
end

function C:nextSnapPos(srcPosIn, directionPos)
  -- make sure that srcPosIn is aligned to a snaproad node.
  local srcPos, _ = self:closestSnapPos(srcPosIn)

  if not directionPos or not srcPos then
    return nil, nil
  end

  local direction = directionPos - srcPos
  local nextPoint = nil
  local minDistance = 4294967295
  -- local snaps = self.handle_points
  local snaps = self.spline_points

  for _, point in ipairs(snaps) do
    if point ~= srcPos then
      local relativePoint = point - srcPos
      local projection = relativePoint:dot(direction)

      if projection > 0 then
        local distance = srcPos:distance(point)
        if distance < minDistance then
          minDistance = distance
          nextPoint = point
        end
      end
    end
  end

  local _, posAfter = self:closestSnapPos(nextPoint)
  return nextPoint, posAfter
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
