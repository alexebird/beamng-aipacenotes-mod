-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'
local normalizer = require('/lua/ge/extensions/editor/rallyEditor/normalizer')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
C.windowDescription = 'Static Pacenotes'

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor

  self.columnsBasic = {}
  -- self.columnsBasic.selected = im.IntPtr(-1)
end

-- this is the notebook. why am I still calling it a path???
function C:setPath(path)
  self.path = path
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end

  self.settings = self.rallyEditor.loadMissionSettings(self.rallyEditor.getMissionDir())

  local names = {}
  local notes = {}
  local fnames = {}
  self.codriver = self.path:getCodriverByName(self.settings.notebook.codriver)
  for i,spn in ipairs(self.path.static_pacenotes.sorted) do
    table.insert(names, spn.name)
    table.insert(notes, spn:joinedNote(self.path._default_note_lang))
    if codriver then
      table.insert(fnames, spn:audioFname(codriver))
    else
      table.insert(fnames, '')
    end
  end

  self.columnsBasic.names = im.ArrayCharPtrByTbl(names)
  self.columnsBasic.notes = im.ArrayCharPtrByTbl(notes)
  self.columnsBasic.paths = im.ArrayCharPtrByTbl(fnames)

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:draw(mouseInfo)
  if not self.path then return end

  im.HeaderText("Static Pacenotes")
  im.Text("These are special pacenotes for internal use that are automatically created.")
  for _ = 1,5 do im.Spacing() end

  im.Columns(3, "spn_columns")
  im.Separator()
  im.Text("Name")       im.NextColumn()
  im.Text("Note Text")  im.NextColumn()
  im.Text("File")       im.NextColumn()
  im.Separator()

  for _,spn in ipairs(self.path.static_pacenotes.sorted) do
    im.Text(spn.name)                                      im.NextColumn()
    im.Text(spn:joinedNote(self.path._default_note_lang))  im.NextColumn()

    local fname = ''
    local tooltipStr = ''
    local voicePlayClr = nil
    local file_exists = false
    if self.codriver then
      fname = spn:audioFname(self.codriver)
      if re_util.fileExists(fname) then
        file_exists = true
        tooltipStr = "Play pacenote audio file:\n\n"..fname
      else
        voicePlayClr = im.ImVec4(0.5, 0.5, 0.5, 1.0)
        tooltipStr = "Pacenote audio file not found:\n\n"..fname
      end

      if editor.uiIconImageButton(editor.icons.play_circle_filled, im.ImVec2(20, 20), voicePlayClr) then
        if file_exists then
          local audioObj = re_util.buildAudioObjPacenote(fname)
          re_util.playPacenote(audioObj)
        end
      end
      im.tooltip(tooltipStr)
      im.SameLine()
    end
    im.Text(fname)
    im.NextColumn()
    im.tooltip(fname)
  end

  im.Columns(1)
  im.Separator()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
