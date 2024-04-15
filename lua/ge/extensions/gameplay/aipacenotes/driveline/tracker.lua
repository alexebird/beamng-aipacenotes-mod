local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local Driveline = require('/lua/ge/extensions/gameplay/aipacenotes/driveline')

local C = {}
local logTag = 'aipacenotes'

function C:init(missionDir, vehicleTracker)
  self.vehicleTracker = vehicleTracker

  self.driveline = Driveline(missionDir)
  if not self.driveline:load() then
    self.driveline = nil
    return
  end

  self.currPoint = nil

  self:detectCurrPoint()
end

function C:detectCurrPoint()
  self.currPoint = self.driveline:findNearestPoint(self.vehicleTracker:pos())
end

function C:onUpdate()
  self:drawDebug()

  if self:intersectCorners() then
    local nextPoint = self.currPoint.next
    self.currPoint = nextPoint
  end
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

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
