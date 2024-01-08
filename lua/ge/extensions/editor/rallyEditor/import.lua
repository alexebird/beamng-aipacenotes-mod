-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'
local normalizer = require('/lua/ge/extensions/editor/rallyEditor/normalizer')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
C.windowDescription = 'Voice Import'

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor

  self.default_transcript = "/settings/aipacenotes/transcript.json"
  self.transcript = nil
  self.default_notebooks_dir = "/gameplay/aipacenotes"
end

function C:setPath(path)
  self.path = path
end

function C:convertTranscriptToNotebook(transcript_data, importIdent)
  local ts = os.time()
  local fname_out = 'transcript_'..ts..'.notebook.json'
  local notebook = {
    authors = "aipacenotes",
    description = "created using aipacenotes voice transcription.",
    name = "Transcript "..ts,
    version = "2",
    oldId = 1,
    created_at = ts,
    updated_at = ts,
    codrivers = {
      {
        voice = re_util.default_codriver_voice,
        language = re_util.default_codriver_language,
        name = re_util.default_codriver_name,
        oldId = 2,
      }
    },
    pacenotes = {},
  }

  local i = 1
  local oldId = 2

  for _,transcript in ipairs(transcript_data['transcript']) do
    local note = transcript.transcript or ""
    note = normalizer.replaceDigits(note)

    if transcript.vehicle_pos then
      local pos = transcript.vehicle_pos.pos or {}
      -- local rot = transcript.vehicle_pos.rot or {}
      local radius = self.rallyEditor.getPrefDefaultRadius()

      local name = "Pacenote "..i
      if importIdent then
        name = "Import_"..importIdent.." " .. i
      end

      local metadata = {}
      if transcript.beamng_file then
        metadata['success'] = transcript.success
        metadata['beamng_file'] = transcript.beamng_file
      end

      local pn = {
        name = name,
        notes = { english = {note = note}},
        metadata = metadata,
        oldId = oldId,
        -- segment = -1,  -- Replace with actual value if available
        pacenoteWaypoints = {
        --   {
        --     name = "curr",
        --     normal = {rot[1].x or 0, rot[1].y or 0, rot[1].z or 0},
        --     oldId = oldId + 1,
        --     pos = {pos.x or 0, pos.y or 0, pos.z or 0},
        --     radius = 8,  -- Replace with actual value if available
        --     waypointType = "fwdAudioTrigger"
        --   },
          {
            name = "corner start",
            normal = {0.0, 1.0, 0.0},
            oldId = oldId + 1,
            pos = {(pos.x or 0) + radius, pos.y or 0, pos.z or 0},
            radius = radius,
            waypointType = "cornerStart"
          },
          {
            name = "corner end",
            -- normal = {rot[1].x or 0, rot[1].y or 0, rot[1].z or 0},
            normal = {0.0, 1.0, 0.0},
            oldId = oldId + 1,
            pos = {pos.x or 0, pos.y or 0, pos.z or 0},
            radius = radius,
            waypointType = "cornerEnd"
          }
        }
      }

      table.insert(notebook.pacenotes, pn)
      i = i + 1
      oldId = oldId + 2
    end
  end

  return notebook, fname_out
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end
  self:reloadTranscriptFile()

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:reloadTranscriptFile()
  self.default_notebooks_dir = self.path._dir

  local json = jsonReadFile(self.default_transcript)
  if not json then
    log('E', logTag, 'unable to find transcript file: ' .. tostring(self.default_transcript))
  else
    self.transcript = json
  end
end

function C:importTranscriptToNewNotebook()
  self:reloadTranscriptFile()
  local notebook_data, fname_out = self:convertTranscriptToNotebook(self.transcript, nil)
  fname_out = self.default_notebooks_dir..fname_out
  jsonWriteFile(fname_out, notebook_data, true)
  self.rallyEditor.loadNotebook(fname_out)
  self.rallyEditor.showPacenotesTab()
end

function C:importTranscriptToCurrentNotebook()
  self:reloadTranscriptFile()
  local importIdent = self.path:nextImportIdent()
  local notebook_data, _ = self:convertTranscriptToNotebook(self.transcript, importIdent)

  editor.history:commitAction("Import transcript to current notebook",
    {
      self = self,
      old_pacenotes = self.path.pacenotes:onSerialize(),
      transcript_notebook = notebook_data,
    },
    function(data) -- undo
      data.self.path.pacenotes:onDeserialized(data.old_pacenotes, {})
    end,
    function(data) -- redo
      -- log("D", 'wtf', dumps(#data.self.path.pacenotes.objects))
      local curr_notes = data.self.path.pacenotes:onSerialize()

      for _,pn in ipairs(data.transcript_notebook.pacenotes) do
        table.insert(curr_notes, pn)
      end

      data.self.path.pacenotes:onDeserialized(curr_notes, {})
      -- log("D", 'wtf', dumps(#data.self.path.pacenotes.objects))
    end
  )
end

function C:draw(mouseInfo)
  if not self.path then return end

  im.HeaderText("Import from Voice Transcript")

  im.Text("Importing from: " .. self.default_transcript)
  im.Text("Importing to: " .. self.default_notebooks_dir)
  for i = 1,5 do im.Spacing() end
  im.Separator()
  for i = 1,5 do im.Spacing() end

  if im.Button("Import to New Notebook") then
    self:importTranscriptToNewNotebook()
  end
  im.Text("A new notebook will be created.")
  for i = 1,5 do im.Spacing() end
  im.Separator()
  for i = 1,5 do im.Spacing() end

  if im.Button("Import to Current Notebook") then
    self:importTranscriptToCurrentNotebook()
  end
  im.Text("The imported notes will be added to the end of the currently loaded notebook.")
  for i = 1,5 do im.Spacing() end
  im.Separator()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
