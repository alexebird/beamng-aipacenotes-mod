-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local C = {}
-- local imVec24x24 = im.ImVec2(24,24)
-- local imVec16x16 = im.ImVec2(16,16)
-- local imVec4Red = im.ImVec4(1,0,0,1)
-- local imVec4Green = im.ImVec4(0,1,0,1)

function C:init(aiPacenotes)
  self.aiPacenotes = aiPacenotes
--   self.pacenotes = nil

--   self.recommendedAttributes = gameplay_missions_missions.getRecommendedAttributesList()
--   self.recBooleans = {}
--   for _, rec in ipairs(self.recommendedAttributes) do
    -- self.recBooleans[rec] = im.BoolPtr(false)
--   end
end

-- here, self.pacenotes is the same as currentPath in the parent window.
function C:setPacenotes(pacenotes)
  self.pacenotes = pacenotes
  self.currentVersionText = im.ArrayChar(1024, self.pacenotes.current_version)

--   self.descText = im.ArrayChar(2048, self.mission.description)
--   self._titleTranslated = nil
--   self._descTranslated = nil
--   self._groupLabelTranslated = nil
--   for _, rec in ipairs(self.recommendedAttributes) do
    -- self.recBooleans[rec][0] = (self.mission.recommendedAttributesKeyBasedCache and self.mission.recommendedAttributesKeyBasedCache[rec]) or false
--   end
end

function C:draw()
  im.Columns(2)
  im.SetColumnWidth(0,150)

  im.Text("Current version")
  im.NextColumn()
  local editEnded = im.BoolPtr(false)
  im.PushItemWidth(im.GetContentRegionAvailWidth() - 35)
  editor.uiInputText("##currentVersion", self.currentVersionText, 1024, nil, nil, nil, editEnded)
  im.PopItemWidth()
  if editEnded[0] then
    self.pacenotes.current_version = ffi.string(self.currentVersionText)
    self.pacenotes._dirty = true
  end
  im.SameLine()

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

  im.NextColumn()
  im.Columns(1)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
