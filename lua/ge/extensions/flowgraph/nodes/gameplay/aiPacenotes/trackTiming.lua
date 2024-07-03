local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local socket = require('socket')
-- local mime = require("mime")
-- local bit32 = bit

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Track Timing'
C.description = 'Track timing data.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},
  { dir = 'in', type = 'table',  name = 'pathData', tableType = 'pathData', description = 'Path data.'},
  { dir = 'in', type = 'number', name = 'damage', description = 'Vehicle damage.'},
}

function C:workOnce()
  self.path = self.pinIn.pathData.value
  if not self.path then
    log('W', logTag, 'no pathData')
    return
  end

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

  local tracker = gameplay_racelink.getTracker()
  tracker:setRacePath(self.path)
  tracker:setRaceData(self.race)
  tracker:write()
end

return _flowgraph_createNode(C)
