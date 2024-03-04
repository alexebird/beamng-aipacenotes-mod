local logTag = 'aipacenotes'
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')

local C = {}

local startingMinDist = 4294967295

function C:init(recce)
  self.recce = recce

  -- self.settings = nil
  -- self.transcript_path = nil
  -- self.missionDir = missionDir
  -- self.radius = 0.25
  -- self.spline_points = {}
  self.filtered_points = nil
end

-- function C:load()
--   local settings = re_util.loadMissionSettings(self.missionDir)
--
--   if settings then
--     self.settings = settings
--     local abspath = self.settings:getFullCourseTranscriptAbsPath(self.missionDir)
--     self.transcript_path = require('/lua/ge/extensions/gameplay/aipacenotes/transcripts/path')(abspath)
--
--     if not self.transcript_path:load() then
--       log('W', logTag, 'snapVC.load couldnt load transcripts file from '..tostring(abspath))
--       self.transcript_path = nil
--       return false
--     end
--   else
--     return false
--   end
--
--   self.spline_points = {}
--   self._filtered_spline_points = nil
--
--   for _,tsc in ipairs(self.transcript_path.transcripts.sorted) do
--     if tsc:capture_data() then
--       for _,cap in ipairs(tsc:capture_data().captures) do
--         table.insert(self.spline_points, vec3(cap.pos))
--       end
--     end
--   end
--
--   log('I', logTag, 'snapVC loaded '..tostring(#self.spline_points)..' points')
--   return true
-- end

-- function C:_mouseOverSnapRoad(mouseInfo)
--   if not mouseInfo then return nil end
--
--   local minNoteDist = startingMinDist
--   local closestWp = nil
--   local sphereRadius = self.radius
--
--   for _,node in ipairs(self:_filteredSnapPoints()) do
--     local pos = node
--     local distNoteToCam = (pos - mouseInfo.camPos):length()
--     local noteRayDistance = (pos - mouseInfo.camPos):cross(mouseInfo.rayDir):length() / mouseInfo.rayDir:length()
--     if noteRayDistance <= sphereRadius then
--       if distNoteToCam < minNoteDist then
--         minNoteDist = distNoteToCam
--         closestWp = node
--       end
--     end
--   end
--
--   return closestWp
-- end

function C:drawDebugSnaproad()

  self.recce.driveline:drawDebugDriveline()




  -- if not self.transcript_path then return end
  --
  -- -- local closest_snap_for_hover = self:_mouseOverSnapRoad(mouseInfo)
  -- local clr = nil
  -- local alpha = nil
  --
  -- for _,pos in pairs(self:_filteredSnapPoints()) do
  --   -- if pos == closest_snap_for_hover then
  --     -- clr = clr_override or cc.snaproads_clr_hover
  --     -- alpha = cc.snaproads_alpha_hover
  --   -- elseif pos == snap_pos then
  --   --   clr = clr_blue
  --   -- else
  --     clr = clr_override or cc.snaproads_clr
  --     alpha = cc.snaproads_alpha
  --   -- end
  --   debugDrawer:drawSphere(
  --     (pos),
  --     self.radius,
  --     ColorF(clr[1],clr[2],clr[3], alpha)--,false)
  --   )
  -- end
end

-- use this in case you still want a point for orienting a normal
-- but it's the last point in the spline list.
-- local function extrapolateLine(point1, point2)
--   -- Calculate direction vector from point1 to point2
--   local dirVector = {
--     x = point2.x - point1.x,
--     y = point2.y - point1.y,
--     z = point2.z - point1.z
--   }
--
--   -- Normalize the direction vector
--   local length = math.sqrt(dirVector.x^2 + dirVector.y^2 + dirVector.z^2)
--   local normVector = {
--     x = dirVector.x / length,
--     y = dirVector.y / length,
--     z = dirVector.z / length
--   }
--
--   -- Calculate the new point (point3)
--   local point3 = {
--     point2.x + normVector.x * length,
--     point2.y + normVector.y * length,
--     point2.z + normVector.z * length
--   }
--
--   return vec3(point3)
-- end

-- local function findPosForNormal(snaps, closest_i)
--   local posAfter = nil
--   if closest_i and closest_i + 1 <= #snaps then
--     posAfter = snaps[closest_i + 1]
--   elseif #snaps >= 2 then
--     posAfter = extrapolateLine(snaps[#snaps-1], snaps[#snaps])
--   end
--
--   return posAfter
-- end

function C:_operativePoints()
  return self.filtered_points or self.recce.driveline.points
end

-- source_pos - should be a vec3
function C:closestSnapPoint(source_pos)
  local points = self:_operativePoints()

  local minDist = startingMinDist
  local closestPoint = nil

  for _,point in ipairs(points) do
    local pos = vec3(point.pos)
    local dist = (pos - source_pos):length()
    if dist < minDist then
      minDist = dist
      closestPoint = point
    end
  end

  return closestPoint
end

function C:closestSnapPos(source_pos)
  local point = self:closestSnapPoint(source_pos)
  if point then
    return point.pos
  else
    return source_pos
  end
end

function C:forwardNormalVec(point)
  local fromPoint = nil
  local toPoint = nil

  if point.next then
    fromPoint = point
    toPoint = point.next
  elseif point.prev then
    fromPoint = point.prev
    toPoint = point
  else
    return vec3(1,0,0)
  end

  local normVec = re_util.calculateForwardNormal(fromPoint.pos, toPoint.pos)
  return vec3(normVec.x, normVec.y, normVec.z)
end

function C:pointsBackwards(fromPoint, steps)
  local toPoint = fromPoint
  for _ = 1,steps do
    local prevPoint = toPoint.prev
    if prevPoint then
      toPoint = prevPoint
    end
  end
  return toPoint
end

function C:distanceBackwards(fromPoint, meters)
  local toPoint = fromPoint
  local dist = 0
  while true do
    local prevPoint = toPoint.prev
    if prevPoint then

      dist = dist + vec3(toPoint.pos):distance(vec3(prevPoint.pos))
      toPoint = prevPoint

      if dist > meters then
        break
      end
    else
      break
    end
  end
  return toPoint
end

function C:prevSnapPos(srcPos)
  if not self.transcript_path then return end

  srcPos = vec3(srcPos)

  -- make sure that srcPos is aligned to a snaproad node.
  local _
  srcPos, _ = self:closestSnapPos(srcPos)

  if not srcPos then
    return nil, nil
  end

  local points = self:_operativePoints()

  -- find current snaproad point
  local i_curr = nil
  for i,point in ipairs(points) do
    if srcPos == point then
      i_curr = i
    end
  end

  if i_curr then
    return points[i_curr-1], points[i_curr]
  end
end

function C:nextSnapPos(srcPos)
  if not self.transcript_path then return end
  srcPos = vec3(srcPos)

  -- make sure that srcPos is aligned to a snaproad node.
  local _
  srcPos, _ = self:closestSnapPos(srcPos)

  if not srcPos then
    return nil, nil
  end

  local points = self:_operativePoints()

  -- find current snaproad point
  local i_curr = nil
  for i,point in ipairs(points) do
    if srcPos == point then
      i_curr = i
    end
  end

  if i_curr then
    return points[i_curr+1], points[i_curr+2]
  end
end

function C:setFilter(wp)
  self.filtered_points = nil
  if not wp then return end

  -- filtering modes:
  -- * AT is selected
  --   ->  back: cant go past prev AT
  --   ->  fwd:  cant go past self CS
  -- * CS is selected
  --   -> back: cant go past self AT
  --   -> fwd:  cant go past self CE
  -- * CE is selected
  --   -> back: cant go past self CS
  --   -> fwd:  cant go past next CS

  local notebook = wp.pacenote.notebook
  local pn_prev, pn_sel, pn_next = notebook:getAdjacentPacenoteSet(wp.pacenote.id)

  local limitBackPoint = nil
  local limitFwdPoint = nil

  if wp:isAt() then
    if pn_prev then
      local wp_at_prev = pn_prev:getActiveFwdAudioTrigger()
      if wp_at_prev then
        local point = self:closestSnapPoint(wp_at_prev.pos)
        limitBackPoint = point
      end
    end
    local wp_cs = pn_sel:getCornerStartWaypoint()
    if wp_cs then
      local point = self:closestSnapPoint(wp_cs.pos)
      limitFwdPoint = point
    end
  elseif wp:isCs() then
    local wp_at = pn_sel:getActiveFwdAudioTrigger()
    if wp_at then
      local point = self:closestSnapPoint(wp_at.pos)
      limitBackPoint = point
    end
    local wp_ce = pn_sel:getCornerEndWaypoint()
    if wp_ce then
      local point = self:closestSnapPoint(wp_ce.pos)
      limitFwdPoint = point
    end
  elseif wp:isCe() then
    local wp_cs = pn_sel:getCornerStartWaypoint()
    if wp_cs then
      local point = self:closestSnapPoint(wp_cs.pos)
      limitBackPoint = point
    end
    if pn_next then
      local wp_cs_next = pn_next:getCornerStartWaypoint()
      if wp_cs_next then
        local point = self:closestSnapPoint(wp_cs_next.pos)
        limitFwdPoint = point
      end
    end
  end

  local unfilteredPoints = self.recce.driveline.points

  limitBackPoint = limitBackPoint or unfilteredPoints[1]
  local hitBackPos = false
  limitFwdPoint = limitFwdPoint or unfilteredPoints[#unfilteredPoints]

  self.filtered_points = {}

  for _,point in ipairs(unfilteredPoints) do
    if not hitBackPos then
      if point == limitBackPoint then
        hitBackPos = true
      end
    elseif point == limitFwdPoint then
      break
    else
      table.insert(self.filtered_points, point)
    end
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end

