local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'racelink'

C.name = 'Racelink Finish'
C.description = 'Track stuff upon finish'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_instant'

C.pinSchema = {
}

function C:workOnce()
  if extensions.isExtensionLoaded("gameplay_racelink") then
    local tracker = gameplay_racelink.getTracker()
    if tracker then
      tracker:triggerVehicleLuaReading()
    end
  end
end

return _flowgraph_createNode(C)
