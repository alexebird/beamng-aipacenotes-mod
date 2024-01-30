local im  = ui_imgui
local logTag = 'aipacenotes'
local normalizer = require('/lua/ge/extensions/editor/rallyEditor/normalizer')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
C.windowDescription = 'Transcripts'

local fileRenameText = im.ArrayChar(1024, "")

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  self.default_transcript_fname = re_util.desktopTranscriptFname
  -- self.transcripts_path = nil
  -- self.notebook_create_dir = nil

  -- self.render_transcripts = true

  self.corner_angles_data = nil

  self.selected_fname = nil
  self.transcript_files = {}
  self.loaded_transcript = nil
end

function C:getCornerAngles(reload)
  if reload then
    self.corner_angles_data = nil
  end

  if self.corner_angles_data then return self.corner_angles_data end

  local json, err = re_util.loadCornerAnglesFile()
  if json then
    self.corner_angles_data = json
    return self.corner_angles_data
  else
    return nil
  end
end

function C:setPath(path)
  self.path = path
  -- self:reloadTranscriptFile()
end

function C:convertTranscriptToNotebook(importIdent, start_i)
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

  for _,transcript in ipairs(self.loaded_transcript.transcripts.sorted) do
    local note = transcript.text or ""
    note = normalizer.replaceDigits(note)

    if transcript.show and transcript.vehicle_data and transcript.vehicle_data.vehicle_data then
      local pos = transcript.vehicle_data.vehicle_data.pos or {}
      -- local rot = transcript.vehicle_pos.rot or {}
      local radius = self.rallyEditor.getPrefDefaultRadius()

      local pacenoteNewId = self.path:getNextUniqueIdentifier()
      local name = "Pacenote "..pacenoteNewId
      if importIdent then
        name = "Import_"..importIdent.." " .. pacenoteNewId
      end

      local metadata = {}
      if transcript.beamng_file then
        metadata['success'] = transcript.success
        metadata['beamng_file'] = transcript.beamng_file
      end

      local posCe = pos
      local posCs = posCe + (vec3(1,0,0) * (radius * 2))

      local lastPacenote = notebook.pacenotes[#notebook.pacenotes]
      if lastPacenote then
        local lastPnCe = lastPacenote.pacenoteWaypoints[2]
        local lastCePos = vec3(lastPnCe.pos)
        local directionVec = lastCePos - posCe
        directionVec = vec3(directionVec):normalized()
        posCs = posCe + (directionVec * (radius * 2))
      end

      local pn = {
        name = name,
        notes = { english = {note = note}},
        metadata = metadata,
        oldId = pacenoteNewId,
        pacenoteWaypoints = {
          {
            name = "corner start",
            normal = {0.0, 1.0, 0.0},
            oldId = self.path:getNextUniqueIdentifier(),
            pos = posCs,
            radius = radius,
            waypointType = "cornerStart"
          },
          {
            name = "corner end",
            normal = {0.0, 1.0, 0.0},
            oldId = self.path:getNextUniqueIdentifier(),
            pos = posCe,
            radius = radius,
            waypointType = "cornerEnd"
          }
        }
      }

      table.insert(notebook.pacenotes, pn)
      -- i = i + 1
      -- oldId = oldId + 2
    end
  end

  return notebook, fname_out
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end
  self:refreshTranscriptFiles()
  -- self:reloadTranscriptFile()

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- function C:reloadTranscriptFile()
--   if not self.path then return end
--
--   self.notebook_create_dir = self.path._dir
--   self.transcripts_path = require('/lua/ge/extensions/gameplay/aipacenotes/transcripts/path')(self.default_transcript_fname)
--
--   if not self.transcripts_path:load() then
--     log('E', logTag, 'couldnt load transcripts file from '..self.default_transcript_fname)
--     self.transcripts_path = nil
--   end
-- end

function C:importTranscriptToNewNotebook()
  -- self:reloadTranscriptFile()
  local notebook_data, fname_out = self:convertTranscriptToNotebook(nil)
  local notebook_create_dir = self.path:dir()
  fname_out = notebook_create_dir..fname_out
  jsonWriteFile(fname_out, notebook_data, true)
  self.rallyEditor.loadNotebook(fname_out)
  self.rallyEditor.showPacenotesTab()
end

function C:importTranscriptToCurrentNotebook()
  -- self:reloadTranscriptFile()
  local importIdent = self.path:nextImportIdent()
  local last_note = self.path.pacenotes.sorted[#self.path.pacenotes.sorted]
  local last_id = self.path.pacenotes.sorted[#self.path.pacenotes.sorted]
  local notebook_data, _ = self:convertTranscriptToNotebook(importIdent)

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

function C:copyDesktopTranscriptsToMission()
  local fromFname = self.default_transcript_fname
  local ts = os.time()
  local basename = 'imported_'..ts
  local toFname = re_util.missionTranscriptPath(self.rallyEditor.getMissionDir(), basename, true)

  log('D', logTag, 'copy from '..fromFname..' to '..toFname)

  FS:copyFile(fromFname, toFname)
  self:selectTranscriptFile(toFname)
  self:refreshTranscriptFiles()
end

function C:refreshTranscriptFiles()
  -- self.selected_fname = nil

  local tscPath = re_util.missionTranscriptsDir(self.rallyEditor.getMissionDir())
  log('D', logTag, 'refreshing transcript files: '..tscPath)
  local files = FS:findFiles(tscPath, '*.'..re_util.transcriptsExt, -1, true, false)
  table.sort(files)
  self.transcript_files = files
end

function C:loadTranscript(fname)
  self.loaded_transcript = require('/lua/ge/extensions/gameplay/aipacenotes/transcripts/path')(fname)

  if not self.loaded_transcript:load() then
    log('E', logTag, 'couldnt load transcripts file from '..fname)
    self.loaded_transcript = nil
  end
end

function C:selectTranscriptFile(fname)
  self.selected_fname = fname
  self:loadTranscript(fname)
end

function C:clearSelection()
  self.selected_fname = nil
  self.loaded_transcript = nil
end

function C:renameSelectedFile(newName)
  newName = re_util.trimString(newName)

  if self.selected_fname and newName and newName ~= '' then
    local dir, filename, ext = path.splitWithoutExt(self.selected_fname, true)
    local newAbsName = dir..newName..'.'..re_util.transcriptsExt

    if FS:fileExists(newAbsName) then
      return false
    else
      log('D', logTag, 'renaming '..self.selected_fname..' to '..newAbsName)
      FS:renameFile(self.selected_fname, newAbsName)
      self.selected_fname = newAbsName
      self:refreshTranscriptFiles()
      return true
    end
  end

  return false
end

function C:setShowForAll(val)
  if not self.loaded_transcript then return end
  for _,transcript in ipairs(self.loaded_transcript.transcripts.sorted) do
    transcript:setShow(val)
  end
  self.loaded_transcript:save()
end

local newName = ''
function C:drawTranscriptFileForm()
  im.HeaderText("Transcript")
  if not self.selected_fname then return end

  im.Text(""..tostring(self.selected_fname))
  for i = 1,5 do im.Spacing() end

  if im.Button("Delete") then
    im.OpenPopup("Delete File")
  end
  if im.BeginPopupModal("Delete File", nil, im.WindowFlags_AlwaysAutoResize) then
    im.Text("Do you really want to delete this transcript file?\n"..
            "Warning: This operation is not undoable.\n\n\n")
    im.Separator()
    if im.Button("Yes", im.ImVec2(120,0)) then
      im.CloseCurrentPopup()
      FS:removeFile(self.selected_fname)
      self.loaded_transcript = nil
      self.selected_fname = nil
      self:refreshTranscriptFiles()
    end
    im.SameLine()
    if im.Button("No", im.ImVec2(120,0)) then
      im.CloseCurrentPopup()
    end
    im.EndPopup()
  end

  im.SameLine()
  if im.Button("Rename") then
    im.OpenPopup("Rename File")
  end
  if im.BeginPopupModal("Rename File", nil, im.WindowFlags_AlwaysAutoResize) then
    local dir, filename, ext = path.splitWithoutExt(self.selected_fname, true)
    im.Text("Current Name: "..filename)
    -- im.InputText("Key:##translationKey", translationData.translationKeyPtr, translationData.translationKeyLength)

    local editEnded = im.BoolPtr(false)
    editor.uiInputText("Name", fileRenameText, nil, nil, nil, nil, editEnded)
    -- if editEnded[0] then
      -- newName = ffi.string(fileRenameText)
    -- end

    im.Separator()
    if im.Button("Ok", im.ImVec2(120,0)) then
      -- im.CloseCurrentPopup()
      -- FS:removeFile(self.selected_fname)
      -- self.loaded_transcript = nil
      -- self.selected_fname = nil
      if self:renameSelectedFile(ffi.string(fileRenameText)) then
        fileRenameText = im.ArrayChar(1024, "")
        im.CloseCurrentPopup()
      end
    end
    im.SameLine()
    if im.Button("Cancel", im.ImVec2(120,0)) then
      log('D', logTag, 'close')
      im.CloseCurrentPopup()
    end
    im.EndPopup()
  end

  im.SameLine()
  if im.Button("Set as Curr") then
    local settings = self.rallyEditor.loadMissionSettings(self.rallyEditor.getMissionDir())
    settings:setCurrTranscript(self.selected_fname)
  end
  im.SameLine()
  if im.Button("Set as Full Course") then
    local settings = self.rallyEditor.loadMissionSettings(self.rallyEditor.getMissionDir())
    settings:setFullCourseTranscript(self.selected_fname)
  end


  -- im.SameLine()
  if im.Button("Import to New Notebook") then
    self:importTranscriptToNewNotebook()
  end
  im.SameLine()
  im.Text("A new notebook will be created.")
  -- for i = 1,5 do im.Spacing() end
  -- im.Separator()
  -- for i = 1,5 do im.Spacing() end

  if im.Button("Import to Current Notebook") then
    self:importTranscriptToCurrentNotebook()
  end
  im.SameLine()
  im.Text("The imported notes will be added to the end of the current notebook.")

  for i = 1,5 do im.Spacing() end

  if im.Button("Select All") then
    self:setShowForAll(true)
  end
  im.SameLine()
  if im.Button("Select None") then
    self:setShowForAll(false)
  end

  im.Columns(4, "transcript_columns")
  im.Separator()

  im.Text("Use?")
  im.SetColumnWidth(0, 40*im.uiscale[0])
  im.NextColumn()

  im.Text("Success")
  im.SetColumnWidth(1, 57*im.uiscale[0])
  im.NextColumn()

  im.Text("Text")
  im.SetColumnWidth(2, 400*im.uiscale[0])
  im.NextColumn()

  im.Text("Vehicle Data")
  im.SetColumnWidth(3, 400*im.uiscale[0])
  im.NextColumn()

  im.Separator()

  if self.loaded_transcript then
    for _,transcript in ipairs(self.loaded_transcript.transcripts.sorted) do
      local pos = transcript:vehiclePos()

      if pos then
        if im.Checkbox("##show_tsc_"..transcript.id, im.BoolPtr(transcript.show)) then
          transcript:toggleShow()
          self.loaded_transcript:save()
        end
      else
        im.Text('n/a')
      end
      im.NextColumn()

      im.Text(tostring(transcript.success))
      im.NextColumn()

      im.Text(transcript.text)
      im.NextColumn()

      local notes_txt = 'No position data.'
      if pos then
        notes_txt = "x="..round(pos.x).." y="..round(pos.y).." z="..round(pos.z)
      end

      im.Text(notes_txt)
      im.NextColumn()
    end
  end
end

function C:drawSectionV2()
  im.HeaderText("Desktop App")

  local fname = self.default_transcript_fname
  im.Text("Desktop app transcript file:")
  if FS:fileExists(fname) then
    im.Text(fname.." (exists)")
    if im.Button("Copy to Mission") then
      self:copyDesktopTranscriptsToMission()
    end
  else
    im.Text(fname.." (not found)")
  end

  im.HeaderText("Mission Transcripts")

  im.BeginChild1("transcript files", im.ImVec2(150*im.uiscale[0],0), im.WindowFlags_ChildWindow)
  for i,absFname in ipairs(self.transcript_files) do
    local dir, filename, ext = path.splitWithoutExt(absFname, true)
    fname = filename
    -- log('D', logTag, tfname)
    if im.Selectable1(fname..'##'..absFname, absFname == self.selected_fname) then
      self:selectTranscriptFile(absFname)
    end
  end
  -- im.Separator()
  -- if im.Selectable1('New...', self.codriver_index == nil) then
  --   local codriver = self.path.codrivers:create(nil, nil)
  --   self:selectCodriver(codriver.id)
  -- end
  im.EndChild() -- transcript files list child window
  --
  im.SameLine()
  im.BeginChild1("selectedTranscriptFile", im.ImVec2(0,0), im.WindowFlags_ChildWindow)
  self:drawTranscriptFileForm()
  im.EndChild() -- selected transcript form child window
end

function C:draw(mouseInfo)
  if not self.path then return end

  self:drawSectionV2()

  -- self:drawSectionImportTranscript()
  -- self:drawSectionTranscriptData()
end

function C:drawDebugEntrypoint()
  if not self.loaded_transcript then return end

  self.loaded_transcript:drawDebug()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
