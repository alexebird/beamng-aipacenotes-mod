local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
local logTag = 'aipacenotes'

function C:init()
  self.setup_complete = false

  self.buddyMode = false
  -- self.buddyMode = true

  self.overrideMissionId = nil
  self.overrideMissionDir = nil

  self.damageThresh = nil
  self.closestPacenotes_n = nil

  self.audioManager = nil
  self.vehicleTracker = nil

  self.missionId = nil
  self.missionDir = nil
  self.missionSettings = nil
  self.notebook = nil
  self.codriver = nil

  self.nextId = nil -- this is the id of the pacenote we are looking for every dt.
  log('D', 'wtf', 'nextId init: hardcoded to nil')
  self.closestPacenotes = nil

  -- use this for debug drawing in the recce app
  self.nextPacenotes = nil

  self.currLap = -1
  self.maxLap = -1
end

function C:setOverrideMission(missionId, missionDir)
  self.overrideMissionId = missionId
  self.overrideMissionDir = missionDir
end

-- function C:toString()
--   if self.missionId then
--     return 'mission: '..self.missionId
--   else
--     return '<setup pending>'
--   end
-- end

-- 1. get mission dir
-- 2. get aipacenotes/mission.settings.json
-- 3. get notebook from settings
-- 4. get codriver from notebook+settings
-- 5. generate list of flowgraph data from the notebook's pacenotes
function C:setup(damageThresh, closestPacenotes_n)
  log('I', logTag, 'RallyManager setup starting')

  self.damageThresh = damageThresh
  self.closestPacenotes_n = closestPacenotes_n

  -- self.audioManager = require('/lua/ge/extensions/gameplay/rally/audioManager')(self)
  self.audioManager = require('/lua/ge/extensions/gameplay/rally/remoteAudioManager')(self)
  self.audioManager:resetAudioQueue()

  self:detectMissionId()

  self:getMissionSettings()
  if not self.missionSettings then
    log('I', logTag, 'RallyManager setup no missionSettings')
    return
  end

  self:loadNotebook()
  if not self.notebook then
    log('I', logTag, 'RallyManager setup no notebook')
    return
  end

  self.missionSettings.dynamic = { missionDir = self.missionDir }

  self.codriver = self.notebook:getCodriverByName(self.missionSettings.notebook.codriver)
  if not self.codriver then
    log('I', logTag, 'RallyManager setup no codriver')
    error('couldnt load codriver: '..self.missionSettings.notebook.codriver)
  end

  -- self.fgPacenotes = self.notebook:getFlowgraphPacenotes(self.missionSettings, self.codriver)
  self.notebook:cachePacenoteFgData(self.missionSettings, self.codriver)

  self:reset()
  self.setup_complete = true
  log('I', logTag, 'RallyManager setup complete nextId='..self.nextId)
end

function C:reset()
  log('I', logTag, 'RallyManager reset')
  self.vehicleTracker = require('/lua/ge/extensions/gameplay/rally/vehicleTracker')(
    self.damageThresh
  )

  self.closestPacenotes = nil
  self.nextId = 1
  log('D', 'wtf', 'nextId reset: hardcoded to 1')
  self.currLap = -1
  self.maxLap = -1
end

function C:detectMissionId()
  if self.overrideMissionId and self.overrideMissionDir then
    self.missionId, self.missionDir = self.overrideMissionId, self.overrideMissionDir
    return
  end

  local missionId, missionDir, err = re_util.detectMissionIdHelper()

  if err then
    error(err)
  end

  self.missionId, self.missionDir = missionId, missionDir
end

function C:getMissionSettings()
  local settings, err = re_util.getMissionSettingsHelper(self.missionDir)

  if err then
    error(err)
  end

  self.missionSettings = settings
end

function C:loadNotebook()
  local notebook, err = re_util.getNotebookHelper(self.missionDir, self.missionSettings)

  if err then
    error(err)
  end

  self.notebook = notebook
end

function C:saveNotebook()
  if self.notebook then
    return self.notebook:save()
  end
end

function C:handleLapChange(currLap, maxLap)
  self.maxLap = maxLap

  if currLap > self.currLap then
    self.currLap = currLap
    log('D', logTag, 'handleLapChange curr='..self.currLap..' max='..self.maxLap)
    self.nextId = 1
    log('D', 'wtf', 'nextId handleLapChange: hardcoded to 1 ')
  end
end

function C:intersectCorners(pacenote)
  if not pacenote then return false end


  local prevCorners = self.vehicleTracker:getPreviousCorners()
  local currCorners = self.vehicleTracker:getCurrentCorners()
  if prevCorners and currCorners then
    return pacenote:intersectCorners(prevCorners, currCorners)
  else
    return false
  end
end

function C:shouldPlay(pacenote)
  local allowed, err = pacenote:playbackAllowed(self.currLap, self.maxLap)
  if err then
    log('E', logTag, 'error in pacenote:playbackAllowed(): '..err)
    allowed = true
  end
  return allowed and self:intersectCorners(pacenote)
end

function C:update(dtSim, raceData)
  if not self.setup_complete then return end

  -- if self.nextPacenotes then
  --   for i,pacenote in ipairs(self.nextPacenotes) do
  --     local wp_audio_trigger = pacenote:getActiveFwdAudioTrigger()
  --     wp_audio_trigger:drawDebugRecce(i, self.nextPacenotes, pacenote._cached_fgData.note_text)
  --   end
  -- end

  if self.vehicleTracker then
    self.vehicleTracker:onUpdate(dtSim, raceData)
  end

  if self.vehicleTracker:didJustHaveDamage() then
    -- First, check if the last tick had an increase in damage.
    self.audioManager:handleDamage()
  -- else
    -- self.audioManager:playNextInQueue()
  elseif self.closestPacenotes then
    -- log('D', 'wtf', 'has closestPacenotes ('..#self.closestPacenotes..')')
    -- In this case, there is a vehicle position reset and we need to find where
    -- in the pacenotes list we are.
    for _,closePacenote in ipairs(self.closestPacenotes) do
      if self:intersectCorners(closePacenote) then
        if self:shouldPlay(closePacenote) then
          self.audioManager:enqueuePacenote(closePacenote)
        end
        -- nextId is not the pacenote.id, its the index in the ordered list of pacenotes.
        for i,pacenote in ipairs(self.notebook.pacenotes.sorted) do
          if pacenote.id == closePacenote.id then
            -- log('D', 'wtf', 'found pn match at i='..tostring(i))
            self.nextId = i+1
            -- log('D', 'wtf', 'nextId update,closestPacenotes: incremented to '..tostring(self.nextId))
            self.nextPacenotes = { self.notebook.pacenotes.sorted[self.nextId] }
            self:nextPacenotesUpdated()
            break
          end
        end
        self.closestPacenotes = nil
        break
      end
    end
  else
    -- in the normal case, we assume the next pacenote is nextId+1.
    -- yes, this won't support skipping pacenotes, but I don't think
    -- that should be expected.
    -- log('D', 'wtf', 'nextId='..tostring(self.nextId))
    local pacenote = self.notebook.pacenotes.sorted[self.nextId]
    if pacenote and self:intersectCorners(pacenote) then
      if self:shouldPlay(pacenote) then
        self.audioManager:enqueuePacenote(pacenote)
      end
      -- advance the pacenote even if we dont play the audio.
      self.nextId = self.nextId + 1
      -- log('D', 'wtf', 'nextId update,else: incremented to '..tostring(self.nextId))
      self.nextPacenotes = { self.notebook.pacenotes.sorted[self.nextId] }
    self:nextPacenotesUpdated()
    end
  end
end

function C:nextPacenotesUpdated()

  if not self.buddyMode then return end


  local requestBody = {}

  local pacenotes = {}

  if #self.nextPacenotes > 1 then
    for i,pn in ipairs(self.nextPacenotes) do
      table.insert(pacenotes, pn)
    end
  else
    table.insert(pacenotes, self.nextPacenotes[1])
    local nextNextPn = self.notebook.pacenotes.sorted[self.nextId+1]
    table.insert(pacenotes, nextNextPn)
  end

  for i,pacenote in ipairs(pacenotes) do
    local entry = {
      pacenote = pacenote._cached_fgData.note_text
    }
    table.insert(requestBody, entry)
  end

  -- local resp = extensions.gameplay_aipacenotes_client.update_next_pacenotes({ pacenotes = requestBody })
end

function C:handleNoteSearch()
  self.closestPacenotes = self.notebook:findNClosestPacenotes(self.vehicleTracker:pos(), self.closestPacenotes_n)
  self.nextPacenotes = self.closestPacenotes
  self:nextPacenotesUpdated()
end

function C:getNextPacenotes()
  if self.nextPacenotes then
    return self.nextPacenotes
  else
    return {}
  end
end

function C:updateRaceData(raceData)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
