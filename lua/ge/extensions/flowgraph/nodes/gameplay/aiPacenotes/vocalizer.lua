local C = {}

local logTag = 'aipacenotes-fg'
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

C.name = 'AI Pacenotes Vocalizer'
C.description = 'Plays pacenotes from a notebook.'
C.color = re_util.aip_fg_color

C.pinSchema = {
  { dir = 'in', type = 'flow',   name = 'flow',  description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow',   name = 'reset', description = 'Resets this node.', impulse = true },
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},
  -- { dir = 'in', type = 'bool',   name = 'noteSearch', description = 'Reset completed pacenotes to near car.', default = false},
  { dir = 'in', type = 'flow',   name = 'noteSearch', description = 'Reset completed pacenotes to near car.', impulse = true },
  -- { dir = 'in', type = 'flow',   name = 'finish', description = 'On finish', impulse = true },

  { dir = 'in', type = 'flow',   name = 'lapChange', description = 'When a lap changes.', impulse = true },
  { dir = 'in', type = 'number', name = 'currLap', description = 'Current lap number.'},
  { dir = 'in', type = 'number', name = 'maxLap', description = 'Maximum lap number.'},

  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.' },
}

C.tags = {'aipacenotes'}

function C:init(mgr, ...)
  self.audioManager = require('/lua/ge/extensions/gameplay/rally/audioManager')()
  self:resetState()
end

function C:resetState()
  self.damageThresh = 1000
  self.closestPacenotes_n = 5

  self.setupDone = false
  self.missionId = nil
  self.missionDir = nil
  self.missionSettings = nil
  self.notebook = nil
  self.codriver = nil
  self.nextId = nil -- this is the id of the pacenote we are looking for every dt.
  self.vehicleTracker = nil
  self.audioManager:resetAudioQueue()
  self.closestPacenotes = nil
  self.currLap = -1
  self.maxLap = -1
end

function C:detectMissionId()
  local missionId, missionDir, error = re_util.detectMissionIdHelper()

  if error then
    self:__setNodeError('setup', error)
  end

  self.missionId, self.missionDir = missionId, missionDir
end

function C:getMissionSettings()
  local settings, error = re_util.getMissionSettingsHelper(self.missionDir)

  if error then
    self:__setNodeError('setup', error)
  end

  self.missionSettings = settings
end

function C:getNotebook()
  local notebook, error = re_util.getNotebookHelper(self.missionDir, self.missionSettings)

  if error then
    self:__setNodeError('setup', error)
  end

  self.notebook = notebook
end

-- 1. get mission dir
-- 2. get aipacenotes/mission.settings.json
-- 3. get notebook from settings
-- 4. get codriver from notebook+settings
-- 5. generate list of flowgraph data from the notebook's pacenotes
function C:initialSetup()
  log('I', logTag, 'setting up AI Pacenotes flowgraph node')

  self:detectMissionId()

  self:getMissionSettings()
  if not self.missionSettings then
    return
  end

  self:getNotebook()
  if not self.notebook then
    return
  end

  self.missionSettings.dynamic = { missionDir = self.missionDir }

  self.codriver = self.notebook:getCodriverByName(self.missionSettings.notebook.codriver)
  if not self.codriver then
    self:__setNodeError('setup', 'couldnt load codriver: '..self.missionSettings.notebook.codriver)
  end

  self.fgPacenotes = self.notebook:getFlowgraphPacenotes(self.missionSettings, self.codriver)

  self.vehicleTracker = require('/lua/ge/extensions/gameplay/rally/vehicleTracker')(
    self.pinIn.vehId.value,
    self.damageThresh,
    self.pinIn.raceData.value
  )

  self.nextId = 1

  self.setupDone = true
end

function C:isRace()
  return not not self.pinIn.raceData.value
end

function C:intersectCorners(pacenote)
  if not pacenote then return false end
  local prevCorners = self.vehicleTracker:getPreviousCorners()
  local currCorners = self.vehicleTracker:getCurrentCorners()
  if prevCorners and currCorners then
    return pacenote.pacenote:intersectCorners(prevCorners, currCorners)
  else
    return false
  end
end

function C:playAudio(pacenote_name)
  if self.notebook then
    local pacenote = self.notebook:getStaticPacenoteByName(pacenote_name)
    if pacenote then
      local fgNote = pacenote:asFlowgraphData(self.missionSettings, self.codriver)
      self.audioManager:enqueuePauseSecs(0.5)
      self.audioManager:enqueuePacenote(fgNote)
    end
  end
end

function C:handleFinish()
  self:playAudio('finish_1')
end

function C:handleLapChange()
  local currLap = self.pinIn.currLap.value
  self.maxLap = self.pinIn.maxLap.value

  if currLap > self.currLap then
    self.currLap = currLap
    log('D', logTag, 'handleLapChange curr='..self.currLap..' max='..self.maxLap)
    self.nextId = 1
  end
end

function C:handleWork()
  if self.vehicleTracker then
    self.vehicleTracker:onUpdate(self.mgr.dtSim, self.pinIn.raceData.value)
  end

  if self.closestPacenotes then
    for _,pacenote in ipairs(self.closestPacenotes) do
      if self:intersectCorners(pacenote._cached_fgData) then
        self.audioManager:enqueuePacenote(pacenote._cached_fgData)
        -- its not the pacenote id, its the index in the ordered list of pacenotes.
        for i,pnData in ipairs(self.fgPacenotes) do
          if pnData.id == pacenote.id then
            self.nextId = i+1
            break
          end
        end
        self.closestPacenotes = nil
        break
      end
    end
  else
    local nextId = self.nextId
    local pacenote = self.fgPacenotes[nextId]
    if self:intersectCorners(pacenote) then
      self.audioManager:enqueuePacenote(pacenote)
      self.nextId = self.nextId + 1
    end
  end

  if self.vehicleTracker:didJustHaveDamage() and self.notebook and self.missionSettings and self.codriver then
    self.audioManager:resetAudioQueue()
    self.audioManager:enqueueDamageSfx(self.notebook, self.missionSettings, self.codriver)
  else
    self.audioManager:playNextInQueue()
  end
end

function C:work(args)
  if self.pinIn.reset.value then
    self:resetState()
    self:initialSetup()
    self.pinOut.flow.value = false
    -- self.pinIn.lapChange.value = false
    -- self.pinIn.noteSearch.value = false
  end

  if self.pinIn.lapChange.value then
    self:handleLapChange()
  end

  if self.pinIn.noteSearch.value then
    self.closestPacenotes = self.notebook:findNClosestPacenotes(self.vehicleTracker:pos(), self.closestPacenotes_n)
  end

  if self.pinIn.finish.value then
    self:handleFinish()
  end

  if self.pinIn.flow.value then
    self:handleWork()
  end

  if editor_rallyEditor then
    editor_rallyEditor.showWaypoints(not simTimeAuthority.getPause())
  end
end

return _flowgraph_createNode(C)
