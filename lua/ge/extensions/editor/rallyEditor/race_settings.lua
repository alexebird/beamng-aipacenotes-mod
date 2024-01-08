-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
C.windowDescription = 'Mission Settings'

local filenamesNamesSorted = {}

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  self.settings = nil
end

function C:setPath(path)
  self.path = path
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end

  self.settings = self.rallyEditor.loadMissionSettings(self.rallyEditor.getMissionDir())
  filenamesNamesSorted = self.rallyEditor.listNotebooks()

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:draw(_mouseInfo)
  if not self.path then return end

  im.HeaderText("Race Settings")

  self:notebookFilenameSelector()
  self:codriverSelector()
end

function C:loadCodrivers()
  local folder = self.rallyEditor.getMissionDir()
  local full_filename = folder..re_util.notebooksPath..self.settings.notebook.filename
  print(full_filename)
  local json = jsonReadFile(full_filename)
  if not json then
    log('E', logTag, 'couldnt find notebook file')
  end
  local notebook = require('/lua/ge/extensions/gameplay/notebook/path')("New Notebook")
  notebook:onDeserialized(json)

  local codrivers = {}
  for _,codriver in ipairs(notebook.codrivers.sorted) do
    print(codriver.name)
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

  for _,thepath in ipairs(filenamesNamesSorted) do
    local _, fname, _ = path.split(thepath)
    table.insert(basenames, fname)
  end

  if im.BeginCombo(name..'##filename', self.settings.notebook.filename or '') then

    for _, fname in ipairs(basenames) do
      local current = self.settings.notebook.filename == fname
      if im.Selectable1(((current and '[current] ') or '')..fname, current) then
        self.settings.notebook.filename = fname
        self.codrivers = self:loadCodrivers()
        self.settings.notebook.codriver = self.codrivers[1] or '<none>'
        self.settings:write()
      end
    end

    im.EndCombo()
  end

  im.tooltip(tt)
end

function C:codriverSelector()
  local name = 'Codriver'
  local tt = 'Set the codriver.'

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

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
