-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'Play Pacenote Audio'
C.description = 'Plays the audio file associated with the pacenote.'
C.category = 'logic'

C.color = im.ImVec4(1, 1, 0, 0.75)
C.pinSchema = {
  {dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.'},
  {dir = 'in', type = 'string', name = 'note', description = 'Note of the pacenote.'},
  {dir = 'in', type = 'bool', name = 'use_race_editor', description = 'Should the race file be pulled from the race tool.'},
  -- { dir = 'in', type = 'table', name = 'pathData', tableType = 'pathData', description = 'Path data' },
--   {dir = 'in', type = 'table', name = 'raceData', tableType = 'raceData', description = 'Data from the race for other nodes to process.'},
--   {dir = 'in', type = 'number', name = 'vehId', description = 'The Vehicle that should be tracked.'},
--   {dir = 'out', type = 'flow', name = 'flow', description = 'Outflow from this node.', impulse = true},
--   {dir = 'out', type = 'string', name = 'note', description = 'Note of the pacenote.'},
}

C.tags = {'scenario'}

local logTag = 'aipacenotes'

local function normalize_text(input)
  -- Convert the input to lower case
  input = input:lower()

  -- special char subs
  input = input:gsub(',', 'C')
  input = input:gsub('%?', 'Q') -- replace '?' with 'Q'
  input = input:gsub('%.', 'P') -- replace '.' with 'P'
  input = input:gsub(';', 'S')
  input = input:gsub('!', 'E')

  -- Substitute any non-alphanumeric character with a hyphen
  input = input:gsub("%W", "-")

  -- Remove any consecutive hyphens
  input = input:gsub("%-+", "-")

  -- Remove any leading or trailing hyphens
  input = input:gsub("^%-", ""):gsub("%-$", "")

  return input
end

local function normalize_text(s)
  local hash_value = 0
  for i = 1, #s do
    hash_value = (hash_value * 33 + string.byte(s, i)) % 2147483647
  end
  return hash_value
end

local function readMissionSpecificSettings(missionDir)
  local settingsFname = missionDir .. '/pacenotes/settings.json'
  log('D', logTag, 'settings file: ' .. tostring(settingsFname))
  local json = jsonReadFile(settingsFname)
  if not json then
    log('E', logTag, 'unable to read settings file at: ' .. tostring(settingsFname))
    return
  end
  return json
end

local function file_exists(filename)
  local file = io.open(filename, "r")
  if file == nil then
    return false
  else
    file:close()
    return true
  end
end

local function getTheDirname(path)
    return string.match(path, "(.+)/[^/]*$")
end

-- for cli running and testing of code only
-- local isDev = os.getenv("DEV")
-- if isDev == "t" then
--   print(normalize_text("Hello, World!"))
-- else
--   entrypoint()
-- end

function C:init(mgr, ...)
  self.data.detailed = false
end

function C:drawMiddle(builder, style)

end

function C:work(args)
  local pacenote = self.pinIn.note.value
  -- local pathData = self.pinIn.pathData.value
  local useRaceEditor = self.pinIn.use_race_editor.value

  local raceFname = nil
  local missionDir = nil

  if useRaceEditor == true then
    log('D', logTag, 'using race file from Race Editor')
    raceFname = editor_raceEditor.getCurrentFilename()
    missionDir = getTheDirname(raceFname)
    -- local pnWindow = editor_raceEditor.getPacenotesWindow()
  else
    raceFname = 'race.race.json'
    missionDir = 'gameplay/missions/' .. gameplay_missions_missionManager.getForegroundMissionId()
  end

  log('I', logTag, 'got pacenote=' .. pacenote)

  local settings = readMissionSpecificSettings(missionDir)
  if not settings then
    log('E', logTag, 'settings were nil')
    return
  end
  local pacenoteHash = normalize_text(pacenote)
  local volume = settings.volume or 4
  local pacenotesVersion = settings.currentVersion

  log('D', logTag, "pacenote: " .. pacenote .. ", hash=" .. pacenoteHash)
  local pacenoteFilePath = missionDir .. '/pacenotes/' .. pacenotesVersion .. '/pacenote_' .. pacenoteHash .. '.ogg'

  if file_exists(pacenoteFilePath) then
    Engine.Audio.playOnce('AudioGui', pacenoteFilePath, { volume=volume })
  else
    log('E', logTag, "pacenote audio file does not exist: " .. pacenoteFilePath)
    return
  end
end

return _flowgraph_createNode(C)