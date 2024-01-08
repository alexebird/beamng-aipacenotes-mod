-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local im  = ui_imgui
local logTag = 'aipacenotes'

local C = {}

C.name = 'AI Pacenotes Stage Finish'
C.description = 'Plays audio after crossing the finish line.'

C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
}

C.tags = {'aipacenotes'}

function C:init(mgr, ...)
  self.audioManager = require('/lua/ge/extensions/gameplay/rally/audioManager')()
  self.audioManager:resetAudioQueue()
  self.setupDone = false
end

function C:initRally()
  self:detectMissionId()

  self:getMissionSettings()
  if not self.missionSettings then
    return
  end

  self:getNotebook()
  if not self.notebook then
    return
  end

  self.missionSettings.fgNode = { missionDir = self.missionDir }

  self.codriver = self.notebook:getCodriverByName(self.missionSettings.notebook.codriver)
  if not self.codriver then
    self:__setNodeError('setup', 'couldnt load codriver: '..self.missionSettings.notebook.codriver)
  end
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

function C:work(args)
  if not self.setupDone then
    self:initRally()
    self:playAudio('finish_1')
    self.setupDone = true
  end

  self.audioManager:playNextInQueue()
end

return _flowgraph_createNode(C)
