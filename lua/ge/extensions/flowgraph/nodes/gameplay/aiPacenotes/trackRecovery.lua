local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Track Recovery'
C.description = 'Track flips and recoveries.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}

C.pinSchema = {
  -- { dir = 'in', type = 'flow',   name = 'flow', description = 'Inflow for this node.' },
  -- { dir = 'in', type = 'flow',   name = 'reset', description = 'Inflow for this node.', impulse = true },
  -- { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},
  -- { dir = 'in', type = 'flow',   name = 'noteSearch', description = 'Reset completed pacenotes to near car.', impulse = true },
  -- { dir = 'in', type = 'flow',   name = 'lapChange', description = 'When a lap changes.', impulse = true },
  { dir = 'in', type = 'flow', name = 'flip', description = 'A flip'},
  { dir = 'in', type = 'flow', name = 'recovery', description = 'A recovery'},
  { dir = 'in', type = 'flow', name = 'restart', description = 'A recovery'},

  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},
  -- { dir = 'in', type = 'flow', name = 'maxLap', description = 'Maximum lap number.'},

  { dir = 'out', type = 'flow', name = 'flip', description = 'Flip out.' },
  { dir = 'out', type = 'flow', name = 'recovery', description = 'Recovery out.' },
}

-- function C:init()
-- end

function C:work()
  local recoveryType = nil

  self.pinOut.flip.value = false
  self.pinOut.recovery.value = false
  -- self.pinOut.restart.value = false

  print(self.pinIn.flip.value)
  print(self.pinIn.recovery.value)
  print(self.pinIn.restart.value)

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


  -- self.pinOut.flow.value = self.pinIn.flow.value

  -- if self.pinIn.flow.value then
    -- gameplay_aipacenotes.getRallyManager():handleLapChange(self.pinIn.currLap.value, self.pinIn.maxLap.value)
    -- print(self.pinIn.flip.value)
    -- print(self.pinIn.recovery.value)
  -- end

  if recoveryType then
    self.race = self.pinIn.raceData.value
    if not self.race then
      log('W', logTag, 'no raceData')
      return
    end

    self.vehId = self.pinIn.vehId.value
    if not self.vehId then
      log('W', logTag, 'no vehId')
      return
    end

    local state = self.race.states[self.vehId]
    local currSeg = state.currentSegments
    -- local hist_data = state.historicTimes[#state.historicTimes]
    -- local timing_data = state.currentTimes
    -- local dur = timing_data.duration
    local time = self.race.time

    -- print(dumps(state))
    -- print(dumps(hist_data))
    -- print(dumps(timing_data))
    -- print(dumps(dur))

    -- print(recoveryType)
    -- print(dumps(currSeg))
    -- print(dumps(time))

    local recoveryEntry = {
      recoveryType = recoveryType,
      currSegmentId = currSeg,
      time = time,
      damage = map.objects[self.vehId].damage,
    }
    gameplay_aipacenotes.getRallyManager():addRecovery(recoveryEntry)
  end
end

return _flowgraph_createNode(C)
