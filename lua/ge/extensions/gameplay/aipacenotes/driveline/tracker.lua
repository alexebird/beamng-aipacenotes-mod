local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local Driveline = require('/lua/ge/extensions/gameplay/aipacenotes/driveline')

local C = {}
local logTag = 'aipacenotes'
local infiniteTimeToPacenote = 1000000
local msToMph = 2.236936
local mphToMs = 0.44704

function C:init(missionDir, vehicleTracker, notebook)
  self.vehicleTracker = vehicleTracker
  self.notebook = notebook

  self.driveline = Driveline(missionDir)
  if not self.driveline:load() then
    self.driveline = nil
    return
  end

  --
  -- state tracking
  --
  -- These are set across multiple ticks.
  self.currPoint = nil
  self.nextPacenote = nil

  -- This is set only for one tick.
  self.intersectedPacenoteData = nil

  self.inFlightPacenotes = {}
  self.inFlightPacenotesCount = 0
  self.nextPointSearchLimit = 10
  self.drawDebugEnabled = false

  --
  -- logic paramters
  --

  -- base params
  self.default_threshold_sec = 8.0
  self.threshold_sec = nil

  -- CodriverWait params
  self.codriver_wait_scaling_amount = 3.0
  -- each step is a multiplier against codriver_wait_scaling_amount
  self.codriverWaitTable = {
    -- broken up by thirds
    -- ['none'] = 0.0,
    ['small'] = 0.33,
    ['medium'] = 0.66,
    ['large'] = 1.0,
  }

  -- speed-scaling params
  -- self.max_threshold_scaling_factor = 2.0
  self.speed_scaling_start_mph = 30
  self.speed_scaling_end_mph = 70
  self.max_threshold_scaling_amount = 3.0


  -- in-flight params
  self.inFlightRemovalPointType = 'half'
  self.inFlightAllowed = 2


  --
  -- setup
  --

  self:setThreshold(self.default_threshold_sec)
  self:detectCurrPoint()
  self.driveline:preCalculatePacenoteDistances(self.notebook, 5)
end

function C:enableDrawDebug(val)
  self.drawDebugEnabled = val
end

function C:getInFlightPacenotesCount()
  return self.inFlightPacenotesCount
end

function C:putInFlightPacenote(pacenote)
  if self.inFlightPacenotes[pacenote.name] then
    error("pacenote already in flight: "..pacenote.name)
  end

  self.inFlightPacenotes[pacenote.name] = true
  self.inFlightPacenotesCount = self.inFlightPacenotesCount + 1
end

function C:setThreshold(newThresh)
  self.threshold_sec = newThresh
  log('D', logTag, 'set threshold_sec to '..self.threshold_sec)
  -- self:notifyThreshold()
end

function C:getThreshold()
  if not self.threshold_sec then
    return self.default_threshold_sec
  else
    return self.threshold_sec
  end
end

function C:notifyThreshold()
  guihooks.trigger('aiPacenotesSetCodriverTimingThreshold', self.threshold_sec)
end

function C:detectCurrPoint()
  -- local currCorners = self.vehicleTracker:getCurrentCorners()
  -- print(dumps(currCorners))

  -- find the point nearest the vehicle center, I presume.
  self.currPoint = self.driveline:findNearestPoint(self.vehicleTracker:pos())
  -- that point probably wont be in front of the front wheels.

  -- so, advance the point, in hopes that the car isn't too long and the point still isnt out front.
  -- definitely could use a more robust solution.
  self.currPoint = self.currPoint.next
end

function C:onUpdate(nextPacenote)
  if not self.driveline then return end

  if not self.nextPacenote or nextPacenote.id ~= self.nextPacenote.id then
    self.nextPacenote = nextPacenote
  end

  if self.drawDebugEnabled then
    self:drawDebug()
  end

  if self:intersectCorners() then
    self.intersectedPacenoteData = self.currPoint.pacenote
    if self.intersectedPacenoteData then
      local pnName = self.intersectedPacenoteData.pn.name
      local point_type = self.intersectedPacenoteData.point_type
      -- local wp = intersectedPacenoteData.wp

      -- print(dumps(self.inFlightPacenotes))
      -- if wp then
      --   print("pnName="..pnName..' isCs='..tostring(wp:isCs())..' isCe='..tostring(wp:isCe()))
      -- end

      if self.inFlightPacenotes[pnName] then
        if point_type == self.inFlightRemovalPointType then
          -- remove the in-flight note when you hit an intermediate point.
          self.inFlightPacenotes[pnName] = nil
          self.inFlightPacenotesCount = self.inFlightPacenotesCount - 1
        end
      -- elseif wp and not wp:isCe() then
        -- this block is a sanity check.
        -- if we are using an intermediate point to remove the in-flight state for a note,
        -- then by the time we hit CE, the note should be gone from in-flight.
        --
        -- therefore the sanity check is only needed when not isCe.
        -- log('E', logTag, 'expected inFlightPacenotes entry for '..pnName)
      end

    end

    self.currPoint = self.currPoint.next
  else
    -- clear for ticks where there is no intersection.
    self.intersectedPacenoteData = nil
  end
end

function C:shouldPlayNextPacenote()
  local shouldPlay = false
  local forceManual = self.notebook:forceManualAudioTriggers()

  if forceManual or self.nextPacenote:isAudioTriggerTypeManual() then
    if self.intersectedPacenoteData then
      local pnId = self.intersectedPacenoteData.pn.id
      local pnName = self.intersectedPacenoteData.pn.name
      local point_type = self.intersectedPacenoteData.point_type

      if pnId == self.nextPacenote.id and point_type == "at" then
        print('manual AT for '..tostring(pnName))
        shouldPlay = true
      end
    end
  elseif self.nextPacenote:isAudioTriggerTypeAuto() then
    local cnt = self:getInFlightPacenotesCount()
    if cnt < self.inFlightAllowed and self:isUnderTimeThreshold() then
      -- print('inFlight='..tostring(cnt))
      shouldPlay = true
    end
  else
    log('E', logTag, "unknown audioTriggerType: ".. self.nextPacenote.audioTriggerType)
  end

  -- add the in-flight note at the same time the audio enqueue decision is made.
  if shouldPlay then
    self:putInFlightPacenote(self.nextPacenote)
  end

  return shouldPlay
end

function C:speedMetersPerSecond()
  local vel = self.vehicleTracker:velocity()
  local speed_ms = vel:length()
  return speed_ms
end

function C:getSpeedScaledThreshold()
  local speed_ms = self:speedMetersPerSecond()
  local minScalingSpeedMs = self.speed_scaling_start_mph * mphToMs
  local maxScalingSpeedMs = self.speed_scaling_end_mph * mphToMs
  local minThresh = self.threshold_sec
  -- local maxThresh = minThresh * self.max_threshold_scaling_factor
  local maxThresh = minThresh + self.max_threshold_scaling_amount

  local scaledThresh = nil

  if speed_ms < minScalingSpeedMs then
    scaledThresh = minThresh
  elseif speed_ms > maxScalingSpeedMs then
    scaledThresh = maxThresh
  else
    local speedScale = (speed_ms - minScalingSpeedMs) / (maxScalingSpeedMs - minScalingSpeedMs)
    scaledThresh = minThresh + ((maxThresh - minThresh) * speedScale)
  end

  return scaledThresh
end

function C:getCodriverWaitScaledThreshold()
  local codriverWait = self.nextPacenote.codriverWait or 'none'

  if codriverWait == 'none' then
    return nil
  else
    local codriverWaitFactor = self.codriverWaitTable[codriverWait]
    local adjustAmount = self.codriver_wait_scaling_amount * codriverWaitFactor
    return self.threshold_sec - adjustAmount
  end
end

function C:isUnderTimeThreshold()
  if not self.nextPacenote then return false end

  local thresh = self:getCodriverWaitScaledThreshold()
  if not thresh then
    -- codriverwait scaling and speed scaling are mutually exclusive.
    thresh = self:getSpeedScaledThreshold()
  end

  -- local speed_mph = self:speedMetersPerSecond() * msToMph
  -- print("scaledThresh="..string.format("%.1f", thresh).."@"..string.format("%.1f", speed_mph).."mph")

  local timeToPacenote = self:timeToNextPacenote()

  if timeToPacenote <= thresh then
    local timestr = string.format("%.1f", timeToPacenote)
    log('D', logTag, self.nextPacenote.name..' under threshhold: '..timestr..' <= '..thresh)
    return true
  else
    return false
  end
end

function C:timeToNextPacenote()
  local timeToPacenote = infiniteTimeToPacenote
  if not self.currPoint then return timeToPacenote end

  local speed_ms = self:speedMetersPerSecond()
  local dist = self.currPoint.pacenoteDistances[self.nextPacenote.name]

  if dist then
    if speed_ms ~= 0 then
      timeToPacenote = dist / speed_ms
    end
  end

  return timeToPacenote
end

function C:intersectCorners()
  local prevCorners = self.vehicleTracker:getPreviousCorners()
  local currCorners = self.vehicleTracker:getCurrentCorners()
  if prevCorners and currCorners then
    return self:_intersectCornersHelper(prevCorners, currCorners)
  else
    return false
  end
end

function C:_intersectCornersHelper(fromCorners, toCorners)
  local minT = math.huge

  local radius = self.driveline.radius
  local currPos = self.currPoint.pos
  local currNormal = self.currPoint.normal

  for i = 1, #fromCorners do
    local rPos, rDir = fromCorners[i], toCorners[i]-fromCorners[i]
    local len = rDir:length()
    if len > 0 then
      len = 1/len
      rDir:normalize()
      local sMin, sMax = intersectsRay_Sphere(rPos, rDir, currPos, radius)
      --adjust for normlized rDir
      sMin = sMin * len
      sMax = sMax * len
      -- inside sphere?
      if sMin <= 0 and sMax >= 1 then
        -- check both directions of the plane so we dont have to worry about having the normal in the right direction when editing pacenoteWaypoints.
        local t1 = intersectsRay_Plane(rPos, rDir, currPos, currNormal)
        -- local t2 = intersectsRay_Plane(rPos, rDir, currPos, -currNormal)
        t1 = t1*len
        -- t2 = t2*len
        -- if (t1<=1 and t1>=0) or (t2<=1 and t2>=0) then
        if (t1<=1 and t1>=0)  then
          -- minT = math.min(t1, t2, minT)
          minT = math.min(t1, minT)
        end
      end
    end
  end

  return minT <= 1, minT
end

function C:findNextPacenote()
  local curr = self.currPoint
  while curr do
    if curr.pacenote then
      return curr.pacenote
    end
    curr = curr.next
  end
end

function C:drawDebug()
  if not self.driveline then return end

  local drawnCache = {
    points = {},
    pacenotes = {},
  }

  -- self.driveline:drawDebugDriveline()

  local clr = cc.clr_white
  local alpha_shape = 0.9
  -- local clr_shape = cc.clr_white
  local plane_radius = re_util.default_waypoint_intersect_radius
  local midWidth = plane_radius * 2

  if self.currPoint then
    drawnCache.points[self.currPoint.id] = true

    debugDrawer:drawSphere(
      self.currPoint.pos,
      1.0,
      ColorF(clr[1], clr[2], clr[3], alpha_shape)
    )

    local side = self.currPoint.normal:cross(vec3(0,0,1)) * (plane_radius - (midWidth / 2))
    alpha_shape = 0.3
    debugDrawer:drawSquarePrism(
      self.currPoint.pos + side,
      self.currPoint.pos + 0.25 * self.currPoint.normal + side,
      Point2F(5, midWidth),
      Point2F(0, 0),
      ColorF(clr[1], clr[2], clr[3], alpha_shape)
    )

    local alpha_text = 1.0
    local clr_text_fg = cc.clr_white
    local clr_text_bg = cc.clr_black

    -- local txt = ''

    local sortedDistances = {}
    for pnName,dist in pairs(self.currPoint.pacenoteDistances) do
      table.insert(sortedDistances, pnName)
    end

    table.sort(sortedDistances)

    -- for pnName,dist in pairs(self.currPoint.pacenoteDistances) do
    for i,pnName in ipairs(sortedDistances) do
      local dist = self.currPoint.pacenoteDistances[pnName]
      local txt = ''
      local distStr = string.format("%.1f", dist)

      local vel = self.vehicleTracker:velocity()
      local speed_ms = vel:length()
      -- local speed_mph = speed_ms * msToMph
      -- print(dumps(speed_mph))
      local velStr = string.format("%.1f", speed_ms)

      local timeToPacenote = (speed_ms ~= 0) and (dist / speed_ms) or -1
      if timeToPacenote > 30 then
        timeToPacenote = -1
      end
      local timeStr = string.format("%.1f", timeToPacenote)

      txt = pnName.." | t="..timeStr.."s d="  ..distStr.."m speed="..velStr.."m/s"
      debugDrawer:drawTextAdvanced(
        self.currPoint.pos,
        String(txt),
        ColorF(clr_text_fg[1], clr_text_fg[2], clr_text_fg[3], alpha_text),
        true,
        false,
        ColorI(clr_text_bg[1]*255, clr_text_bg[2]*255, clr_text_bg[3]*255, alpha_text*255)
      )
    end

    -- debugDrawer:drawTextAdvanced(
    --   self.currPoint.pos,
    --   String(txt),
    --   ColorF(clr_text_fg[1], clr_text_fg[2], clr_text_fg[3], alpha_text),
    --   true,
    --   false,
    --   ColorI(clr_text_bg[1]*255, clr_text_bg[2]*255, clr_text_bg[3]*255, alpha_text*255)
    -- )
  end

  if self.nextPacenote then
    drawnCache.pacenotes[self.nextPacenote.id] = true
    local wp_cs = self.nextPacenote:getCornerStartWaypoint()
    local pos = wp_cs.pos
    clr = cc.clr_green
    debugDrawer:drawSphere(
      pos,
      wp_cs.radius,
      ColorF(clr[1], clr[2], clr[3], alpha_shape)
    )

    local forceManual = self.notebook:forceManualAudioTriggers()

    if forceManual or self.nextPacenote:isAudioTriggerTypeManual() then
      local wp_at = self.nextPacenote:getActiveFwdAudioTrigger()
      local point_at = wp_at._driveline_point
      pos = wp_at.pos
      clr = cc.clr_blue
      -- debugDrawer:drawSphere(
      --   pos,
      --   10.0,
      --   ColorF(clr[1], clr[2], clr[3], alpha_shape)
      -- )


      local side = point_at.normal:cross(vec3(0,0,1)) * (plane_radius - (midWidth / 2))

      debugDrawer:drawSquarePrism(
        point_at.pos + side,
        point_at.pos + 0.25 * point_at.normal + side,
        Point2F(5, midWidth),
        Point2F(0, 0),
        ColorF(clr[1], clr[2], clr[3], alpha_shape)
      )
    end
  end

  -- draw remaining pacenotes
  for i,pacenote in ipairs(self.notebook.pacenotes.sorted) do
    if not drawnCache.pacenotes[pacenote.id] then
      local wp_cs = pacenote:getCornerStartWaypoint()
      local pos = wp_cs.pos
      clr = cc.clr_light_green
      debugDrawer:drawSphere(
        pos,
        wp_cs.radius,
        ColorF(clr[1], clr[2], clr[3], alpha_shape)
      )
    end
  end


  clr = cc.recce_driveline_clr

  for _,point in ipairs(self.driveline.points) do
    if not drawnCache.points[point.id] then
      local pos = point.pos
      debugDrawer:drawSphere(
        (pos),
        0.5,
        ColorF(clr[1], clr[2], clr[3], alpha_shape)
      )

      -- local side = point.normal:cross(vec3(0,0,1)) * (plane_radius - (midWidth / 2))

      -- debugDrawer:drawSquarePrism(
      --   point.pos + side,
      --   point.pos + 0.25 * point.normal + side,
      --   Point2F(5, midWidth),
      --   Point2F(0, 0),
      --   ColorF(clr[1], clr[2], clr[3], alpha_shape)
      -- )
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
