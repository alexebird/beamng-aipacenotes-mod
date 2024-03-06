local logTag = 'aipacenotes'
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')

local C = {}

local startingMinDist = 4294967295

function C:init(recce)
  self.recce = recce
  self.cameraPathPlayer = require('/lua/ge/extensions/gameplay/aipacenotes/cameraPathPlayer')(self)

  self.filter = {
    enabled = false,
    points = {},
  }

  self.partition = {
    enabled = false,
    pacenote = nil,
    before_points = {},
    focus_points = {},
    after_points = {},
  }

  self.partition_all_state = {
    enabled = false,
    notebook = nil,
    partitions = {},
    pacenote_partitions = {},
  }
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

local function _drawDebugPoints(points, clr, alpha, radius)
  local alpha_shape = alpha or cc.snaproads_alpha
  local radius = radius or cc.snaproads_radius

  for _,point in ipairs(points) do
    local pos = point.pos
    debugDrawer:drawSphere(
      pos,
      radius,
      ColorF(clr[1],clr[2],clr[3], alpha_shape)
    )
  end
end

function C:_drawDebugPartitionsAll()
  local points = self.partition_all_state.partitions
  if not points then return end
  -- local clr = cc.snaproads_clr
  local clr = cc.clr_green

  for i,partition in ipairs(points) do
    _drawDebugPoints(partition, clr)
  end

  points = self.partition_all_state.pacenote_partitions
  clr = cc.waypoint_clr_background

  for i,partition in ipairs(points) do
    _drawDebugPoints(partition, clr)
  end
end

function C:_drawDebugPartition()
  local points = self.partition.focus_points
  local clr = nil

  if self.filter.enabled then
    clr = cc.clr_white
  else
    clr = cc.snaproads_clr
  end

  _drawDebugPoints(points, clr)

  points = self.partition.before_points
  -- clr = cc.snaproads_clr
  clr = cc.waypoint_clr_background
  _drawDebugPoints(points, clr)

  points = self.partition.after_points
  -- clr = cc.snaproads_clr
  clr = cc.waypoint_clr_background
  _drawDebugPoints(points, clr)
end

-- function C:_drawDebugFilter()
--   local points = self:_operativePoints()
--   local clr = cc.clr_white
--   _drawDebugPoints(points, clr)
-- end

function C:_drawDebugDefault()
  local points = self:_allPoints()
  local clr = cc.snaproads_clr
  _drawDebugPoints(points, clr)
end

function C:drawDebugSnaproad()
  -- if self.filter.enabled then
    -- self:_drawDebugFilter()
  if self.partition.enabled then
    self:_drawDebugPartition()
  elseif self.partition_all_state.enabled then
    self:_drawDebugPartitionsAll()
  else
    self:_drawDebugDefault()
  end
end

function C:drawDebugCameraPlaying()
  local pn = self.partition.pacenote
  if self.partition.enabled and pn then
    local radius = 1.0
    local clr = cc.waypoint_clr_at
    local alpha_shape = 0.2

    local adjustHeight = function(pos, r)
      local newZ = core_terrain.getTerrainHeight(pos)
      return vec3(pos.x, pos.y, newZ-(r*0.25))
    end

    debugDrawer:drawSphere(
      adjustHeight(pn:getActiveFwdAudioTrigger().pos, radius),
      radius,
      ColorF(clr[1],clr[2],clr[3], alpha_shape)
    )

    clr = cc.waypoint_clr_cs
    debugDrawer:drawSphere(
      adjustHeight(pn:getCornerStartWaypoint().pos, radius),
      radius,
      ColorF(clr[1],clr[2],clr[3], alpha_shape)
    )

    clr = cc.waypoint_clr_ce
    debugDrawer:drawSphere(
      adjustHeight(pn:getCornerEndWaypoint().pos, radius),
      radius,
      ColorF(clr[1],clr[2],clr[3], alpha_shape)
    )

    clr = cc.clr_white
    -- alpha_shape = 0.2
    radius = 0.2
    local points = self.partition.focus_points
    for _,point in ipairs(points) do
      local pos = point.pos
      debugDrawer:drawSphere(
        adjustHeight(pos, radius),
        radius,
        ColorF(clr[1],clr[2],clr[3], alpha_shape)
      )
    end
  end
end

function C:_allPoints()
  if self.recce.driveline then
    return self.recce.driveline.points
  else
    return {}
  end
end

function C:_operativePoints()
  if self.filter.enabled then
    return self.filter.points
  else
    return self:_allPoints()
  end
end

-- source_pos - should be a vec3
function C:closestSnapPoint(source_pos, useAllPoints)
  useAllPoints = useAllPoints or false
  local points = nil

  if useAllPoints then
    points = self:_allPoints()
  else
    points = self:_operativePoints()
  end

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

function C:normalAlignPoints(point)
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

function C:forwardNormalVec(point)
  local fromPoint, toPoint = self:normalAlignPoints(point)

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

function C:distanceForwards(fromPoint, meters)
  local toPoint = fromPoint
  local dist = 0
  while true do
    local nextPoint = toPoint.next
    if nextPoint then

      dist = dist + vec3(toPoint.pos):distance(vec3(nextPoint.pos))
      toPoint = nextPoint

      if dist > meters then
        break
      end
    else
      break
    end
  end
  return toPoint
end

-- function C:closestPointBackwards(sourcePoint, notebook)
-- end

function C:prevSnapPos(srcPos)
  return self:prevSnapPoint(srcPos).pos
end

function C:prevSnapPoint(srcPos)
  print('prevSnapPos')

  -- srcPos = vec3(srcPos)

  local snapPoint = self:closestSnapPoint(srcPos)
  if not snapPoint then return nil end

  local points = self:_operativePoints()

  -- check if we are at the beginning of the points list
  if snapPoint.id == points[1].id then
    return snapPoint
  elseif snapPoint.prev then
    local newPoint = snapPoint.prev
    return newPoint
  else
    return snapPoint
  end
end

function C:nextSnapPos(srcPos)
  return self:nextSnapPoint(srcPos).pos
end

function C:nextSnapPoint(srcPos)
  print('nextSnapPos')

  local snapPoint = self:closestSnapPoint(srcPos)
  if not snapPoint then return nil end

  local points = self:_operativePoints()

  -- check if we are at the end of the points list
  if snapPoint.id == points[#points].id then
    return snapPoint
  elseif snapPoint.next then
    local newPoint = snapPoint.next
    return newPoint
  else
    return snapPoint
  end
end

function C:setPacenote(pn)
  self.partition.pacenote = pn

  if not pn then
    self:clearPartition()
    return
  end

  -- find snappoints for pacenote CE and CS
  local pointAt = self:closestSnapPoint(pn:getActiveFwdAudioTrigger().pos)
  -- local pointCs = self:closestSnapPoint(pn:getCornerStartWaypoint().pos)
  local pointCe = self:closestSnapPoint(pn:getCornerEndWaypoint().pos)

  self:_partitionPoints(pointAt, pointCe)
end

function C:clearPartition()
  self.partition.enabled = false
  self.partition.before_points = {}
  self.partition.focus_points = {}
  self.partition.after_points = {}
end

function C:_partitionPoints(fromPoint, toPoint)
  if not (fromPoint and toPoint) then
    return
  end

  -- reset state
  self.partition.enabled = true
  self.partition.before_points = {}
  self.partition.focus_points = {}
  self.partition.after_points = {}
  self:_clearPointCachedPartitions()

  -- fill the focus points
  local currPoint = fromPoint
  table.insert(self.partition.focus_points, currPoint)

  while true do
    local nextPoint = currPoint.next

    if nextPoint then
      table.insert(self.partition.focus_points, nextPoint)
      nextPoint.partition = self.partition.focus_points

      if nextPoint.id == toPoint.id then
        break
      end

      currPoint = nextPoint
    else
      break
    end
  end

  -- fill the before points
  local points = self:_allPoints()
  local currPoint = points[1]
  local toPoint = self.partition.focus_points[1]
  table.insert(self.partition.before_points, currPoint)
  while true do
    local nextPoint = currPoint.next

    if nextPoint then
      if nextPoint.id == toPoint.id then
        break
      else
        table.insert(self.partition.before_points, nextPoint)
      end

      currPoint = nextPoint
    else
      break
    end
  end

  -- fill the after points
  local points = self:_allPoints()
  local currPoint = self.partition.focus_points[#self.partition.focus_points]
  if currPoint.next then
    local toPoint = points[#points]
    while true do
      local nextPoint = currPoint.next

      if nextPoint then
        table.insert(self.partition.after_points, nextPoint)
        if nextPoint.id == toPoint.id then
          break
        -- else
          -- table.insert(self.partition.after_points, nextPoint)
        end

        currPoint = nextPoint
      else
        break
      end
    end
  end
end

function C:clearAll()
  self.partition_all_state.enabled = false
  self.partition_all_state.notebook = nil
  self.partition_all_state.partitions = {}
  self.partition_all_state.pacenote_partitions = {}
  self:clearFilter()
  self:_clearPointCachedPartitions()
end

function C:_clearPointCachedPartitions()
  for _,point in ipairs(self:_allPoints()) do
    point.partition = nil
  end
end

function C:partitionAllPacenotes(notebook)
  -- reset state
  self.partition_all_state.enabled = true
  self.partition_all_state.notebook = notebook
  self.partition_all_state.partitions = {}
  self.partition_all_state.pacenote_partitions = {}
  self:_clearPointCachedPartitions()

  local pn_partitions = {}
  local partitions = {}

  local pt_curr = self:_allPoints()[1]

  local partition = {}
  local pn_partition = {}

  for _,pn_curr in ipairs(notebook.pacenotes.sorted) do
    local wp_cs = pn_curr:getCornerStartWaypoint()
    local wp_ce = pn_curr:getCornerEndWaypoint()
    local pos_cs = wp_cs.pos
    local pos_ce = wp_ce.pos
    wp_cs._snap_point = self:closestSnapPoint(pos_cs)
    wp_ce._snap_point = self:closestSnapPoint(pos_ce)

    partition = {}
    pn_partition = {}

    while pt_curr.id < wp_cs._snap_point.id do
      table.insert(partition, pt_curr)
      pt_curr.partition = partition
      pt_curr = pt_curr.next
    end

    while pt_curr.id <= wp_ce._snap_point.id do
      table.insert(pn_partition, pt_curr)
      pt_curr = pt_curr.next
    end

    partition.pacenote_after = pn_curr
    table.insert(partitions, partition)
    table.insert(pn_partitions, pn_partition)
  end

  -- add points after the last pacenote to it's own partition
  partition = {}
  while pt_curr do
    table.insert(partition, pt_curr)
    pt_curr.partition = partition
    pt_curr = pt_curr.next
  end
  table.insert(partitions, partition)

  -- print('partitions:')
  -- for i,p in ipairs(partitions) do
  --   local s = ''
  --   for i,pt in ipairs(p) do
  --     s = s..', '..tostring(pt.id)
  --   end
  --   print(s)
  -- end

  self.partition_all_state.partitions = partitions
  self.partition_all_state.pacenote_partitions = pn_partitions
end

function C:clearFilter()
  self.filter.enabled = false
  self.filter.points = {}
end

function C:setFilterToAllPartitions()
  if not self.partition_all_state.enabled then return end

  self.filter.enabled = true
  self.filter.points = {}

  local partitions = self.partition_all_state.partitions

  for i,partition in ipairs(partitions) do
    for i,point in ipairs(partition) do
      table.insert(self.filter.points, point)
    end
  end
end

function C:setFilterPartitionPoint(point)
  if not self.partition_all_state.enabled then return end

  self.filter.enabled = true
  self.filter.points = {}

  local partition = point.partition

  for i,point in ipairs(partition) do
    table.insert(self.filter.points, point)
  end
end

function C:setFilter(wp)
  if not wp then
    self.filter.enabled = false
    self.filter.points = {}
    self:clearPartition()
    return
  end

  -- self.filter.points = {}

  -- filtering modes:
  -- * AT is selected
  --   ->  back: cant go past prev AT
  --   ->  fwd:  cant go past self CS
  -- * CS is selected
  --   -> back: cant go past self AT OR cant go past prev CE
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
        local point = self:closestSnapPoint(wp_at_prev.pos, true)
        limitBackPoint = point
      end
    end
    local wp_cs = pn_sel:getCornerStartWaypoint()
    if wp_cs then
      local point = self:closestSnapPoint(wp_cs.pos, true)
      limitFwdPoint = point
    end
  elseif wp:isCs() then
    local wp_at = pn_sel:getActiveFwdAudioTrigger()
    if wp_at then
      local point = self:closestSnapPoint(wp_at.pos, true)
      limitBackPoint = point
    end

    if pn_prev then
      local prev_wp_ce = pn_prev:getCornerEndWaypoint()
      if prev_wp_ce then
        local point = self:closestSnapPoint(prev_wp_ce.pos, true)
        if limitBackPoint then
          if point.id > limitBackPoint.id then
            limitBackPoint = point
          end
        else
          limitBackPoint = point
        end
      end
    end

    local wp_ce = pn_sel:getCornerEndWaypoint()
    if wp_ce then
      local point = self:closestSnapPoint(wp_ce.pos, true)
      limitFwdPoint = point
    end
  elseif wp:isCe() then
    local wp_cs = pn_sel:getCornerStartWaypoint()
    if wp_cs then
      local point = self:closestSnapPoint(wp_cs.pos, true)
      limitBackPoint = point
    end
    if pn_next then
      local wp_cs_next = pn_next:getCornerStartWaypoint()
      if wp_cs_next then
        local point = self:closestSnapPoint(wp_cs_next.pos, true)
        limitFwdPoint = point
      end
    end
  end

  local unfilteredPoints = self:_allPoints()

  limitBackPoint = limitBackPoint or unfilteredPoints[1]
  local hitBackPos = false
  limitFwdPoint = limitFwdPoint or unfilteredPoints[#unfilteredPoints]

  self.filter.enabled = true
  self.filter.points = {}

  for _,point in ipairs(unfilteredPoints) do
    if not hitBackPos then
      if point == limitBackPoint then
        hitBackPos = true
      end
    elseif point == limitFwdPoint then
      break
    else
      table.insert(self.filter.points, point)
    end
  end

  self:_partitionPoints(self.filter.points[1], self.filter.points[#self.filter.points])
end

function C:pointsForCameraPath()
  if self.partition.enabled then
    local points = self.partition.focus_points
    return points
  else
    return nil
  end
end

function C:playCameraPath()
  self.cameraPathPlayer:play()
end

function C:stopCameraPath()
  self.cameraPathPlayer:stop()
end

function C:partitionAllEnabled()
  return self.partition_all_state.enabled
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
