local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local socket = require('socket')
-- local mime = require("mime")
-- local bit32 = bit

local C = {}
local logTag = 'racelink'

C.name = 'Racelink TT Mission Vars'
C.description = 'Track vars from the timeTrial or rallyStage flowgraph.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'laps', description = 'from Get laps' },
  -- { dir = 'in', type = 'number', name = 'defaultLaps', description = 'from Get defaultLaps' },

  -- { dir = 'in', type = 'bool', name = 'reversible', description = 'from Get reversible' },
  { dir = 'in', type = 'bool', name = 'reverse', description = 'from Get reverse' },

  -- { dir = 'in', type = 'bool', name = 'allowRollingStart', description = 'from Get allowRollingStart' },
  { dir = 'in', type = 'bool', name = 'rolling', description = 'from Get rolling' },

  -- { dir = 'in', type = 'bool', name = 'allowFlip', description = 'from Get allowFlip' },
  -- { dir = 'in', type = 'number', name = 'flipLimit', description = 'from Get flipLimit' },
  -- { dir = 'in', type = 'number', name = 'flipPenalty', description = 'from Get flipPenalty' },
  { dir = 'in', type = 'number', name = 'flipsUsed', description = 'from Get flipsUsed' },

  -- { dir = 'in', type = 'bool', name = 'allowRecover', description = 'from Get allowRecover' },
  -- { dir = 'in', type = 'number', name = 'recoverLimit', description = 'from Get recoverLimit' },
  -- { dir = 'in', type = 'number', name = 'recoverPenalty', description = 'from Get recoverPenalty' },
  { dir = 'in', type = 'number', name = 'recoversUsed', description = 'from Get recoversUsed' },

  { dir = 'in', type = 'string', name = 'recoveryMode', description = 'from Get recoveryMode' },
}

function C:workOnce()
  print('racelink track mission vars')

  local data = {
    laps = self.pinIn.laps.value,
    -- defaultLaps = self.pinIn.defaultLaps.value,

    -- reversible = self.pinIn.reversible.value,
    reverse = self.pinIn.reverse.value,

    -- allowRollingStart = self.pinIn.allowRollingStart.value,
    rolling = self.pinIn.rolling.value,

    -- allowFlip = self.pinIn.allowFlip.value,
    -- flipLimit = self.pinIn.flipLimit.value,
    -- flipPenalty = self.pinIn.flipPenalty.value,
    flipsUsed = self.pinIn.flipsUsed.value,

    -- allowRecover = self.pinIn.allowRecover.value,
    -- recoverLimit = self.pinIn.recoverLimit.value,
    -- recoverPenalty = self.pinIn.recoverPenalty.value,
    recoversUsed = self.pinIn.recoversUsed.value,

    recoveryMode = self.pinIn.recoveryMode.value
  }

  local tracker = gameplay_racelink.getTracker()
  if tracker then
    tracker:putMissionVarsReading(data)
  end
end

return _flowgraph_createNode(C)
