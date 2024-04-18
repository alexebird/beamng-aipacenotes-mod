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
    point.pacenoteDistances = {}
    point.pacenote = nil
  end

  log('I', logTag, 'loaded driveline with '..tostring(#points)..' points')
  self:setPoints(points)

  return true
end

function C:drawDebugDriveline()
  if not self.points then return end

  local clr = cc.recce_driveline_clr
  -- local alpha_shape = cc.recce_alpha
  local alpha_shape = 0.3

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
  --   debugDrawer:drawSquarePrism(
  --     point.pos + side,
  --     point.pos + 0.25 * point.normal + side,
  --     Point2F(5, midWidth),
  --     Point2F(0, 0),
  --     ColorF(clr_shape[1], clr_shape[2], clr_shape[3], alpha_shape)
  --   )
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

function C:preCalculatePacenoteDistances(notebook, numPacenotes)
  local pacenotes = notebook.pacenotes.sorted
  local pacenotePointMapCs = self:mapPacenotesCsToPoints(notebook)

  local printLimit = 2
  local printCount = 0

  for name,point in pairs(pacenotePointMapCs) do
    print(name..' -> '..tostring(point.id))
  end

  for _,point in ipairs(self.points) do
    point.pacenoteDistances = {}
  end

  local pacenoteIndex = 1

  -- Loop over each driveline point
  for _,point in ipairs(self.points) do

    if printCount <= printLimit then
      print('point id='..tostring(point.id))
      printCount = printCount + 1
    end

    -- see if we need to advance the pacenoteIndex by checking if the current
    -- point is the same as the pacenote's point.
    --
    -- basically once you pass a pacenote, you dont need to calc the distance anymore.
    if pacenoteIndex <= #pacenotes then
      local pacenote = pacenotes[pacenoteIndex]
      local pacenotePoint = pacenotePointMapCs[pacenote.name]

      if point.id == pacenotePoint.id then
        pacenoteIndex = pacenoteIndex + 1
      end
    end

    if printCount <= printLimit then
      print('pacenoteIndex='..tostring(pacenoteIndex))
    end

    -- Calculate distance to the next 'numPacenotes' pacenotes from this point
    for j = 1, numPacenotes do
       -- subtract 1 so that the pacenote at pacenoteIndex is used
      local currIdx = pacenoteIndex + (j - 1)

      if currIdx <= #pacenotes then
        local pacenote = pacenotes[currIdx]
        local pacenotePoint = pacenotePointMapCs[pacenote.name]

        if pacenotePoint then
          local distance = self:calculatePathDistance(point, pacenotePoint)

          if printCount <= printLimit then
            print('point.pacenoteDistances['..pacenote.name..']='..tostring(distance))
          end
          point.pacenoteDistances[pacenote.name] = distance
        end
      else
        -- Break the loop if there are no more pacenotes to process
        break
      end
    end
  end
end

-- Loop over each pacenote and map it to the nearest driveline point
function C:mapPacenotesCsToPoints(notebook)
  local pacenotes = notebook.pacenotes.sorted
  local pacenotePointMap = {}

  for i, pacenote in ipairs(pacenotes) do
    local wp_cs = pacenote:getCornerStartWaypoint()
    local pos_cs = wp_cs.pos
    local point_cs = self:findNearestPoint(pos_cs)
    if point_cs then
      -- Map pacenote name to the point's ID
      pacenotePointMap[pacenote.name] = self.points[point_cs.id]
      point_cs.pacenote = { pn=pacenote, wp=wp_cs } --, i=i }
    end

    local wp_ce = pacenote:getCornerEndWaypoint()
    local pos_ce = wp_ce.pos
    local point_ce = self:findNearestPoint(pos_ce)
    if point_ce then
      -- dont add to the pacenotePointMap.
      -- but we still want to mark that the point has a CE on it.
      point_ce.pacenote = { pn=pacenote, wp=wp_ce } -- , i=i }
    end

    -- mark some intermediate points
    if point_cs and point_ce then
      local i_cs = point_cs.id
      local i_ce = point_ce.id
      local diff = i_ce - i_cs
      local half = round(diff / 2)
      local i_half = i_cs + half
      local point_half = self.points[i_half]
      -- print('point_half id='..tostring(point_half.id)..' pos='..dumps(point_half.pos))
      point_half.pacenote = { pn=pacenote, intermediate='half' }
    end

  end

  return pacenotePointMap
end

-- Calculate the distance along the points line from startIndex to pacenoteIndex
function C:calculatePathDistance(startPoint, pacenotePoint)
  local distance = 0
  local currPoint = startPoint
  while currPoint do
    if currPoint.next then
      distance = distance + self:calculateDistance(currPoint, currPoint.next)
      currPoint = currPoint.next
      if currPoint.id == pacenotePoint.id then
        break
      end
    else
      break
    end
  end
  return distance
end

-- Calculate the distance between two consecutive points using the vec3 object method
function C:calculateDistance(point1, point2)
  local pos1 = vec3(point1.pos)
  local pos2 = vec3(point2.pos)
  return (pos2 - pos1):length()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
