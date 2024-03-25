local im  = ui_imgui
local logTag = 'aipacenotes'
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local RecceSettings = require('/lua/ge/extensions/gameplay/aipacenotes/recceSettings')

local C = {}
C.windowDescription = 'Settings'

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  self.settings = nil
  self.notebookFilenamesSorted = {}
  self.recce_settings = nil
end

function C:setPath(path)
  -- self.path = path
end

function C:load()
  local err
  self.settings, err = re_util.getMissionSettingsHelper(self.rallyEditor.getMissionDir())
  print(err)
  self.notebookFilenamesSorted = self.rallyEditor.listNotebooks()

  self.recce_settings = RecceSettings()
  self.recce_settings:load()
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  -- if not self.path then return end
  self:load()
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  -- if not self.path then return end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:draw()
  -- if not self.path then return end

  im.HeaderText("Mission Settings")

  im.Text("When you run the mission, the below notebook and codriver will be used.")
  self:notebookFilenameSelector()
  self:codriverSelector()

  for i = 1,5 do im.Spacing() end
  im.Separator()
  for i = 1,5 do im.Spacing() end

  im.HeaderText("Recce Settings")
  im.Text('Recce settings apply to all missions, as well as the Recce UI app.')
  self:recceSettingsSection()
end

function C:loadCodrivers()
  local folder = self.rallyEditor.getMissionDir()
  local full_filename = folder..'/'..re_util.notebooksPath..'/'..self.settings.notebook.filename
  local json = jsonReadFile(full_filename)
  if not json then
    log('E', logTag, 'couldnt find notebook file')
  end
  local notebook = require('/lua/ge/extensions/gameplay/notebook/path')()
  notebook:onDeserialized(json)

  local codrivers = {}
  for _,codriver in ipairs(notebook.codrivers.sorted) do
    table.insert(codrivers, codriver.name)
  end
  table.sort(codrivers)
  self.settings.notebook.codriver = codrivers[1] or '-'
  return codrivers
end

function C:notebookFilenameSelector()
  local name = 'Notebook'
  local tt = 'Set the notebook filename for this mission.'

  local basenames = {}

  for _,thepath in ipairs(self.notebookFilenamesSorted) do
    local _, fname, _ = path.split(thepath)
    table.insert(basenames, fname)
  end

  im.SetNextItemWidth(400)
  if im.BeginCombo(name..'##filename', self.settings.notebook.filename or '') then

    for _, fname in ipairs(basenames) do
      local current = self.settings.notebook.filename == fname
      if current then
        self.codrivers = self:loadCodrivers()
      end
      if im.Selectable1(((current and '[current] ') or '')..fname, current) then
        self.settings.notebook.filename = fname
        self.codrivers = self:loadCodrivers()
        self.settings.notebook.codriver = self.codrivers[1] or '<none>'
        self.settings:write()

        local notebookFname = editor_rallyEditor.detectNotebookToLoad()
        log('I', logTag, 'opening RallyEditor with notebookFname='..notebookFname)
        editor_rallyEditor.loadNotebook(notebookFname)
      end
    end

    im.EndCombo()
  end

  im.tooltip(tt)
end

function C:codriverSelector()
  local name = 'Codriver'
  local tt = 'Set the codriver.'

  im.SetNextItemWidth(400)
  if im.BeginCombo(name..'##codriver', self.settings.notebook.codriver or '') then

    for _, codriver in ipairs(self.codrivers or {}) do
      local current = self.settings.notebook.codriver == codriver
      if im.Selectable1(((current and '[current] ') or '')..codriver, current) then
        self.settings.notebook.codriver = codriver
        self.settings:write()
      end
    end

    im.EndCombo()
  end

  im.tooltip(tt)
end

function C:recceSettingsSection()
  local name = 'Corner Call Style'
  local tt = 'Set the style of corner calls.'

  im.SetNextItemWidth(400)
  if im.BeginCombo(name..'##corner_call_style_name', self.recce_settings:getCornerCallStyleName() or '') then

    for _, style_name in ipairs(self.recce_settings:cornerCallStyleNames()) do
      local current = self.recce_settings:getCornerCallStyleName() == style_name
      if im.Selectable1(((current and '[current] ') or '')..style_name, current) then
        self.recce_settings:setCornerCallStyleName(style_name)
      end
    end

    im.EndCombo()
  end

  im.tooltip(tt)
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
