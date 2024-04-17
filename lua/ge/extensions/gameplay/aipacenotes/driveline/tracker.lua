local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local Driveline = require('/lua/ge/extensions/gameplay/aipacenotes/driveline')

local C = {}
local logTag = 'aipacenotes'
local infiniteTimeToPacenote = 1000000

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
  self.default_threshold_sec = 8
  self:setThreshold(self.default_threshold_sec)

  self.nextPointSearchLimit = 10

  self:detectCurrPoint()
  self.driveline:preCalculatePacenoteDistances(self.notebook, 5)
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

  self.nextPacenote = nextPacenote
  -- self:drawDebug()

  if self:intersectCorners() then
    local nextPoint = self.currPoint.next
    self.currPoint = nextPoint
  end
end

function C:isUnderThreshold()
  local timeToPacenote = self:timeToNextPacenote()
  local thresh = self:getThreshold()
  if thresh and timeToPacenote <= thresh then
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
  local vel = self.vehicleTracker:velocity()
  local speed_ms = vel:length()
  if not self.currPoint then return timeToPacenote end
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

  self.driveline:drawDebugDriveline()

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

    local txt = ''

    for pnName,dist in pairs(self.currPoint.pacenoteDistances) do
      local distStr = string.format("%.1f", dist)

      local vel = self.vehicleTracker:velocity()
      local speed_ms = vel:length()
      -- local speed_mph = speed_ms * 2.23694
      -- print(dumps(speed_mph))
      local velStr = string.format("%.1f", speed_ms)

      local timeToPacenote = (speed_ms ~= 0) and (dist / speed_ms) or -1
      if timeToPacenote > 30 then
        timeToPacenote = -1
      end
      local timeStr = string.format("%.1f", timeToPacenote)

      txt = txt..pnName..": "..distStr.."m | speed: "..velStr.."m/s | t: "..timeStr.."s || "
    end

    debugDrawer:drawTextAdvanced(
      self.currPoint.pos,
      String(txt),
      ColorF(clr_text_fg[1], clr_text_fg[2], clr_text_fg[3], alpha_text),
      true,
      false,
      ColorI(clr_text_bg[1]*255, clr_text_bg[2]*255, clr_text_bg[3]*255, alpha_text*255)
    )
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
