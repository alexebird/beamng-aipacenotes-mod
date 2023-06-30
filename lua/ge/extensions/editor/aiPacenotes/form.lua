-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local C = {}

function C:init(aiPacenotes)
  self.aiPacenotes = aiPacenotes
  self.index = nil
end

-- here, self.pacenotes is the same as currentPath in the parent window.
function C:setPacenotes(pacenotes)
  self.pacenotes = pacenotes

  print(dumps(self.pacenotes))

  if self.pacenotes and not self.index then
    for i, version in ipairs(self.pacenotes.versions) do
      if version.installed == true then
        self.index = i
      end
    end
  end
end

-- function C:setCurrentVersion(newVersion)
--   self.pacenotes.current_version = newVersion
-- end

-- function C:getAllVersionNames()
--   local versionNames = {}

--   for i, version in ipairs(self.pacenotes.versions) do
--     table.insert(versionNames, version.name)
--   end

--   return versionNames
-- end

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

  -- im.NextColumn()
  -- im.Columns(1)


  local avail = im.GetContentRegionAvail()
  im.BeginChild1("versions", im.ImVec2(225 * im.uiscale[0], 0), im.WindowFlags_ChildWindow)

  -- for idx, versionName in ipairs(self:getAllVersions()) do
  for i, version in ipairs(self.pacenotes.versions) do
    local versionName = version.name
    local installed = (version.installed) and " (installed)" or ""
    if im.Selectable1(versionName .. installed, i == self.index) then
      -- self:setCurrentVersion(versionName)
      self.index = i
      print(self.index)
      -- self.selectedVersion = versionName
    end
  end

  im.Separator()

  if im.Selectable1('Create', false) then
    print("create")
  end
  im.EndChild()

  im.SameLine()
  im.BeginChild1("currentSegment", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
    if self.index then
      local versionData = self.pacenotes.versions[self.index]
      im.Text("Pacenotes version name: " .. versionData.name)

      im.BeginChild1("currentVersionInner", im.ImVec2(0, 0), im.WindowFlags_ChildWindow)
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
