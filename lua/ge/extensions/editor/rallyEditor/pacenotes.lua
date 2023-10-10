-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt
local im  = ui_imgui
local logTag = 'aipacenotes'

-- notebook form fields
local notebookNameText = im.ArrayChar(1024, "")
local notebookAuthorsText = im.ArrayChar(1024, "")
local notebookDescText = im.ArrayChar(2048, "")

-- pacenote form fields
local pacenoteNameText = im.ArrayChar(1024, "")
local pacenoteNoteText = im.ArrayChar(2048, "")

-- waypoint form fields
local waypointNameText = im.ArrayChar(1024, "")
local waypointPosition = im.ArrayFloat(3)
local waypointNormal = im.ArrayFloat(3)
local waypointRadius = im.FloatPtr(0)

local voiceFname = "/settings/aipacenotes/voices.json"
local voices = {}
local voiceNamesSorted = {}

local C = {}
C.windowDescription = 'Pacenotes'

local function selectNotebookUndo(data)
  data.self:selectNotebook(data.old)
end
local function selectNotebookRedo(data)
  data.self:selectNotebook(data.new)
end

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
  self.notebook_index = nil
  self.pacenote_index = nil
  self.waypoint_index = nil
  self.mouseInfo = {}
end

function C:setPath(path)
  self.path = path
end

function C:selectedNotebook()
  if not self.path then return nil end
  if self.notebook_index then
    return self.path.notebooks.objects[self.notebook_index]
  else
    return nil
  end
end

function C:selectedPacenote()
  if not self:selectedNotebook() then return nil end
  if self.pacenote_index then
    return self:selectedNotebook().pacenotes.objects[self.pacenote_index]
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
  self.notebook_index = nil
  self.pacenote_index = nil
  self.waypoint_index = nil

  if not self.path then return end

  -- select the installed notebook when the pacenotes tab is selected.
  for i,notebook in pairs(self.path.notebooks.objects) do
    if notebook.installed then
      self:selectNotebook(notebook.id)
    end
  end

  if not self:selectedNotebook() then return end

  -- for _, n in pairs(self:selectedNotebook().pacenotes.objects) do
  --   n._drawMode = 'normal'
  -- end

  for _, wp in pairs(self:selectedNotebook():allWaypoints()) do
    wp._drawMode = 'normal'
  end

  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = "Add new waypoint for current pacenote"
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Ctrl] = "Add new waypoint for new pacenote"
  self.map = map.getMap()

  for _, seg in pairs(self.path.segments.objects) do
    seg._drawMode = 'faded'
  end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end
  if not self:selectedNotebook() then return end

  self:selectWaypoint(nil)
  self:selectPacenote(nil)

  -- for _, n in pairs(self:selectedNotebook().pacenotes.objects) do
  --   n._drawMode = 'none'
  -- end
  for _, wp in pairs(self:selectedNotebook():allWaypoints()) do
    wp._drawMode = 'none'
  end

  self:selectNotebook(nil)

  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Shift] = nil
  editor.editModes.raceEditMode.auxShortcuts[editor.AuxControl_Ctrl] = nil
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:selectNotebook(id)
  -- log('D', 'wtf', 'selecting notebook: '..tostring(id))
  self.notebook_index = id
  -- for _, note in pairs(self.path.notebooks.objects) do
  --   note._drawMode = (id == note.id) and 'highlight' or 'normal'
  -- end
  if id then
    self:loadVoices()
    local notebook = self.path.notebooks.objects[id]
    notebookNameText = im.ArrayChar(1024, notebook.name)
  else
    notebookNameText = im.ArrayChar(1024, "")
  end
end

function C:selectPacenote(id)
  log('D', 'wtf', 'selecting pacenote id='..tostring(id))
  self.pacenote_index = id

  -- for _, note in pairs(self:selectedNotebook().pacenotes.objects) do
  --   note._drawMode = (id == note.id) and 'highlight' or 'normal'
  -- end

  if id then
    local note = nil
    local wp = self:selectedWaypoint()
    if not wp or wp.missing then
      note = self:selectedNotebook().pacenotes.objects[id]
      wp = note:getCornerStartWaypoint()
      if wp then
        self:selectWaypoint(wp.id)
      end
    else
      note = wp.note
    end

    pacenoteNameText = im.ArrayChar(1024, note.name)
    pacenoteNoteText = im.ArrayChar(2048, note.note)
  else
    -- for _, seg in pairs(self.path.segments.objects) do
    --   seg._drawmode = 'faded'
    -- end
    pacenoteNameText = im.ArrayChar(1024, "")
    pacenoteNoteText = im.ArrayChar(2048, "")
  end
end

function C:selectWaypoint(id)
  log('D', 'wtf', 'selecting waypoint id='..tostring(id))
  self.waypoint_index = id

  for _, wp in pairs(self:selectedNotebook():allWaypoints()) do
    wp._drawMode = (id == wp.id) and 'highlight' or 'normal'
    log('D', 'wtf', 'waypoint['..wp.id..']: drawMode set to '..wp._drawMode)
  end

  if id then
    -- local waypoint = self:selectedPacenote().pacenoteWaypoints.objects[id]
    local waypoint = self:selectedNotebook():getWaypoint(id)
    log('D', 'wtf', dumps(id))
    self:selectPacenote(waypoint.note.id)
    waypointNameText = im.ArrayChar(1024, waypoint.name)
    self:updateTransform(id)
  else
    waypointNameText = im.ArrayChar(1024, "")
    -- self:selectPacenote(nil)
  end
end

function C:updateTransform(index)
  if not self.rallyEditor.allowGizmo() then return end

  local wp = self:selectedNotebook():getWaypoint(index)
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
  if self.notebook_index then
    self:selectNotebook(self.notebook_index)
  end
end

function C:draw(mouseInfo)
  self.mouseInfo = mouseInfo
  if self.rallyEditor.allowGizmo() then
    editor.updateAxisGizmo(function() self:beginDrag() end, function() self:endDragging() end, function() self:dragging() end)
    self:input()
  end
  self:drawNotebookList()
end

function C:createManualPacenote()
  if not self:selectedNotebook() then return end

end

function C:createManualWaypoint()
  if not self:selectedNotebook() then return end

  if not self.mouseInfo.rayCast then
    return
  end

  local txt = "Add manual Pacenote Waypoint (Drag for Size)"
  debugDrawer:drawTextAdvanced(vec3(self.mouseInfo.rayCast.pos), String(txt), ColorF(1,1,1,1),true, false, ColorI(0,0,0,255))

  if self.mouseInfo.hold then

    local radius = (self.mouseInfo._downPos - self.mouseInfo._holdPos):length()
    if radius <= 1 then
      radius = 5
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
        data.self:selectWaypoint(data.index)
      end,
      function(data) --redo
        -- log('D', 'wtf', dumps(data.self:selectedPacenote()))
        local wp = data.self:selectedPacenote().pacenoteWaypoints:create(nil, data.wpId or nil)
        -- log('D', 'wtf', dumps(wp))
        data.wpId = wp.id
        local normal = data.normal
        local radius = (data.mouseInfo._downPos - data.mouseInfo._upPos):length()
        if radius <= 1 then
          radius = 5
        end
        wp:setManual(data.mouseInfo._downPos, radius, normal)

        data.self:selectWaypoint(wp.id)
      end)
    end
  end
end

-- figures out which pacenote to select with the mouse in the 3D scene.
function C:mouseOverWaypoints()
  if not self:selectedNotebook() then return end
  -- if self:selectedPacenote().missing then return end

  local minNoteDist = 4294967295
  local closestWp = nil

  for _, pacenote in pairs(self:selectedNotebook().pacenotes.objects) do
    for _, waypoint in pairs(pacenote.pacenoteWaypoints.objects) do
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
  return closestWp
end

function C:input()
  if not self.mouseInfo.valid then return end

  if editor.keyModifiers.shift then
    self:createManualWaypoint()
  elseif editor.keyModifiers.ctrl then
    self:createManualPacenote()
  else
    local selectedWp = self:mouseOverWaypoints()
    if self.mouseInfo.down and not editor.isAxisGizmoHovered() then
      if selectedWp then
        self:selectWaypoint(selectedWp.id)
      else
        self:selectWaypoint(nil)
      end
    end
  end
end

-- for pacenote 'Move Up'/'Move Down' buttons, I think?
local function moveNotebookUndo(data)
  data.self.path.notebooks:move(data.index, -data.dir)
end
local function moveNotebookRedo(data)
  data.self.path.notebooks:move(data.index,  data.dir)
end
local function movePacenoteUndo(data)
  data.self:selectedNotebook().pacenotes:move(data.index, -data.dir)
end
local function movePacenoteRedo(data)
  data.self:selectedNotebook().pacenotes:move(data.index,  data.dir)
end
local function moveWaypointUndo(data)
  data.self:selectedPacenote().pacenoteWaypoints:move(data.index, -data.dir)
end
local function moveWaypointRedo(data)
  data.self:selectedPacenote().pacenoteWaypoints:move(data.index,  data.dir)
end

local function setNotebookFieldUndo(data)
  data.self.path.notebooks.objects[data.index][data.field] = data.old
end
local function setNotebookFieldRedo(data)
  data.self.path.notebooks.objects[data.index][data.field] = data.new
end
local function setPacenoteFieldUndo(data)
  data.self:selectedNotebook().pacenotes.objects[data.index][data.field] = data.old
end
local function setPacenoteFieldRedo(data)
  data.self:selectedNotebook().pacenotes.objects[data.index][data.field] = data.new
end
local function setWaypointFieldUndo(data)
  data.self:selectedPacenote().pacenoteWaypoints.objects[data.index][data.field] = data.old
  data.self:updateTransform(data.index)
end
local function setWaypointFieldRedo(data)
  data.self:selectedPacenote().pacenoteWaypoints.objects[data.index][data.field] = data.new
  data.self:updateTransform(data.index)
end

local function setNormalUndo(data)
  data.self:selectedPacenote().pacenoteWaypoints.objects[data.index]:setNormal(data.old)
  data.self:updateTransform(data.index)
end
local function setNormalRedo(data)
  data.self:selectedPacenote().pacenoteWaypoints.objects[data.index]:setNormal(data.new)
  data.self:updateTransform(data.index)
end

function C:drawNotebookList()
  local avail = im.GetContentRegionAvail()

  im.BeginChild1("notebooks", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)
  im.Text("Notebooks")
  im.Separator()
  for i, notebook in pairs(self.path.notebooks.sorted) do
    if im.Selectable1((notebook.installed and '* ' or '')..notebook.name, notebook.id == self.notebook_index) then
      editor.history:commitAction("Select Notebook",
        {old = self.notebook_index, new = notebook.id, self = self},
        selectNotebookUndo, selectNotebookRedo)
    end
  end
  im.Separator()
  if im.Selectable1('New...', self.notebook_index == nil) then
    local notebook = self.path.notebooks:create(nil, nil)
    self:selectNotebook(notebook.id)
  end
  im.EndChild() -- notebooks child window

  if self.notebook_index then
    local notebook = self:selectedNotebook()

    im.SameLine()
    im.BeginChild1("currentNotebook", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)
    im.HeaderText("Notebook Info")
    im.Text("Current Notebook: #" .. self.notebook_index)
    im.SameLine()
    if im.Button("Delete..") then im.OpenPopup("Delete?") end
    -- if im.Button("Delete") then
    if im.BeginPopupModal("Delete?", nil, ImGuiWindowFlags_AlwaysAutoResize) then
      im.Text("Really delete notebook?\n(Actually you can still use Ctrl+z to undo)\n\n")
      -- im.Separator()
      if im.Button("OK", im.ImVec2(120,0)) then
        editor.history:commitAction("Delete Notebook",
        {index = self.notebook_index, self = self},
        function(data) -- undo
          local note = data.self.path.notebooks:create(nil, data.notebookData.oldId)
          note:onDeserialized(data.notebookData, {})
          self:selectNotebook(data.index)
        end,function(data) --redo
          data.notebookData = data.self.path.notebooks.objects[data.index]:onSerialize()
          data.self.path.notebooks:remove(data.index)
          self:selectNotebook(nil)
        end)
      end
      im.SetItemDefaultFocus()
      im.SameLine()
      if im.Button("Cancel", im.ImVec2(120,0)) then im.CloseCurrentPopup() end
      im.EndPopup()
    end

    im.SameLine()
    if im.Button("Move Up") then
      editor.history:commitAction("Move Notebook in List",
        {index = self.notebook_index, self = self, dir = -1},
        moveNotebookUndo, moveNotebookRedo)
    end
    im.SameLine()
    if im.Button("Move Down") then
      editor.history:commitAction("Move Notebook in List",
        {index = self.notebook_index, self = self, dir = 1},
        moveNotebookUndo, moveNotebookRedo)
    end

    im.Text("Installed: " .. tostring(notebook.installed))

    local editEnded = im.BoolPtr(false)
    editor.uiInputText("Name", notebookNameText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("Change Name of Notebook",
        {index = self.notebook_index, self = self, old = notebook.name, new = ffi.string(notebookNameText), field = 'name'},
        setNotebookFieldUndo, setNotebookFieldRedo)
    end

    editEnded = im.BoolPtr(false)
    editor.uiInputText("Authors", notebookAuthorsText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("Change Authors of Notebook",
        {index = self.notebook_index, self = self, old = notebook.authors, new = ffi.string(notebookAuthorsText), field = 'authors'},
        setNotebookFieldUndo, setNotebookFieldRedo)
    end

    editEnded = im.BoolPtr(false)
    editor.uiInputText("Description", notebookDescText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("Change Description of Notebook",
        {index = self.notebook_index, self = self, old = notebook.description, new = ffi.string(notebookDescText), field = 'description'},
        setNotebookFieldUndo, setNotebookFieldRedo)
    end

    self:voicesSelector(notebook)

    self:drawPacenoteList(notebook)

    im.EndChild() -- currentNotebook child window
  end
end

function C:drawPacenoteList(notebook)
  if not notebook then return end

  local avail = im.GetContentRegionAvail()

  im.HeaderText("Pacenotes")
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
    local pacenote = self:selectedNotebook().pacenotes:create(nil, nil)
    self:selectPacenote(pacenote.id)
  end
  im.tooltip("Ctrl-Drag in the world to create a new pacenote.")
  im.EndChild() -- pacenotes child window

  im.SameLine()
  im.BeginChild1("currentPacenote", im.ImVec2(0, 0 ), im.WindowFlags_ChildWindow)

  if self.pacenote_index then
    local note = notebook.pacenotes.objects[self.pacenote_index]

    if not note.missing then

    -- if self.rallyEditor.allowGizmo() then
      -- editor.drawAxisGizmo()
    -- end
    im.HeaderText("Pacenote Info")
    im.Text("Current Pacenote: #" .. self.pacenote_index)
    im.SameLine()
    if im.Button("Delete") then
      editor.history:commitAction("Delete Note",
      {index = self.pacenote_index, self = self},
      function(data) -- undo
        local note = notebook.pacenotes:create(nil, data.noteData.oldId)
        note:onDeserialized(data.noteData, {})
        self:selectPacenote(data.index)
      end,function(data) --redo
        data.noteData = notebook.pacenotes.objects[data.index]:onSerialize()
        notebook.pacenotes:remove(data.index)
        self:selectPacenote(nil)
      end)
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

    local editEnded = im.BoolPtr(false)
    editor.uiInputText("Name", pacenoteNameText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("Change Name of Note",
        {index = self.pacenote_index, self = self, old = note.name, new = ffi.string(pacenoteNameText), field = 'name'},
        setPacenoteFieldUndo, setPacenoteFieldRedo)
    end

    self:segmentSelector('Segment','segment', 'Associated Segment')
    for _, seg in pairs(self.path.segments.objects) do
      seg._drawMode = note.segment == -1 and 'normal' or (note.segment == seg.id and 'normal' or 'faded')
    end

    editEnded = im.BoolPtr(false)
    editor.uiInputText("Note", pacenoteNoteText, nil, nil, nil, nil, editEnded)
    if editEnded[0] then
      editor.history:commitAction("Change Note of Pacenote",
        {index = self.pacenote_index, self = self, old = note.note, new = ffi.string(pacenoteNoteText), field = 'note'},
        setPacenoteFieldUndo, setPacenoteFieldRedo)
    end

    self:drawWaypointList(note)

    im.EndChild() -- currentPacenote child window

    end -- / if not note.missing then
  end -- / if pacenote_index
end

function C:drawWaypointList(note)
  im.HeaderText("Waypoints")
  im.BeginChild1("waypoints", im.ImVec2(125 * im.uiscale[0], 0 ), im.WindowFlags_ChildWindow)

  for i, waypoint in ipairs(note.pacenoteWaypoints.sorted) do
    if im.Selectable1(waypoint.name, waypoint.id == self.waypoint_index) then
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
      editor.drawAxisGizmo()
    end
      
    im.HeaderText("Waypoint Info")
    im.Text("Current Waypoint: #" .. self.waypoint_index)
    im.SameLine()
    if im.Button("Delete") then
      editor.history:commitAction("Delete Pacenote Waypoint",
      {index = self.waypoint_index, self = self},
      function(data) -- undo
        local wp = data.self:selectedPacenote().pacenoteWaypoints:create(nil, data.wpData.oldId)
        wp:onDeserialized(data.wpData)
        self:selectWaypoint(data.index)
      end,function(data) --redo
        data.wpData = data.self:selectedPacenote().pacenoteWaypoints.objects[data.index]:onSerialize()
        data.self:selectedPacenote().pacenoteWaypoints:remove(data.index)
        self:selectWaypoint(nil)
      end)
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
        {index = self.waypoint_index, self = self, old = waypoint.name, new = ffi.string(waypointNameText), field = 'waypointName'},
        setWaypointFieldUndo, setWaypointFieldRedo)
    end

    self:waypointTypeSelector(note)

    waypointPosition[0] = waypoint.pos.x
    waypointPosition[1] = waypoint.pos.y
    waypointPosition[2] = waypoint.pos.z
    if im.InputFloat3("Position", waypointPosition, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
      editor.history:commitAction("Change note Position",
        {index = self.pacenote_index, old = waypoint.pos, new = vec3(waypointPosition[0], waypointPosition[1], waypointPosition[2]), field = 'pos', self = self},
        setWaypointFieldUndo, setWaypointFieldRedo)
    end
    if scenetree.findClassObjects("TerrainBlock") and im.Button("Down to Terrain") then
      editor.history:commitAction("Drop Note to Ground",
        {index = self.pacenote_index, old = waypoint.pos,self = self, new = vec3(waypointPosition[0], waypointPosition[1], core_terrain.getTerrainHeight(waypoint.pos)), field = 'pos'},
        setWaypointFieldUndo, setWaypointFieldRedo)
    end
    waypointRadius[0] = waypoint.radius
    if im.InputFloat("Radius",waypointRadius, 0.1, 0.5, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
      if waypointRadius[0] < 0 then
        waypointRadius[0] = 0
      end
      editor.history:commitAction("Change Note Size",
        {index = self.pacenote_index, old = waypoint.radius, new = waypointRadius[0], self = self, field = 'radius'},
        setWaypointFieldUndo, setWaypointFieldRedo)
    end

    waypointNormal[0] = waypoint.normal.x
    waypointNormal[1] = waypoint.normal.y
    waypointNormal[2] = waypoint.normal.z
    if im.InputFloat3("Normal", waypointNormal, "%0." .. editor.getPreference("ui.general.floatDigitCount") .. "f", im.InputTextFlags_EnterReturnsTrue) then
      editor.history:commitAction("Change Normal",
        {index = self.pacenote_index, old = waypoint.normal, self = self, new = vec3(waypointNormal[0], waypointNormal[1], waypointNormal[2])},
        setNormalUndo, setNormalRedo)
    end
    if scenetree.findClassObjects("TerrainBlock") and im.Button("Align Normal with Terrain") then
      local normalTip = waypoint.pos + waypoint.normal*waypoint.radius
      normalTip = vec3(normalTip.x, normalTip.y, core_terrain.getTerrainHeight(normalTip))
      editor.history:commitAction("Align Normal with Terrain",
        {index = self.pacenote_index, old = waypoint.normal, self = self, new = normalTip - waypoint.pos},
        setNormalUndo, setNormalRedo)
    end

    end -- / if waypoint
  end -- / if waypoint_index
  im.EndChild() -- currentWaypoint child window
end


function C:segmentSelector(name, fieldName, tt)
  if not self:selectedNotebook() then return end

  local node = self:selectedNotebook().pacenotes.objects[self.pacenote_index]
  local objects = self.path.segments.objects

  if im.BeginCombo(name..'##'..fieldName, objects[node[fieldName]].name) then
    if im.Selectable1('#'..0 .. " - None", node[fieldName] == -1) then
      editor.history:commitAction("Removed Segment for pacenote",
        {index = self.pacenote_index, self = self, old = node[fieldName], new = -1, field = fieldName},
        setPacenoteFieldUndo, setPacenoteFieldRedo)
    end
    for i, sp in ipairs(self.path.segments.sorted) do
      if im.Selectable1('#'..i .. " - " .. sp.name, node[fieldName] == sp.id) then
              editor.history:commitAction("Changed Segment for pacenote",
        {index = self.pacenote_index, self = self, old = node[fieldName], new = sp.id, field = fieldName},
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
  local waypointTypes = {
    editor_rallyEditor.wpTypeFwdAudioTrigger,
    editor_rallyEditor.wpTypeRevAudioTrigger,
    editor_rallyEditor.wpTypeCornerStart,
    editor_rallyEditor.wpTypeCornerEnd,
    editor_rallyEditor.wpTypeDistanceMarker,
  }

  local name = 'WaypointType'
  local fieldName = 'waypointType'
  local tt = 'Set the waypointType'

  if im.BeginCombo(name..'##'..fieldName, waypoint.waypointType) then

    for i, wt in ipairs(waypointTypes) do
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

function C:voicesSelector(notebook)
  local name = 'Voice'
  local fieldName = 'voice'
  local tt = 'Set the text-to-speech voice'

  if im.BeginCombo(name..'##'..fieldName, notebook.voice) then

    for i, voice in ipairs(voiceNamesSorted) do
      if im.Selectable1(voice, notebook[fieldName] == voice) then
        editor.history:commitAction("Changed voice for notebook",
          {index = self.notebook_index, self = self, old = notebook[fieldName], new = voice, field = fieldName},
          setNotebookFieldUndo, setNotebookFieldRedo)
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

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
