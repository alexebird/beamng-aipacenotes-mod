local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local C = {}
local logTag = 'aipacenotes'

local default_settings = {
  notebook = {
    filename = "primary.notebook.json",
    codriver = "Sophia",
  },
  transcripts = {
    full_course = "full_course.transcripts.json",
    curr = "curr.transcripts.json",
  }
}

function C:getNextUniqueIdentifier()
  self._uid = self._uid + 1
  return self._uid
end

function C:init(fname)
  self._uid = 0
  -- self.missionDir = nil -- can be set by AIP Loader flowgraph node.
  self.fname = fname

  self.id = self:getNextUniqueIdentifier()
  self:_reset()
end

function C:_reset()
  self.notebook = default_settings.notebook
  self.transcripts = default_settings.transcripts
end

function C:load()
  self:_reset()

  if not FS:fileExists(self.fname) then
    log('E', logTag, "mission settings file not found: "..self.fname)
    return false
  end

  log('I', logTag, 'reading settings file: ' .. tostring(self.fname))

  local json = jsonReadFile(self.fname)
  if not json then
    log('E', logTag, 'unable to read settings file at: ' .. tostring(self.fname))
    return false
  end

  self:onDeserialized(json)

  return true
end

function C:defaultSettings()
  return default_settings
end

function C:onSerialize()
  local ret = {
    notebook = self.notebook,
    transcripts = self.transcripts,
  }

  return ret
end

function C:onDeserialized(data)
  if not data then return end
  self.notebook = data.notebook or default_settings.notebook
  self.transcripts = data.transcripts or default_settings.transcripts
end

function C:write()
  local json = self:onSerialize()
  jsonWriteFile(self.fname, json, true)
end

function C:getFullCourseTranscript(missionDir)
  return self:getTranscript('full_course', missionDir)
end

function C:getTranscript(settingName, missionDir)
  if self.transcripts and self.transcripts[settingName] then
    local basenameWithExt = self.transcripts[settingName]
    local absPath = re_util.missionTranscriptPath(missionDir, basenameWithExt)
    if FS:fileExists(absPath) then
      local loaded_transcript = require('/lua/ge/extensions/gameplay/aipacenotes/transcripts/path')(absPath)
      if not loaded_transcript:load() then
        log('E', logTag, 'couldnt load transcripts file from '..absPath)
        return nil
      else
        return loaded_transcript
      end
    end
  else
    return nil
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
