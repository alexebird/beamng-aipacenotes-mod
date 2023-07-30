logTag = 'aiPacenotes_custom_lua_node'

function normalize_text(input)
  -- Convert the input to lower case
  input = input:lower()

  -- Substitute any non-alphanumeric character with a hyphen
  input = input:gsub("%W", "-")

  -- Remove any consecutive hyphens
  input = input:gsub("%-+", "-")

  -- Remove any leading or trailing hyphens
  input = input:gsub("^%-", ""):gsub("%-$", "")

  return input
end

function readMissionSpecificSettings(missionId)
  local settingsFname = 'gameplay/missions/' .. missionId .. '/pacenotes/settings.json'
  local json = jsonReadFile(settingsFname)
  if not json then
    log('E', logTag, 'unable to read settings file at: ' .. tostring(settingsFname))
    return
  end
  return json
end

function entrypoint()
  local pacenote = self.pinIn.pacenote.value
  local levelName = self.pinIn.levelName.value
  local pathData = self.pinIn.pathData.value
  local missionId = gameplay_missions_missionManager.getForegroundMissionId()

  local settings = readMissionSpecificSettings(missionId)
  local pacenoteHash = normalize_text(pacenote)
  local volume = settings.volume or 8
  local pacenotesVersion = settings.currentVersion

  log('D', logTag, "missionId: " .. missionId)
  log('D', logTag, "pacenote: " .. pacenote .. ", hash=" .. pacenoteHash)
  local pacenoteFilePath = 'gameplay/missions/' .. missionId .. '/pacenotes/' .. pacenotesVersion .. '/pacenote_' .. pacenoteHash .. '.ogg'

  if file_exists(pacenoteFilePath) then
    Engine.Audio.playOnce('AudioGui', pacenoteFilePath, { volume=volume })
  else
    log('E', logTag, "pacenote audio file does not exist: " .. pacenoteFilePath)
  end
end

function file_exists(filename)
  local file = io.open(filename, "r")
  if file == nil then
    return false
  else
    file:close()
    return true
  end
end

-- for cli running and testing of code only
local isDev = os.getenv("DEV")
if isDev == "t" then
  print(normalize_text("Hello, World!"))
else
  entrypoint()
end
