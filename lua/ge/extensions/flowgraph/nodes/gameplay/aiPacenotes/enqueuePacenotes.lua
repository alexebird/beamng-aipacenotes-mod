local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Enqueue Pacenotes'
C.description = 'Tracks vehicle position and plays pacenote audio.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}

C.pinSchema = {
  { dir = 'in', type = 'flow',   name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow',   name = 'reset', description = 'Inflow for this node.', impulse = true },
  { dir = 'in', type = 'table',  name = 'rallyManager', tableType = 'rallyManager', description = 'The RallyManager' },
  { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},
  { dir = 'in', type = 'flow',   name = 'noteSearch', description = 'Reset completed pacenotes to near car.', impulse = true },
  { dir = 'in', type = 'flow',   name = 'lapChange', description = 'When a lap changes.', impulse = true },
  { dir = 'in', type = 'number', name = 'currLap', description = 'Current lap number.'},
  { dir = 'in', type = 'number', name = 'maxLap', description = 'Maximum lap number.'},

  -- { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
}

function C:init()
  self.rallyManager = nil
end

function C:work()
  if self.rallyManager == nil then
    self.rallyManager = self.pinIn.rallyManager.value
  end

  if self.rallyManager then
    if self.pinIn.reset.value then
      self.rallyManager:reset()
    end

    if self.pinIn.noteSearch.value then
      self.rallyManager:handleNoteSearch()
    end

    if self.pinIn.lapChange.value then
      self.rallyManager:handleLapChange(self.pinIn.currLap.value, self.pinIn.maxLap.value)
    end

    self.rallyManager:update(self.mgr.dtSim, self.pinIn.raceData.value)
  end
end

return _flowgraph_createNode(C)
