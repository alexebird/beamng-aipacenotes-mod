local C = {}

function C:init(path, name, forceId)
  self.path = path

  -- sortedList fields
  self.id = forceId or self.path:getNextUniqueIdentifier()
  self.name = name or ('t_'..self.id)
  self.sortOrder = 999999
  self.show = true

  self.text = nil
  self.success = false
  self.src = nil
  self.file = nil
  self.beamng_file = nil
  self.timestamp = nil
  self.vehicle_data = nil
end

function C:debugDrawText(hovered)
  local txt = self.text
  if hovered then
    txt = txt .. ' (click to copy)'
  end
  return txt
end

function C:vehiclePos()
  if not (self.vehicle_data.vehicle_data and self.vehicle_data.vehicle_data.pos) then return nil end
  return vec3(self.vehicle_data.vehicle_data.pos)
end

function C:vehicleQuat()
  if not (self.vehicle_data.vehicle_data and self.vehicle_data.vehicle_data.quat) then return nil end
  return quat(self.vehicle_data.vehicle_data.quat)
end

function C:onSerialize()
  local ret = {
    oldId = self.id,
    name = self.name,
    show = self.show,

    text = self.text,
    success = self.success,
    src = self.src,
    file = self.file,
    beamng_file = self.beamng_file,
    timestamp = self.timestamp,
    vehicle_data = self.vehicle_data,
  }

  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.show = (data.show == nil and true) or data.show
  self.text = data.text or ''
  self.success = data.success or false
  self.src = data.src or ''
  self.file = data.file or ''
  self.beamng_file = data.beamng_file or ''
  self.timestamp = data.timestamp or 0.0
  self.vehicle_data = data.vehicle_data or {}
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
