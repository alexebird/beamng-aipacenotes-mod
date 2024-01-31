local im  = ui_imgui
local logTag = 'aipacenotes'
local normalizer = require('/lua/ge/extensions/editor/rallyEditor/normalizer')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
C.windowDescription = 'Static Pacenotes'

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor

  -- self.columnsBasic = {}
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

  -- local names = {}
  -- local notes = {}
  -- local fnames = {}
  -- self.codriver = self.path:getCodriverByName(self.settings.notebook.codriver)
  -- for i,spn in ipairs(self.path.static_pacenotes.sorted) do
  --   table.insert(names, spn.name)
  --   table.insert(notes, spn:joinedNote(self.path._default_note_lang))
  --   if self.codriver then
  --     table.insert(fnames, spn:audioFname(self.codriver))
  --   else
  --     table.insert(fnames, '')
  --   end
  -- end

  -- self.columnsBasic.names = im.ArrayCharPtrByTbl(names)
  -- self.columnsBasic.notes = im.ArrayCharPtrByTbl(notes)
  -- self.columnsBasic.paths = im.ArrayCharPtrByTbl(fnames)

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

  im.Columns(4, "spn_columns")
  im.Separator()

  im.Text("Name")
  im.SetColumnWidth(0, 130*im.uiscale[0])
  im.NextColumn()

  im.Text("Language")
  im.SetColumnWidth(1, 100*im.uiscale[0])
  im.NextColumn()

  im.Text("Note Text")
  im.SetColumnWidth(2, 400*im.uiscale[0])
  im.NextColumn()

  im.Text("Files")
  im.SetColumnWidth(3, 400*im.uiscale[0])
  im.NextColumn()

  im.Separator()

  -- local lang = self.path._default_note_lang
  -- local langs = self.path:getLanguages()
  --
  local lang_set = {}
  for i,langData in ipairs(self.path:getLanguages()) do
    lang_set[langData.language] = langData.codrivers
  end

  for _,spn in ipairs(self.path.static_pacenotes.sorted) do
    for lang,langData in pairs(spn.notes) do
      im.Text(spn.name)
      im.NextColumn()

      im.Text(lang)
      im.NextColumn()

      -- im.Text(spn:joinedNote(lang))
      im.Text(langData.note)
      im.NextColumn()

      local codrivers = lang_set[lang]

      for _,codriver in ipairs(codrivers or {}) do
        local fname = ''
        local tooltipStr = ''
        local voicePlayClr = nil
        local file_exists = false

        fname = spn:audioFname(codriver)
        if re_util.fileExists(fname) then
          file_exists = true
          tooltipStr = "Codriver: "..codriver.name.."\nPlay pacenote audio file:\n"..fname
        else
          voicePlayClr = im.ImVec4(0.5, 0.5, 0.5, 1.0)
          tooltipStr = "Codriver: "..codriver.name.."\nPacenote audio file not found:\n"..fname
        end

        im.Text('[')
        im.SameLine()
        if editor.uiIconImageButton(editor.icons.play_circle_filled, im.ImVec2(20, 20), voicePlayClr) then
          if file_exists then
            local audioObj = re_util.buildAudioObjPacenote(fname)
            re_util.playPacenote(audioObj)
          end
        end
        im.tooltip(tooltipStr)
        im.SameLine()
        im.Text(codriver.name)
        im.SameLine()
        im.Text(']')
        im.SameLine()
      end

      -- im.Text(fname)
      im.NextColumn()
      -- im.tooltip(fname)
    end
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
