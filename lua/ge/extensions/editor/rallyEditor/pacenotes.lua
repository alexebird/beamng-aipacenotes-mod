-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'
local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')
local snaproads = require('/lua/ge/extensions/editor/rallyEditor/snaproads')

-- pacenote form fields
local pacenoteNameText = im.ArrayChar(1024, "")

-- waypoint form fields
local waypointNameText = im.ArrayChar(1024, "")
local waypointPosition = im.ArrayFloat(3)
local waypointNormal = im.ArrayFloat(3)
local waypointRadius = im.FloatPtr(0)


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

local dragModes = {
  simple = 'simple',
  simple_road_snap = 'simple_road_snap',
  gizmo = 'gizmo',
}

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  self.pacenote_index = nil
  self.waypoint_index = nil
  self.mouseInfo = {}
  self.dragMode = dragModes.simple
end

function C:setPath(path)
  self.path = path
end

function C:selectedPacenote()
  if not self.path then return nil end
  if self.pacenote_index then
    return self.path.pacenotes.objects[self.pacenote_index]
  else
    return nil
  end
end

function C:selectedWaypoint()
  if not self:selectedPacenote() then return nil end
  if self.waypoint_index then
    return self:selectedPacenote().pacenoteWaypoints.objects[self.waypoint_index]
  else
    return nil
  end
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end

  -- self.pacenote_index = nil
  -- self.waypoint_index = nil

  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Shift] = "Add waypoint to current pacenote"
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

  -- self:selectWaypoint(nil)
  -- self:selectPacenote(nil)

  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Ctrl] = nil
  -- editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Alt] = nil
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Delete] = nil
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:selectPacenote(id)
  if not self.path then return end
  if not self.path.pacenotes then return end

  self.pacenote_index = id

  -- find the pacenotes before and after the selected one.
  local pacenotesSorted = self.path.pacenotes.sorted
  for i, note in ipairs(pacenotesSorted) do
    if self.pacenote_index == note.id then
      local prevNote = pacenotesSorted[i-1]
      local nextNote = pacenotesSorted[i+1]
      note:setAdjacentNotes(prevNote, nextNote)
    else
      note:clearAdjacentNotes()
    end
  end

  -- select the pacenote
  if id then
    local note = self.path.pacenotes.objects[id]
    pacenoteNameText = im.ArrayChar(1024, note.name)
  else
    pacenoteNameText = im.ArrayChar(1024, "")
  end
end

function C:selectWaypoint(id)
  if not self.path then return end
  self.waypoint_index = id

  if id then
    local waypoint = self.path:getWaypoint(id)
    if waypoint then
      self:selectPacenote(waypoint.pacenote.id)
      waypointNameText = im.ArrayChar(1024, waypoint.name)
      self:updateGizmoTransform(id)
    else
      log('E', logTag, 'expected to find waypoint with id='..id)
    end
  else
    waypointNameText = im.ArrayChar(1024, "")
    -- I think this fixes the bug where you cant click on a pacenote waypoint anymore.
    -- I think that was due to the Gizmo being present but undrawn, and the gizmo's mouseover behavior was superseding our pacenote hover.
    self:resetGizmoTransformToOrigin()
  end
end

function C:resetGizmoTransformToOrigin()
  local rotation = QuatF(0,0,0,1)
  local transform = rotation:getMatrix()
  local pos = {0, 0, 0}
  transform:setPosition(pos)
  editor.setAxisGizmoTransform(transform)
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
  local wp = self:selectedPacenote().pacenoteWaypoints.objects[self.waypoint_index]
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
  local wp = self:selectedPacenote().pacenoteWaypoints.objects[self.waypoint_index]
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
  local wp = self:selectedPacenote().pacenoteWaypoints.objects[self.waypoint_index]
  if not wp or wp.missing then return end

  editor.history:commitAction("Manipulated Note Waypoint via Gizmo",
    {old = self.beginDragNoteData,
     new = wp:onSerialize(),
     index = self.waypoint_index, self = self},
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

function C:drawDebugNotebookEntrypoint()
  if self.path then
    self.path:drawDebug(self.pacenote_index, self.waypoint_index)
  end
end

-- args are both vec3's representing a position.
local function calculateForwardNormal(snap_pos, next_pos, flip)
  local dx = next_pos.x - snap_pos.x
  local dy = next_pos.y - snap_pos.y
  local dz = next_pos.z - snap_pos.z

  local magnitude = math.sqrt(dx*dx + dy*dy + dz*dz)
  if magnitude == 0 then
    error("The two positions must not be identical.")
  end

  local normal = vec3(dx / magnitude, dy / magnitude, dz / magnitude)

  if flip then
    normal = -normal
  end

  return normal
end

function C:handleMouseDown(hoveredWp)
  if hoveredWp then
    local selectedPn = hoveredWp.pacenote
    if self:selectedPacenote() and self:selectedPacenote().id == selectedPn.id then
      self.simpleDragMouseOffset = self.mouseInfo._downPos - hoveredWp.pos
      self.beginSimpleDragNoteData = hoveredWp:onSerialize()
      self:selectWaypoint(hoveredWp.id)
    elseif not self:selectedPacenote() or self:selectedPacenote().id ~= selectedPn.id then
      self:selectPacenote(selectedPn.id)
    end
  else
    -- clear selection by clicking off waypoint. since there are two levels of selection (waypoint+pacenote, pacenote),
    -- you must click twice to deselect everything.
    if self:selectedWaypoint() then
      self:selectWaypoint(nil)
    else
      self:selectPacenote(nil)
    end
  end
end

function C:handleMouseHold()
  if self.dragMode == dragModes.simple or self.dragMode == dragModes.simple_road_snap then
    local mouse_pos = self.mouseInfo._holdPos
    -- this sphere indicates the drag cursor
    -- debugDrawer:drawSphere((mouse_pos), 1, ColorF(1,1,0,1.0)) -- radius=1, color=yellow

    local wp_sel = self:selectedWaypoint()
    if wp_sel then
      if self.mouseInfo.rayCast then
        local new_pos, normal_align_pos = self:wpPosForSimpleDrag(wp_sel, mouse_pos, self.simpleDragMouseOffset)
        if new_pos then
          wp_sel.pos = new_pos
          if normal_align_pos then
            local flip = self.rallyEditor.getPrefFlipSnaproadNormal()
            local rv = calculateForwardNormal(new_pos, normal_align_pos, flip)
            wp_sel.normal = vec3(rv.x, rv.y, rv.z)
          end
        end
      end
    end
  end
end

function C:handleMouseUp()
  if self.dragMode == dragModes.simple or self.dragMode == dragModes.simple_road_snap then
    local wp_sel = self:selectedWaypoint()
    if wp_sel and not wp_sel.missing then
      editor.history:commitAction("Manipulated Note Waypoint via SimpleDrag",
        {
          self = self, -- the rallyEditor pacenotes tab
          pacenote_idx = self.pacenote_index,
          wp_index = self.waypoint_index,
          old = self.beginSimpleDragNoteData,
          new = wp_sel:onSerialize(),
        },
        function(data) -- undo
          local notebook = data.self.path
          local pacenote = notebook.pacenotes.objects[data.pacenote_idx]
          local wp = pacenote.pacenoteWaypoints.objects[data.wp_index]
          wp:onDeserialized(data.old)
          data.self:selectWaypoint(data.wp_index)
        end,
        function(data) --redo
          local notebook = data.self.path
          local pacenote = notebook.pacenotes.objects[data.pacenote_idx]
          local wp = pacenote.pacenoteWaypoints.objects[data.wp_index]
          wp:onDeserialized(data.new)
          data.self:selectWaypoint(data.wp_index)
        end
      )
    end
  end
end

function C:setHover(wp)
  if wp then
    self.path._hover_waypoint_id = wp.id
  else
    self.path._hover_waypoint_id = nil
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
  if self.dragMode == dragModes.gizmo then
    self:updateGizmoTransform(self.waypoint_index)
    editor.drawAxisGizmo()
  else
    self:resetGizmoTransformToOrigin()
  end
  editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)

  self.path._hover_waypoint_id = nil -- clear hover state
  -- if the gizmo is hovered, allow that to have precednce.
  if editor.isAxisGizmoHovered() then return end

  local hoveredWp = self:detectMouseHoverWaypoint()

  if editor.keyModifiers.shift then
    -- local shouldCreateNewPacenote = false
    -- self:createManualWaypoint(shouldCreateNewPacenote)
    self:addMouseWaypointToPacenote()
  elseif editor.keyModifiers.ctrl then
    -- local shouldCreateNewPacenote = true
    -- self:createManualWaypoint(shouldCreateNewPacenote)
    self:createMouseDragPacenote()
  else
    self:handleUnmodifiedMouseInteraction(hoveredWp)
  end
end

function C:draw(mouseInfo)
  self.mouseInfo = mouseInfo
  if self.rallyEditor.allowGizmo() then
    self:handleMouseInput()
  end

  -- draw the non-viewport GUI
  self:drawPacenotesList()

  -- visualize the snap road points with debugDraw.
  -- the same data is utilized separately -- this is just for visualizing.
  if self.dragMode == dragModes.simple_road_snap then
    snaproads.drawSnapRoads(self.mouseInfo)
  end
end

function C:debugDrawNewPacenote(pos_cs, pos_ce)
  local defaultRadius = self.rallyEditor.getPrefDefaultRadius()
  local radius = defaultRadius

  -- local radius = (self.mouseInfo._downPos - self.mouseInfo._holdPos):length()
  -- if radius <= 1 then
  --   radius = defaultRadius
  -- end

  local alpha = 0.8
  local clr_white = {1.0, 1.0, 1.0}
  local clr_light_green = {0.5, 1.0, 0.5}
  local clr_light_red = {1.0, 0.5, 0.5}
  local clr_link = clr_white
  local clr_cs = clr_light_green
  local clr_ce = clr_light_red

  debugDrawer:drawSphere((pos_cs), radius, ColorF(clr_cs[1],clr_cs[2],clr_cs[3],alpha))
  debugDrawer:drawSphere((pos_ce), radius, ColorF(clr_ce[1],clr_ce[2],clr_ce[3],alpha))

  local linkHeightRadiusShinkFactor = 0.5
  local linkFromWidth = 1.0
  local linkToWidth = 0.25
  local fromHeight = radius * linkHeightRadiusShinkFactor
  local toHeight = radius * linkHeightRadiusShinkFactor
  debugDrawer:drawSquarePrism(
    pos_cs,
    pos_ce,
    Point2F(fromHeight, linkFromWidth),
    Point2F(toHeight, linkToWidth),
    ColorF(clr_link[1],clr_link[2],clr_link[3],alpha)
  )

  -- local normal = (self.mouseInfo._holdPos - self.mouseInfo._downPos):normalized()
  -- debugDrawer:drawSquarePrism(
  --   (self.mouseInfo._downPos),
  --   ((self.mouseInfo._downPos) + radius * normal),
  --   Point2F(1,radius/2),
  --   Point2F(0,0),
  --   ColorF(1,1,1,0.5)
  -- )
  -- debugDrawer:drawSquarePrism(
  --   (self.mouseInfo._downPos),
  --   ((self.mouseInfo._downPos) + 0.25 * normal),
  --   Point2F(2,radius*2),
  --   Point2F(0,0),
  --   ColorF(1,1,1,0.4)
  -- )
end

function C:createMouseDragPacenote()
  if not self.path then return end
  if not self.mouseInfo.rayCast then return end

  local txt = "Create new pacenote (Drag to place corner start and end)"

  local pos_rayCast = self.mouseInfo.rayCast.pos
  local pos_cs = self.mouseInfo._downPos
  local pos_ce = self.mouseInfo._holdPos

  -- draw the cursor text
  debugDrawer:drawTextAdvanced(
    vec3(pos_rayCast),
    String(txt),
    ColorF(1,1,1,1),
    true,
    false,
    ColorI(0,0,0,255)
  )

  if self.mouseInfo.hold then
    self:debugDrawNewPacenote(pos_cs, pos_ce)
  elseif self.mouseInfo.up then
    local newPacenote = self.path.pacenotes:create(nil, nil)
    newPacenote.pacenoteWaypoints:create('corner start', pos_cs)
    newPacenote.pacenoteWaypoints:create('corner end', pos_ce)

    editor.history:commitAction("Create pacenote from mouse drag",
      {
        self = self,
        pacenote_data = newPacenote:onSerialize(),
        pacenote_index = newPacenote.id,
      },
      function(data) -- undo
        self.path.pacenotes:remove(data.pacenote_index)
        self:selectPacenote(nil)
      end,
      function(data) -- redo
        local note = self.path.pacenotes:create(nil, data.pacenote_data.oldId)
        note:onDeserialized(data.pacenote_data, {})
        self:selectPacenote(data.pacenote_index)
      end
    )
  end
end

function C:addMouseWaypointToPacenote()
  if not self.path then return end
  if not self.mouseInfo.rayCast then return end

  local pacenote = self:selectedPacenote()
  if not pacenote then return end

  local nextType = pacenote:getNextWaypointType()
  local txt = "Add ".. nextType .." Waypoint to '".. (pacenote.name) .."'"

  local pos_rayCast = self.mouseInfo.rayCast.pos

  -- draw the cursor text
  debugDrawer:drawTextAdvanced(
    vec3(pos_rayCast),
    String(txt),
    ColorF(1,1,1,1),
    true,
    false,
    ColorI(0,0,0,255)
  )

  if self.mouseInfo.down then
    -- local wp = pacenote.pacenoteWaypoints:create(nil, pos_rayCast)

    editor.history:commitAction("Add waypoint to pacenote '".. pacenote.name .."'",
      {
        self = self,
        pos = pos_rayCast,
        wp_data = nil,
        wp_index = nil,
        pacenote_index = pacenote.id,
      },
      function(data) -- undo
        local note = self.path.pacenotes.objects[data.pacenote_index]
        note.pacenoteWaypoints:remove(data.wp_index)
        self:selectPacenote(data.pacenote_index)
      end,
      function(data) -- redo
        local note = self.path.pacenotes.objects[data.pacenote_index]
        local waypoint = note.pacenoteWaypoints:create(nil, data.pos, data.wp_data and data.wp_data.oldId or nil)
        if not data.wp_data then
          data.wp_data = waypoint:onSerialize()
        else
          waypoint:onDeserialized(data.wp_data)
        end
        data.wp_index = waypoint.id
        self:selectWaypoint(waypoint.id)
      end
    )
  end
end

function C:createManualWaypoint(shouldCreateNewPacenote)
  if not self.path then return end
  if not self.mouseInfo.rayCast then return end

  local txt = "Add waypoint to current pacenote"
  if shouldCreateNewPacenote then
    txt = "Create new pacenote (Drag to place corner start and end)"
  end

  -- draw the cursor text
  debugDrawer:drawTextAdvanced(
    vec3(self.mouseInfo.rayCast.pos),
    String(txt),
    ColorF(1,1,1,1),
    true,
    false,
    ColorI(0,0,0,255)
  )

  if self.mouseInfo.hold then
    if shouldCreateNewPacenote then
      self:debugDrawNewPacenote()
    end
  elseif self.mouseInfo.up then
    local created_pacenote_id = nil
    if shouldCreateNewPacenote then
      local pacenote = self.path.pacenotes:create(nil, nil)
      created_pacenote_id = pacenote.id
      self:selectPacenote(pacenote.id)
    end

    editor.history:commitAction("Create Manual Pacenote Waypoint",
      {
        self = self,
        mouseInfo = deepcopy(self.mouseInfo),
        -- wp_index = self.waypoint_index,
        pacenote_index = self.pacenote_index,
        created_pacenote_id = created_pacenote_id,
        normal =(self.mouseInfo._upPos - self.mouseInfo._downPos),
      },
      function(data) -- undo
        if data.wpId then
          data.self:selectedPacenote().pacenoteWaypoints:remove(data.wpId)
        end
        if data.wpIdCE then
          data.self:selectedPacenote().pacenoteWaypoints:remove(data.wpIdCE)
        end
        if data.pacenote_index then
          data.self:selectPacenote(data.pacenote_index)
        end
      end,
      function(data) --redo
        if data.pacenote_index then
          data.self:selectPacenote(data.pacenote_index)
        end
        local note = data.self:selectedPacenote()
        if note then
          -- create a waypoint
          local wp = note.pacenoteWaypoints:create(nil, data.wpId or nil)
          local wpCE = nil

          -- sort new fwdAudio waypoints to the top.
          if wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
            wp.sortOrder = note.pacenoteWaypoints.sorted[1].sortOrder - 1
            local fwdTriggerCount = #note:getAudioTriggerWaypoints()
            if fwdTriggerCount == 1 then
              -- if the one we just added is the only one.
              wp.name = "curr"
            end
          elseif wp.waypointType == waypointTypes.wpTypeDistanceMarker then
            local distMarkerCount = #note:getDistanceMarkerWaypoints()
            wp.name = 'dist'..distMarkerCount
          elseif wp.waypointType == waypointTypes.wpTypeCornerStart then
            wp.name = 'corner start'
            local ce = note:getCornerEndWaypoint()
            if ce then
              wp.sortOrder = ce.sortOrder - 1
            end
          elseif wp.waypointType == waypointTypes.wpTypeCornerEnd then
            wp.name = 'corner end'
            local cs = note:getCornerStartWaypoint()
            if cs then
              wp.sortOrder = cs.sortOrder + 1
            end
          end
          note.pacenoteWaypoints:sort()

          -- if the CornerEnd doesnt exist, also create it.
          if not note:getCornerEndWaypoint() then
            wpCE = note.pacenoteWaypoints:create(nil, data.wpIdCE or nil)
            data.wpIdCE = wpCE.id
          end

          data.wpId = wp.id
          local normal = data.normal
          -- local radius = (data.mouseInfo._downPos - data.mouseInfo._upPos):length()
          -- if radius <= 1 then
          --   radius = defaultRadius
          -- end

          local defaultRadius = self.rallyEditor.getPrefDefaultRadius()
          wp:setManual(data.mouseInfo._downPos, defaultRadius, normal)
          if wpCE then
            wpCE:setManual(data.mouseInfo._upPos, defaultRadius, normal)
          end

          -- data.self:selectWaypoint(wp.id)
        end
      end
    )
  end
end

-- figures out which pacenote to select with the mouse in the 3D scene.
function C:detectMouseHoverWaypoint()
  if not self.path then return end
  if not self.path.pacenotes then return end

  local min_note_dist = 4294967295
  local hover_wp = nil
  local selected_pacenote_i = -1
  local waypoints = {}


  -- figure out which waypoints are available to select.
  for i, pacenote in ipairs(self.path.pacenotes.sorted) do
    -- if a pacenote is selected, then we can only select it's waypoints.
    if self:selectedPacenote() and self:selectedPacenote().id == pacenote.id then
      selected_pacenote_i = i
      for _,waypoint in ipairs(pacenote.pacenoteWaypoints.sorted) do
        if waypoint.waypointType == waypointTypes.wpTypeDistanceMarker and editor_rallyEditor.getPrefShowDistanceMarkers() then
          table.insert(waypoints, waypoint)
        elseif waypoint.waypointType == waypointTypes.wpTypeFwdAudioTrigger and editor_rallyEditor.getPrefShowAudioTriggers() then
          table.insert(waypoints, waypoint)
        else
          table.insert(waypoints, waypoint)
        end
      end
    elseif not self:selectedWaypoint() then
    -- if no waypoint is selected (ie at the PacenoteSelected mode), we can select any corner start.
      local waypoint = pacenote:getCornerStartWaypoint()
      table.insert(waypoints, waypoint)
    end
  end

  -- add waypoints from the previous pacenote.
  if editor_rallyEditor.getPrefShowPreviousPacenote() then
    local prev_i = selected_pacenote_i - 1
    if prev_i > 0 and self:selectedWaypoint() then
      local pn_prev = self.path.pacenotes.sorted[prev_i]
      for _,waypoint in ipairs(pn_prev.pacenoteWaypoints.sorted) do
        table.insert(waypoints, waypoint)
      end
    end
  end

  -- of the available waypoints, figure out the closest one.
  for _, waypoint in ipairs(waypoints) do
    local distNoteToCam = (waypoint.pos - self.mouseInfo.camPos):length()
    local noteRayDistance = (waypoint.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
    local sphereRadius = waypoint.radius
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
  newPos.z = core_terrain.getTerrainHeight(pos)
  return newPos
end

-- returns new position for the drag, and another position for orienting the normal perpendicularly.
function C:wpPosForSimpleDrag(wp, mousePos, mouseOffset)
  if self.dragMode == dragModes.simple then
    if wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
      local newPos = offsetMousePosWithTerrainZSnap(mousePos, mouseOffset)
      local otherWp = wp.pacenote:getCornerStartWaypoint()
      if otherWp then
        return newPos, otherWp.pos
      else
        return newPos, nil
      end
    else
      local newPos = offsetMousePosWithTerrainZSnap(mousePos, mouseOffset)
      return newPos, nil
    end
  elseif self.dragMode == dragModes.simple_road_snap then
    -- if wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
      if self.mouseInfo.rayCast then
        return snaproads.closestSnapPos(self.mouseInfo.rayCast.pos)
      else
        return newPos, nil
      end
    -- else
    --   local newPos = offsetMousePosWithTerrainZSnap(mousePos, mouseOffset)
    --   return newPos, nil
    -- end
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
  if self:selectedWaypoint() then
    self:deleteSelectedWaypoint()
  elseif self:selectedPacenote() then
    self:deleteSelectedPacenote()
  end
end

function C:deleteSelectedWaypoint()
  if not self.path then return end

  editor.history:commitAction(
    "RallyEditor DeleteSelectedWaypoint",
    {index = self.waypoint_index, self = self},
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
    {index = self.pacenote_index, self = self},
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

function C:selectPrevPacenote()
  local notebook = self.path
  local curr = notebook.pacenotes.objects[self.pacenote_index]
  if curr and not curr.missing then
    local prev = notebook.pacenotes.sorted[curr.sortOrder-1]
    if prev then
      self:selectPacenote(prev.id)
    end
  else
    -- if no curr, that means no pacenote was selected, so then select the first one.
    local prev = notebook.pacenotes.sorted[1]
    if prev then
      self:selectPacenote(prev.id)
    end
  end

  if self.rallyEditor.getPrefTopDownCameraFollow() then
    self:setCameraToPacenote()
  end
end

function C:selectNextPacenote()
  local notebook = self.path
  local curr = notebook.pacenotes.objects[self.pacenote_index]
  if curr and not curr.missing then
    local next = notebook.pacenotes.sorted[curr.sortOrder+1]
    if next then
      self:selectPacenote(next.id)
    end
  else
    -- if no curr, that means no pacenote was selected, so then select the first one.
    local next = notebook.pacenotes.sorted[#notebook.pacenotes.sorted]
    if next then
      self:selectPacenote(next.id)
    end
  end

  if self.rallyEditor.getPrefTopDownCameraFollow() then
    self:setCameraToPacenote()
  end
end

function C:cycleDragMode()
  self:resetGizmoTransformToOrigin()

  if self.dragMode == dragModes.simple then
    self.dragMode = dragModes.simple_road_snap
  elseif self.dragMode == dragModes.simple_road_snap then
    -- self.dragMode = dragModes.gizmo
    self.dragMode = dragModes.simple
  -- elseif self.dragMode == dragModes.gizmo then
    -- self.dragMode = dragModes.simple
  end

  -- log('D', logTag, 'cycle dragMode to '..self.dragMode)
end

function C:flipSnaproadNormal()
  local curr = editor.getPreference('rallyEditor.general.flipSnaproadNormal')
  log('D', 'wtf', dumps(curr))
  editor.setPreference('rallyEditor.general.flipSnaproadNormal', not curr)

  local wp = self:selectedWaypoint()
  if wp and wp.waypointType == waypointTypes.wpTypeFwdAudioTrigger then
    wp:flipNormal()
  end
end

function C:drawDebugSegments()
  local racePath = editor_raceEditor.getCurrentPath()
  local pathnodes = racePath.pathnodes.objects
  for _, seg in pairs(racePath.segments.objects) do
    -- seg._drawMode = note.segment == -1 and 'normal' or (note.segment == seg.id and 'normal' or 'faded')

    local from = pathnodes[seg.from]
    local to = pathnodes[seg.to]
    local pn_sel = self:selectedPacenote()

    local alpha = 0.6
    local clr_white = {1,1,1}
    local clr_red = {1,0,0}
    local clr = nil

    if pn_sel and seg.id == pn_sel.segment then
      clr = clr_white
    else
      clr = clr_red
    end

    debugDrawer:drawSquarePrism(
      from.pos,
      to.pos,
      Point2F(10,1),
      Point2F(10,0.25),
      ColorF(clr[1],clr[2],clr[3],alpha)
    )
  end
end

function C:drawPacenotesList()
  if not self.path then return end

  local notebook = self.path

  im.HeaderText(tostring(#notebook.pacenotes.sorted).." Pacenotes")
  -- im.SameLine()
  if im.Button("Clean up names") then
    self.path:cleanupPacenoteNames()
  end
  im.SameLine()
  if im.Button("Auto-assign segments") then
    local racePath = editor_raceEditor.getCurrentPath()
    self.path:autoAssignSegments(racePath)
  end
  im.SameLine()
  if im.Button("Snap all") then
    self:snapAll()
  end
  im.SameLine()
  if im.Button("Set All Radii") then
    if self.path then
      self.path:setAllRadii(self.rallyEditor.getPrefDefaultRadius())
    end
  end
  im.tooltip("Force the radius of all waypoints to the default value.")

  im.BeginChild1("pacenotes", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)
  for i, note in ipairs(notebook.pacenotes.sorted) do
    if im.Selectable1(note.name, note.id == self.pacenote_index) then
      editor.history:commitAction("Select Pacenote",
        {old = self.pacenote_index, new = note.id, self = self},
        selectPacenoteUndo, selectPacenoteRedo)
    end
  end
  im.Separator()
  if im.Selectable1('New...', self.pacenote_index == nil) then
    local pacenote = notebook.pacenotes:create(nil, nil)
    self:selectPacenote(pacenote.id)
  end
  im.tooltip("Ctrl-Drag in the world to create a new pacenote.")
  im.EndChild() -- pacenotes child window

  im.SameLine()
  im.BeginChild1("currentPacenote", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)

  if self.pacenote_index then
    local note = notebook.pacenotes.objects[self.pacenote_index]

    if not note.missing then

    im.HeaderText("Pacenote Info")
    im.Text("Current Pacenote: #" .. self.pacenote_index)
    im.SameLine()
    if im.Button("Delete") then
      self:deleteSelectedPacenote()
    end
    im.SameLine()
    if im.Button("Move Up") then
      editor.history:commitAction("Move Pacenote in List",
        {index = self.pacenote_index, self = self, dir = -1},
        movePacenoteUndo, movePacenoteRedo)
    end
    im.SameLine()
    if im.Button("Move Down") then
      editor.history:commitAction("Move Pacenote in List",
        {index = self.pacenote_index, self = self, dir = 1},
        movePacenoteUndo, movePacenoteRedo)
    end
    im.SameLine()
    if im.Button("Move Camera") then
      self:setCameraToPacenote()
    end

    local editEnded = im.BoolPtr(false)
    editor.uiInputText("Name", pacenoteNameText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("Change Name of Note",
        {index = self.pacenote_index, self = self, old = note.name, new = ffi.string(pacenoteNameText), field = 'name'},
        setPacenoteFieldUndo, setPacenoteFieldRedo)
    end
    -- im.Text("Segment: "..note.segment)

    self:segmentSelector('Segment','segment', 'Associated Segment')

    if self.rallyEditor.getPrefShowRaceSegments() then
      self:drawDebugSegments()
    end

    im.HeaderText("Languages")
    for i,language in ipairs(self.path:getLanguages()) do
      editEnded = im.BoolPtr(false)

      local buf = im.ArrayChar(256, note.notes[language])
      editor.uiInputText(language, buf, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        local newVal = note.notes
        newVal[language] = ffi.string(buf)
        editor.history:commitAction("Change Notes of Pacenote",
          {index = self.pacenote_index, self = self, old = note.notes, new = newVal, field = 'notes'},
          setPacenoteFieldUndo, setPacenoteFieldRedo)
      end
    end

    self:drawWaypointList(note)

    im.EndChild() -- currentPacenote child window

    end -- / if not note.missing then
  end -- / if pacenote_index
end

function C:drawWaypointList(note)
  im.HeaderText("Waypoints")
  im.BeginChild1("waypoints", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)

  for i,waypoint in ipairs(note.pacenoteWaypoints.sorted) do
    if im.Selectable1('['..waypointTypes.shortenWaypointType(waypoint.waypointType)..'] '..waypoint.name, waypoint.id == self.waypoint_index) then
      editor.history:commitAction("Select Waypoint",
        {old = self.waypoint_index, new = waypoint.id, self = self},
        selectWaypointUndo, selectWaypointRedo)
    end
  end

  im.Separator()

  if im.Selectable1('New...', self.waypoint_index == nil) then
    self:selectWaypoint(nil)
  end

  im.tooltip("Shift-Drag in the world to create a new pacenote waypoint.")
  im.EndChild() -- waypoints child window

  im.SameLine()
  im.BeginChild1("currentWaypoint", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)

  if self.waypoint_index then
    local waypoint = note.pacenoteWaypoints.objects[self.waypoint_index]
    if not waypoint.missing then
      im.HeaderText("Waypoint Info")
      im.Text("Current Waypoint: #" .. self.waypoint_index)
      im.SameLine()
      if im.Button("Delete") then
        self:deleteSelectedWaypoint()
      end
      im.SameLine()
      if im.Button("Move Up") then
        editor.history:commitAction("Move Pacenote Waypoint in List",
          {index = self.waypoint_index, self = self, dir = -1},
          moveWaypointUndo, moveWaypointRedo)
      end
      im.SameLine()
      if im.Button("Move Down") then
        editor.history:commitAction("Move Pacenote Waypoint in List",
          {index = self.waypoint_index, self = self, dir = 1},
          moveWaypointUndo, moveWaypointRedo)
      end

      local editEnded = im.BoolPtr(false)
      editor.uiInputText("Name", waypointNameText, nil, nil, nil, nil, editEnded)
      if editEnded[0] then
        editor.history:commitAction("Change Name of Waypoint",
          {index = self.waypoint_index, self = self, old = waypoint.name, new = ffi.string(waypointNameText), field = 'name'},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end

      self:waypointTypeSelector(note)

      waypointPosition[0] = waypoint.pos.x
      waypointPosition[1] = waypoint.pos.y
      waypointPosition[2] = waypoint.pos.z
      if im.InputFloat3("Position", waypointPosition, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        editor.history:commitAction("Change note Position",
          {index = self.waypoint_index, old = waypoint.pos, new = vec3(waypointPosition[0], waypointPosition[1], waypointPosition[2]), field = 'pos', self = self},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end
      if scenetree.findClassObjects("TerrainBlock") and im.Button("Down to Terrain") then
        editor.history:commitAction("Drop Note to Ground",
          {index = self.waypoint_index, old = waypoint.pos,self = self, new = vec3(waypointPosition[0], waypointPosition[1], core_terrain.getTerrainHeight(waypoint.pos)), field = 'pos'},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end
      waypointRadius[0] = waypoint.radius
      if im.InputFloat("Radius",waypointRadius, 0.1, 0.5, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        if waypointRadius[0] < 0 then
          waypointRadius[0] = 0
        end
        editor.history:commitAction("Change Note Size",
          {index = self.waypoint_index, old = waypoint.radius, new = waypointRadius[0], self = self, field = 'radius'},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end

      waypointNormal[0] = waypoint.normal.x
      waypointNormal[1] = waypoint.normal.y
      waypointNormal[2] = waypoint.normal.z
      if im.InputFloat3("Normal", waypointNormal, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
        editor.history:commitAction("Change Normal",
          {index = self.waypoint_index, old = waypoint.normal, self = self, new = vec3(waypointNormal[0], waypointNormal[1], waypointNormal[2])},
          setWaypointNormalUndo, setWaypointNormalRedo)
      end
      if scenetree.findClassObjects("TerrainBlock") and im.Button("Align Normal with Terrain") then
        local normalTip = waypoint.pos + waypoint.normal*waypoint.radius
        normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
        editor.history:commitAction("Align Normal with Terrain",
          {index = self.waypoint_index, old = waypoint.normal, self = self, new = normalTip - waypoint.pos},
          setWaypointNormalUndo, setWaypointNormalRedo)
      end

    end -- / if not waypoint.missing
  end -- / if waypoint_index
  im.EndChild() -- currentWaypoint child window
end

function C:segmentSelector(name, fieldName, tt)
  if not self.path then return end

  local _seg_name = function(seg)
    return '#'..seg.id .. " - '" .. seg.name.."'"
  end

  local racePath = editor_raceEditor.getCurrentPath()
  local selected_pacenote = self.path.pacenotes.objects[self.pacenote_index]
  local segments = racePath.segments.objects

  if im.BeginCombo(name..'##'..fieldName, _seg_name(segments[selected_pacenote[fieldName]])) then
    if im.Selectable1('#'..0 .. " - None", selected_pacenote[fieldName] == -1) then
      editor.history:commitAction("Removed Segment for pacenote",
        {index = self.pacenote_index, self = self, old = selected_pacenote[fieldName], new = -1, field = fieldName},
        setPacenoteFieldUndo, setPacenoteFieldRedo)
    end
    for i, sp in ipairs(racePath.segments.sorted) do
      if im.Selectable1(_seg_name(sp), selected_pacenote[fieldName] == sp.id) then
              editor.history:commitAction("Changed Segment for pacenote",
        {index = self.pacenote_index, self = self, old = selected_pacenote[fieldName], new = sp.id, field = fieldName},
        setPacenoteFieldUndo, setPacenoteFieldRedo)
      end
    end
    im.EndCombo()
  end

  im.tooltip(tt or "")
end

function C:waypointTypeSelector(note)
  if not self:selectedWaypoint() then return end

  local waypoint = note.pacenoteWaypoints.objects[self.waypoint_index]
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
          {index = self.waypoint_index, self = self, old = waypoint[fieldName], new = wt, field = fieldName},
          setWaypointFieldUndo, setWaypointFieldRedo)
      end
    end

    im.EndCombo()
  end

  im.tooltip(tt)
end

-- function C:loadVoices()
--   local voices = readJsonFile(voiceFname)
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

function C:setCameraToPacenote()
  local pacenote = self:selectedPacenote()
  if not pacenote then return end

  pacenote:setCameraToWaypoints()
end

function C:snapAll()
  -- log('D','wtf', 'snapall')
  -- log('D','wtf', dumps(self.path:allWaypoints()))

  for i,wp in pairs(self.path:allWaypoints()) do
    -- log('D','wtf', dumps(wp.pos))
    local newPos, normalAlignPos = snaproads.closestSnapPos(wp.pos)
    wp.pos = newPos
    if normalAlignPos then
      local rv = calculateForwardNormal(newPos, normalAlignPos, false)
      wp.normal = vec3(rv.x, rv.y, rv.z)
    end
  end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
