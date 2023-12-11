-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'

local C = {}
C.windowDescription = 'Voice Import'

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor

  self.default_transcript = "/settings/aipacenotes/transcripts.json"
  self.transcript = nil
  self.default_notebooks_dir = "/gameplay/aipacenotes"
end

function C:setPath(path)
  self.path = path
end

function C:convertTranscriptToNotebook(transcripts_data)
  local ts = os.time()
  local fname_out = 'transcript_'..ts..'.notebook.json'
  local notebook = {
    authors = "aipacenotes",
    description = "created using aipacenotes voice transcription.",
    name = "Transcript "..ts,
    oldId = 1,
    created_at = ts,
    updated_at = ts,
    codrivers = {
      {
        voice = "british_lady",
        language = "english",
        name = "Sophia",
        oldId = 2,
      }
    },
    pacenotes = {},
  }
  local i = 1
  local oldId = 2

  for i,transcript in ipairs(transcripts_data['transcripts']) do
    local note = transcript.transcript or ""

    -- add the question mark to make voice inflection go up.
    -- if note ~= "" then
      -- note = note..'?'
    -- end

    if transcript.vehicle_pos then

      local pos = transcript.vehicle_pos.pos or {}
      -- local rot = transcript.vehicle_pos.rot or {}
      local radius = self.rallyEditor.getPrefDefaultRadius()

      local pn = {
        name = "Pacenote " .. i,
        notes = { english = note },
        oldId = oldId,
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
        },
        segment = -1  -- Replace with actual value if available
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
  self.default_notebooks_dir = self.path._dir

  local json = readJsonFile(self.default_transcript)
  if not json then
    log('E', logTag, 'unable to find transcript file: ' .. tostring(self.default_transcript))
  else
    self.transcript = json
  end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:importTranscripts()
  local notebook_data, fname_out = self:convertTranscriptToNotebook(self.transcript)
  fname_out = self.default_notebooks_dir..'/'..fname_out
  jsonWriteFile(fname_out, notebook_data, true)
end

function C:draw(mouseInfo)
  if not self.path then return end

  im.HeaderText("Import from Voice Transcript")

  im.Text("Importing from: " .. self.default_transcript)
  im.Text("Importing to: " .. self.default_notebooks_dir)
  if im.Button("Import") then
    self:importTranscripts()
  end
  im.Text("Note: When you Import, a new notebook is created.")
  -- im.Separator()
  -- im.Text(dumps(self.transcript))
  -- im.Separator()

end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
