-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'
local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')

-- notebook form fields
-- local notebookNameText = im.ArrayChar(1024, "")
-- local notebookAuthorsText = im.ArrayChar(1024, "")
-- local notebookDescText = im.ArrayChar(2048, "")

-- pacenote form fields
local pacenoteNameText = im.ArrayChar(1024, "")
-- local pacenoteNoteText = im.ArrayChar(2048, "")

-- waypoint form fields
local waypointNameText = im.ArrayChar(1024, "")
local waypointPosition = im.ArrayFloat(3)
local waypointNormal = im.ArrayFloat(3)
local waypointRadius = im.FloatPtr(0)

-- local voiceFname = "/settings/aipacenotes/voices.json"
-- local voices = {}
-- local voiceNamesSorted = {}

local C = {}
C.windowDescription = 'Pacenotes'

-- local function selectNotebookUndo(data)
--   data.self:selectNotebook(data.old)
-- end
-- local function selectNotebookRedo(data)
--   data.self:selectNotebook(data.new)
-- end

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

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  self.pacenote_index = nil
  self.waypoint_index = nil
  self.mouseInfo = {}
  self._road_snap = false
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
  -- self.notebook_index = nil
  self.pacenote_index = nil
  self.waypoint_index = nil

  if not self.path then return end

  -- for _, n in pairs(self.path.pathnodes.objects) do
  --   n._drawMode = 'none'
  -- end
  -- for _, seg in pairs(self.path.segments.objects) do
  --   seg._drawMode = 'none'
  -- end

  -- select the installed notebook when the pacenotes tab is selected.
  -- for i,notebook in pairs(self.path.notebooks.objects) do
  --   if notebook.installed then
  --     self:selectNotebook(notebook.id)
  --   end
  -- end

  -- if not self.path then return end

  -- for _, n in pairs(self.path.pacenotes.objects) do
  --   n._drawMode = 'normal'
  -- end

  for _, wp in pairs(self.path:allWaypoints()) do
    wp._drawMode = 'normal'
  end

  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Shift] = "Add new waypoint for current pacenote"
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Ctrl] = "Add new waypoint for new pacenote"
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Alt] = "Snap to Road"
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Delete] = "Delete"
  -- self.map = map.getMap()

  -- for _, seg in pairs(self.path.segments.objects) do
  --   seg._drawMode = 'faded'
  -- end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end

  self:selectWaypoint(nil)
  self:selectPacenote(nil)

  -- for _, n in pairs(self.path.pathnodes.objects) do
  --   n._drawMode = 'faded'
  -- end
  -- for _, seg in pairs(self.path.segments.objects) do
  --   seg._drawMode = 'faded'
  -- end

  -- for _, n in pairs(self.path.pacenotes.objects) do
  --   n._drawMode = 'none'
  -- end
  if self.path then
    for _, wp in pairs(self.path:allWaypoints()) do
      wp._drawMode = 'none'
    end
  end

  -- self:selectNotebook(nil)

  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Ctrl] = nil
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Alt] = nil
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_Delete] = nil
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- function C:selectNotebook(id)
--   -- log('D', 'wtf', 'selecting notebook: '..tostring(id))
--   self.notebook_index = id
--   -- for _, notebook in pairs(self.path.notebooks.objects) do
--   --   notebook._drawMode = (id == notebook.id) and 'highlight' or 'normal'
--   -- end
--   if id then
--     self:loadVoices()
--     local notebook = self.path.notebooks.objects[id]
--     notebookNameText = im.ArrayChar(1024, notebook.name)
--   else
--     notebookNameText = im.ArrayChar(1024, "")
--   end
-- end

function C:selectPacenote(id)
  if not self.path then return end
  if not self.path.pacenotes then return end

  -- log('D', 'wtf', 'selecting pacenote id='..tostring(id))
  self.pacenote_index = id

  -- find the pacenotes before and after the selected one.
  local pacenotesSorted = self.path.pacenotes.sorted
  for i, note in ipairs(pacenotesSorted) do
    if self.pacenote_index == note.id then
      local prevNote = pacenotesSorted[i-1]
      local nextNote = pacenotesSorted[i+1]
      note:setAdjacentNotes(prevNote, nextNote)
    else
      note._drawMode = self.waypoint_index and 'undistract' or 'normal'
      note:clearAdjacentNotes()
    end
  end

  -- select the pacenote
  if id then
    local note = self.path.pacenotes.objects[id]
    pacenoteNameText = im.ArrayChar(1024, note.name)
  else
    for _,note in pairs(self.path.pacenotes.objects) do
      note._drawmode = 'normal'
    end
    pacenoteNameText = im.ArrayChar(1024, "")
  end
end

function C:selectWaypoint(id)
  -- log('D', 'wtf', 'begin select waypoint')
  if not self.path then return end
  -- log('D', 'wtf', 'selecting waypoint id='..tostring(id))
  self.waypoint_index = id

  for _, wp in pairs(self.path:allWaypoints()) do
    wp._drawMode = (id == wp.id) and 'highlight' or 'normal'
    -- log('D', 'wtf', 'waypoint['..wp.id..']: drawMode set to '..wp._drawMode)
  end

  if id then
    -- local waypoint = self:selectedPacenote().pacenoteWaypoints.objects[id]
    local waypoint = self.path:getWaypoint(id)
    -- log('D', 'wtf', dumps(id))
    self:selectPacenote(waypoint.pacenote.id)
    waypointNameText = im.ArrayChar(1024, waypoint.name)
    self:updateTransform(id)
  else
    waypointNameText = im.ArrayChar(1024, "")
    -- self:selectPacenote(nil)
    -- I think this fixes the bug where you cant click on a pacenote waypoint anymore.
    -- I think that was due to the Gizmo being present but undrawn, and the gizmo's mouseover behavior was superseding our pacenote hover.
    self:resetGizmoTransformAtOrigin()
  end
end

function C:resetGizmoTransformAtOrigin()
  -- if not self.rallyEditor.allowGizmo() then return end
  local rotation = QuatF(0,0,0,1)
  local transform = rotation:getMatrix()
  local pos = {0, 0, 0}
  transform:setPosition(pos)
  editor.setAxisGizmoTransform(transform)
end

function C:updateTransform(index)
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
  -- log('D', 'wtf', 'beginDrag')
  local wp = self:selectedPacenote().pacenoteWaypoints.objects[self.waypoint_index]
  if not wp or wp.missing then return end

  self.beginDragNoteData = wp:onSerialize()

  if wp.normal then
    self.beginDragRotation = deepcopy(quatFromDir(wp.normal, vec3(0,0,1)))
  end

  self.beginDragRadius = wp.radius

  if wp.mode == 'navgraph' then
    self.beginDragRadius = wp.navRadiusScale
  end
end

function C:dragging()
  if not self:selectedPacenote() then return end
  -- log('D', 'wtf', 'dragging')
  local wp = self:selectedPacenote().pacenoteWaypoints.objects[self.waypoint_index]
  if not wp or wp.missing then return end

  -- update/save our gizmo matrix
  if editor.getAxisGizmoMode() == editor.AxisGizmoMode_Translate then
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
    end)
end

function C:onEditModeActivate()
  -- if self.note then
  --   self:selectPacenote(self.note.id)
  -- end
  -- if self.notebook_index then
    -- self:selectNotebook(self.notebook_index)
  -- end
end

function C:draw(mouseInfo)
  if self.path then
    self.path:drawDebug(self.pacenote_index, self.waypoint_index)
  end

  self.mouseInfo = mouseInfo
  if self.rallyEditor.allowGizmo() then
    editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)
    self:input()
  end
  -- self:drawNotebookList()
  self:drawPacenotesList()

  if self._road_snap then
    self.rallyEditor.getOptionsWindow():drawSnapRoad()
  end
end

function C:dragWithRoadSnap()
end

function C:createManualWaypoint(shouldCreateNewPacenote)
  if not self.path then return end

  if not self.mouseInfo.rayCast then
    return
  end

  local defaultRadius = self.rallyEditor:getOptionsWindow():getPrefDefaultRadius()

  local txt = "Add manual Pacenote Waypoint (Drag for Size)"
  if shouldCreateNewPacenote then
    txt = "Create new Pacenote and add manual Pacenote Waypoint (Drag for Size)"
  end
  debugDrawer:drawTextAdvanced(vec3(self.mouseInfo.rayCast.pos), String(txt), ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))

  if self.mouseInfo.hold then

    local radius = (self.mouseInfo._downPos - self.mouseInfo._holdPos):length()
    if radius <= 1 then
      radius = defaultRadius
    end
    debugDrawer:drawSphere((self.mouseInfo._downPos), radius, ColorF(1,1,1,0.8))
    local normal = (self.mouseInfo._holdPos - self.mouseInfo._downPos):normalized()
    debugDrawer:drawSquarePrism(
      (self.mouseInfo._downPos),
      ((self.mouseInfo._downPos) + radius * normal),
      Point2F(1,radius/2),
      Point2F(0,0),
      ColorF(1,1,1,0.5))
    debugDrawer:drawSquarePrism(
      (self.mouseInfo._downPos),
      ((self.mouseInfo._downPos) + 0.25 * normal),
      Point2F(2,radius*2),
      Point2F(0,0),
      ColorF(1,1,1,0.4))
  else
    if self.mouseInfo.up then
      if shouldCreateNewPacenote then
        local pacenote = self.path.pacenotes:create(nil, nil)
        self:selectPacenote(pacenote.id)
      end

      editor.history:commitAction("Create Manual Pacenote Waypoint",
        {
          mouseInfo = deepcopy(self.mouseInfo),
          index = self.waypoint_index,
          self = self,
          normal =(self.mouseInfo._upPos - self.mouseInfo._downPos),
        },
        function(data) -- undo
          if data.wpId then
            data.self:selectedPacenote().pacenoteWaypoints:remove(data.wpId)
          end
          if data.wpIdCE then
            data.self:selectedPacenote().pacenoteWaypoints:remove(data.wpIdCE)
          end
          data.self:selectWaypoint(data.index)
        end,
        function(data) --redo
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
            local radius = (data.mouseInfo._downPos - data.mouseInfo._upPos):length()
            if radius <= 1 then
              radius = defaultRadius
            end
            wp:setManual(data.mouseInfo._downPos, defaultRadius, normal)
            if wpCE then
              wpCE:setManual(data.mouseInfo._upPos, defaultRadius, normal)
            end

            data.self:selectWaypoint(wp.id)
          end
        end
      )
    end
  end
end

-- figures out which pacenote to select with the mouse in the 3D scene.
function C:mouseOverWaypoints()
  if not self.path then return end
  if not self.path.pacenotes then return end
  -- if self:selectedPacenote().missing then return end

  local minNoteDist = 4294967295
  local closestWp = nil
  local selected_i = -1
  local waypoints = {}

  for i, pacenote in ipairs(self.path.pacenotes.sorted) do
    if self:selectedPacenote() and self:selectedPacenote().id == pacenote.id then
      selected_i = i
      for _,waypoint in ipairs(pacenote.pacenoteWaypoints.sorted) do
        table.insert(waypoints, waypoint)
      end
    elseif not self:selectedWaypoint() then
      local waypoint = pacenote:getCornerStartWaypoint()
      table.insert(waypoints, waypoint)
    end
  end

  local prev_i = selected_i - 1
  if prev_i > 0 and self:selectedWaypoint() then
    local pn_prev = self.path.pacenotes.sorted[prev_i]
    for _,waypoint in ipairs(pn_prev.pacenoteWaypoints.sorted) do
      table.insert(waypoints, waypoint)
    end
  end

  for _, waypoint in ipairs(waypoints) do
    local distNoteToCam = (waypoint.pos - self.mouseInfo.camPos):length()
    local noteRayDistance = (waypoint.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
    local sphereRadius = waypoint.radius
    if noteRayDistance <= sphereRadius then
      if distNoteToCam < minNoteDist then
        minNoteDist = distNoteToCam
        closestWp = waypoint
      end
    end
  end

  -- for idx, waypoint in pairs(self:selectedPacenote().pacenoteWaypoints.objects) do
  --   -- use the corner start marker to represent pacenotes for mouse select purposes.
  --   -- local waypoint = wp:getCornerStartWaypoint()
  --
  --   local distNoteToCam = (waypoint.pos - self.mouseInfo.camPos):length()
  --   local noteRayDistance = (waypoint.pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
  --   local sphereRadius = waypoint.radius
  --   if noteRayDistance <= sphereRadius then
  --     if distNoteToCam < minNoteDist then
  --       minNoteDist = distNoteToCam
  --       closestWp = waypoint
  --     end
  --   end
  -- end

  -- if not closestWp then
    -- log('E', 'wtf', 'closestWP is nil')
  -- end

  return closestWp
end

function C:clearHover()
  self.path._hover_waypoint_id = nil
end

-- local function calculateForwardNormal(snap_pos, next_pos)
--   local forwardNormal = {
--     x = next_pos.x - snap_pos.x,
--     y = next_pos.y - snap_pos.y,
--     z = next_pos.z - snap_pos.z
--   }

--   -- Optionally, normalize the forward normal if needed
--   local magnitude = math.sqrt(forwardNormal.x^2 + forwardNormal.y^2 + forwardNormal.z^2)
--   if magnitude ~= 0 then
--     forwardNormal.x = forwardNormal.x / magnitude
--     forwardNormal.y = forwardNormal.y / magnitude
--     forwardNormal.z = forwardNormal.z / magnitude
--   end

--   return forwardNormal
-- end

-- args are both vec3
local function calculateForwardNormal(snap_pos, next_pos)
  -- Ensure the positions are indeed tables and have three elements
  -- if not (type(snap_pos) == "table" and type(next_pos) == "table") then
    -- error("Positions must be tables.")
  -- end
  -- if not (#snap_pos == 3 and #next_pos == 3) then
    -- error("Positions must have three elements.")
  -- end

  local dx = next_pos.x - snap_pos.x
  local dy = next_pos.y - snap_pos.y
  local dz = next_pos.z - snap_pos.z

  local magnitude = math.sqrt(dx*dx + dy*dy + dz*dz)
  if magnitude == 0 then
    error("The two positions must not be identical.")
  end

  return vec3(dx / magnitude, dy / magnitude, dz / magnitude)
end


function C:setHover(wp)
  if wp then
    self.path._hover_waypoint_id = wp.id
  else
    self.path._hover_waypoint_id = nil
  end
  -- if self.hoverWaypoint == wp then
    -- no change
  -- else
    -- self.hoverWaypoint = wp
    -- log('D', 'wtf', 'hover changed')
  -- end
  -- if self.hoverWaypoint then
    -- log('D', 'wtf', 'yes hover')
  -- else
    -- log('D', 'wtf', 'no hover')
  -- end
end

function C:input()
  if not self.mouseInfo.valid then
    -- log('E', 'wtf', 'mouseInfo is not valid')
    return
  end

  -- log('D', 'wtf', dumps(self.mouseInfo))

  self._road_snap = false
  if editor.keyModifiers.alt then
    self._road_snap = true
  end

  if editor.keyModifiers.shift then
    self:createManualWaypoint(false)
  elseif editor.keyModifiers.ctrl then
    self:createManualWaypoint(true)
  else
    self:clearHover()
    local selectedWp = self:mouseOverWaypoints()

    if self.mouseInfo.down and not editor.isAxisGizmoHovered() then
      if selectedWp then
        local selectedPn = selectedWp.pacenote
        if self:selectedPacenote() and self:selectedPacenote().id == selectedPn.id then
          self:selectWaypoint(selectedWp.id)
        elseif not self:selectedPacenote() or self:selectedPacenote().id ~= selectedPn.id then
          self:selectPacenote(selectedPn.id)
        end
      else
        if self:selectedWaypoint() then
          self:selectWaypoint(nil)
        else
          self:selectPacenote(nil)
        end
      end
    elseif self._road_snap and self.mouseInfo.hold and not editor.isAxisGizmoHovered() then
      -- log("D", 'wtf', dumps(self.mouseInfo._holdPos))
      local new_pos = self.mouseInfo._holdPos
      debugDrawer:drawSphere((new_pos), 2, ColorF(1,0,0,1.0))
      local wp_sel = self:selectedWaypoint()
      if wp_sel then
        if self.mouseInfo.rayCast then
          local snap_pos, next_pos = self.rallyEditor:getOptionsWindow():closestSnapPos(new_pos)
          if snap_pos then
            wp_sel.pos = snap_pos
            if next_pos then
              local rv = calculateForwardNormal(snap_pos, next_pos)
              wp_sel.normal = vec3(rv.x, rv.y, rv.z)
              -- local normalTip = wp_sel.pos + wp_sel.normal*wp_sel.radius
              -- normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
              -- wp_sel.normal = normalTip
            end
          end
        end
      end
    elseif not self.mouseInfo.hold and not self.mouseInfo.up and not self.mouseInfo.down and not editor.isAxisGizmoHovered() then
      self:setHover(selectedWp)
    end
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
  data.self:updateTransform(data.index)
end
local function setWaypointFieldRedo(data)
  data.self:selectedPacenote().pacenoteWaypoints.objects[data.index][data.field] = data.new
  data.self:updateTransform(data.index)
end

local function setWaypointNormalUndo(data)
  local wp = data.self:selectedPacenote().pacenoteWaypoints.objects[data.index]
  if wp then
    wp:setNormal(data.old)
  end
  data.self:updateTransform(data.index)
end
local function setWaypointNormalRedo(data)
  local wp = data.self:selectedPacenote().pacenoteWaypoints.objects[data.index]
  if wp and not wp.missing then
    wp:setNormal(data.new)
  end
  data.self:updateTransform(data.index)
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
      local wp = data.self:selectedPacenote().pacenoteWaypoints:create(nil, data.wpData.oldId)
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
  log('D', logTag, 'hello world: prev')
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

  if self.rallyEditor:getOptionsWindow():getPrefTopDownCameraFollow() then
    self:setCameraToPacenote()
  end
end

function C:selectNextPacenote()
  log('D', logTag, 'hello world: next')
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

  if self.rallyEditor:getOptionsWindow():getPrefTopDownCameraFollow() then
    self:setCameraToPacenote()
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

    if self.rallyEditor:getOptionsWindow():getPrefShowRaceSegments() then
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

    -- only draw the axis gizmo if there is a selected waypoint
    if self.rallyEditor.allowGizmo() then
      if self._road_snap then
        self:resetGizmoTransformAtOrigin()
      else
        self:updateTransform(self.waypoint_index)
        editor.drawAxisGizmo()
      end
    end

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

    end -- / if waypoint
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

function C:loadVoices()
  voices = readJsonFile(voiceFname)
  voiceNamesSorted = {}

  if not voices then
    log('E', logTag, 'unable to load voices file from ' .. tostring(filename))
    voices = {"can't load voices file from "..voiceFname}
    return
  end

  for voiceName, _ in pairs(voices) do
    table.insert(voiceNamesSorted, voiceName)
  end

  table.sort(voiceNamesSorted)

  log('I', logTag, 'reloaded voices from '..voiceFname)
end

function C:setCameraToPacenote()
  local pacenote = self:selectedPacenote()
  if not pacenote then return end

  pacenote:setCameraToWaypoints()
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
