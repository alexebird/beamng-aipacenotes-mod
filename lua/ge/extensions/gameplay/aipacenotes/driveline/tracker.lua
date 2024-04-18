local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
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

  self.currPoint = nil
  self.nextPacenote = nil
  self.default_threshold_sec = 10.0
  self.max_threshold_scaling_factor = 2.0
  self:setThreshold(self.default_threshold_sec)

  self.inFlightPacenotes = {}
  self.inFlightPacenotesCount = 0

  self.nextPointSearchLimit = 10

  self:detectCurrPoint()
  self.driveline:preCalculatePacenoteDistances(self.notebook, 5)
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
  self.currPoint = self.driveline:findNearestPoint(self.vehicleTracker:pos())
end

function C:onUpdate(nextPacenote)
  if not self.driveline then return end

  if not self.nextPacenote or nextPacenote.id ~= self.nextPacenote.id then
    self.nextPacenote = nextPacenote
  end

  self:drawDebug()

  if self:intersectCorners() then
    local intersectedPacenoteData = self.currPoint.pacenote
    if intersectedPacenoteData then
      local pnName = intersectedPacenoteData.pn.name
      local wp = intersectedPacenoteData.wp
      local intermediate = intersectedPacenoteData.intermediate

      -- print(dumps(self.inFlightPacenotes))
      -- if wp then
      --   print("pnName="..pnName..' isCs='..tostring(wp:isCs())..' isCe='..tostring(wp:isCe()))
      -- end
      -- if intermediate then
      --   print("pnName="..pnName..' intermediate='..tostring(intermediate))
      -- end

      if self.inFlightPacenotes[pnName] then
        -- if wp:isCe() then
          -- remove the in-flight note when you hit the CE.
        if intermediate == 'half' then
          -- remove the in-flight note when you hit an intermediate point.
          self.inFlightPacenotes[pnName] = nil
          self.inFlightPacenotesCount = self.inFlightPacenotesCount - 1
        end
      elseif wp and not wp:isCe() then
        -- this block is a sanity check.
        -- if we are using an intermediate point to remove the in-flight state for a note,
        -- then by the time we hit CE, the note should be gone from in-flight.
        --
        -- therefore the sanity check is only needed when not isCe.
        log('E', logTag, 'expected inFlightPacenotes entry for '..pnName)
      end
    end

    self.currPoint = self.currPoint.next
  end
end

function C:speedMetersPerSecond()
  local vel = self.vehicleTracker:velocity()
  local speed_ms = vel:length()
  return speed_ms
end

function C:getSpeedScaledThreshold()
  local speed_ms = self:speedMetersPerSecond()
  local minScalingSpeedMs = 30 * mphToMs
  local maxScalingSpeedMs = 70 * mphToMs
  local minThresh = self.threshold_sec
  local maxThresh = minThresh * self.max_threshold_scaling_factor

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

local codriverWaitTable = {
  -- broken up by thirds
  ['none'] = 1.0,
  ['small'] = 0.9,
  ['medium'] = 0.8,
  ['large'] = 0.7,
}

function C:isUnderThreshold()
  local timeToPacenote = self:timeToNextPacenote()
  -- local thresh = self:getThreshold()
  local thresh = self:getSpeedScaledThreshold()

  if self.nextPacenote then
    local codriverWait = self.nextPacenote.codriverWait or 'none'
    local codriverWaitFactor = codriverWaitTable[codriverWait]
    thresh = thresh * codriverWaitFactor
  end

  -- local speed_mph = self:speedMetersPerSecond() * msToMph
  -- print("scaledThresh="..string.format("%.1f", thresh).."@"..string.format("%.1f", speed_mph).."mph")

  if timeToPacenote <= thresh then
    if self.nextPacenote then
      local timestr = string.format("%.1f", timeToPacenote)
      log('D', logTag, self.nextPacenote.name..' under threshhold: '..timestr..' <= '..thresh)
    end
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

function C:drawDebug()
  if not self.driveline then return end

  -- self.driveline:drawDebugDriveline()

  local clr = cc.clr_white
  local alpha_shape = 0.9

  if self.currPoint then
    debugDrawer:drawSphere(
      self.currPoint.pos,
      1.0,
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
    local pos = self.nextPacenote:getCornerStartWaypoint().pos
    clr = cc.clr_green
    debugDrawer:drawSphere(
      pos,
      10.0,
      ColorF(clr[1], clr[2], clr[3], alpha_shape)
    )
  end

  for i,pacenote in ipairs(self.notebook.pacenotes.sorted) do
    local pos = pacenote:getCornerStartWaypoint().pos
    clr = cc.clr_blue
    debugDrawer:drawSphere(
      pos,
      7.0,
      ColorF(clr[1], clr[2], clr[3], alpha_shape)
    )
  end
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
        local t2 = intersectsRay_Plane(rPos, rDir, currPos, -currNormal)
        t1 = t1*len
        t2 = t2*len
        if (t1<=1 and t1>=0) or (t2<=1 and t2>=0) then
          minT = math.min(t1, t2, minT)
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

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
