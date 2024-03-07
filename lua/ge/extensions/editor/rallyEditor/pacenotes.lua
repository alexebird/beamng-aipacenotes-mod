local im  = ui_imgui
local logTag = 'aipacenotes'
local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local Snaproad = require('/lua/ge/extensions/gameplay/aipacenotes/snaproad')
local Recce = require('/lua/ge/extensions/gameplay/aipacenotes/recce')

-- pacenote form fields
local pacenoteNameText = im.ArrayChar(1024, "")
local playbackRulesText = im.ArrayChar(1024, "")

-- waypoint form fields
local waypointNameText = im.ArrayChar(1024, "")
local waypointPosition = im.ArrayFloat(3)
local waypointNormal = im.ArrayFloat(3)
local waypointRadius = im.FloatPtr(0)

-- local transcriptsSearchText = im.ArrayChar(1024, "")
local pacenotesSearchText = im.ArrayChar(1024, "")

local editingNote = false
local pacenoteUnderEdit = false

local C = {}
C.windowDescription = 'Pacenotes'

local function selectPacenoteUndo(data)
  data.self:selectPacenote(data.old)
end
local function selectPacenoteRedo(data)
  data.self:selectPacenote(data.new)
end

local function selectWaypointUndo(data)
  data.self:selectWaypoint(data.old)
end
local function selectWaypointRedo(data)
  data.self:selectWaypoint(data.new)
end

local dragModes = re_util.dragModes

local language_form_fields = {}
-- language_form_fields.before = im.ArrayChar(64)
-- language_form_fields.note = im.ArrayChar(1024)
-- language_form_fields.after = im.ArrayChar(256)

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  self.mouseInfo = {}

  self._insertMode = false
  self.wasWPSelected = false

  self.notes_valid = true
  self.validation_issues = {}

  self.pacenote_tools_state = {
    -- drag_mode = dragModes.simple,
    snaproad = nil,
    search = nil,
    internal_lock = false,
    hover_wp_id = nil,
    selected_pn_id = nil,
    selected_wp_id = nil,
    recent_selected_pn_id = nil,
    playbackLastCameraPos = nil,
    last_camera = {
      pos = nil,
      quat = nil
    }
  }

  -- self.transcript_tools_state = {
  --   show = false,
  --   selected_id = nil,
  -- }
end

function C:isValid()
  return self.notes_valid and #self.validation_issues == 0
end

function C:setPath(path)
  self.path = path
end

function C:onEditModeActivate()
  self:selectPacenote(self.pacenote_tools_state.selected_pn_id)
end

function C:onEditModeDeactivate()
  self.rallyEditor.setFreeCam()
end

function C:getRacePath()
  return editor_raceEditor.getCurrentPath()
end

function C:selectionString()
  local pn = self:selectedPacenote()
  local wp = self:selectedWaypoint()
  local text = {}
  local mode = '--'
  if pn and not pn.missing then
    mode = 'P-'
    local p_txt = '"' .. pn:noteTextForDrawDebug() .. '" ('.. pn.name ..')'
    table.insert(text, p_txt)
    if wp and not wp.missing then
      mode = 'PW'
      local w_txt = wp:selectionString()
      table.insert(text, w_txt)
    end
  end
  return text, mode
end

function C:selectedPacenote()
  if not self.path then return nil end
  if self.pacenote_tools_state.selected_pn_id then
    return self.path.pacenotes.objects[self.pacenote_tools_state.selected_pn_id]
  else
    return nil
  end
end

function C:selectedWaypoint()
  if not self:selectedPacenote() then return nil end
  if self.pacenote_tools_state.selected_wp_id then
    if self:selectedPacenote().pacenoteWaypoints then
      return self:selectedPacenote().pacenoteWaypoints.objects[self.pacenote_tools_state.selected_wp_id]
    else
      return nil
    end
  else
    return nil
  end
end

-- function C:selectedTranscript()
--   if not self:getTranscripts() then return nil end
--   if self.transcript_tools_state.selected_id then
--     return self:getTranscripts().transcripts.objects[self.transcript_tools_state.selected_id]
--   else
--     return nil
--   end
-- end

function C:loadSnaproad()
  local recce = Recce(self.rallyEditor.getMissionDir())
  recce:load()
  self.pacenote_tools_state.snaproad = Snaproad(recce)

  -- self.pacenote_tools_state.drag_mode = dragModes.simple_road_snap
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end

  self:loadSnaproad()
  self:selectPacenote(self.pacenote_tools_state.selected_pn_id)

  -- self:loadFullCourse(false)

  -- self.pacenote_tools_state.selected_pn_id = nil
  -- self.pacenote_tools_state.selected_wp_id = nil

  -- editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Shift] = "Add waypoint to current pacenote"
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Ctrl] = "Create new pacenote"
  -- editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Alt] = "Free Edit with Gizmo"
  -- editor.editModes.notebookEditMode.auxShortcuts["g"] = "Cycle Drag MMode"
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Delete] = "Delete"
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end

  self.rallyEditor.setFreeCam()

  -- self:selectWaypoint(nil)
  -- self:selectPacenote(nil)

  -- editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Ctrl] = nil
  -- editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Alt] = nil
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Delete] = nil
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:selectPacenote(id)
  if not self.path then return end
  if not self.path.pacenotes then return end

  -- deselect waypoint if we are changing pacenotes.
  if self.pacenote_tools_state.selected_pn_id ~= id then
    self.pacenote_tools_state.selected_wp_id = nil
    if self.pacenote_tools_state.snaproad then
      self.pacenote_tools_state.snaproad:setFilter(nil)
    end
  end

  if not id then -- track the most recent selection
    if self.pacenote_tools_state.selected_pn_id then
      self.pacenote_tools_state.recent_selected_pn_id = self.pacenote_tools_state.selected_pn_id
    end
    self.pacenote_tools_state.playbackLastCameraPos = nil
  end

  self.pacenote_tools_state.selected_pn_id = id

  -- find the pacenotes before and after the selected one.
  -- local pacenotesSorted = self.path.pacenotes.sorted
  -- for i, note in ipairs(pacenotesSorted) do
  --   if self.pacenote_tools_state.selected_pn_id == note.id then
  --     local prevNote = pacenotesSorted[i-1]
  --     local nextNote = pacenotesSorted[i+1]
  --     note:setAdjacentNotes(prevNote, nextNote)
  --   else
  --     note:clearAdjacentNotes()
  --   end
  -- end

  self.path:setAdjacentNotes(self.pacenote_tools_state.selected_pn_id)

  -- select the pacenote
  if id then
    local note = self.path.pacenotes.objects[id]
    pacenoteNameText = im.ArrayChar(1024, note.name)
    playbackRulesText = im.ArrayChar(1024, note.playback_rules)
    self.pacenote_tools_state.snaproad:setPacenote(note)

    -- core_camera.setByName(0, "pacenote")
    -- local camMode = core_camera.getGlobalCameras().pacenote
    -- local cams = core_camera.getGlobalCameras()
    -- print(dumps(cams))
    -- camMode:setTarget(note:getCornerStartWaypoint().pos)

    core_camera.setByName(0, "pacenoteOrbit")
    core_camera.setRef(0, note:getCornerStartWaypoint().pos)
    core_camera.setDistance(0, self.rallyEditor.getPrefTopDownCameraElevation())
  else
    pacenoteNameText = im.ArrayChar(1024, "")
    playbackRulesText = im.ArrayChar(1024, "")
    self.pacenote_tools_state.snaproad:setPacenote(nil)
    self.rallyEditor.setFreeCam()
  end
end


function C:selectWaypoint(id)
  if not self.path then return end
  self.pacenote_tools_state.selected_wp_id = id

  if id then
    local waypoint = self.path:getWaypoint(id)
    if waypoint then
      self:selectPacenote(waypoint.pacenote.id)
      waypointNameText = im.ArrayChar(1024, waypoint.name)
      self:updateGizmoTransform(id)
      if self.pacenote_tools_state.snaproad then
        self.pacenote_tools_state.snaproad:setFilter(waypoint)
        -- self.pacenote_tools_state.snaproad:setPacenote(nil)
      end
    else
      log('E', logTag, 'expected to find waypoint with id='..id)
      if self.pacenote_tools_state.snaproad then
        self.pacenote_tools_state.snaproad:setFilter(nil)
        self.pacenote_tools_state.snaproad:setPacenote(self:selectedPacenote())
      end
    end
  else -- deselect waypoint
    waypointNameText = im.ArrayChar(1024, "")
    -- I think this fixes the bug where you cant click on a pacenote waypoint anymore.
    -- I think that was due to the Gizmo being present but undrawn, and the gizmo's mouseover behavior was superseding our pacenote hover.
    self:resetGizmoTransformToOrigin()

    if self.pacenote_tools_state.snaproad then
      self.pacenote_tools_state.snaproad:setFilter(nil)
      self.pacenote_tools_state.snaproad:setPacenote(self:selectedPacenote())
    end
  end
end

function C:deselect()
  -- since there are two levels of selection (waypoint+pacenote, pacenote),
  -- you must deselect twice to deselect everything.
  if self:selectedWaypoint() then
    self:selectWaypoint(nil)
  else
    self:selectPacenote(nil)
  end
end

-- function C:selectTranscript(id)
--   if not self:getTranscripts() then return end
--   self.transcript_tools_state.selected_id = id
--   -- if id then
--   -- else
--   -- end
-- end

function C:attemptToFixMapEdgeIssue()
  self:resetGizmoTransformToOrigin()
end

function C:resetGizmoTransformToOrigin()
  local rotation = QuatF(0,0,0,1)
  local transform = rotation:getMatrix()
  local pos = {0, 0, -1000} -- stick gizmo far away down the Z axis to hide it.
  transform:setPosition(pos)
  editor.setAxisGizmoTransform(transform)
  worldEditorCppApi.setAxisGizmoSelectedElement(-1)
  -- editor.drawAxisGizmo()
end

function C:updateGizmoTransform(index)
  if not self.rallyEditor.allowGizmo() then return end

  local wp = self.path:getWaypoint(index)
  if not wp then return end

  local rotation = QuatF(0,0,0,1)

  if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
    local q = quatFromDir(wp.normal, vec3(0,0,1))
    rotation = QuatF(q.x, q.y, q.z, q.w)
  else
    rotation = QuatF(0, 0, 0, 1)
  end

  local transform = rotation:getMatrix()
  transform:setPosition(wp.pos)
  editor.setAxisGizmoTransform(transform)
end

function C:beginDrag()
  if not self:selectedPacenote() then return end
  local wp = self:selectedPacenote().pacenoteWaypoints.objects[self.pacenote_tools_state.selected_wp_id]
  if not wp or wp.missing then return end

  self.beginDragNoteData = wp:onSerialize()

  if wp.normal then
    self.beginDragRotation = deepcopy(quatFromDir(wp.normal, vec3(0,0,1)))
  end

  self.beginDragRadius = wp.radius

  -- if wp.mode == 'navgraph' then
  --   self.beginDragRadius = wp.navRadiusScale
  -- end
end

function C:dragging()
  if not self:selectedPacenote() then return end
  local wp = self:selectedPacenote().pacenoteWaypoints.objects[self.pacenote_tools_state.selected_wp_id]
  if not wp or wp.missing then return end

  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
    -- log('D', 'wtf', dumps(editor.getAxisGizmoTransform():getPosition()))
    wp.pos = vec3(editor.getAxisGizmoTransform():getColumn(3))
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Rotate then
    local gizmoTransform = editor.getAxisGizmoTransform()
    local rotation = QuatF(0,0,0,1)
    if wp.normal then
      rotation:setFromMatrix(gizmoTransform)
      if editor.getAxisGizmoAlignment() == editor.AxisGizmoAlignment_Local then
        wp.normal = quat(rotation)*vec3(0,1,0)
      else
        wp.normal = self.beginDragRotation * quat(rotation)*vec3(0,1,0)
      end
    end
  elseif editor.getAxisGizmoMode() == editor.AxisGizmoMode_Scale then
    local scl = vec3(worldEditorCppApi.getAxisGizmoScale())
    if scl.x ~= 1 then
      scl = scl.x
    elseif scl.y ~= 1 then
      scl = scl.y
    elseif scl.z ~= 1 then
      scl = scl.z
    else
      scl = 1
    end
    if scl < 0 then
      scl = 0
    end
    wp.radius = self.beginDragRadius * scl
  end
end

function C:endDragging()
  if not self:selectedPacenote() then return end
  -- log('D', 'wtf', 'endDragging')
  local wp = self:selectedPacenote().pacenoteWaypoints.objects[self.pacenote_tools_state.selected_wp_id]
  if not wp or wp.missing then return end

  editor.history:commitAction("Manipulated Note Waypoint via Gizmo",
    {old = self.beginDragNoteData,
     new = wp:onSerialize(),
     index = self.pacenote_tools_state.selected_wp_id, self = self},
    function(data) -- undo
      local wp = self:selectedPacenote().pacenoteWaypoints.objects[data.index]
      wp:onDeserialized(data.old)
      data.self:selectWaypoint(data.index)
    end,
    function(data) --redo
      local wp = self:selectedPacenote().pacenoteWaypoints.objects[data.index]
      wp:onDeserialized(data.new)
      data.self:selectWaypoint(data.index)
    end
  )
end

function C:getTranscripts()
  if not self.rallyEditor then return nil end
  local loaded_transcript = self.rallyEditor.getTranscriptsWindow().loaded_transcript

  if  loaded_transcript then
    return loaded_transcript
  else
    return nil
  end
end

function C:drawDebugEntrypoint()
  if self.path then
    if not self.pacenote_tools_state.snaproad:partitionAllEnabled() then
      self.path:drawDebugNotebook(self.pacenote_tools_state)
    end
  end

  if self.pacenote_tools_state.snaproad then
    self.pacenote_tools_state.snaproad:drawDebugSnaproad()
    if self.pacenote_tools_state.snaproad:partitionAllEnabled() then
      self.path:drawDebugNotebookForPartitionedSnaproad()
    end
  end

  if self.pacenote_tools_state.playbackLastCameraPos then
    local clr = cc.clr_purple
    local radius = cc.cam_last_pos_radius
    local alpha = cc.cam_last_pos_alpha
    debugDrawer:drawSphere(self.pacenote_tools_state.playbackLastCameraPos, radius, ColorF(clr[1],clr[2],clr[3],alpha))
  end
end

function C:drawDebugCameraPlaying()
  -- if self.pacenote_tools_state.snaproad and self.pacenote_tools_state.drag_mode == dragModes.simple_road_snap then
  if self.pacenote_tools_state.snaproad then
    self.pacenote_tools_state.snaproad:drawDebugCameraPlaying()
  end
end

function C:handleMouseDown(hoveredWp)
  if hoveredWp then
    local selectedPn = hoveredWp.pacenote
    if self:selectedPacenote() and self:selectedPacenote().id == selectedPn.id then
      -- if a pacenote is already selected and the clicked waypoint is in that pacenote.
      self.simpleDragMouseOffset = self.mouseInfo._downPos - hoveredWp.pos
      self.beginSimpleDragNoteData = hoveredWp:onSerialize()
      self:selectWaypoint(hoveredWp.id)
    elseif self:selectedPacenote() and self:selectedWaypoint() and self:selectedPacenote().id ~= selectedPn.id then
      -- if the selected pacenote is different than clicked waypoint
      self.simpleDragMouseOffset = self.mouseInfo._downPos - hoveredWp.pos
      self.pacenote_tools_state.internal_lock = true
      self:selectPacenote(selectedPn.id)
      self:selectWaypoint(hoveredWp.id)
    elseif self:selectedPacenote() and self:selectedPacenote().id ~= selectedPn.id then
      -- if the selected pacenote is different than clicked waypoint
      self.simpleDragMouseOffset = self.mouseInfo._downPos - hoveredWp.pos
      self.pacenote_tools_state.internal_lock = true
      self:selectPacenote(selectedPn.id)
      self:selectWaypoint(nil)
    elseif not self:selectedPacenote() then
      -- if no pacenote is selected
      self:selectPacenote(selectedPn.id)
      self:selectWaypoint(nil)
    end
  else
    -- clear selection by clicking off waypoint.
    self:deselect()
  end
end

function C:handleMouseHold()
  local mouse_pos = self.mouseInfo._holdPos

  -- this sphere indicates the drag cursor
  -- debugDrawer:drawSphere((mouse_pos), 1, ColorF(1,1,0,1.0)) -- radius=1, color=yellow

  local wp_sel = self:selectedWaypoint()

  if wp_sel and not wp_sel:isLocked() and not self.pacenote_tools_state.internal_lock then
    if self.mouseInfo.rayCast then
      local new_pos, normal_align_pos = self:wpPosForSimpleDrag(wp_sel, mouse_pos, self.simpleDragMouseOffset)
      if new_pos then
        wp_sel.pos = new_pos
        self:autoFillDistanceCalls()
        if normal_align_pos then
          local rv = re_util.calculateForwardNormal(new_pos, normal_align_pos)
          wp_sel.normal = vec3(rv.x, rv.y, rv.z)
        -- elseif wp_sel.waypointType == waypointTypes.wpTypeCornerStart then
        --   local note = wp_sel.pacenote
        --   for _,at in ipairs(note:getAudioTriggerWaypoints()) do
        --     local rv = re_util.calculateForwardNormal(at.pos, wp_sel.pos)
        --     at.normal = vec3(rv.x, rv.y, rv.z)
        --   end
        end
      end
    end
  end
end

function C:handleMouseUp()
  self.pacenote_tools_state.internal_lock = false

  -- if self.pacenote_tools_state.drag_mode == dragModes.simple or self.pacenote_tools_state.drag_mode == dragModes.simple_road_snap then
    local wp_sel = self:selectedWaypoint()
    if wp_sel and not wp_sel.missing then
      editor.history:commitAction("Manipulated Note Waypoint via SimpleDrag",
        {
          self = self, -- the rallyEditor pacenotes tab
          pacenote_idx = self.pacenote_tools_state.selected_pn_id,
          wp_id = self.pacenote_tools_state.selected_wp_id,
          old = self.beginSimpleDragNoteData,
          new = wp_sel:onSerialize(),
          wasPWselection = self.wasWPSelected,
        },
        function(data) -- undo
          local notebook = data.self.path
          local pacenote = notebook.pacenotes.objects[data.pacenote_idx]
          local wp = pacenote.pacenoteWaypoints.objects[data.wp_id]
          wp:onDeserialized(data.old)
          -- if data.wasWPSelected then
            data.self:selectWaypoint(data.wp_id)
          -- else
            -- data.self:selectWaypoint(nil)
          -- end
        end,
        function(data) --redo
          local notebook = data.self.path
          local pacenote = notebook.pacenotes.objects[data.pacenote_idx]
          local wp = pacenote.pacenoteWaypoints.objects[data.wp_id]
          wp:onDeserialized(data.new)
          -- if data.wasWPSelected then
            data.self:selectWaypoint(data.wp_id)
          -- else
            -- data.self:selectWaypoint(nil)
          -- end
        end
      )
    end
  -- end
end

function C:setHover(wp)
  -- local tscs = self:getTranscripts()
  -- if tscs and self.transcript_tools_state.show then
  --   tscs._draw_debug_hover_tsc_id = nil
  -- end
  self.pacenote_tools_state.hover_wp_id = nil

  -- if tscs and self.transcript_tools_state.show and tsc then
    -- tscs._draw_debug_hover_tsc_id = tsc.id
  if wp then
    self.pacenote_tools_state.hover_wp_id = wp.id
  end
end

function C:handleUnmodifiedMouseInteraction(hoveredWp)
  if self.mouseInfo.down then
    self:handleMouseDown(hoveredWp)
  elseif self.mouseInfo.hold then
    self:handleMouseHold()
  elseif self.mouseInfo.up then
    self:handleMouseUp()
  else
    self:setHover(hoveredWp)
  end
end

function C:handleMouseInput()
  if not self.mouseInfo.valid then return end

  -- handle positioning and drawing of the gizmo
  -- if self.pacenote_tools_state.drag_mode == dragModes.gizmo then
  --   self:updateGizmoTransform(self.pacenote_tools_state.selected_wp_id)
  --   editor.drawAxisGizmo()
  -- else
  --   self:resetGizmoTransformToOrigin()
  -- end
  self:resetGizmoTransformToOrigin()
  editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)

  self.pacenote_tools_state.hover_wp_id = nil -- clear hover state

  -- There is a bug (in race tool as well) where if you start the game, open
  -- the world editor, and try to use the tool without having selected anything
  -- in Object Select mode (named "Manipulate Object(s)"), then the below line
  -- (which I copied from race tool) will cause the tool not to respond to
  -- mouse interactions.
  --
  -- The Line (which I have commented):
  -- if editor.isAxisGizmoHovered() then return end
  --
  -- Here's the underlying call that editor.isAxisGizmoHovered() uses from gizmo.lua:
  --
  --     -- Return true if the axis gizmo has any hovered elements (axes).
  --     local function isAxisGizmoHovered()
  --       return worldEditorCppApi.getAxisGizmoSelectedElement() ~= -1
  --     end
  --
  -- Turns out that worldEditorCppApi.getAxisGizmoSelectedElement() returns 6
  -- after a cold world editor start. Well, since I'm not using the gizmo for
  -- this tool, I'm just going to comment it and hope for the best.

  local hoveredWp = self:detectMouseHoverWaypoint()

  -- local states = self:getSelectionLayerStates()

  -- if editor.keyModifiers.shift then
    -- if states.pacenotesLayer == 'none' then
    --   local pos_rayCast = self.mouseInfo.rayCast.pos
    --   debugDrawer:drawTextAdvanced(
    --     vec3(pos_rayCast),
    --     String("Shift+Click to deselect Transcript"),
    --     ColorF(1,1,1,1),
    --     true,
    --     false,
    --     ColorI(0,0,0,255)
    --   )
    --
    --   if self.mouseInfo.down then
    --     self:selectTranscript(nil)
    --   end
    -- elseif states.pacenotesLayer == 'pacenote' then
      -- if self.mouseInfo.down then
        -- self:addMouseWaypointToPacenote()
      -- elseif self.mouseInfo.hold then
        -- self:handleMouseHold()
    -- end
  if editor.keyModifiers.ctrl then
    if not self:selectedPacenote() then
      self:createMouseDragPacenote()
    end
  elseif self.pacenote_tools_state.snaproad.recce.driveline then
    if self.pacenote_tools_state.snaproad:partitionAllEnabled() then
      self.pacenote_tools_state.snaproad:clearAll()
    end

    self:handleUnmodifiedMouseInteraction(hoveredWp)
  end
  -- end
end

-- function C:isNothingSelected()
--   local states = self:getSelectionLayerStates()
--   if states.pacenotesLayer == 'none' and states.transcriptsLayer == 'none' then
--     return true
--   else
--     return false
--   end
-- end

-- function C:getSelectionLayerStates()
--   local pacenoteLayerState = 'none'
--   if self:selectedPacenote() then
--     if self:selectedWaypoint() then
--       pacenoteLayerState = 'waypoint'
--     else
--       pacenoteLayerState = 'pacenote'
--     end
--   end
--
--   -- local transcriptsLayerState = 'none'
--   -- if self:selectedTranscript() then
--   --   transcriptsLayerState = 'transcript'
--   -- end
--
--   return {
--     pacenotesLayer = pacenoteLayerState,
--     -- transcriptsLayer = transcriptsLayerState,
--   }
-- end

function C:draw(mouseInfo, tabContentsHeight)
  self.mouseInfo = mouseInfo
  if self.rallyEditor.allowGizmo() then
    self:handleMouseInput()
  end

  -- draw the non-viewport GUI
  -- local availableHeight = tabContentsHeight - 120*im.uiscale[0]
  -- local ratio = 0.88
  -- self:drawPacenotesList(availableHeight * ratio)
  -- self:drawTranscriptsSection(availableHeight * (1.0 - ratio))

  self:drawPacenotesList(tabContentsHeight * 0.7)
  -- self:drawTranscriptsSection(tabContentsHeight * 0.15)
end

function C:debugDrawNewPacenote(pos_cs, pos_ce)
  local defaultRadius = self.rallyEditor.getPrefDefaultRadius()
  local radius = defaultRadius

  local alpha = cc.new_pacenote_cursor_alpha
  local clr_link = cc.new_pacenote_cursor_clr_link
  local clr_cs = cc.new_pacenote_cursor_clr_cs
  local clr_ce = cc.new_pacenote_cursor_clr_ce
  debugDrawer:drawSphere((pos_cs), radius, ColorF(clr_cs[1],clr_cs[2],clr_cs[3],alpha))
  debugDrawer:drawSphere((pos_ce), radius, ColorF(clr_ce[1],clr_ce[2],clr_ce[3],alpha))

  local fromHeight = radius * cc.new_pacenote_cursor_linkHeightRadiusShinkFactor
  local toHeight = radius * cc.new_pacenote_cursor_linkHeightRadiusShinkFactor
  debugDrawer:drawSquarePrism(
    pos_cs,
    pos_ce,
    Point2F(fromHeight, cc.new_pacenote_cursor_linkFromWidth),
    Point2F(toHeight, cc.new_pacenote_cursor_linkToWidth),
    ColorF(clr_link[1],clr_link[2],clr_link[3],alpha)
  )
end

function C:debugDrawNewPacenote2(pos_cs, pos_ce)
  local defaultRadius = self.rallyEditor.getPrefDefaultRadius()
  local radius = defaultRadius

  local alpha = cc.new_pacenote_cursor_alpha
  local clr_link = cc.new_pacenote_cursor_clr_link
  local clr_cs = cc.new_pacenote_cursor_clr_cs
  local clr_ce = cc.new_pacenote_cursor_clr_ce
  debugDrawer:drawSphere(pos_cs, radius, ColorF(clr_cs[1],clr_cs[2],clr_cs[3],alpha))
  debugDrawer:drawSphere(pos_ce, radius, ColorF(clr_ce[1],clr_ce[2],clr_ce[3],alpha))

  local fromHeight = radius * cc.new_pacenote_cursor_linkHeightRadiusShinkFactor
  local toHeight = radius * cc.new_pacenote_cursor_linkHeightRadiusShinkFactor
  debugDrawer:drawSquarePrism(
    pos_cs,
    pos_ce,
    Point2F(fromHeight, cc.new_pacenote_cursor_linkFromWidth),
    Point2F(toHeight, cc.new_pacenote_cursor_linkToWidth),
    ColorF(clr_link[1],clr_link[2],clr_link[3],alpha)
  )
end

function C:createMouseDragPacenote()
  if not self.path then return end
  if not self.mouseInfo.rayCast then return end
  if not self.pacenote_tools_state.snaproad then return end

  if not self.pacenote_tools_state.snaproad:partitionAllEnabled() then
    self.pacenote_tools_state.snaproad:partitionAllPacenotes(self.path)
    self.pacenote_tools_state.snaproad:setFilterToAllPartitions()
  end

  local txt = "Click to Create New Pacenote"

  local pos_rayCast = self.mouseInfo.rayCast.pos
  pos_rayCast = self.pacenote_tools_state.snaproad:closestSnapPos(pos_rayCast)

  -- local pos_ce = self.mouseInfo._holdPos
  -- if pos_ce then
  --   pos_ce = self.pacenote_tools_state.snaproad:closestSnapPos(pos_ce)
  -- end

  -- draw the cursor text
  local clr_txt = cc.clr_black
  local clr_bg = cc.clr_green
  debugDrawer:drawTextAdvanced(
    pos_rayCast,
    String(txt),
    ColorF(clr_txt[1],clr_txt[2],clr_txt[3],1),
    true,
    false,
    ColorI(clr_bg[1]*255, clr_bg[2]*255, clr_bg[3]*255, 255)
  )

  if self.mouseInfo.down then
    print('down')

    local pos_down = self.mouseInfo._downPos
    if pos_down then
      local point_cs = self.pacenote_tools_state.snaproad:closestSnapPoint(pos_down)
      local partition = point_cs.partition
      if not partition then
        log('W', logTag, 'found no snaproad partition for create')
        return
      end

      local pn = partition.pacenote_after
      local sortOrder = self.path.pacenotes.sorted[#self.path.pacenotes.sorted].sortOrder + 5 -- default to end of pacenotes list
      if pn then
        print(pn.sortOrder)
        sortOrder = pn.sortOrder - 0.5 -- go before the partition's pacenote_after
      end

      -- print(dumps(partition))

      -- local pos_cs = point_cs.pos

      self.pacenote_tools_state.snaproad:setFilterPartitionPoint(point_cs)

      if point_cs.id == partition[1].id then
        if point_cs.next then
          point_cs = point_cs.next
        end
      end

      if point_cs.id == partition[#partition].id then
        if point_cs.prev then
          point_cs = point_cs.prev
        end
      end

      local defaultDistMeters = 10
      local point_ce = self.pacenote_tools_state.snaproad:distanceForwards(point_cs, defaultDistMeters)
      local point_at = self.pacenote_tools_state.snaproad:distanceBackwards(point_cs, defaultDistMeters)

      local newPacenote = self.path.pacenotes:create(nil, nil)
      newPacenote.sortOrder = sortOrder
      newPacenote.pacenoteWaypoints:create('corner start', point_cs.pos)
      newPacenote.pacenoteWaypoints:create('corner end', point_ce.pos)
      local wp_at = newPacenote.pacenoteWaypoints:create('audio trigger', point_at.pos)

      local normalVec = self.pacenote_tools_state.snaproad:forwardNormalVec(point_at)
      if normalVec then
        wp_at:setNormal(normalVec)
      end

      self.path.pacenotes:sort()
      self.path:cleanupPacenoteNames()
      -- self.path:sortPacenotesByName()
      -- sortOrder = newPacenote.sortOrder

      self.pacenote_tools_state.snaproad:clearAll()

      self:autoFillDistanceCalls()
      self:selectPacenote(newPacenote.id)

      -- editor.history:commitAction("Create pacenote with mouse",
      --   {
      --     self = self,
      --     pacenote_data = newPacenote:onSerialize(),
      --     pacenote_id = newPacenote.id,
      --     sortOrder = newPacenote.sortOrder,
      --   },
      --   function(data) -- undo
      --     self.path.pacenotes:remove(data.pacenote_id)
      --     self:selectPacenote(nil)
      --   end,
      --   function(data) -- redo
      --     local note = self.path.pacenotes:create(nil, data.pacenote_data.oldId)
      --     note.sortOrder = data.sortOrder
      --     data.self.path.pacenotes:sort()
      --     -- data.self.path:sortPacenotesByName()
      --     note:onDeserialized(data.pacenote_data, {})
      --     self:selectPacenote(data.pacenote_id)
      --   end
      -- )
    end
  end

  if self.mouseInfo.hold then
    -- self:debugDrawNewPacenote2(pos_cs, pos_ce)
  elseif self.mouseInfo.up then
    -- local newPacenote = self.path.pacenotes:create(nil, nil)
    -- newPacenote.pacenoteWaypoints:create('corner start', pos_cs)
    -- local point_ce = self.pacenote_tools_state.snaproad:distanceForwards(point_cs, 10)
    -- newPacenote.pacenoteWaypoints:create('corner end', point_ce.pos)
    -- local point_at = self.pacenote_tools_state.snaproad:distanceBackwards(point_cs, 10)
    -- newPacenote.pacenoteWaypoints:create('audio trigger', point_at.pos)


    -- self.path:sortPacenotesByName()
    -- self:selectPacenote(newPacenote.id)
    -- for i,pn in ipairs(self.path.pacenotes.sorted) do
    --   local cs = pn:getCornerStartWaypoint()
    --   cs._snap_point = self.pacenote_tools_state.snaproad:closestSnapPoint(cs.pos)
    -- end

    -- editor.history:commitAction("Create pacenote with mouse",
    --   {
    --     self = self,
    --     pacenote_data = newPacenote:onSerialize(),
    --     pacenote_id = newPacenote.id,
    --   },
    --   function(data) -- undo
    --     self.path.pacenotes:remove(data.pacenote_id)
    --     self:selectPacenote(nil)
    --   end,
    --   function(data) -- redo
    --     local note = self.path.pacenotes:create(nil, data.pacenote_data.oldId)
    --     note:onDeserialized(data.pacenote_data, {})
    --     self:selectPacenote(data.pacenote_id)
    --   end
    -- )
  end
end

-- function C:addMouseWaypointToPacenote()
--   if not self.path then return end
--   if not self.mouseInfo.rayCast then return end
--
--   local pacenote = self:selectedPacenote()
--   if not pacenote then return end
--
--   local nextType = pacenote:getNextWaypointType()
--   local txt = "Add ".. nextType .." Waypoint to '".. (pacenote.name) .."'"
--
--   local pos_rayCast = self.mouseInfo.rayCast.pos
--
--   -- if self.pacenote_tools_state.snaproad and self.pacenote_tools_state.drag_mode == dragModes.simple_road_snap then
--   if self.pacenote_tools_state.snaproad then
--     pos_rayCast = self.pacenote_tools_state.snaproad:closestSnapPos(pos_rayCast)
--   end
--
--   -- draw the cursor text
--   debugDrawer:drawTextAdvanced(
--     vec3(pos_rayCast),
--     String(txt),
--     ColorF(1,1,1,1),
--     true,
--     false,
--     ColorI(0,0,0,255)
--   )
--
--   if self.mouseInfo.down then
--     self.wasWPSelected = not not self:selectedWaypoint()
--
--     editor.history:commitAction("Add waypoint to pacenote '".. pacenote.name .."'",
--       {
--         self = self,
--         pos = pos_rayCast,
--         wp_data = nil,
--         wp_id = nil,
--         pacenote_id = pacenote.id,
--       },
--       function(data) -- undo
--         local note = self.path.pacenotes.objects[data.pacenote_id]
--         note.pacenoteWaypoints:remove(data.wp_id)
--         self:selectPacenote(data.pacenote_id)
--       end,
--       function(data) -- redo
--         local note = self.path.pacenotes.objects[data.pacenote_id]
--         local waypoint = note.pacenoteWaypoints:create(nil, data.pos, data.wp_data and data.wp_data.oldId or nil)
--
--         if waypoint.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
--           if self.pacenote_tools_state.drag_mode == dragModes.simple_road_snap then
--             self:_snapOneHelper(waypoint)
--           elseif self.pacenote_tools_state.drag_mode == dragModes.simple then
--             local cs = note:getCornerStartWaypoint()
--             if cs then
--               local rv = re_util.calculateForwardNormal(data.pos, cs.pos)
--               waypoint.normal = vec3(rv.x, rv.y, rv.z)
--             end
--           end
--         end
--
--         if not data.wp_data then
--           data.wp_data = waypoint:onSerialize()
--         else
--           waypoint:onDeserialized(data.wp_data)
--         end
--
--         data.wp_id = waypoint.id
--         self:selectWaypoint(waypoint.id)
--       end
--     )
--
--   elseif self.mouseInfo.hold then
--     -- local note = self.path.pacenotes.objects[data.pacenote_id]
--     -- local waypoint = note.pacenoteWaypoints:create(nil, data.pos, data.wp_data and data.wp_data.oldId or nil)
--     local note = self:selectedPacenote()
--     local waypoint = self:selectedWaypoint()
--
--     if waypoint and waypoint.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
--       if self.pacenote_tools_state.drag_mode == dragModes.simple_road_snap then
--         self:_snapOneHelper(waypoint)
--       elseif self.pacenote_tools_state.drag_mode == dragModes.simple then
--         local cs = note:getCornerStartWaypoint()
--         if cs then
--           local rv = re_util.calculateForwardNormal(waypoint.pos, cs.pos)
--           waypoint.normal = vec3(rv.x, rv.y, rv.z)
--         end
--       end
--     end
--   elseif self.mouseInfo.up then
--     if not self.wasWPSelected then
--       self:selectWaypoint(nil)
--     end
--   end
-- end

-- function C:detectMouseHoverTranscript()
--   local transcripts = self:getTranscripts()
--   if not transcripts then return end
--   if not self.transcript_tools_state.show then return end
--
--   local min_dist = 4294967295
--   local hover_tsc = nil
--
--   for _,tsc in ipairs(transcripts.transcripts.sorted) do
--     local vpos = tsc:vehiclePos()
--     if vpos and tsc.show then
--       local distNoteToCam = (vpos - self.mouseInfo.camPos):length()
--       local noteRayDistance = (vpos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
--       if noteRayDistance <= transcripts.selection_sphere_r then
--         if distNoteToCam < min_dist then
--           min_dist = distNoteToCam
--           hover_tsc = tsc
--         end
--       end
--     end
--   end
--
--   return hover_tsc
-- end

-- figures out which pacenote to select with the mouse in the 3D scene.
function C:detectMouseHoverWaypoint()
  if not self.path then return end
  if not self.path.pacenotes then return end

  local min_note_dist = 4294967295
  local hover_wp = nil
  local selected_pacenote_i = -1
  local waypoints = {}
  local radius_factors = {}

  -- figure out which waypoints are available to select.
  for i, pacenote in ipairs(self.path.pacenotes.sorted) do
    -- if a pacenote is selected, then we can only select it's waypoints.
    if self:selectedPacenote() and self:selectedPacenote().id == pacenote.id then
      selected_pacenote_i = i
      for _,waypoint in ipairs(pacenote.pacenoteWaypoints.sorted) do
        -- if waypoint.waypointType == waypointTypes.wpTypeDistanceMarker and editor_rallyEditor.getPrefShowDistanceMarkers() then
          -- table.insert(waypoints, waypoint)
        if waypoint:isAt() and editor_rallyEditor.getPrefShowAudioTriggers() then
          table.insert(waypoints, waypoint)
        elseif waypoint:isCs() or waypoint:isCe() then
          table.insert(waypoints, waypoint)
        end
      end
    elseif not self:selectedPacenote() then
    -- if no waypoint is selected (ie at the PacenoteSelected mode), we can select any corner start.
      local waypoint = pacenote:getCornerStartWaypoint()
      table.insert(waypoints, waypoint)
    elseif not self:selectedWaypoint() then
    -- if no waypoint is selected (ie at the PacenoteSelected mode), we can select any corner start.
      local waypoint = pacenote:getCornerStartWaypoint()
      radius_factors[waypoint.id] = cc.pacenote_adjacent_radius_factor
      table.insert(waypoints, waypoint)
    end
  end

  -- add waypoints from the previous pacenote.
  if editor_rallyEditor.getPrefShowPreviousPacenote() then
    local prev_i = selected_pacenote_i - 1
    if prev_i > 0 and self:selectedWaypoint() then
      local pn_prev = self.path.pacenotes.sorted[prev_i]
      for _,waypoint in ipairs(pn_prev.pacenoteWaypoints.sorted) do
        radius_factors[waypoint.id] = cc.pacenote_adjacent_radius_factor
        table.insert(waypoints, waypoint)
      end
    end
  end

  -- add waypoints from the next pacenote.
  if editor_rallyEditor.getPrefShowNextPacenote() then
    local next_i = selected_pacenote_i + 1
    if next_i <= #self.path.pacenotes.sorted and self:selectedWaypoint() then
      local pn_next = self.path.pacenotes.sorted[next_i]
      for _,waypoint in ipairs(pn_next.pacenoteWaypoints.sorted) do
        radius_factors[waypoint.id] = cc.pacenote_adjacent_radius_factor
        table.insert(waypoints, waypoint)
      end
    end
  end

  -- of the available waypoints, figure out the closest one.
  for _, waypoint in ipairs(waypoints) do
    local distNoteToCam = (waypoint.pos - self.mouseInfo.camPos):length()
    local noteRayDistance = (waypoint.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
    local sphereRadius =  waypoint.radius
    if radius_factors[waypoint.id] then
      sphereRadius = sphereRadius * radius_factors[waypoint.id]
    end
    if noteRayDistance <= sphereRadius then
      if distNoteToCam < min_note_dist then
        min_note_dist = distNoteToCam
        hover_wp = waypoint
      end
    end
  end

  return hover_wp
end

local function offsetMousePosWithTerrainZSnap(pos, offset)
  local newPos = pos - offset
  local rv = core_terrain.getTerrainHeight(pos)
  if rv then
    newPos.z = core_terrain.getTerrainHeight(pos)
  end
  return newPos
end

-- returns new position for the drag, and another position for orienting the normal perpendicularly.
function C:wpPosForSimpleDrag(wp, mousePos, mouseOffset)
  -- if self.pacenote_tools_state.drag_mode == dragModes.simple then
  --   if wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
  --     local newPos = offsetMousePosWithTerrainZSnap(mousePos, mouseOffset)
  --     local otherWp = wp.pacenote:getCornerStartWaypoint()
  --     if otherWp then
  --       return newPos, otherWp.pos
  --     else
  --       return newPos, nil
  --     end
  --   else
  --     local newPos = offsetMousePosWithTerrainZSnap(mousePos, mouseOffset)
  --     return newPos, nil
  --   end
  -- if self.pacenote_tools_state.snaproad and self.pacenote_tools_state.drag_mode == dragModes.simple_road_snap then
  if self.pacenote_tools_state.snaproad then
    if self.mouseInfo.rayCast then
      local newPos = offsetMousePosWithTerrainZSnap(mousePos, mouseOffset)
      local newPoint = self.pacenote_tools_state.snaproad:closestSnapPoint(newPos)
      local _, toPoint = self.pacenote_tools_state.snaproad:normalAlignPoints(newPoint)
      if newPoint and toPoint then
        return newPoint.pos, toPoint.pos
      else
        return nil, nil
      end
    else
      -- local newPos = offsetMousePosWithTerrainZSnap(mousePos, mouseOffset)
      return nil, nil
    end
  else
    log('W', logTag, 'wpPosForSimpleDrag hit the else when should no hit else')
    return nil, nil
  end
end

-- for pacenote 'Move Up'/'Move Down' buttons, I think?
-- local function moveNotebookUndo(data)
--   data.self.path.notebooks:move(data.index, -data.dir)
-- end
-- local function moveNotebookRedo(data)
--   data.self.path.notebooks:move(data.index,  data.dir)
-- end
local function movePacenoteUndo(data)
  data.self.path.pacenotes:move(data.index, -data.dir)
end
local function movePacenoteRedo(data)
  data.self.path.pacenotes:move(data.index,  data.dir)
end
local function moveWaypointUndo(data)
  data.self:selectedPacenote().pacenoteWaypoints:move(data.index, -data.dir)
end
local function moveWaypointRedo(data)
  data.self:selectedPacenote().pacenoteWaypoints:move(data.index,  data.dir)
end

-- local function setNotebookFieldUndo(data)
--   data.self.path.notebooks.objects[data.index][data.field] = data.old
-- end
-- local function setNotebookFieldRedo(data)
--   data.self.path.notebooks.objects[data.index][data.field] = data.new
-- end
local function setPacenoteFieldUndo(data)
  data.self.path.pacenotes.objects[data.index][data.field] = data.old
  data.self.path:sortPacenotesByName()
end
local function setPacenoteFieldRedo(data)
  data.self.path.pacenotes.objects[data.index][data.field] = data.new
  data.self.path:sortPacenotesByName()
end
local function setWaypointFieldUndo(data)
  data.self:selectedPacenote().pacenoteWaypoints.objects[data.index][data.field] = data.old
  data.self:updateGizmoTransform(data.index)
end
local function setWaypointFieldRedo(data)
  data.self:selectedPacenote().pacenoteWaypoints.objects[data.index][data.field] = data.new
  data.self:updateGizmoTransform(data.index)
end

local function setWaypointNormalUndo(data)
  local wp = data.self:selectedPacenote().pacenoteWaypoints.objects[data.index]
  if wp then
    wp:setNormal(data.old)
  end
  data.self:updateGizmoTransform(data.index)
end
local function setWaypointNormalRedo(data)
  local wp = data.self:selectedPacenote().pacenoteWaypoints.objects[data.index]
  if wp and not wp.missing then
    wp:setNormal(data.new)
  end
  data.self:updateGizmoTransform(data.index)
end

function C:deleteSelected()
  if self:selectedPacenote() then
    self:deleteSelectedPacenote()
  end
end

function C:deleteSelectedWaypoint()
  if not self.path then return end

  local wp_sel = self:selectedWaypoint()

  if wp_sel and wp_sel.waypointType == waypointTypes.wpTypeCornerStart then
    return
  elseif wp_sel and wp_sel.waypointType == waypointTypes.wpTypeCornerEnd then
    return
  end

  editor.history:commitAction(
    "RallyEditor DeleteSelectedWaypoint",
    {index = self.pacenote_tools_state.selected_wp_id, self = self},
    function(data) -- undo
      local wp = data.self:selectedPacenote().pacenoteWaypoints:create(nil, nil, data.wpData.oldId)
      wp:onDeserialized(data.wpData)
      self:selectWaypoint(data.index)
    end,
    function(data) --redo
      data.wpData = data.self:selectedPacenote().pacenoteWaypoints.objects[data.index]:onSerialize()
      data.self:selectedPacenote().pacenoteWaypoints:remove(data.index)
      self:selectWaypoint(nil)
    end
  )
end

function C:deleteSelectedPacenote()
  if not self.path then return end

  local notebook = self.path

  editor.history:commitAction(
    "RallyEditor DeleteSelectedPacenote",
    {index = self.pacenote_tools_state.selected_pn_id, self = self},
    function(data) -- undo
      local note = notebook.pacenotes:create(nil, data.noteData.oldId)
      note:onDeserialized(data.noteData, {})
      self:selectPacenote(data.index)
    end,
    function(data) --redo
      data.noteData = notebook.pacenotes.objects[data.index]:onSerialize()
      notebook.pacenotes:remove(data.index)
      self:selectPacenote(nil)
    end
  )
end

function C:selectRecentPacenote()
  if not self:selectedPacenote() then
    if self.pacenote_tools_state.recent_selected_pn_id then
      self:selectPacenote(self.pacenote_tools_state.recent_selected_pn_id)
      return true
    end
  end
  return false
end

function C:selectPrevPacenote()
  if not self.path then return end

  if self:selectRecentPacenote() then return end

  local curr = self.path.pacenotes.objects[self.pacenote_tools_state.selected_pn_id]
  local sorted = self.path.pacenotes.sorted

  if curr and not curr.missing then
    local prev = nil
    for i = curr.sortOrder-1,1,-1 do
      local pacenote = sorted[i]
      if self:searchPacenoteMatchFn(pacenote) then
        prev = pacenote
        break
      end
    end

    -- wrap around: find the first usable one
    -- if not prev then
    --   for i = #sorted,1,-1 do
    --     local pacenote = sorted[i]
    --     if self:searchPacenoteMatchFn(pacenote) then
    --       prev = pacenote
    --       break
    --     end
    --   end
    -- end

    if prev then
      self:selectPacenote(prev.id)
    end
  else
    -- if no curr, that means no pacenote was selected, so then select the last one.
    for i = 1,#sorted do
      local pacenote = sorted[i]
      if self:searchPacenoteMatchFn(pacenote) then
        self:selectPacenote(pacenote.id)
        break
      end
    end
  end

  if self.rallyEditor.getPrefTopDownCameraFollow() then
    self:setCameraToPacenote()
  end
end

function C:selectNextPacenote()
  if not self.path then return end

  if self:selectRecentPacenote() then return end

  local curr = self.path.pacenotes.objects[self.pacenote_tools_state.selected_pn_id]
  local sorted = self.path.pacenotes.sorted

  if curr and not curr.missing then
    local next = nil
    for i = curr.sortOrder+1,#sorted do
      local pacenote = sorted[i]
      if self:searchPacenoteMatchFn(pacenote) then
        next = pacenote
        break
      end
    end

    -- wrap around: find the first usable one
    -- if not next then
    --   for i = 1,#sorted do
    --     local pacenote = sorted[i]
    --     if self:searchPacenoteMatchFn(pacenote) then
    --       next = pacenote
    --       break
    --     end
    --   end
    -- end

    if next then
      self:selectPacenote(next.id)
    end
  else
    -- if no curr, that means no pacenote was selected, so then select the last one.
    for i = #sorted,1,-1 do
      local pacenote = sorted[i]
      if self:searchPacenoteMatchFn(pacenote) then
        self:selectPacenote(pacenote.id)
        break
      end
    end
  end

  if self.rallyEditor.getPrefTopDownCameraFollow() then
    self:setCameraToPacenote()
  end
end

-- function C:cycleDragMode()
--   self:resetGizmoTransformToOrigin()
--
--   if self.pacenote_tools_state.drag_mode == dragModes.simple then
--     if self.pacenote_tools_state.snaproad then
--       self.pacenote_tools_state.drag_mode = dragModes.simple_road_snap
--     end
--   elseif self.pacenote_tools_state.drag_mode == dragModes.simple_road_snap then
--     self.pacenote_tools_state.drag_mode = dragModes.simple
--   end
--
--   -- log('D', logTag, 'cycle dragMode to '..self.pacenote_tools_state.drag_mode)
-- end

function C:insertMode()
  self._insertMode = true
end

-- function C:drawDebugSegments()
--   local racePath = self:getRacePath()
--   local pathnodes = racePath.pathnodes.objects
--   for _, seg in pairs(racePath.segments.objects) do
--     -- seg._drawMode = note.segment == -1 and 'normal' or (note.segment == seg.id and 'normal' or 'faded')
--
--     local from = pathnodes[seg.from]
--     local to = pathnodes[seg.to]
--     local pn_sel = self:selectedPacenote()
--
--     local clr = nil
--
--     if pn_sel and seg.id == pn_sel.segment then
--       clr = cc.segments_clr_assigned
--     else
--       clr = cc.segments_clr
--     end
--
--     debugDrawer:drawSquarePrism(
--       from.pos,
--       to.pos,
--       Point2F(10, 1),
--       Point2F(10, 0.25),
--       ColorF(clr[1], clr[2], clr[3], cc.segments_alpha)
--     )
--   end
-- end

function C:validate()
  self.validation_issues = {}
  self.notes_valid = true
  local invalid_notes_count = 0

  for _,note in ipairs(self.path.pacenotes.sorted) do
    note:validate()
    if not note:is_valid() then
      self.notes_valid = false
      invalid_notes_count = invalid_notes_count + 1
    end
  end

  if not self.notes_valid then
    table.insert(self.validation_issues, tostring(invalid_notes_count)..' pacenote(s) have issues')
  end

  local distance_call_issues = 0
  local did_add_first_issue = false
  for _,lang_data in ipairs(self.path:getLanguages()) do
    local language = lang_data.language
    local prev = nil
    for _,curr in ipairs(self.path.pacenotes.sorted) do
      if prev ~= nil then
        local prev_after = prev:getNoteFieldAfter(language)
        local curr_before = curr:getNoteFieldBefore(language)
        if prev_after == '' and curr_before == '' then
          if not did_add_first_issue then
            table.insert(self.validation_issues, 'missing distance call for '..prev.name..' -> '..curr.name..'. Use "#" if you want none.')
            did_add_first_issue = true
          end
          distance_call_issues = distance_call_issues + 1
        end
      end
      prev = curr
    end
  end

  if distance_call_issues >= 2 then
    table.insert(self.validation_issues, 'missing distance calls for '..(distance_call_issues-1)..' more pacenotes.')
  end
end

function C:deleteAllPacenotes()
  if not self.path then return end
  self.path:deleteAllPacenotes()
end

function C:drawPacenotesList(height)
  if not self.path then return end

  local notebook = self.path
  self:validate()

  if self:isValid() then
    im.HeaderText(tostring(#notebook.pacenotes.sorted).." Pacenotes")
  else
    im.HeaderText("[!] "..tostring(#notebook.pacenotes.sorted).." Pacenotes")
    local issues = "Issues (".. (#self.validation_issues) .."):\n"
    for _, issue in ipairs(self.validation_issues) do
      issues = issues..'- '..issue..'\n'
    end
    im.Text(issues)
    im.Separator()
  end

  -- im.SameLine()
  if im.Button("Cleanup Names") then
    self:cleanupPacenoteNames()
  end
  im.tooltip("Re-name all pacenotes with increasing numbers.")
  im.SameLine()
  -- if im.Button("Auto-assign segments") then
  --   self:autoAssignSegments()
  -- end
  -- im.tooltip("Requires race to be loaded in Race Tool.\n\nAssign pacenote to nearest segment.")
  -- im.SameLine()
  -- if im.Button("Snap All") then
  --   self:_snapAll()
  -- end
  -- im.tooltip("Snap all waypoints to nearest snaproad point.")
  -- im.SameLine()
  -- if im.Button("All to Terrain") then
  --   self:allToTerrain()
  -- end
  -- im.tooltip("Snap all waypoints to terrain.")
  im.SameLine()
  if im.Button("Set All Radii") then
    self:setAllRadii()
  end
  im.tooltip("Force the radius of all waypoints to the default value set in Edit > Preferences.")
  im.SameLine()
  if im.Button("Set Punctuation") then
    self:normalizeNotes()
  end
  im.tooltip("Add puncuation and replace digits with words.")
  -- im.SameLine()
  -- if im.Button("Autofill Dist Calls") then
  --   self:autoFillDistanceCalls()
  -- end
  -- im.tooltip("Autofill distance calls.")

  im.SameLine()
  if im.Button("Delete All") then
    im.OpenPopup("Delete All")
  end
  im.tooltip("Delete all pacenotes from this notebook.")
  if im.BeginPopupModal("Delete All", nil, im.WindowFlags_AlwaysAutoResize) then
    -- local dir, filename, ext = path.splitWithoutExt(self.selected_fname, true)
    -- im.Text("Current Name: "..filename)
    im.Text("Delete all pacenotes?")
    -- im.InputText("Key:##translationKey", translationData.translationKeyPtr, translationData.translationKeyLength)

    im.Separator()
    if im.Button("Ok", im.ImVec2(120,0)) then
      self:deleteAllPacenotes()
      im.CloseCurrentPopup()
    end
    im.SameLine()
    if im.Button("Cancel", im.ImVec2(120,0)) then
      im.CloseCurrentPopup()
    end
    im.EndPopup()
  end

  if im.Button("Prev") then
      self:selectPrevPacenote()
  end
  im.SameLine()
  if im.Button("Next") then
      self:selectNextPacenote()
  end
  im.SameLine()
  local editEnded = im.BoolPtr(false)
  editor.uiInputText("##SearchPn", pacenotesSearchText, nil, nil, nil, nil, editEnded)
  if editEnded[0] then
    self.pacenote_tools_state.search = ffi.string(pacenotesSearchText)

    if re_util.trimString(self.pacenote_tools_state.search) == '' then
      self.pacenote_tools_state.search = nil
    end

    if self.pacenote_tools_state.search then
      log('D', logTag, 'searching pacenotes: '..self.pacenote_tools_state.search)
      local pn = self:selectedPacenote()
      if pn then
        if not self:pacenoteSearchMatches(pn) then
          self:selectNextPacenote()
        end
      end
    end
  end
  im.SameLine()
  if im.Button("X") then
    self.pacenote_tools_state.search = nil
    pacenotesSearchText = im.ArrayChar(1024, "")
  end


  -- vertical space
  for i = 1,5 do im.Spacing() end

  im.BeginChild1("pacenotes", im.ImVec2(200*im.uiscale[0],height), im.WindowFlags_ChildWindow)
  for i, note in ipairs(notebook.pacenotes.sorted) do
    if im.Selectable1(note:nameForSelect(), note.id == self.pacenote_tools_state.selected_pn_id) then
      editor.history:commitAction("Select Pacenote",
        {old = self.pacenote_tools_state.selected_pn_id, new = note.id, self = self},
        selectPacenoteUndo, selectPacenoteRedo)
    end
    if note:is_valid() then
      im.tooltip("No issues")
    else
      im.tooltip("[!] Found "..(#note.validation_issues).." issue(s).\nCheck pacenote for details ")
    end
  end
  -- im.Separator()
  -- if im.Selectable1('New...', self.pacenote_tools_state.selected_pn_id == nil) then
  --   local pacenote = notebook.pacenotes:create(nil, nil)
  --   self:selectPacenote(pacenote.id)
  -- end
  -- im.tooltip("Ctrl-Drag in the world to create a new pacenote.")
  im.EndChild() -- pacenotes child window

  im.SameLine()
  im.BeginChild1("currentPacenote", im.ImVec2(0,height), im.WindowFlags_ChildWindow)

  if self.pacenote_tools_state.selected_pn_id then
    local pacenote = notebook.pacenotes.objects[self.pacenote_tools_state.selected_pn_id]

    if not pacenote.missing then

    if pacenote:is_valid() then
      im.HeaderText("Pacenote Info")
    else
      im.HeaderText("[!] Pacenote Info")
      local issues = "Issues (".. (#pacenote.validation_issues) .."):\n"
      for _, issue in ipairs(pacenote.validation_issues) do
        issues = issues..'- '..issue..'\n'
      end
      im.Text(issues)
      im.Separator()
    end

    im.Text("Current Pacenote: #" .. self.pacenote_tools_state.selected_pn_id)

    if im.Button("Focus Camera") then
      self:setCameraToPacenote()
    end
    im.SameLine()
    if im.Button("Place Vehicle") then
      self:placeVehicleAtPacenote()
    end
    -- im.SameLine()
    if im.Button("Move Up") then
      editor.history:commitAction("Move Pacenote in List",
        {index = self.pacenote_tools_state.selected_pn_id, self = self, dir = -1},
        movePacenoteUndo, movePacenoteRedo)
    end
    im.SameLine()
    if im.Button("Move Down") then
      editor.history:commitAction("Move Pacenote in List",
        {index = self.pacenote_tools_state.selected_pn_id, self = self, dir = 1},
        movePacenoteUndo, movePacenoteRedo)
    end
    im.SameLine()
    if im.Button("Delete") then
      self:deleteSelectedPacenote()
    end

    if im.Button("Insert After") then
      self:insertNewPacenoteAfter(pacenote)
    end

    local icon = editor.icons.play_arrow
    local paused = simTimeAuthority.getPause()
    local camTxt = 'Play'..((paused and ' (must unpause game!)') or '')

    if self:cameraPathIsPlaying() then
      icon = editor.icons.stop
      camTxt = 'Stop'
    end
    if editor.uiIconImageButton(icon, im.ImVec2(24, 24)) then
      self:cameraPathPlay()
    end
    im.SameLine()
    im.Text(camTxt)

    for _ = 1,5 do im.Spacing() end

    local editEnded = im.BoolPtr(false)
    editor.uiInputText("Name", pacenoteNameText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("Change Name of Note",
        {index = self.pacenote_tools_state.selected_pn_id, self = self, old = pacenote.name, new = ffi.string(pacenoteNameText), field = 'name'},
        setPacenoteFieldUndo, setPacenoteFieldRedo)
    end

    editor.uiInputText("Playback Rules", playbackRulesText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("Change the playback rules",
        {index = self.pacenote_tools_state.selected_pn_id, self = self, old = pacenote.playback_rules, new = ffi.string(playbackRulesText), field = 'playback_rules'},
        setPacenoteFieldUndo, setPacenoteFieldRedo)
    end
    im.tooltip([[Playback Rules

Available variables:
- currLap (the current lap)
- maxLap  (the maximum lap)

Any lua code is allowed, so be careful. Examples:
- '' (empty string, the default) -> audio will play
- 'true' -> audio will play
- 'false' -> audio will not play
- 'currLap > 1' -> audio will play except for on the first lap
- 'currLap == 3' -> audio will play only on the 3rd lap
- 'currLap ~= 3' -> audio will play except on the 3rd lap
- 'currLap < maxLap' -> audio will play except for on the last lap
]])

    -- im.Text("Segment: "..note.segment)

    -- self:segmentSelector('Segment','segment', 'Associated Segment')

    -- if self.rallyEditor.getPrefShowRaceSegments() then
    --   self:drawDebugSegments()
    -- end

    im.HeaderText("Languages")
    editEnded = im.BoolPtr(false)
    -- language_form_fields = {}
    for i,lang_data in ipairs(self.path:getLanguages()) do
      local language = lang_data.language
      local codrivers = lang_data.codrivers
      language_form_fields[language] = language_form_fields[language] or {}
      local fields = language_form_fields[language]

      fields.before = im.ArrayChar(256, pacenote:getNoteFieldBefore(language))
      fields.note   = im.ArrayChar(1024, pacenote:getNoteFieldNote(language))
      fields.after  = im.ArrayChar(256, pacenote:getNoteFieldAfter(language))

      im.Text(language..": ")

      local file_exists = false
      local voicePlayClr = nil
      local tooltipStr = nil
      local fname = nil

      for _,codriver in ipairs(codrivers) do
        fname = pacenote:audioFname(codriver)
        if re_util.fileExists(fname) then
          file_exists = true
          tooltipStr = "Codriver: "..codriver.name.."\nPlay pacenote audio file:\n"..fname
        else
          voicePlayClr = im.ImVec4(0.5, 0.5, 0.5, 1.0)
          tooltipStr = "Codriver: "..codriver.name.."\nPacenote audio file not found:\n"..fname
        end
        if editor.uiIconImageButton(editor.icons.play_circle_filled, im.ImVec2(20, 20), voicePlayClr) then
          if file_exists then
            local audioObj = re_util.buildAudioObjPacenote(fname)
            re_util.playPacenote(audioObj)

            -- core_sounds.cabinFilterStrength = 0
            -- local globalParams = Engine.Audio.getGlobalParams()
            -- globalParams:setParameterValue("c_CabinFilterReverbStrength", 1) -- cockpit flag, used e.g. for driver camera
            -- re_util.playPacenote2(audioObj)
          end
        end
        im.tooltip(tooltipStr)
        im.SameLine()
      end

      -- voicePlayClr = nil
      -- file_exists = false
      -- tooltipStr = "Play audio from voice transcription"
      -- if note.metadata.beamng_file and re_util.fileExists(note.metadata.beamng_file) then
      --   fname = note.metadata.beamng_file
      --   file_exists = true
      -- else
      --   voicePlayClr = im.ImVec4(0.5, 0.5, 0.5, 1.0)
      --   tooltipStr = "No voice transcription audio"
      -- end
      -- if editor.uiIconImageButton(editor.icons.record_voice_over, im.ImVec2(20, 20), voicePlayClr) then
      --   if file_exists then
      --     local audioObj = re_util.buildAudioObjPacenote(fname)
      --     re_util.playPacenote(audioObj)
      --   end
      -- end
      -- im.tooltip(tooltipStr)
      -- im.SameLine()

      im.SetNextItemWidth(90)
      editor.uiInputText('##'..language..'_before', fields.before, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        self:handleNoteFieldEdit(pacenote, language, 'before', fields.before)
      end
      im.SameLine()

      if self._insertMode then
        if i == 1 then
          im.SetKeyboardFocusHere()
        end
        self._insertMode = false
      end
      im.SetNextItemWidth(self.rallyEditor.getPrefUiPacenoteNoteFieldWidth())
      -- editor.uiInputTextMultiline('##'..language..'_note', fields.note, nil, im.ImVec2(300, 2 * im.GetTextLineHeightWithSpacing()), nil, nil, nil, editEnded)
      editingNote = editor.uiInputText('##'..language..'_note', fields.note, nil, nil, nil, nil, editEnded)

      if editEnded[0] then
        if pacenoteUnderEdit and pacenote.id == pacenoteUnderEdit.id then
          self:handleNoteFieldEdit(pacenote, language, 'note', fields.note)
        end
      end

      if editingNote and not pacenoteUnderEdit then
        pacenoteUnderEdit = pacenote
      elseif not editingNote then
        pacenoteUnderEdit = nil
      end

      im.SameLine()
      im.SetNextItemWidth(150)
      editor.uiInputText('##'..language..'_after', fields.after, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        self:handleNoteFieldEdit(pacenote, language, 'after', fields.after)
      end
    end -- / self.path:getLanguages()

    -- self:drawWaypointList(note)

    end -- / if not note.missing then
  end -- / if pacenote_id

  im.EndChild() -- currentPacenote child window
  -- for i = 1,3 do im.Spacing() end
end

-- function C:drawTranscriptsSection(height)
--   -- im.BeginChild1("transcriptsSection", im.ImVec2(0, height*im.uiscale[0]), im.WindowFlags_ChildWindow)
--   im.BeginChild1("transcriptsSection", nil, im.WindowFlags_ChildWindow)
--
--   local tscs = self:getTranscripts()
--   im.BeginChild1("transcriptsList", im.ImVec2(200*im.uiscale[0], 0), im.WindowFlags_ChildWindow)
--   if tscs then
--     for _,tsc in ipairs(tscs.transcripts.sorted) do
--       if tsc:isUsable() then
--         if im.Selectable1((tsc.text)..'##'..(tsc.id), tsc.id == self.transcript_tools_state.selected_id) then
--           self.transcript_tools_state.selected_id = tsc.id
--           self.transcript_tools_state.show = true
--         end
--       end
--     end
--   end
--   im.EndChild() -- transcripts section child window
--
--   im.SameLine()
--
--   im.BeginChild1("transcriptDetail", im.ImVec2(0, 0), im.WindowFlags_ChildWindow and im.ImGuiWindowFlags_NoBorder)
--   im.HeaderText('Transcript Tools')
--
--   -- im.SameLine()
--   -- if im.Button("Load") then
--     -- self.recording_state.driveline = require('/lua/ge/extensions/gameplay/aipacenotes/recording/driveline')(self.rallyEditor.getMissionDir())
--     -- self.recording_state.driveline:load()
--   -- end
--
--   -- im.SameLine()
--   -- if im.Button("Clear") then
--   --   self.rallyEditor.getTranscriptsWindow():clearSelection()
--   --   self.pacenote_tools_state.snaproads = nil
--   --   self.transcript_tools_state.search = nil
--   --   self.transcript_tools_state.show = true
--   --   transcriptsSearchText = im.ArrayChar(1024, "")
--   --   self.pacenote_tools_state.drag_mode = dragModes.simple
--   -- end
--   -- im.SameLine()
--   -- if im.Button("Load Curr") then
--   --   local settings = self.rallyEditor.loadMissionSettings(self.rallyEditor.getMissionDir())
--   --   if settings then
--   --     self.transcript_tools_state.search = nil
--   --     transcriptsSearchText = im.ArrayChar(1024, "")
--   --     local abspath = settings:getCurrTranscriptAbsPath()
--   --     self.rallyEditor.getTranscriptsWindow():selectTranscriptFile(abspath)
--   --     self:selectFirstTranscript()
--   --   end
--   -- end
--   -- im.SameLine()
--   -- if im.Button("Load Full Course") then
--   --   self:loadFullCourse(true)
--   -- end
--   im.SameLine()
--   if im.Checkbox("Show/Hide Transcripts##show_tscs", im.BoolPtr(self.transcript_tools_state.show)) then
--     self.transcript_tools_state.show = not self.transcript_tools_state.show
--   end
--
--   if im.Button("Prev") then
--     -- if self.transcript_tools_state.search then
--       -- self:searchForTranscript()
--     -- else
--       self:selectPrevTranscript()
--     -- end
--   end
--   im.SameLine()
--   if im.Button("Next") then
--     -- if self.transcript_tools_state.search then
--       -- self:searchForTranscript()
--     -- else
--       self:selectNextTranscript()
--     -- end
--   end
--   im.SameLine()
--   local editEnded = im.BoolPtr(false)
--   editor.uiInputText("##SearchTsc", transcriptsSearchText, nil, nil, nil, nil, editEnded)
--   if editEnded[0] then
--     self.transcript_tools_state.search = ffi.string(transcriptsSearchText)
--     if re_util.trimString(self.transcript_tools_state.search) == '' then
--       self.transcript_tools_state.search = nil
--     end
--
--     if self.transcript_tools_state.search then
--       log('D', logTag, 'searching transcripts: '..self.transcript_tools_state.search)
--       local tsc = self:selectedTranscript()
--       if tsc then
--         if not self:transcriptSearchMatches(tsc.text) then
--           self:selectNextTranscript()
--         end
--       end
--     end
--   end
--   im.SameLine()
--   if im.Button("X") then
--     self.transcript_tools_state.search = nil
--     self.transcript_tools_state.playbackLastCameraPos = nil
--     transcriptsSearchText = im.ArrayChar(1024, "")
--   end
--
--   if not tscs then
--     im.Text('Click one of the Load buttons above, or select a Transcript in the Transcripts tab.')
--   else
--     local tsc = self:selectedTranscript()
--     if tsc then
--       if editor.uiIconImageButton(editor.icons.content_copy, im.ImVec2(24, 24)) then
--         im.SetClipboardText(tsc.text)
--       end
--       -- im.tooltip('Copy to clipboard')
--       im.SameLine()
--       im.Text('Copy to Clipboard')
--
--       if core_camera.getActiveCamName() == "path" then
--         if editor.uiIconImageButton(editor.icons.stop, im.ImVec2(24, 24)) then
--           core_paths.stopCurrentPath()
--           self.transcript_tools_state.playbackLastCameraPos = core_camera.getPosition()
--           core_camera.setPosition(0, self.transcript_tools_state.last_camera.pos)
--           core_camera.setRotation(0, self.transcript_tools_state.last_camera.quat)
--         end
--         im.SameLine()
--         im.Text('Stop Camera Path')
--       else
--         if editor.uiIconImageButton(editor.icons.play_arrow, im.ImVec2(24, 24)) then
--           self.transcript_tools_state.last_camera.pos = core_camera.getPosition()
--           self.transcript_tools_state.last_camera.quat = core_camera.getQuat()
--           tsc:playCameraPath()
--         end
--         im.SameLine()
--         local paused = simTimeAuthority.getPause()
--         im.Text('Play Camera Path'..((paused and ' (must unpause game!)') or ''))
--       end
--
--       if editor.uiIconImageButton(editor.icons.location_searching, im.ImVec2(24, 24)) then
--         tsc:lookAtMe()
--       end
--       -- im.tooltip('')
--       im.SameLine()
--       im.Text('Look at')
--     end
--   end
--   im.EndChild() -- transcript detail section child window
--
--   im.EndChild() -- transcripts section child window
-- end

-- function C:loadFullCourse(show)
--   local settings = self.rallyEditor.loadMissionSettings(self.rallyEditor.getMissionDir())
--   if settings then
--     self.transcript_tools_state.search = nil
--     self.transcript_tools_state.show = show
--     transcriptsSearchText = im.ArrayChar(1024, "")
--     local abspath = settings:getFullCourseTranscriptAbsPath()
--     self.rallyEditor.getTranscriptsWindow():selectTranscriptFile(abspath)
--     -- self:selectFirstTranscript()
--
--     self.pacenote_tools_state.snaproads = require('/lua/ge/extensions/editor/rallyEditor/snapVC')(self.rallyEditor.getMissionDir())
--     self.pacenote_tools_state.snaproads.radius = 0.5
--     if not self.pacenote_tools_state.snaproads:load() then
--       self.pacenote_tools_state.snaproads = nil
--       self.pacenote_tools_state.drag_mode = dragModes.simple
--     else
--       self.pacenote_tools_state.drag_mode = dragModes.simple_road_snap
--     end
--   end
-- end

-- function C:selectFirstTranscript()
--   local transcripts_path = self:getTranscripts()
--   if not transcripts_path then return end
--
--   -- local curr = transcripts_path.transcripts.objects[self.transcript_tools_state.selected_id]
--   local sorted = transcripts_path.transcripts.sorted
--
--   for i = 1,#sorted do
--     local tsc = sorted[i]
--     if tsc and not tsc.missing and tsc:isUsable() then
--       self:selectTranscript(tsc.id)
--       break
--     end
--   end
--
--   if self.rallyEditor.getPrefTopDownCameraFollow() then
--     self:setCameraToTranscript()
--   end
-- end

-- function C:searchTranscriptMatchFn(tsc)
--   -- return tsc and not tsc.missing and tsc:isUsable()
--   return tsc and not tsc.missing and tsc:isUsable() and self:transcriptSearchMatches(tsc.text)
-- end

function C:searchPacenoteMatchFn(pacenote)
  -- return pacenote and not pacenote.missing and pacenote:isUsable()
  return pacenote and not pacenote.missing and self:pacenoteSearchMatches(pacenote)
end

-- function C:selectPrevTranscript()
--   local transcripts_path = self:getTranscripts()
--   if not transcripts_path then return end
--
--   self.transcript_tools_state.show = true
--
--   local curr = transcripts_path.transcripts.objects[self.transcript_tools_state.selected_id]
--   local sorted = transcripts_path.transcripts.sorted
--
--   if curr and not curr.missing then
--     local prev = nil
--     for i = curr.sortOrder-1,1,-1 do
--       local tsc = sorted[i]
--       if self:searchTranscriptMatchFn(tsc) then
--         prev = tsc
--         break
--       end
--     end
--
--     if not prev then
--       for i = #sorted,1,-1 do
--         local tsc = sorted[i]
--         if self:searchTranscriptMatchFn(tsc) then
--           prev = tsc
--           break
--         end
--       end
--     end
--
--     if prev then
--       self:selectTranscript(prev.id)
--     end
--   else
--     -- if no curr, that means no pacenote was selected, so then select the last one.
--     for i = 1,#sorted do
--       local tsc = sorted[i]
--       if self:searchTranscriptMatchFn(tsc) then
--         self:selectTranscript(tsc.id)
--         break
--       end
--     end
--   end
--
--   if self.rallyEditor.getPrefTopDownCameraFollow() then
--     self:setCameraToTranscript()
--   end
-- end
--
-- function C:transcriptSearchMatches(stringToMatch)
--   if not self.transcript_tools_state.search then return true end
--
--   local searchPattern = re_util.trimString(self.transcript_tools_state.search)
--   if searchPattern == '' then return true end
--   log('D', logTag, 'transcriptSearchMatches: search="'..searchPattern..'" input="'..stringToMatch..'"')
--
--   return re_util.matchSearchPattern(searchPattern, stringToMatch)
-- end

function C:pacenoteSearchMatches(pacenote)
  if not self.pacenote_tools_state.search then return true end

  local searchPattern = re_util.trimString(self.pacenote_tools_state.search)
  if searchPattern == '' then return true end

  return pacenote:matchesSearchPattern(searchPattern)
end

-- function C:selectNextTranscript()
--   local transcripts_path = self:getTranscripts()
--   if not transcripts_path then return end
--
--   self.transcript_tools_state.show = true
--
--   local curr = transcripts_path.transcripts.objects[self.transcript_tools_state.selected_id]
--   local sorted = transcripts_path.transcripts.sorted
--
--   if curr and not curr.missing then
--     local next = nil
--     for i = curr.sortOrder+1,#sorted do
--       local tsc = sorted[i]
--       if self:searchTranscriptMatchFn(tsc) then
--         next = tsc
--         break
--       end
--     end
--
--     -- wrap around: find the first usable one
--     if not next then
--       for i = 1,#sorted do
--         local tsc = sorted[i]
--         if self:searchTranscriptMatchFn(tsc) then
--           next = tsc
--           break
--         end
--       end
--     end
--
--     if next then
--       self:selectTranscript(next.id)
--     end
--   else
--     -- if no curr, that means no pacenote was selected, so then select the last one.
--     for i = #sorted,1,-1 do
--       local tsc = sorted[i]
--       if self:searchTranscriptMatchFn(tsc) then
--         self:selectTranscript(tsc.id)
--         break
--       end
--     end
--   end
--
--   if self.rallyEditor.getPrefTopDownCameraFollow() then
--     self:setCameraToTranscript()
--   end
-- end

function C:handleNoteFieldEdit(note, language, subfield, buf)
  local newVal = note.notes
  local lang_data = newVal[language] or {}
  lang_data[subfield] = re_util.trimString(ffi.string(buf))
  newVal[language] = lang_data
  editor.history:commitAction("Change Notes of Pacenote",
    {index = self.pacenote_tools_state.selected_pn_id, self = self, old = note.notes, new = newVal, field = 'notes'},
    setPacenoteFieldUndo, setPacenoteFieldRedo)
end

function C:drawWaypointList(note)
  im.HeaderText("Waypoints")
  im.BeginChild1("waypoints", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)

  for i,waypoint in ipairs(note.pacenoteWaypoints.sorted) do
    if im.Selectable1('['..waypointTypes.shortenWaypointType(waypoint.waypointType)..'] '..waypoint.name, waypoint.id == self.pacenote_tools_state.selected_wp_id) then
      editor.history:commitAction("Select Waypoint",
        {old = self.pacenote_tools_state.selected_wp_id, new = waypoint.id, self = self},
        selectWaypointUndo, selectWaypointRedo)
    end
  end

  -- im.Separator()

  -- if im.Selectable1('New...', self.pacenote_tools_state.selected_wp_id == nil) then
  --   self:selectWaypoint(nil)
  -- end

  -- im.tooltip("Shift-Drag in the world to create a new pacenote waypoint.")
  im.EndChild() -- waypoints child window

  im.SameLine()
  im.BeginChild1("currentWaypoint", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)

  if self.pacenote_tools_state.selected_wp_id then
    local waypoint = note.pacenoteWaypoints.objects[self.pacenote_tools_state.selected_wp_id]
    if not waypoint.missing then
      im.HeaderText("Waypoint Info")
      im.Text("Current Waypoint: #" .. self.pacenote_tools_state.selected_wp_id)
      im.SameLine()
      if im.Button("Delete") then
        self:deleteSelectedWaypoint()
      end
      im.SameLine()
      if im.Button("Move Up") then
        editor.history:commitAction("Move Pacenote Waypoint in List",
          {index = self.pacenote_tools_state.selected_wp_id, self = self, dir = -1},
          moveWaypointUndo, moveWaypointRedo)
      end
      im.SameLine()
      if im.Button("Move Down") then
        editor.history:commitAction("Move Pacenote Waypoint in List",
          {index = self.pacenote_tools_state.selected_wp_id, self = self, dir = 1},
          moveWaypointUndo, moveWaypointRedo)
      end

      for i = 1,5 do im.Spacing() end

      local editEnded = im.BoolPtr(false)
      editor.uiInputText("Name", waypointNameText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        editor.history:commitAction("Change Name of Waypoint",
          {index = self.pacenote_tools_state.selected_wp_id, self = self, old = waypoint.name, new = ffi.string(waypointNameText), field = 'name'},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end

      self:waypointTypeSelector(note)

      waypointPosition[0] = waypoint.pos.x
      waypointPosition[1] = waypoint.pos.y
      waypointPosition[2] = waypoint.pos.z
      if im.InputFloat3("Position", waypointPosition, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        editor.history:commitAction("Change note Position",
          {index = self.pacenote_tools_state.selected_wp_id, old = waypoint.pos, new = vec3(waypointPosition[0], waypointPosition[1], waypointPosition[2]), field = 'pos', self = self},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end
      -- if scenetree.findClassObjects("TerrainBlock") and im.Button("Down to Terrain") then
      --   editor.history:commitAction("Drop Note to Ground",
      --     {index = self.pacenote_tools_state.selected_wp_id, old = waypoint.pos,self = self, new = vec3(waypointPosition[0], waypointPosition[1], core_terrain.getTerrainHeight(waypoint.pos)), field = 'pos'},
      --     setWaypointFieldUndo, setWaypointFieldRedo)
      -- end
      waypointRadius[0] = waypoint.radius
      if im.InputFloat("Radius",waypointRadius, 0.1, 0.5, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        if waypointRadius[0] < 0 then
          waypointRadius[0] = 0
        end
        editor.history:commitAction("Change Note Size",
          {index = self.pacenote_tools_state.selected_wp_id, old = waypoint.radius, new = waypointRadius[0], self = self, field = 'radius'},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end

      waypointNormal[0] = waypoint.normal.x
      waypointNormal[1] = waypoint.normal.y
      waypointNormal[2] = waypoint.normal.z
      if im.InputFloat3("Normal", waypointNormal, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        editor.history:commitAction("Change Normal",
          {index = self.pacenote_tools_state.selected_wp_id, old = waypoint.normal, self = self, new = vec3(waypointNormal[0], waypointNormal[1], waypointNormal[2])},
          setWaypointNormalUndo, setWaypointNormalRedo)
      end
      -- if scenetree.findClassObjects("TerrainBlock") and im.Button("Align Normal with Terrain") then
      --   local normalTip = waypoint.pos + waypoint.normal*waypoint.radius
      --   normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
      --   editor.history:commitAction("Align Normal with Terrain",
      --     {index = self.pacenote_tools_state.selected_wp_id, old = waypoint.normal, self = self, new = normalTip - waypoint.pos},
      --     setWaypointNormalUndo, setWaypointNormalRedo)
      -- end

    end -- / if not waypoint.missing
  end -- / if waypoint_id
  im.EndChild() -- currentWaypoint child window
end

-- function C:segmentSelector(name, fieldName, tt)
--   if not self.path then return end
--
--   local _seg_name = function(seg)
--     return '#'..seg.id .. " - '" .. seg.name.."'"
--   end
--
--   local racePath = self:getRacePath()
--   local selected_pacenote = self.path.pacenotes.objects[self.pacenote_tools_state.selected_pn_id]
--   local segments = racePath.segments.objects
--
--   if im.BeginCombo(name..'##'..fieldName, _seg_name(segments[selected_pacenote[fieldName]])) then
--     if im.Selectable1('#'..0 .. " - None", selected_pacenote[fieldName] == -1) then
--       editor.history:commitAction("Removed Segment for pacenote",
--         {index = self.pacenote_tools_state.selected_pn_id, self = self, old = selected_pacenote[fieldName], new = -1, field = fieldName},
--         setPacenoteFieldUndo, setPacenoteFieldRedo)
--     end
--     for i, sp in ipairs(racePath.segments.sorted) do
--       if im.Selectable1(_seg_name(sp), selected_pacenote[fieldName] == sp.id) then
--               editor.history:commitAction("Changed Segment for pacenote",
--         {index = self.pacenote_tools_state.selected_pn_id, self = self, old = selected_pacenote[fieldName], new = sp.id, field = fieldName},
--         setPacenoteFieldUndo, setPacenoteFieldRedo)
--       end
--     end
--     im.EndCombo()
--   end
--
--   im.tooltip(tt or "")
-- end

function C:waypointTypeSelector(note)
  if not self:selectedWaypoint() then return end

  local waypoint = note.pacenoteWaypoints.objects[self.pacenote_tools_state.selected_wp_id]
  local wpTypesList = {
    waypointTypes.wpTypeFwdAudioTrigger,
    waypointTypes.wpTypeRevAudioTrigger,
    waypointTypes.wpTypeCornerStart,
    waypointTypes.wpTypeCornerEnd,
    waypointTypes.wpTypeDistanceMarker,
  }

  local name = 'WaypointType'
  local fieldName = 'waypointType'
  local tt = 'Set the waypointType'

  if im.BeginCombo(name..'##'..fieldName, waypoint.waypointType) then

    for i, wt in ipairs(wpTypesList) do
      -- log('D', 'wtf', 'i='..i..' type='..wt)
      if im.Selectable1(wt, waypoint[fieldName] == wt) then
        editor.history:commitAction("Changed waypointType for waypoint",
          {index = self.pacenote_tools_state.selected_wp_id, self = self, old = waypoint[fieldName], new = wt, field = fieldName},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end
    end

    im.EndCombo()
  end

  im.tooltip(tt)
end

-- function C:loadVoices()
--   local voices = jsonReadFile(voiceFname)
--   voiceNamesSorted = {}
--
--   if not voices then
--     log('E', logTag, 'unable to load voices file from ' .. tostring(filename))
--     voices = {"can't load voices file from "..voiceFname}
--     return
--   end
--
--   for voiceName, _ in pairs(voices) do
--     table.insert(voiceNamesSorted, voiceName)
--   end
--
--   table.sort(voiceNamesSorted)
--
--   log('I', logTag, 'reloaded voices from '..voiceFname)
-- end

-- function C:setCameraToTranscript()
--   local tsc = self:selectedTranscript()
--   if tsc then
--     tsc:lookAtMe()
--   end
-- end

function C:setCameraToPacenote()
  local pacenote = self:selectedPacenote()
  if not pacenote then return end

  pacenote:setCameraToWaypoints()
end

function C:_snapAll()
  if not self.path then return end
  if not self.pacenote_tools_state.snaproad then return end

  editor.history:commitAction("Snap all waypoints",
    {
      self = self,
      old_pacenotes = deepcopy(self.path.pacenotes:onSerialize()),
    },
    function(data) -- undo
      data.self.path.pacenotes:onDeserialized(data.old_pacenotes, {})
    end,
    function(data) -- redo
      data.self:_snapAllHelper()
    end
  )
end

function C:_snapOneHelper(wp)
  if not self.pacenote_tools_state.snaproad then return end

  local newPos, normalAlignPos = self.pacenote_tools_state.snaproad:closestSnapPos(wp.pos)
  wp.pos = newPos
  if normalAlignPos then
    local rv = re_util.calculateForwardNormal(newPos, normalAlignPos)
    wp.normal = vec3(rv.x, rv.y, rv.z)
  end
end

function C:_snapAllHelper()
  for i,wp in pairs(self.path:allWaypoints()) do
    self:_snapOneHelper(wp)
  end
end

function C:allToTerrain()
  if not self.path then return end

  editor.history:commitAction("Set radius of all waypoints",
    {
      notebook = self.path,
      old_pacenotes = deepcopy(self.path.pacenotes:onSerialize()),
    },
    function(data) -- undo
      data.notebook.pacenotes:onDeserialized(data.old_pacenotes, {})
    end,
    function(data) -- redo
      data.notebook:allToTerrain()
    end
  )
end

function C:setAllRadii()
  if not self.path then return end

  editor.history:commitAction("Set radius of all waypoints",
    {
      notebook = self.path,
      old_pacenotes = deepcopy(self.path.pacenotes:onSerialize()),
    },
    function(data) -- undo
      data.notebook.pacenotes:onDeserialized(data.old_pacenotes, {})
    end,
    function(data) -- redo
      data.notebook:setAllRadii(self.rallyEditor.getPrefDefaultRadius())
    end
  )
end

function C:cleanupPacenoteNames()
  if not self.path then return end

  editor.history:commitAction("Cleanup pacenote names",
    {
      self = self,
      notebook = self.path,
      old_pacenotes = deepcopy(self.path.pacenotes:onSerialize()),
    },
    function(data) -- undo
      data.notebook.pacenotes:onDeserialized(data.old_pacenotes, {})
    end,
    function(data) -- redo
      data.self:selectPacenote(nil)
      data.notebook:cleanupPacenoteNames()
    end
  )
end

-- function C:autoAssignSegments()
--   if not self.path then return end
--
--   editor.history:commitAction("Auto-assign segments to pacenotes",
--     {
--       racePath = self:getRacePath(),
--       notebook = self.path,
--       old_pacenotes = deepcopy(self.path.pacenotes:onSerialize()),
--     },
--     function(data) -- undo
--       data.notebook.pacenotes:onDeserialized(data.old_pacenotes, {})
--     end,
--     function(data) -- redo
--       data.notebook:autoAssignSegments(data.racePath)
--     end
--   )
-- end

function C:normalizeNotes()
  if not self.path then return end

  editor.history:commitAction("Normalize pacenote.note field",
    {
      notebook = self.path,
      old_pacenotes = deepcopy(self.path.pacenotes:onSerialize()),
    },
    function(data) -- undo
      data.notebook.pacenotes:onDeserialized(data.old_pacenotes, {})
    end,
    function(data) -- redo
      data.notebook:normalizeNotes()
    end
  )
end

function C:autoFillDistanceCalls()
  if not self.path then return end

  editor.history:commitAction("Auto-fill distance calls",
    {
      notebook = self.path,
      old_pacenotes = deepcopy(self.path.pacenotes:onSerialize()),
    },
    function(data) -- undo
      data.notebook.pacenotes:onDeserialized(data.old_pacenotes, {})
    end,
    function(data) -- redo
      data.notebook:autofillDistanceCalls()
    end
  )
end

function C:placeVehicleAtPacenote()
  local pos, rot = self:selectedPacenote():vehiclePlacementPosAndRot()

  if pos and rot then
    local playerVehicle = be:getPlayerVehicle(0)
    if playerVehicle then
      spawn.safeTeleport(playerVehicle, pos, rot)
    end
  end
end

function C:insertNewPacenoteAfter(note)
  if not self.path then return end

  local pn_next = nil

  for i,pn in ipairs(self.path.pacenotes.sorted) do
    if pn.id == note.id then
      pn_next = i+1
    end
  end

  local _, numA = note:nameComponents()
  numA = tonumber(numA)
  local nextNum = numA

  if pn_next <= #self.path.pacenotes.sorted then
    local next_note = self.path.pacenotes.sorted[pn_next]
    if next_note then
      local _, numB = next_note:nameComponents()
      numB = tonumber(numB)
      nextNum = numA + ((numB - numA) / 2)
    end
  else
    nextNum = numA+1
  end

  -- local currId = self:selectedPacenote().id
  -- num = tonumber(num) + 0.01

  local newPacenote = self.path.pacenotes:create("Pacenote "..tostring(nextNum))
  self.path:sortPacenotesByName()
  -- self:cleanupPacenoteNames()
  -- self:selectPacenote(currId)
end

function C:selectNextWaypoint()
  -- if there's no selected PN, select the recent one.

  -- if not pn then
  --   if self.pacenote_tools_state.recent_selected_pn_id then
  --     self:selectPacenote(self.pacenote_tools_state.recent_selected_pn_id)
  --   end
  --   return
  -- end

  -- if self:selectRecentPacenote() then return end
  self:selectRecentPacenote()

  local pn = self:selectedPacenote()
  if not pn then return end

  local wp_sel = self:selectedWaypoint()

  if wp_sel then
    local wp_new = nil
    if wp_sel:isAt() then
      wp_new = pn:getCornerStartWaypoint()
    elseif wp_sel:isCs() then
      wp_new = pn:getCornerEndWaypoint()
    elseif wp_sel:isCe() then
      wp_new = pn:getActiveFwdAudioTrigger()
      if not wp_new then
        wp_new = pn:getCornerStartWaypoint()
      end
    end

    if wp_new then
      self:selectWaypoint(wp_new.id)
    end
  else
    local wp = pn:getActiveFwdAudioTrigger()
    if not wp then
      wp = pn:getCornerStartWaypoint()
    end
    self:selectWaypoint(wp.id)
  end
end

function C:_moveSelectedWaypointHelper(fwd, steps)
  local wp = self:selectedWaypoint()
  if not wp then return end

  if self.pacenote_tools_state.snaproad then
    local pn = self:selectedPacenote()
    pn:moveWaypointTowards(self.pacenote_tools_state.snaproad, wp, fwd, steps)
  end
end

function C:moveSelectedWaypointForward(steps)
  steps = steps or 1
  self:_moveSelectedWaypointHelper(true, steps)
end

function C:moveSelectedWaypointBackward(steps)
  steps = steps or 1
  self:_moveSelectedWaypointHelper(false, steps)
end

function C:cameraPathPlay()
  if self:cameraPathIsPlaying() then
    self.pacenote_tools_state.snaproad:stopCameraPath()
    self.pacenote_tools_state.playbackLastCameraPos = core_camera.getPosition()
    core_camera.setPosition(0, self.pacenote_tools_state.last_camera.pos)
    core_camera.setRotation(0, self.pacenote_tools_state.last_camera.quat)
    self:selectPacenote(self:selectedPacenote().id)
  else
    self:selectWaypoint(nil)
    self.pacenote_tools_state.last_camera.pos = core_camera.getPosition()
    self.pacenote_tools_state.last_camera.quat = core_camera.getQuat()
    self.pacenote_tools_state.snaproad:playCameraPath()
  end
end

function C:cameraPathIsPlaying()
  return core_camera.getActiveCamName() == "path"
end

-- function C:moveSelectedWaypointForwardFast()
--   self:_moveSelectedWaypointHelper(true, 5)
-- end
--
-- function C:moveSelectedWaypointBackwardFast()
--   self:_moveSelectedWaypointHelper(false, 5)
-- end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
