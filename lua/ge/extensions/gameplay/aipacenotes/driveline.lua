local dequeue = require('dequeue')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local snaproadNormals = require('/lua/ge/extensions/gameplay/aipacenotes/snaproad/normals')

local C = {}
local logTag = 'aipacenotes-driveline'

local startingMinDist = 4294967295

function C:init(missionDir)
  self.missionDir = missionDir
  self.points = nil

  self._cached_dist = nil

  self.radius = re_util.default_waypoint_intersect_radius
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
    point.cachedPacenotes = {
      cs = nil,
      ce = nil,
      at = nil,
      half = nil,
    }
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

    -- local side = point.normal:cross(vec3(0,0,1)) * (plane_radius - (midWidth / 2))
    --
    -- -- this square prism is the intersection "plane" of the point.
    -- debugDrawer:drawSquarePrism(
    --   point.pos + side,
    --   point.pos + 0.25 * point.normal + side,
    --   Point2F(5, midWidth),
    --   Point2F(0, 0),
    --   ColorF(clr_shape[1], clr_shape[2], clr_shape[3], alpha_shape)
    -- )
  end
end

function C:findNearestPoint(srcPos, startPoint_i, reverse, limit)
  startPoint_i = startPoint_i or 1
  reverse = reverse or false
  limit = limit or false

  -- if the consecutive number of points, when compared, have increasing distance, call it quits.
  local searchConfidenceThreshold = 100
  local increasingDistSearches = 0

  local minDist = startingMinDist
  local closestPoint = nil

  -- for _,point in ipairs(self.points) do
  --   local pos = vec3(point.pos)
  --   local dist = (pos - srcPos):length()
  --   if dist < minDist then
  --     minDist = dist
  --     closestPoint = point
  --   end
  -- end

  local incr = (reverse and -1) or 1
  local end_i = (reverse and 1) or #self.points

  for i=startPoint_i,end_i,incr do
    local point = self.points[i]
    local pos = vec3(point.pos)
    local dist = (pos - srcPos):length()
    if dist < minDist then
      minDist = dist
      closestPoint = point
    else
      increasingDistSearches = increasingDistSearches + 1
    end

    if limit and increasingDistSearches > searchConfidenceThreshold then
      break
    end
  end

  return closestPoint
end

function C:resetDistancesCache()
  for _,point in ipairs(self.points) do
    point.pacenoteDistances = {}
  end

  self:setupEmptyDistanceCache()
end

function C:setupEmptyDistanceCache()
  local qLimit = 5
  local queue = dequeue.new()
  local currPoint = nil

  -- local pint = true

  for i=#self.points,1,-1 do
    currPoint = self.points[i]
    -- if pint then
    --   -- print('currPoint i='..i..' id='..currPoint.id)
    -- end

    for _,pacenoteName in ipairs(queue:contents()) do
      currPoint.pacenoteDistances[pacenoteName] = 0.0
    end

    local pacenoteData = currPoint.cachedPacenotes.cs

    -- if pacenoteData and pacenoteData.pn.name == 'Import_A 10' and pacenoteData.point_type == 'cs' then
    -- if pacenoteData and pacenoteData.pn.name == 'Import_A 10' then
    --   print(pacenoteData.point_type)
    --   print('currPoint i='..i..' id='..currPoint.id)
    --   print('found 10 by name')
    -- end

    if pacenoteData then
      -- if pint then
      --   -- print(pacenoteData.pn.name)
      -- end
      -- if pacenoteData.pn.name == "Import_A 9" then
      --   pint = false
      -- end
      queue:push_right(pacenoteData.pn.name)
    end

    if queue:length() > qLimit then
      local _ = queue:pop_left()
    end
  end
end

-- This method takes the driveline points and the pacenotes (and waypoints),
-- and merges the data together so that the location of the waypoints are
-- associated with the desired driveline points.
function C:preCalculatePacenoteDistances(notebook)
  local t_start_precalc = re_util.getTime()

  local t_start_caching = re_util.getTime()
  local pacenotePointMapCs = self:mapPacenotesCsToPoints(notebook)
  log('D', logTag, 't_caching='..(re_util.getTime() - t_start_caching)..' sec')

  self:resetDistancesCache()

  local t_start_outerloop = re_util.getTime()
  -- self:cacheDistances1(notebook, pacenotePointMapCs)
  self:cacheDistances2()

  log('D', logTag, 't_outerloop='..(re_util.getTime() - t_start_outerloop)..' sec')
  log('D', logTag, 't_preCalc='..(re_util.getTime() - t_start_precalc)..' sec')
end

function C:cacheDistances2()
  local prevPoint = self.points[#self.points]
  local currPoint = prevPoint
  local currDist = nil

  -- iterate backwards
  for i=#self.points,1,-1 do
    currPoint = self.points[i]
    currDist = self:calculateDistance(prevPoint, currPoint)

    for pnName,_ in pairs(currPoint.pacenoteDistances) do
      local prevDist = prevPoint.pacenoteDistances[pnName] or 0
      currPoint.pacenoteDistances[pnName] = prevDist + currDist
    end

    prevPoint = currPoint
  end
end

function C:cacheDistances1(notebook, pacenotePointMapCs)
  local numPacenotes = 5 -- number of pacenotes to lookahead for
  local printLimit = 2
  local printCount = 0
  local pacenotes = notebook.pacenotes.sorted
  local pacenoteIndex = 1

  -- Loop over each driveline point
  for _,point in ipairs(self.points) do

    if printCount <= printLimit then
      -- print('point id='..tostring(point.id))
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

    -- if printCount <= printLimit then
    --   print('pacenoteIndex='..tostring(pacenoteIndex))
    -- end

    -- local t_start_innerloop = re_util.getTime()
    -- Calculate distance to the next 'numPacenotes' pacenotes from this point
    for j = 1, numPacenotes do
       -- subtract 1 so that the pacenote at pacenoteIndex is used
      local currIdx = pacenoteIndex + (j - 1)

      if currIdx <= #pacenotes then
        local pacenote = pacenotes[currIdx]
        local pacenotePoint = pacenotePointMapCs[pacenote.name]

        if pacenotePoint then
          -- local t_start_dist = re_util.getTime()
          local distance = self:calculatePathDistance(point, pacenotePoint)
          -- log('D', logTag, 't_dist='..(re_util.getTime() - t_start_dist)..' sec')

          -- if printCount <= printLimit then
          --   print('point.pacenoteDistances['..pacenote.name..']='..tostring(distance))
          -- end
          point.pacenoteDistances[pacenote.name] = distance
        end
      else
        -- Break the loop if there are no more pacenotes to process
        break
      end
    end
    -- log('D', logTag, 't_innerloop='..(re_util.getTime() - t_start_innerloop)..' sec')
  end
end

function C:cacheNearestPoints(notebook)
  local pacenotes = notebook.pacenotes.sorted
  -- track the previous CS point and use it as the current one's starting point.
  local prevCSPointId = nil

  for i, pacenote in ipairs(pacenotes) do
    local wp_cs = pacenote:getCornerStartWaypoint()
    wp_cs._driveline_point = self:findNearestPoint(wp_cs.pos, prevCSPointId, false, false)
    -- wp_cs._driveline_point = self:findNearestPoint(wp_cs.pos, nil, false, false)

    -- if pacenote.name == "Import_A 10" then
    --   print('found 10')
    --   print(wp_cs._driveline_point.id)
    -- end

    prevCSPointId = wp_cs._driveline_point.id

    local wp_ce = pacenote:getCornerEndWaypoint()
    wp_ce._driveline_point = self:findNearestPoint(wp_ce.pos, wp_cs._driveline_point.id, false, true)

    local wp_at = pacenote:getActiveFwdAudioTrigger()
    wp_at._driveline_point = self:findNearestPoint(wp_at.pos, wp_cs._driveline_point.id, true, true)
  end
end

-- Loop over each pacenote and map it to the nearest driveline point.
--
-- Returns a map of pacenote name to the closest point. The map is a cache that
-- is used for distance calculations in another function.
function C:mapPacenotesCsToPoints(notebook)
  self:cacheNearestPoints(notebook)
  local pacenotes = notebook.pacenotes.sorted
  local pacenoteCsPointMap = {}

  for i, pacenote in ipairs(pacenotes) do
    -- print('mapPacenotesCsToPoints main loop '..pacenote.name)
    local wp_cs = pacenote:getCornerStartWaypoint()
    local point_cs = wp_cs._driveline_point
    if point_cs then
      -- Map pacenote name to the point's ID
      -- pacenoteCsPointMap[pacenote.name] = self.points[point_cs.id]

      -- if point_cs.pacenote then
      --   print('point_cs id='..point_cs.id..' already has a pacenote')
      -- end

      point_cs.cachedPacenotes.cs = {
        pn=pacenote,
        -- point_type="cs",
        pacenote_i=i,
      }

    --   if pacenote.name == "Import_A 10" then
    --     print("set 10, point.id="..point_cs.id.." pacenote_i="..point_cs.cachedPacenotes.cs.pacenote_i)
    --   end
    -- else
    --   print('['.. pacenote.name ..'] couldnt find point_cs')
    end

    local wp_ce = pacenote:getCornerEndWaypoint()
    local point_ce = wp_ce._driveline_point
    if point_ce then
      -- dont add to the pacenoteCsPointMap.
      -- but we still want to mark that the point has a CE on it.
      point_ce.cachedPacenotes.ce = {
        pn=pacenote,
        -- point_type="ce",
        pacenote_i=i,
      }
    -- else
      -- print('['.. pacenote.name ..'] couldnt find point_ce')
    end

    local wp_at = pacenote:getActiveFwdAudioTrigger()
    local point_at = wp_at._driveline_point
    if point_at then
      -- dont add to the pacenoteCsPointMap.
      -- but we still want to mark that the point has an AT on it.
      point_at.cachedPacenotes.at = {
        pn=pacenote,
        -- point_type="at",
        pacenote_i=i,
      }
    -- else
      -- print('['.. pacenote.name ..'] couldnt find point_at')
    end

    -- Mark some intermediate points -- such as the drivline point halfway between the CS and CE.
    -- This is just to give some more options for granularity for which
    -- driveline points to use for triggering when a pacenote is considered no
    -- longer in-flight.
    if point_cs and point_ce then
      local i_cs = point_cs.id
      local i_ce = point_ce.id
      local diff = i_ce - i_cs
      local half = round(diff / 2)
      local i_half = i_cs + half
      local point_half = self.points[i_half]
      point_half.cachedPacenotes.half = {
        pn=pacenote,
        -- point_type="half",
        pacenote_i=i,
      }
    end

  end

  -- for name,point in pairs(pacenoteCsPointMap) do
  --   print(name..' -> '..tostring(point.id))
  -- end

  return pacenoteCsPointMap
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

function C:length()
  if self._cached_dist then
    return self._cached_dist
  end

  self._cached_dist = 0
  local prevPoint = self.points[1]

  for _,point in ipairs(self.points) do
    self._cached_dist = self._cached_dist + self:calculateDistance(prevPoint, point)
    prevPoint = point
  end

  return self._cached_dist
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
