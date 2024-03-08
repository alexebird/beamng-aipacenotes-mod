local im  = ui_imgui
local logTag = 'aipacenotes'
-- local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')

-- notebook form fields
local notebookNameText = im.ArrayChar(1024, "")
local notebookAuthorsText = im.ArrayChar(1024, "")
local notebookDescText = im.ArrayChar(2048, "")

-- codriver form fields
local codriverNameText = im.ArrayChar(1024, "")
local codriverLanguageText = im.ArrayChar(1024, "")
-- local codriverVoiceText = im.ArrayChar(1024, "")

-- local voiceFname = "/settings/aipacenotes/default.voices.json"
-- local voices = {}
local voiceNamesSorted = {}

local C = {}
C.windowDescription = 'Notebook'

local function selectCodriverUndo(data)
  data.self:selectCodriver(data.old)
end
local function selectCodriverRedo(data)
  data.self:selectCodriver(data.new)
end
function C:selectCodriver(id)
  self.codriver_index = id
  local codriver = self:selectedCodriver()

  if codriver then
    codriverNameText = im.ArrayChar(1024, codriver.name)
    codriverVoiceText = im.ArrayChar(1024, codriver.voice)
    codriverLanguageText = im.ArrayChar(1024, codriver.language)
  end
end

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  self.codriver_index = nil
  -- self.mouseInfo = {}
  self.valid = true
end

function C:isValid()
  return self.valid
end

function C:validate()
  self.valid = true

  self.path:validate()
  if not self.path:is_valid() then
    self.valid = false
  end
end

function C:setPath(path)
  self.path = path
end

function C:selectedCodriver()
  if not self.path then return nil end

  if self.codriver_index then
    return self.path.codrivers.objects[self.codriver_index]
  else
    return nil
  end
end

-- called by RallyEditor when this tab is selected.
function C:selected()

  if not self.path then return end

  self:loadVoices()

  notebookNameText = im.ArrayChar(1024, self.path.name)
  notebookAuthorsText = im.ArrayChar(1024, self.path.authors)
  notebookDescText = im.ArrayChar(1024, self.path.description)

  -- editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = "Add new waypoint for current pacenote"
  -- editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Ctrl] = "Add new waypoint for new pacenote"
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end
  -- editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
  -- editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Ctrl] = nil
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- function C:onEditModeActivate()
-- end

function C:draw(mouseInfo, tabContentsHeight)
  -- self.mouseInfo = mouseInfo
  -- if self.rallyEditor.allowGizmo() then
    -- editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)
    -- self:input()
  -- end
  -- self:drawNotebookList()
  self:drawNotebook(tabContentsHeight)
end

local function setNotebookFieldUndo(data)
  data.self.path[data.field] = data.old
end
local function setNotebookFieldRedo(data)
  data.self.path[data.field] = data.new
end
local function setCodriverFieldUndo(data)
  data.self.path.codrivers.objects[data.index][data.field] = data.old
end
local function setCodriverFieldRedo(data)
  data.self.path.codrivers.objects[data.index][data.field] = data.new
end

function C:drawNotebook(tabContentsHeight)
  if not self.path then return end

  self:validate()

  if self:isValid() then
    im.HeaderText("Notebook Info")
  else
    im.HeaderText("[!] Notebook Info")
    local issues = "Issues (".. (#self.path.validation_issues) .."):\n"
    for _, issue in ipairs(self.path.validation_issues) do
      issues = issues..'- '..issue..'\n'
    end
    im.Text(issues)
    im.Separator()
  end

  im.Text("Current Notebook: #" .. self.path.id)

  for _ = 1,5 do im.Spacing() end

  local editEnded = im.BoolPtr(false)
  editor.uiInputText("Name", notebookNameText, nil, nil, nil, nil, editEnded)
  if editEnded[0] then
    editor.history:commitAction("Change Name of Notebook",
      {self = self, old = self.path.name, new = ffi.string(notebookNameText), field = 'name'},
      setNotebookFieldUndo, setNotebookFieldRedo)
  end

  editEnded = im.BoolPtr(false)
  editor.uiInputText("Authors", notebookAuthorsText, nil, nil, nil, nil, editEnded)
  if editEnded[0] then
    editor.history:commitAction("Change Authors of Notebook",
      {self = self, old = self.path.authors, new = ffi.string(notebookAuthorsText), field = 'authors'},
      setNotebookFieldUndo, setNotebookFieldRedo)
  end

  editEnded = im.BoolPtr(false)
  editor.uiInputText("Description", notebookDescText, nil, nil, nil, nil, editEnded)
  if editEnded[0] then
    editor.history:commitAction("Change Description of Notebook",
      {self = self, old = self.path.description, new = ffi.string(notebookDescText), field = 'description'},
      setNotebookFieldUndo, setNotebookFieldRedo)
  end

  -- im.BeginChild1("codrivers-wrapper", im.ImVec2(0, 0), im.WindowFlags_ChildWindow and im.ImGuiWindowFlags_NoBorder)
  self:drawCodriversList(tabContentsHeight-260)
  -- im.EndChild()
end

function C:drawCodriversList(tabContentsHeight)
  im.HeaderText("Co-Drivers")

  tabContentsHeight = 0
  im.BeginChild1("codrivers", im.ImVec2(125 * im.uiscale[0], tabContentsHeight), im.WindowFlags_ChildWindow)
  for i, codriver in ipairs(self.path.codrivers.sorted) do
    if im.Selectable1(codriver.name, codriver.id == self.codriver_index) then
      editor.history:commitAction("Select Codriver",
        {old = self.codriver_index, new = codriver.id, self = self},
        selectCodriverUndo, selectCodriverRedo)
    end
  end
  im.Separator()
  if im.Selectable1('New...', self.codriver_index == nil) then
    local codriver = self.path.codrivers:create(nil, nil)
    self:selectCodriver(codriver.id)
  end
  im.EndChild() -- codrivers list child window

  im.SameLine()
  im.BeginChild1("currentCodriver", im.ImVec2(0,tabContentsHeight), im.WindowFlags_ChildWindow)

  self:drawCodriverForm(self:selectedCodriver())

  im.EndChild() -- codriver form child window
end

function C:drawCodriverForm(codriver)
  if not codriver then return end

  if im.Button("Delete") then
    self:deleteCodriver(codriver.id)
  end

  local editEnded = im.BoolPtr(false)
  editor.uiInputText("Name", codriverNameText, nil, nil, nil, nil, editEnded)
  if editEnded[0] then
    editor.history:commitAction("Change Name of Codriver",
      {self = self, index = self.codriver_index, old = codriver.name, new = ffi.string(codriverNameText), field = 'name'},
      setCodriverFieldUndo, setCodriverFieldRedo)
  end

  editEnded = im.BoolPtr(false)
  editor.uiInputText("Language", codriverLanguageText, nil, nil, nil, nil, editEnded)
  if editEnded[0] then
    editor.history:commitAction("Change Language of Codriver",
      {self = self, index = self.codriver_index, old = codriver.language, new = ffi.string(codriverLanguageText), field = 'language'},
      setCodriverFieldUndo, setCodriverFieldRedo)
  end

  self:voicesSelector(codriver)
end

function C:voicesSelector(codriver)
  local name = 'Voice'
  local fieldName = 'voice'
  local tt = 'Set the text-to-speech voice'

  if im.BeginCombo(name..'##'..fieldName, codriver[fieldName]) then

    for i, voice in ipairs(voiceNamesSorted) do
      if im.Selectable1(voice, codriver[fieldName] == voice) then
        editor.history:commitAction("Changed "..fieldName.." for Codriver",
          {index = self.codriver_index, self = self, old = codriver[fieldName], new = voice, field = fieldName},
          setCodriverFieldUndo, setCodriverFieldRedo)
      end
    end

    im.EndCombo()
  end

  im.tooltip(tt)
end

function C:loadVoices()
  local defaultVoices = self:loadVoiceFile("/settings/aipacenotes/default.voices.json")
  local userVoices = self:loadVoiceFile("/settings/aipacenotes/user.voices.json")
  local combinedVoices = {}

  for k, v in pairs(defaultVoices) do
    combinedVoices[k] = v
  end
  for k, v in pairs(userVoices) do
    combinedVoices[k] = v
  end

  voiceNamesSorted = {}

  for voiceName, _ in pairs(combinedVoices) do
    table.insert(voiceNamesSorted, voiceName)
  end

  table.sort(voiceNamesSorted)
end

function C:loadVoiceFile(voiceFname)
  local voices = jsonReadFile(voiceFname)

  if not voices then
    log('W', logTag, 'unable to load voices file from '..voiceFname)
    return {}
  end

  log('I', logTag, 'reloaded voices from '..voiceFname)
  return voices
end

function C:deleteCodriver(codriver_id)
  self.path.codrivers:remove(codriver_id)
  self:selectCodriver(nil)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
