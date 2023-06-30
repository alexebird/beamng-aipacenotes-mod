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

function C:pushToRaceFile()
  local raceFname = self:getRaceFilename()
  local race = loadRace(raceFname)
  local selectedPacenotesVersion = self:getSelectedVersion()

  -- race.pacenotes = selectedPacenotesVersion.pacenotes
  -- race.pacenotes = require('/lua/ge/extensions/gameplay/util/sortedList')("pacenotes", race, require('/lua/ge/extensions/gameplay/race/pacenote'))
  race.pacenotes:onDeserialized(selectedPacenotesVersion.pacenotes, {})

  self:setInstalledVersion(selectedPacenotesVersion)
  local pacenotesFname = self.aiPacenotesTool.getCurrentPath()._dir .. 'pacenotes.pacenotes.json'
  self.aiPacenotesTool.savePacenotes(self.pacenotes, pacenotesFname)
  log('I', logTag, "saved pacenotes to file " .. pacenotesFname)
  saveRace(race, raceFname)
  reloadRaceFile(raceFname)
  log('I', logTag, "updated pacenotes in race file " .. raceFname .. " with version named '" .. selectedPacenotesVersion.name .. "'")
end

function C:pullFromRaceFile()
  local raceFname = self:getRaceFilename()
  local race = loadRace(raceFname)
  local pacenotesFromRace = race.pacenotes:onSerialize()
  local selectedPacenotesVersion = self:getSelectedVersion()
  -- printPacenotesVersion(selectedPacenotesVersion)
  selectedPacenotesVersion.pacenotes = pacenotesFromRace
  log('I', logTag, "updated pacenotes with name '" .. selectedPacenotesVersion.name .. "' from race file " .. raceFname)
  printPacenotesVersion(selectedPacenotesVersion)
end

function printPacenotesVersion(ver)
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

function saveRace(race, savePath)
  local json = race:onSerialize()
  jsonWriteFile(savePath, json, true)
end

function loadRace(filename)
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
  -- p._dir = dir
  -- local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  -- p._fnWithoutExt = fn2
  return race
end

function reloadRaceFile(raceFname)
  if editor_raceEditor then
    if not editor.active then
      editor.setEditorActive(true)
    end
    editor_raceEditor.show()
    editor_raceEditor.loadRace(raceFname)
  end
end

function C:draw()
  -- im.Columns(2)
  -- im.SetColumnWidth(0,150)

  -- im.Text("Current version")
  -- im.NextColumn()
  -- local editEnded = im.BoolPtr(false)
  -- im.PushItemWidth(im.GetContentRegionAvailWidth() - 35)
  -- editor.uiInputText("##currentVersion", self.currentVersionText, 1024, nil, nil, nil, editEnded)
  -- im.PopItemWidth()
  -- if editEnded[0] then
  --   self.pacenotes.current_version = ffi.string(self.currentVersionText)
  --   self.pacenotes._dirty = true
  -- end

  -- im.NextColumn()

  -- latest working version
  -- im.Text("Current version")
  -- im.NextColumn()
  -- im.PushItemWidth(200)
  -- -- type dropdown menu
  -- if im.BeginCombo('##currentVersionDropdown', self.pacenotes.current_version or "None!") then
  --   for _, versionName in ipairs(self:getAllVersions()) do
  --     if im.Selectable1(versionName, versionName == self.pacenotes.current_version) then
  --       self:setCurrentVersion(versionName)
  --       self.pacenotes._dirty = true
  --     end
  --   --   if im.IsItemHovered() then
  --   --     im.BeginTooltip()
  --   --     im.PushTextWrapPos(200 * editor.getPreference("ui.general.scale"))
  --   --     im.TextWrapped(gameplay_missions_missions.getMissionStaticData(mType)["description"] or "No Description")
  --   --     im.PopTextWrapPos()
  --   --     im.EndTooltip()
  --   --   end
  --   end
  --   im.EndCombo()
  -- end
  -- im.SameLine()
  -- /latest working version

--   if not self._titleTranslated then
--     self._titleTranslated = translateLanguage(self.mission.name, noTranslation, true)
--   end
--   editor.uiIconImage(editor.icons.translate, imVec24x24 , (self._titleTranslated or noTranslation) == noTranslation and imVec4Red or imVec4Green)
--   if im.IsItemHovered() then
--     im.tooltip(self._titleTranslated)
--   end


--   im.NextColumn()

--   im.Text("Description")
--   im.NextColumn()
--   editEnded = im.BoolPtr(false)
--   im.PushItemWidth(im.GetContentRegionAvailWidth() - 35)
--   editor.uiInputTextMultiline("##Description", self.descText, 2048, im.ImVec2(0,100), nil, nil, nil, editEnded)
--   im.PopItemWidth()
--   if editEnded[0] then
--     self.mission.description = ffi.string(self.descText)
--     self._descTranslated = nil
--     self.mission._dirty = true
--   end
--     im.SameLine()
--   if not self._descTranslated then
--     self._descTranslated = translateLanguage(self.mission.description, noTranslation, true)
--   end
--   editor.uiIconImage(editor.icons.translate, imVec24x24 , (self._descTranslated or noTranslation) == noTranslation and imVec4Red or imVec4Green)
--   if im.IsItemHovered() then
--     im.tooltip(self._descTranslated)
--   end

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

      if im.Button("Delete") then
        print("TODO delete pacenote version")
      end
      im.SameLine()
      if im.Button("Push to Race File") then
        self:pushToRaceFile()
      end
      im.SameLine()
      if im.Button("Pull from Race File") then
        self:pullFromRaceFile()
      end

      im.BeginChild1("currentVersionInner", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
      im.HeaderText("Pacenotes Version Info")
      im.Columns(2)
      im.SetColumnWidth(0,150)

      im.Text("Name")
      im.NextColumn()
      local editEnded = im.BoolPtr(false)
      local versionNameText = im.ArrayChar(1024, versionData.name)
      editor.uiInputText("##versionName", versionNameText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        print('updated version')
        -- self.pacenotes.versions[index] = ffi.string(nameText)
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

      im.Text("Authors")
      im.NextColumn()
      local editEnded = im.BoolPtr(false)
      local authorsText = im.ArrayChar(1024, versionData.authors)
      editor.uiInputText("##authors", authorsText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        print('updated authors')
      end
      im.NextColumn()

      im.Text("Description")
      im.NextColumn()
      local editEnded = im.BoolPtr(false)
      local authorsText = im.ArrayChar(1024, versionData.description)
      editor.uiInputTextMultiline("##description", authorsText, 2048, im.ImVec2(0,100), nil, nil, nil, editEnded)
      if editEnded[0] then
        print('updated description')
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
