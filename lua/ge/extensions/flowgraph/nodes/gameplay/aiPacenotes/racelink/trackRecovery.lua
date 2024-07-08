local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'racelink'

C.name = 'Racelink Track Recovery'
C.description = 'Track flips and recoveries.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flip', description = 'A flip'},
  { dir = 'in', type = 'flow', name = 'recovery', description = 'A recovery'},
  { dir = 'in', type = 'flow', name = 'restart', description = 'A recovery'},

  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},

  { dir = 'out', type = 'flow', name = 'flip', description = 'Flip out.' },
  { dir = 'out', type = 'flow', name = 'recovery', description = 'Recovery out.' },
}

function C:work()
  local recoveryType = nil

  self.pinOut.flip.value = false
  self.pinOut.recovery.value = false
  -- self.pinOut.restart.value = false

  print('flip: '     .. tostring(self.pinIn.flip.value))
  print('recovery: ' .. tostring(self.pinIn.recovery.value))
  print('restart: '  .. tostring(self.pinIn.restart.value))

  if self.pinIn.flip.value then
    recoveryType = 'flip'
    self.pinOut.flip.value = true
  end

  if self.pinIn.recovery.value then
    recoveryType = 'recovery'
    self.pinOut.recovery.value = true
  end

  if self.pinIn.restart.value then
    recoveryType = 'restart'
    -- self.pinOut.restart.value = true
  end

  print('recoveryType: '..recoveryType)

  -- self.pinOut.flow.value = self.pinIn.flow.value

  local tracker = gameplay_racelink.getTracker()
  tracker:addRecovery(recoveryType, self.race)
end

return _flowgraph_createNode(C)
