local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local SettingsManager = require('/lua/ge/extensions/gameplay/aipacenotes/settingsManager')
local DrivelineTracker = require('/lua/ge/extensions/gameplay/aipacenotes/driveline/tracker')

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

  self.drivelineTracker = nil
  self.useDriveline = true

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

  -- reset flag is used to skip a single update tick after a reset.
  -- that way the vehicle velocity is ignored when it jumps to the reset location.
  self.reset_flag = false
end

function C:setOverrideMission(missionId, missionDir)
  self.overrideMissionId = missionId
  self.overrideMissionDir = missionDir
end

function C:setDrivelineTrackerThreshold(val)
  if not self.drivelineTracker then return end
  self.drivelineTracker:setThreshold(val)
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

  -- self.missionSettings.dynamic = { missionDir = self.missionDir }

  -- self.codriver = self.notebook:getCodriverByName(self.missionSettings.notebook.codriver)
  self.codriver = self.notebook:selectedCodriver()
  if not self.codriver then
    log('I', logTag, 'RallyManager setup no codriver')
    -- error('couldnt load codriver: '..self.missionSettings.notebook.codriver)
    error('couldnt load codriver: '..self.notebook:getMissionSettings().notebook.codriver)
  end

  self.audioManager = require('/lua/ge/extensions/gameplay/rally/guiAudioManager')(self)
  self.audioManager:resetAudioQueue()

  self.notebook:cachePacenoteFgData(self.codriver)

  self:reset()
  self.setup_complete = true
  log('I', logTag, 'RallyManager setup complete nextId='..self.nextId)
end

function C:reset()
  log('I', logTag, 'RallyManager reset')

  self.reset_flag = true

  self.audioManager:resetAudioQueue()

  self.vehicleTracker = require('/lua/ge/extensions/gameplay/rally/vehicleTracker')(
    self.damageThresh
  )

  self.closestPacenotes = nil
  self.nextId = 1
  log('D', 'wtf', 'nextId reset: hardcoded to 1')
  self.currLap = -1
  self.maxLap = -1

  self.drivelineTracker = DrivelineTracker(
    self.missionDir,
    self.vehicleTracker,
    self.notebook
  )
  self.drivelineTracker:notifyThreshold()
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
  local settings, err = SettingsManager.loadMissionSettingsForMissionDir(self.missionDir)

  if err then
    error(err)
  end

  self.missionSettings = settings
  -- self.missionSettings = self.notebook:getMissionSettings()
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
    if self.notebook:save() then
      if editor_rallyEditor then
        local notebook = editor_rallyEditor.getCurrentPath()
        if notebook then
          notebook:reload()
        end
      end

      return true
    end
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

function C:playbackAllowed(pacenote)
  local allowed, err = pacenote:playbackAllowed(self.currLap, self.maxLap)
  if err then
    log('E', logTag, 'error in pacenote:playbackAllowed(): '..err)
    allowed = true
  end
  return allowed
end

function C:updateForClosestPacenotes()
  -- log('D', 'wtf', 'has closestPacenotes ('..#self.closestPacenotes..')')
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
end

function C:updateForNextPacenote()
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

function C:update(dtSim)
  if not self.setup_complete then return end

  -- get the latest vehicle position data
  if self.vehicleTracker then
    self.vehicleTracker:onUpdate(dtSim)
  end

  -- handle damage
  if self.vehicleTracker:didJustHaveDamage() then
    -- First, check if the last tick had an increase in damage.
    self.audioManager:handleDamage()
  end

  if self.useDriveline then
    if self.drivelineTracker then
      local pacenote = self.notebook.pacenotes.sorted[self.nextId]
      if pacenote then
        if self.reset_flag then
          self.reset_flag = false
        else
          self.drivelineTracker:onUpdate(pacenote)
          local cnt = self.drivelineTracker:getInFlightPacenotesCount()

          if cnt <= 1 and self.drivelineTracker:isUnderThreshold() then
            print('inFlight='..tostring(cnt))

            if self:playbackAllowed(pacenote) then
              self.audioManager:enqueuePacenote(pacenote)
            end

            -- add the in-flight note at the same time the audio enqueue decision is made.
            self.drivelineTracker:putInFlightPacenote(pacenote)
            -- advance the pacenote even if we dont play the audio.
            self.nextId = self.nextId + 1
            -- log('D', 'wtf', 'nextId update,else: incremented to '..tostring(self.nextId))
            self.nextPacenotes = { self.notebook.pacenotes.sorted[self.nextId] }
            self:nextPacenotesUpdated()
          end
        end
      end
    end
  else
    -- look for the next pacenote to trigger audio for
    if self.closestPacenotes then
      -- In this case, there is a vehicle position reset and we need to find where
      -- in the pacenotes list we are.
      self:updateForClosestPacenotes()
    else
      -- in the normal case, we assume the next pacenote is nextId+1.
      -- yes, this won't support skipping pacenotes, but I don't think
      -- that should be expected.
      self:updateForNextPacenote()
    end
  end
end

-- used to send the next pacenotes to server, for Buddy Mode.
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
    local noteData = pacenote:asFlowgraphData(self.codriver)
    local entry = {
      pacenote = noteData.note_text
    }
    table.insert(requestBody, entry)
  end

  -- local resp = extensions.gameplay_aipacenotes_client.update_next_pacenotes({ pacenotes = requestBody })
end

function C:closestPacenoteToVehicle()
  local pacenotes = self.notebook:findNClosestPacenotes(self.vehicleTracker:pos(), 1)
  if pacenotes and pacenotes[1] then
    return pacenotes[1]
  else
    return nil
  end
end

function C:handleNoteSearch()
  self.closestPacenotes = self.notebook:findNClosestPacenotes(self.vehicleTracker:pos(), self.closestPacenotes_n)
  self.nextPacenotes = self.closestPacenotes
  self:nextPacenotesUpdated()
end

function C:drivelineTrackerNoteSearch()
  local nextPacenoteData = self.drivelineTracker:findNextPacenote()
  local pacenote_i = nextPacenoteData.i
  self.nextId = pacenote_i
  self.nextPacenotes = { self.notebook.pacenotes.sorted[self.nextId] }
  self:nextPacenotesUpdated()
end

function C:getNextPacenotes()
  if self.nextPacenotes then
    return self.nextPacenotes
  else
    return {}
  end
end

function C:getPacenotesNearPos(pos)
  if not pos then return {} end
  -- return self:getNextPacenotes()

  local closestPacenotes = self.notebook:findNClosestPacenotes(pos, self.closestPacenotes_n)
  return closestPacenotes
end

function C:updateRaceData(raceData)
end

function C:getRandomStaticPacenote(prefix)
  return self.notebook:getRandomStaticPacenote(prefix)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
