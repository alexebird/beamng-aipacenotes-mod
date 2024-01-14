local C = {}

function C:init(path, name, forceId)
  self.path = path

  self.id = forceId or self.path:getNextUniqueIdentifier()
  self.name = name or ('t_'..self.id)
  self.text = nil
  self.success = false
  self.src = nil
  self.file = nil
  self.beamng_file = nil
  self.timestamp = nil
  self.vehicle_pos = nil

  self.sortOrder = 999999
end

function C:onSerialize()
  local ret = {
    oldId = self.id,
    name = self.name,
    text = self.text,
  }

  return ret
end

function C:onDeserialized(data, oldIdMap)
  self.text = data.text or ''
  self.success = data.success or false
  self.src = data.src or ''
  self.file = data.file or ''
  self.beamng_file = data.beamng_file or ''
  self.timestamp = data.timestamp or 0.0
  self.vehicle_pos = data.vehicle_pos or {}
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
