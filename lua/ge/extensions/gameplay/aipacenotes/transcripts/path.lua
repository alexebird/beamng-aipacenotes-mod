-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
local logTag = 'aipacenotes-transcripts'

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

function C:getNextUniqueIdentifier()
  if not self._uid then
    self._uid = 0
  end
  self._uid = self._uid + 1
  return self._uid
end

function C:init(fname)
  self.fname = fname

  self.selection_sphere_r = 4.5/2
  self._draw_debug_hover_tsc_id = nil

  self.transcripts = require('/lua/ge/extensions/gameplay/util/sortedList')(
    "transcripts",
    self,
    require('/lua/ge/extensions/gameplay/aipacenotes/transcripts/entry')
  )
end

function C:shouldShow(transcript)
  local tsc = self.transcripts.objects[transcript.id]
  return tsc.show
end

function C:toggleShow(transcript)
  local tsc = self.transcripts.objects[transcript.id]
  tsc.show = not tsc.show
end

function C:load()
  local json = jsonReadFile(self.fname)
  if not json then
    log('E', logTag, 'couldnt find notebook file')
    return false
  end
  self:onDeserialized(json)
  log('I', logTag, 'loaded '.. (#self.transcripts.sorted) ..' transcripts from '..self.fname)
  return true
end

function C:save()
  local json = self:onSerialize()
  jsonWriteFile(self.fname, json, true)
  log('I', logTag, 'saved transcripts file '..self.fname)
end

function C:onSerialize()
  local ret = {
    transcripts = self.transcripts:onSerialize(),
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  local oldIdMap = {}

  self.transcripts:clear()
  -- log('D', logTag, dumps(data.transcripts))
  self.transcripts:onDeserialized(data.transcripts, oldIdMap)
end

-- helped me figure out quat rotation
-----------------------------------------------------------------------
-- test 1
--
-- local function toRadians(degrees)
--   return degrees * (math.pi / 180)
-- end
--
-- local theta = toRadians(45) / 2  -- Convert 45 degrees to radians and halve it
--
-- local testQ = quat({
--   w = math.cos(theta),
--   x = 0,
--   y = 0,
--   z = math.sin(theta)
-- })
--
-- print("Quaternion for 45-degree rotation around Z-axis:", testQ.w, testQ.x, testQ.y, testQ.z)
--
-- local testP = {x=-373.3353577, y=18.58174515, z=49.07889557}
--
-- local h = 2
-- local l = 5
--
-- testP = pos
-- testP = testP + vec3(0,0,20)
-- testQ = rot
--
-- local upVector = vec3(0, 0, 1)  -- 'up' in a Z-up system
-- local rotatedUpVector = testQ * upVector * h  -- Rotate and scale the up vector
-- local topOfCar = testP + rotatedUpVector  -- This gives the top point of the car
--
-- local forwardVector = vec3(0, 1, 0)
-- local rotatedForwardVector = testQ * forwardVector * l
-- local frontOfCar = testP + rotatedForwardVector
--
-- debugDrawer:drawSphere(testP, 1, ColorF(0,1,0,shapeAlpha)) -- green
-- debugDrawer:drawSphere(topOfCar, 1, ColorF(0,0,1,shapeAlpha)) -- blue
-- debugDrawer:drawSphere(frontOfCar, 1, ColorF(0,1,1,shapeAlpha)) -- aqua
function C:drawDebug()
  for i,transcript in ipairs(self.transcripts.sorted) do
    local pos = transcript:vehiclePos()
    local rot = transcript:vehicleQuat()
    local show = self:shouldShow(transcript)

    if show and rot and pos then
      local h = 1.6
      local w = 1.8
      local l = 4.4

      local upVector = vec3(0,0,1)  -- 'up' in a Z-up system
      local rotatedUpVector = rot * upVector * h  -- Rotate and scale the up vector
      -- log('D', logTag, dumps(rotatedUpVector:normalized()))

      local forwardVector = vec3(0,1,0)
      local rotatedForwardVector = rot * forwardVector * (l/2) -- assume pos is the center of car so divide length by 2
      local frontOfCar = pos + rotatedForwardVector
      local backOfCar = pos - rotatedForwardVector

      local raise = vec3(0,0,h/2)
      frontOfCar = frontOfCar + raise
      backOfCar = backOfCar + raise

      local wheelPositions = {
        {0.5, vec3(-(w/2*0.9),   l/2 * 0.6,  0.4)}, -- Front left
        {0.5, vec3( (w/2*0.9),   l/2 * 0.6,  0.4)}, -- Front right
        {0.6, vec3(-(w/2*1.1), -(l/2 * 0.6), 0.4)}, -- Rear left
        {0.6, vec3( (w/2*1.1), -(l/2 * 0.6), 0.4)}, -- Rear right
      }

      -- Function to rotate and translate a local position to a world position
      local function toWorldPosition(localPos)
        local rotatedPos = rot * localPos  -- Rotate by car's orientation
        return pos + rotatedPos             -- Translate to car's world position
      end

      -- Draw the wheels
      for _, wheelPos in ipairs(wheelPositions) do
        local worldWheelPos = toWorldPosition(wheelPos[2])
        debugDrawer:drawSphere(worldWheelPos, wheelPos[1], ColorF(0,0,0,1))
      end

      local clr_base = cc.clr_teal
      local clr = clr_base
      local shapeAlpha = 1.0
      local textAlpha = 0.7
      local clr_text_fg = cc.clr_black
      local clr_text_bg = cc.clr_teal

      local is_hovered = self._draw_debug_hover_tsc_id == transcript.id
      if is_hovered then
        clr = cc.clr_teal_2
        clr_text_bg = cc.clr_teal_2
        textAlpha = 1.0
      end

      debugDrawer:drawSquarePrism(
        frontOfCar,
        backOfCar,
        Point2F(h*0.7, w*0.7), -- make the car look more aero
        Point2F(h, w),
        ColorF(clr[1], clr[2], clr[3], shapeAlpha)
      )

      debugDrawer:drawTextAdvanced(
        backOfCar + vec3(0,0,h/2),
        String(transcript:debugDrawText(is_hovered)),
        ColorF(clr_text_fg[1], clr_text_fg[2], clr_text_fg[3], textAlpha),
        true,
        false,
        ColorI(clr_text_bg[1]*255, clr_text_bg[2]*255, clr_text_bg[3]*255, textAlpha*255)
      )
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
