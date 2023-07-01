-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}
local logTag = 'editor_ai_pacenotes_form'

function C:init(aiPacenotesTool)
  self.aiPacenotesTool = aiPacenotesTool
  self.index = nil -- index is really the id of the selected pacenote version
end

-- here, self.pacenotes is the same as currentPath in the parent window.
-- it's a gameplay/pacenotes/path.lua class instance.
function C:setPacenotes(pacenotes)
  self.pacenotes = pacenotes
  if self.pacenotes and not self.index then
    for _, version in ipairs(self.pacenotes.versions) do
      -- selects the installed pacenotesVersion when pacenotes are set.
      if version.installed == true then
        self.index = version.id
      end
    end
  end
end

function C:getSelectedVersion()
  if self.pacenotes then
    for _, version in ipairs(self.pacenotes.versions) do
      if self.index == version.id then
        return version
      end
    end
  end
end

function C:createEmptyVersion()
  local newEntry = self.pacenotes:createNew()
  self.index = newEntry.id
end

function C:setInstalledVersion(ver)
  for _, version in ipairs(self.pacenotes.versions) do
    if version.installed then
      version.installed = false
    end
  end

  ver.installed = true
end

function C:openRaceFile()
  local raceFname = self:getRaceFilename()
  self.reloadRaceFile(raceFname)
end

function C:updateMissionSpecificSettingsCurrentVersion(newVer)
  local verString = "version" .. newVer.id
  local settingsFname = self.aiPacenotesTool.getCurrentPath()._dir .. 'pacenotes/settings.json'

  local settings = jsonReadFile(settingsFname)
  if not settings then
    log('E', logTag, "couldnt read mission-specific settings file: " .. settingsFname)
    return false
  end

  settings.currentVersion = verString

  if not jsonWriteFile(settingsFname, settings, true) then
    log('E', logTag, "couldnt write mission-specific settings file: " .. settingsFname)
    return false
  end

  return true
end

function C:pushToRaceFile()
  local raceFname = self:getRaceFilename()
  local race = self.loadRace(raceFname)
  local selectedPacenotesVersion = self:getSelectedVersion()

  race.pacenotes:onDeserialized(selectedPacenotesVersion.pacenotes, {})

  self:setInstalledVersion(selectedPacenotesVersion)
  if not self:updateMissionSpecificSettingsCurrentVersion(selectedPacenotesVersion) then
    log('E', logTag, "couldnt push to race file. things may be in a bad state :(")
  end

  local pacenotesFname = self.aiPacenotesTool.getCurrentPath()._dir .. 'pacenotes.pacenotes.json'
  self.aiPacenotesTool.savePacenotes(self.pacenotes, pacenotesFname)
  log('I', logTag, "saved pacenotes to file " .. pacenotesFname)

  self.saveRace(race, raceFname)
  self.reloadRaceFile(raceFname)
  log('I', logTag, "updated pacenotes in race file " .. raceFname .. " with version named '" .. selectedPacenotesVersion.name .. "'")
end

function C:pullFromRaceFile()
  local raceFname = self:getRaceFilename()
  local race = self.loadRace(raceFname)
  local pacenotesFromRace = race.pacenotes:onSerialize()
  local selectedPacenotesVersion = self:getSelectedVersion()
  -- printPacenotesVersion(selectedPacenotesVersion)
  selectedPacenotesVersion.pacenotes = pacenotesFromRace
  local pacenotesFname = self.aiPacenotesTool.getCurrentPath()._dir .. 'pacenotes.pacenotes.json'
  self.aiPacenotesTool.savePacenotes(self.pacenotes, pacenotesFname)
  log('I', logTag, "saved pacenotes to file " .. pacenotesFname)
  log('I', logTag, "updated pacenotes with name '" .. selectedPacenotesVersion.name .. "' from race file " .. raceFname)
  self.printPacenotesVersion(selectedPacenotesVersion)
end

function C.printPacenotesVersion(ver)
  log('D', logTag,
    'pacenoteVersion ' ..
      'name="' .. ver.name .. '" ' ..
      'installed=' .. tostring(ver.installed) .. ' ' ..
      'id=' .. tostring(ver.id) .. ' ' ..
      'voice=' .. ver.voice .. ' ' ..
      'authors="' .. ver.authors .. '" ' ..
      'description="' .. ver.description .. '" ' ..
      'pacenotes.size=' .. tostring(#ver.pacenotes) .. ' ' ..
    ''
  )
  log('D', logTag, 'pacenotes:')
  for _, pn in ipairs(ver.pacenotes) do 
    log('D', logTag, pn.name .. ': ' .. pn.note)
  end
end

function C:getRaceFilename()
  local missionDir = self.aiPacenotesTool.getCurrentPath()._dir
  local raceFile = missionDir .. 'race.race.json'
  return raceFile
end

function C.saveRace(race, savePath)
  local json = race:onSerialize()
  jsonWriteFile(savePath, json, true)
end

function C.loadRace(filename)
  if not filename then
    return
  end
  local json = readJsonFile(filename)
  if not json then
    log('E', logTag, 'unable to find race file: ' .. tostring(filename))
    return
  end
  local dir, filename, ext = path.split(filename)
  local race = require('/lua/ge/extensions/gameplay/race/path')("New Race")
  race:onDeserialized(json)
  return race
end

function C.reloadRaceFile(raceFname)
  if editor_raceEditor then
    if not editor.active then
      editor.setEditorActive(true)
    end
    editor_raceEditor.show()
    editor_raceEditor.loadRace(raceFname)
  end
end

function C:draw()
  im.BeginChild1("versions", im.ImVec2(225 * im.uiscale[0], 0), im.WindowFlags_ChildWindow)
  for i, version in ipairs(self.pacenotes.versions) do
    local versionName = version.name
    local versionId = version.id
    local installed = (version.installed) and " (installed)" or ""
    if im.Selectable1(versionName .. installed, versionId == self.index) then
      self.index = versionId
    end
  end
  im.Separator()
  if im.Selectable1('Create', false) then
    self:createEmptyVersion()
  end
  im.EndChild()

  im.SameLine()
  im.BeginChild1("currentSegment", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
    if self.index then
      local versionData = self.pacenotes.versions[self.index]
      im.SameLine()
      if im.Button("Open Race File") then
        self:openRaceFile()
      end
      im.SameLine()
      if im.Button("Push to Race File") then
        self:pushToRaceFile()
      end
      im.SameLine()
      if im.Button("Pull from Race File") then
        self:pullFromRaceFile()
      end

      -- if im.Button("Delete") then
      --   print("TODO delete pacenote version")
      -- end


      im.BeginChild1("currentVersionInner", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)

      im.Columns(1)
      im.HeaderText("Generate Audio Files")

      im.Columns(2)
      im.SetColumnWidth(0,200)
      im.Text("BeamNG.drive user folder")
      im.NextColumn()
      local pacenotesFname = 'C://Users/<username>/AppData/Local/BeamNG.drive'
      local ptxt = im.ArrayChar(1024, pacenotesFname)
      editor.uiInputText("##userpath", ptxt, nil, nil, nil, nil, nil)
      im.NextColumn()
      im.Text("Pacenotes file in user folder")
      im.NextColumn()
      local pacenotesFname = self.aiPacenotesTool.getCurrentPath()._dir .. 'pacenotes.pacenotes.json'
      local ptxt = im.ArrayChar(1024, pacenotesFname)
      editor.uiInputText("##notepath", ptxt, nil, nil, nil, nil, nil)
      im.NextColumn()
      im.Text("Upload pacenotes here")
      im.NextColumn()
      local urltxt = im.ArrayChar(1024, "https://pacenotes-mo5q6vt2ea-uw.a.run.app")
      editor.uiInputText("##url", urltxt, nil, nil, nil, nil, nil)

      im.NextColumn()

      im.Columns(1)
      im.Separator()
      im.HeaderText("Pacenotes Version Info")

      im.Columns(2)
      -- im.SetColumnWidth(0,150)
      im.Text("Name")
      im.NextColumn()
      local editEnded = im.BoolPtr(false)
      local versionNameText = im.ArrayChar(1024, versionData.name)
      editor.uiInputText("##versionName", versionNameText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        local selectedPacenotesVersion = self:getSelectedVersion()
        local newValue = ffi.string(versionNameText)
        selectedPacenotesVersion.name = newValue
      end
      im.NextColumn()

      im.Text("Installed")
      im.NextColumn()
      im.Text(tostring(versionData.installed))
      im.NextColumn()

      im.Text("# of Pacenotes")
      im.NextColumn()
      im.Text(tostring(#versionData.pacenotes))
      im.NextColumn()

      im.Text("Version id")
      im.NextColumn()
      im.Text('version' .. tostring(versionData.id))
      im.NextColumn()

      im.Text("Voice")
      im.NextColumn()
      local currentVoice = self:getSelectedVersion().voice
      if im.BeginCombo('##voiceDropdown', currentVoice) then
        for _, voiceName in ipairs(self.aiPacenotesTool.voiceNamesSorted) do
          if im.Selectable1(voiceName, voiceName == currentVoice) then
            local selectedPacenotesVersion = self:getSelectedVersion()
            local voiceParams = self.aiPacenotesTool.voices[voiceName]
            selectedPacenotesVersion.voice = voiceName
            selectedPacenotesVersion.language_code = voiceParams.language_code
            selectedPacenotesVersion.voice_name = voiceParams.voice_name
          end
        end
        im.EndCombo()
      end
      im.NextColumn()

      im.Text("Authors")
      im.NextColumn()
      local editEnded = im.BoolPtr(false)
      local authorsText = im.ArrayChar(1024, versionData.authors)
      editor.uiInputText("##authors", authorsText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        local selectedPacenotesVersion = self:getSelectedVersion()
        local newValue = ffi.string(authorsText)
        selectedPacenotesVersion.authors = newValue
      end
      im.NextColumn()

      im.Text("Description")
      im.NextColumn()
      local editEnded = im.BoolPtr(false)
      local descText = im.ArrayChar(1024, versionData.description)
      editor.uiInputTextMultiline("##description", descText, 2048, im.ImVec2(0,100), nil, nil, nil, editEnded)
      if editEnded[0] then
        local selectedPacenotesVersion = self:getSelectedVersion()
        local newValue = ffi.string(descText)
        selectedPacenotesVersion.description = newValue
      end
      im.NextColumn()

      im.EndChild()
    end
  im.EndChild()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
