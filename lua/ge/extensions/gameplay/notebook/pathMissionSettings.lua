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
  self.notebook = default_settings.notebook
  self.transcripts = default_settings.transcripts
  self.missionDir = nil -- can be set by AIP Loader flowgraph node.
  self.fname = fname

  self.id = self:getNextUniqueIdentifier()
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
--
-- function C:getCurrTranscript()
--   return self:getTranscript('curr')
-- end
--
-- function C:getFullCourseTranscript()
--   return self:getTranscript('full_course')
-- end
--
-- function C:getTranscript(settingName)
--   if self.transcripts and self.transcripts[settingName] then
--     local basenameWithExt = self.transcripts[settingName]
--     local absPath = re_util.missionTranscriptPath(self.rallyEditor.getMissionDir(), basenameWithExt)
--     if FS:fileExists(absPath) then
--       local loaded_transcript = require('/lua/ge/extensions/gameplay/aipacenotes/transcripts/path')(absPath)
--       if not loaded_transcript:load() then
--         log('E', logTag, 'couldnt load transcripts file from '..absPath)
--         return nil
--       else
--         return loaded_transcript
--       end
--     end
--   else
--     return nil
--   end
-- end

function C:getCurrTranscriptAbsPath(missionDir)
  return self:getTranscriptAbsPath(missionDir, 'curr')
end

function C:getFullCourseTranscriptAbsPath(missionDir)
  return self:getTranscriptAbsPath(missionDir, 'full_course')
end

function C:getTranscriptAbsPath(missionDir, settingName)
  if self.transcripts and self.transcripts[settingName] then
    local basenameWithExt = self.transcripts[settingName]
    missionDir =  missionDir or editor_rallyEditor.getMissionDir()
    local absPath = re_util.missionTranscriptPath(missionDir, basenameWithExt)
    if not FS:fileExists(absPath) then
      log('W', logTag, 'getTranscriptAbsPath absPath file doesnt exist: '..absPath)
      return nil
    else
      return absPath
    end
  else
    return nil
  end
end

function C:setCurrTranscript(newAbsPath)
  self:setTranscriptAbsPath('curr', newAbsPath)
end

function C:setFullCourseTranscript(newAbsPath)
  self:setTranscriptAbsPath('full_course', newAbsPath)
end

function C:setTranscriptAbsPath(settingName, newAbsPath)
  if not newAbsPath then return end

  if self.transcripts and self.transcripts[settingName] then
    if FS:fileExists(newAbsPath) then
      local dir, filename, ext = path.splitWithoutExt(newAbsPath, true)
      self.transcripts[settingName] = filename..'.'..ext
      self:write()
    else
      log('E', logTag, 'setTranscriptAbsPath newAbsPath doesnt exist: '..newAbsPath)
    end
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
