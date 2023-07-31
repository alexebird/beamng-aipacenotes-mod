-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui

local C = {}
C.windowDescription = 'AI Pacenotes'

local defaultPacenotesFilename = "pacenotes.pacenotes.json"

local form = nil
local voices = nil
local voiceNamesSorted = nil

local previousFilepath = "/gameplay/pacenotes/"
local previousFilename = defaultPacenotesFilename
local currentPath = require("/lua/ge/extensions/editor/raceEditorTurbo/aiPacenotes/path")("New Pacenotes")
currentPath._fnWithoutExt = 'pacenotes'
currentPath._dir = previousFilepath

function C:init(raceEditor)
  self.raceEditor = raceEditor
end

function C:save()
  self:savePacenotes(currentPath, previousFilepath .. previousFilename)
end

function C:getRace()
  return self.raceEditor:getCurrentPath()
end

-- overwrite the pacenotes field in the currently installed pacenotes version
-- with the specified pacenotes.
function C:setNotesForInstalledVersion(newPacenotes)
  local selectedPacenotesVersion = form:getInstalledVersion()
  selectedPacenotesVersion.pacenotes = newPacenotes
end

-- path is a sort of confusing abstraction for representing the pacenotes file.
-- see aiPacenotes/path.lua
function C:setPath(path)
  self.path = path
end
function C:selected() end
function C:unselect() end

local function setFieldUndo(data)
  data.self.path[data.field] = data.old data.self:selected()
end

local function setFieldRedo(data)
  data.self.path[data.field] = data.new data.self:selected()
end

function C:loadForm()
  form = require('/lua/ge/extensions/editor/raceEditorTurbo/aiPacenotes/form')(self)
  form:setPacenotes(currentPath)
end

local function loadVoices()
  local voiceFname = "/settings/aipacenotes/voices.json"
  voices = readJsonFile(voiceFname)
  if not voices then
    log('E', logTag, 'unable to find voices file: ' .. tostring(filename))
    return
  end

  voiceNamesSorted = {}

  for voiceName, _ in pairs(voices) do
    table.insert(voiceNamesSorted, voiceName)
  end

  table.sort(voiceNamesSorted)
  -- print(dumps(voiceNamesSorted))
end

function C:loadPacenotes(filename)
  if not filename then
    return
  end
  local json = readJsonFile(filename)
  if not json then
    log('E', logTag, 'unable to find pacenotes file: ' .. tostring(filename))
    return
  end
  local dir, filename, ext = path.split(filename)
  previousFilepath = dir
  previousFilename = filename
  local p = require('/lua/ge/extensions/editor/raceEditorTurbo/aiPacenotes/path')("New Pacenotes")
  p:onDeserialized(json)
  p._dir = dir
  local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  p._fnWithoutExt = fn2

  currentPath = p

  self:internalLoad()
  form:setPacenotes(currentPath)

  return currentPath
end

function C:savePacenotes(pacenotes, savePath)
  local json = pacenotes:onSerialize()
  jsonWriteFile(savePath, json, true)
  local dir, filename, ext = path.split(savePath)
  previousFilepath = dir
  previousFilename = filename
  pacenotes._dir = dir
  local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  pacenotes._fnWithoutExt = fn2
end

function C:changeField(field,  new)
  if new ~= self.path[field] then
    editor.history:commitAction("Changed Field " .. field.. " of Path",
    {self = self, old = self.path[field], new = new, field = field},
    setFieldUndo, setFieldRedo)
  end
end

function C:internalLoad()
  -- must load voices before loading the form. kinda brittle.
  if not voices then
    loadVoices()
  end

  if not form then
    self:loadForm()
  end
end

function C:draw()
  im.BeginChild1("Layout", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
  -- im.Columns(1)
  -- im.HeaderText("Ai Pacenotes")

  self:internalLoad()

  if form then
    form:draw()
  end

  im.EndChild()
end

function C:getPacenotesFileForMission(missionDir)
  return missionDir..'\\'..defaultPacenotesFilename
end

function C:getDefaultPacenotesFname()
  return defaultPacenotesFilename
end

function C:getCurrentPath()
  return currentPath
end

function C:getVoiceNamesSorted()
  return voiceNamesSorted
end

function C:getVoices()
  return voices
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end