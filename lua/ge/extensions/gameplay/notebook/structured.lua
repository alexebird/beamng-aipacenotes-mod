-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- local maxVelmax = 100000000
local defaults = {
  -- corner descriptors
  -- v1
  -- corner_degrees = 0,
  -- cornerLength = nil, -- short, long
  -- cornerChange = nil, -- opens, tightens

  -- v2
  -- corner_velmax = maxVelmax,    -- in kph
  -- cornerDirection = 0,         -- left=-1, straight=0, right=1
  -- corner_arclength_degrees = 0, -- 45=normal, 90=long, 22.5=short 180=extra_long

  -- v3
  cornerSeverity = -1,    -- 0 to 100 inclusive. 0 is straight. 100 is the tighest. -1 is unknown or not set.
  cornerDirection = 0,   -- left=-1, straight=0, right=1
  cornerLength = 0,      -- enum: 10=short, 20=normal, 30=long, 40=extra_long
  cornerChange = 0,      -- enum: 10=opens, 20=tightens

  -- modifiers
  modSquare = false,     -- square corner -- its a modifier instead of part of the cornerSeverity model because its more like a 2 with a special shape.
  modDontCut = false,
  modBumps = false,
  modJump = false,
  modCrest = false,
  modWater = false,
  modCaution1 = false,
  modCaution2 = false,
  modCaution3 = false,
}

local C = {}

-- self.corner_angles_data = nil
--
-- local json, err = re_util.loadCornerAnglesFile()
-- if json then
--   self.corner_angles_data = json
-- end

function C:init()
  self.fields = deepcopy(defaults)
end

function C:onDeserialized(data)
  if not data then return end

  self.fields = data
end

-- Method to serialize the Structured object
function C:onSerialize()
  return self.fields
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
