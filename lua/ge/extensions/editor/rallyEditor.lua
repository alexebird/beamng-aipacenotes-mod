local im = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local prefsCopy = require('/lua/ge/extensions/editor/rallyEditor/prefsCopy')
local SettingsManager = require('/lua/ge/extensions/gameplay/aipacenotes/settingsManager')

local M = {}
local logTag = 'rally_editor'

local toolWindowName = "rallyEditor"
local editModeName = "AI Pacenotes"
local focusWindow = false
local mouseInfo = {}

-- local previousFilepath = "/gameplay/missions/"
-- local previousFilename = "NewNotebook.notebook.json"
-- local currentPathFname = "/gameplay/missions/NewNotebook.notebook.json"
-- local currentPath = require('/lua/ge/extensions/gameplay/notebook/path')()
local currentPath = nil
-- currentPath._fnWithoutExt = 'NewNotebook'
-- currentPath._dir = previousFilepath

local windows = {}
local pacenotesWindow, recceWindow, testWindow
local currentWindow = {}
local changedWindow = false
local programmaticTabSelect = false
local isDev = false

local function devTxtExists()
  return FS:fileExists('dev.txt')
end


-- useful:
-- Engine.Platform.exploreFolder("/replays/")

local function select(window)
  currentWindow:unselect()
  currentWindow = window
  SettingsManager.load(currentPath)
  currentWindow:setPath(currentPath)
  currentWindow:selected()
  changedWindow = true
end

-- local function setNotebookRedo(data)
--   data.previous = currentPath
--   -- data.previousFilepath = previousFilepath
--   -- data.previousFilename = previousFilename
--
--   -- previousFilename = data.filename
--   -- previousFilepath = data.filepath
--   currentPath = data.path
--   -- currentPath._dir = previousFilepath
--   -- local dir, filename, ext = path.splitWithoutExt(previousFilename, true)
--   -- currentPath._fnWithoutExt = filename
--   for _, window in ipairs(windows) do
--     window:setPath(currentPath)
--     -- window:unselect()
--   end
--   -- currentWindow:selected()
--   -- select(notebookInfoWindow)
-- end

-- local function setNotebookUndo(data)
--   currentPath = data.previous
--   -- previousFilename = data.previousFilename
--   -- previousFilepath = data.previousFilepath
--   for _, window in ipairs(windows) do
--     window:setPath(currentPath)
--     -- window:unselect()
--   end
--   -- currentWindow:selected()
--   -- select(notebookInfoWindow)
-- end

-- local function getMissionDir()
--   if not currentPath then return nil end
--
--   -- looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes\notebooks\
--   local notebooksDir = currentPath:dir()
--   -- log('D', 'wtf', 'notebooksDir: '..notebooksDir)
--   local aipDir = re_util.stripBasename(notebooksDir)
--   -- log('D', 'wtf', 'aipDir: '..aipDir)
--   -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes
--   local missionDir = re_util.stripBasename(aipDir)
--   -- log('D', 'wtf', 'missionDir: '..missionDir)
--   -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2
--
--   return missionDir
-- end

local function ensureMissionSettingsFile()
  local md = currentPath:getMissionDir()
  if md then
    local settingsFname = md..'/'..re_util.aipPath..'/'..re_util.missionSettingsFname
    if not FS:fileExists(settingsFname) then
      log('I', logTag, 'creating mission.settings.json at '..settingsFname)
      local settings = require('/lua/ge/extensions/gameplay/notebook/missionSettings')(settingsFname)
      settings.notebook.filename = currentPath:basename()
      local assumedCodriverName = currentPath.codrivers.sorted[1].name
      settings.notebook.codriver = assumedCodriverName
      jsonWriteFile(settingsFname, settings:onSerialize(), true)
    end
  else
    print('ensureMissionSettingsFile nil missionDir')
  end
end

local function saveNotebook()
  if not currentPath then
    log('W', logTag, 'cant save; no notebook loaded.')
    return
  end

  -- currentPath:normalizeNotes()
  if not currentPath:save() then
    return
  end

  ensureMissionSettingsFile()
end

local function selectPrevPacenote()
  if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:selectPrevPacenote()
end

local function selectNextPacenote()
  if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:selectNextPacenote()
end

-- local function cycleDragMode()
--   if currentWindow ~= pacenotesWindow then return end
--   pacenotesWindow:cycleDragMode()
-- end

local function insertMode()
  if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:insertMode()
end

-- local cameraOrbitState = {
--   up = 0,
--   down = 0,
--   right = 0,
--   left = 0,
--   zoomIn = 0,
--   zoomOut = 0,
-- }
-- local function cameraOrbitRight(v)
  -- if currentWindow ~= pacenotesWindow then return end
  -- if pacenotesWindow:selectedPacenote() then
  --   cameraOrbitState.right = v
  -- end
-- end

-- local function cameraOrbitLeft(v)
  -- if currentWindow ~= pacenotesWindow then return end
  -- if pacenotesWindow:selectedPacenote() then
  --   cameraOrbitState.left = v
  -- end
-- end

-- local function cameraOrbitUp(v)
  -- if currentWindow ~= pacenotesWindow then return end
  -- if pacenotesWindow:selectedPacenote() then
  --   cameraOrbitState.up = v
  -- end
-- end

-- local function cameraOrbitDown(v)
  -- if currentWindow ~= pacenotesWindow then return end
  -- if pacenotesWindow:selectedPacenote() then
  --   cameraOrbitState.down = v
  -- end
-- end

-- local function cameraOrbitZoomIn(v)
  -- if currentWindow ~= pacenotesWindow then return end
  -- if pacenotesWindow:selectedPacenote() then
  --   cameraOrbitState.zoomIn = v
  -- end
-- end

-- local function cameraOrbitZoomOut(v)
  -- if currentWindow ~= pacenotesWindow then return end
  -- if pacenotesWindow:selectedPacenote() then
  --   cameraOrbitState.zoomOut = v
  -- end
-- end

local function setFreeCam()
  local lastCamPos = core_camera.getPosition()
  local lastCamRot = core_camera.getQuat()

  core_camera.setByName(0, 'free')
  core_camera.setPosition(0, lastCamPos)
  core_camera.setRotation(0, lastCamRot)
end

local function deselect()
  if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:deselect()
end

local function selectNextWaypoint()
  if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:selectNextWaypoint()
end

local moveWaypointState = {
  debounce = 0.25,
  lastMoveTs = 0,
  forward = 0,
  backward = 0,
}
local function moveSelectedWaypointForward(v)
  if currentWindow ~= pacenotesWindow then return end

  if v == 0 then
    moveWaypointState.lastMoveTs = 0
  end

  moveWaypointState.forward = v
  -- if pacenotesWindow:selectedWaypoint() then
  -- end
end

local function moveSelectedWaypointBackward(v)
  if currentWindow ~= pacenotesWindow then return end

  if v == 0 then
    moveWaypointState.lastMoveTs = 0
  end

  moveWaypointState.backward = v
  -- if pacenotesWindow:selectedWaypoint() then
  -- end
end

local function cameraPathPlay()
  if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:cameraPathPlay()
end

local function toggleCornerCalls()
  if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:toggleCornerCalls()
end

-- local function moveSelectedWaypointForwardFast()
--   pacenotesWindow:moveSelectedWaypointForwardFast()
-- end
--
-- local function moveSelectedWaypointBackwardFast()
--   pacenotesWindow:moveSelectedWaypointBackwardFast()
-- end

local function loadOrCreateNotebook(full_filename)
  if not full_filename then
    return
  end

  local newPath = require('/lua/ge/extensions/gameplay/notebook/path')()
  newPath:setFname(full_filename)

  if not FS:fileExists(full_filename) then
    log('I', logTag, 'notebook file doesnt exist, creating: '..full_filename)
    if not newPath:save() then
      log('E', logTag, 'error saving new notebook')
    end
  else
    local json = jsonReadFile(full_filename)
    if json then
      newPath:onDeserialized(json)
    else
      log('E', logTag, 'couldnt find notebook file')
    end
  end

  currentPath = newPath
  ensureMissionSettingsFile()

  for _, window in ipairs(windows) do
    window:setPath(currentPath)
  end
end

local function loadNotebook(full_filename)
  if not full_filename then
    return
  end

  local json = jsonReadFile(full_filename)
  if not json then
    log('E', logTag, 'couldnt find notebook file')
  end

  local newPath = require('/lua/ge/extensions/gameplay/notebook/path')()
  newPath:setFname(full_filename)
  newPath:onDeserialized(json)

  currentPath = newPath
  for _, window in ipairs(windows) do
    window:setPath(currentPath)
  end
end

local function updateMouseInfo()
  if core_forest.getForestObject() then core_forest.getForestObject():disableCollision() end
  mouseInfo.camPos = core_camera.getPosition()
  mouseInfo.ray = getCameraMouseRay()
  mouseInfo.rayDir = vec3(mouseInfo.ray.dir)
  mouseInfo.rayCast = cameraMouseRayCast()
  mouseInfo.valid = mouseInfo.rayCast and true or false

  if core_forest.getForestObject() then core_forest.getForestObject():enableCollision() end
  if not mouseInfo.valid then
    mouseInfo.down = false
    mouseInfo.hold = false
    mouseInfo.up   = false
  else
    mouseInfo.down =  im.IsMouseClicked(0) and not im.GetIO().WantCaptureMouse
    mouseInfo.hold = im.IsMouseDown(0) and not im.GetIO().WantCaptureMouse
    mouseInfo.up =  im.IsMouseReleased(0) and not im.GetIO().WantCaptureMouse
    if mouseInfo.down then
      mouseInfo.hold = false
      mouseInfo._downPos = vec3(mouseInfo.rayCast.pos)
    end
    if mouseInfo.hold then
      mouseInfo._holdPos = vec3(mouseInfo.rayCast.pos)
    end
    if mouseInfo.up then
      mouseInfo._upPos = vec3(mouseInfo.rayCast.pos)
    end
  end
end

local function newEmptyNotebook()
  local missionDir = currentPath:getMissionDir()
  local notebooksFullPath = missionDir..'/'..re_util.notebooksPath

  local ts = math.floor(re_util.getTime()) -- convert float to int

  local basename = 'roadbook_'..ts..'.'..re_util.notebookFileExt
  local notebookFname = notebooksFullPath..'/'..basename

  loadOrCreateNotebook(notebookFname)
end

local function openMission()
  editor_missionEditor.show()
  local mid = currentPath:missionId()
  if mid then
    editor_missionEditor.setMissionById(mid)
  end
end

local function drawEditorGui()
  if focusWindow == true then
    im.SetNextWindowFocus()
    focusWindow = false
  end

  local topToolbarHeight = 130 * im.uiscale[0]
  -- local bottomToolbarHeight = 500 * im.uiscale[0]
  -- local minMiddleHeight = 300 * im.uiscale[0]
  -- local heightAdditional = 110-- * im.uiscale[0]
  -- local heightAdditional = 0

  if editor.beginWindow(toolWindowName, "Rally Editor", im.WindowFlags_MenuBar) then
  if editor.beginWindow(toolWindowName, "Rally Editor") then
    if im.BeginMenuBar() then
      if im.BeginMenu("File") then
        -- im.Text(previousFilepath .. previousFilename)
        -- im.Separator()
        if im.MenuItem1("New Notebook") then
          newEmptyNotebook()
        end
        -- local defaultFileDialogPath = '/gameplay/missions'
        -- if im.MenuItem1("Load...") then
        --   editor_fileDialog.openFile(
        --     function(data)
        --       loadNotebook(data.filepath)
        --     end,
        --     {{"Notebook files",".notebook.json"}},
        --     false,
        --     (currentPath and currentPath:dir()) or defaultFileDialogPath
        --   )
        -- end
        -- local canSave = currentPath and previousFilepath
        -- if im.MenuItem1("Save") then
        --   saveNotebook()
        -- end
        -- if im.MenuItem1("Save as...") then
        --   extensions.editor_fileDialog.saveFile(
        --     function(data)
        --       if currentPath then
        --         currentPath:setFname(data.filepath)
        --         saveNotebook()
        --       else
        --         log('W', logTag, 'cant Save As; no notebook loaded.')
        --       end
        --     end,
        --     {{"Notebook files",".notebook.json"}},
        --     false,
        --     (currentPath and currentPath:dir()) or defaultFileDialogPath
        --   )
      end
      im.EndMenu()
    end
    im.EndMenuBar()
  end

    if currentPath then
      im.BeginChild1("##top-toolbar", im.ImVec2(0,topToolbarHeight), im.WindowFlags_ChildWindow)

      im.PushStyleColor2(im.Col_Button, im.ImColorByRGB(0,100,0,255).Value)
      if im.Button("Save") then
        saveNotebook()
      end
      im.PopStyleColor(1)

      -- im.SameLine()
      -- if im.Button("Refresh") then
      --   currentPath:reload()
      -- end

      if not editor.editMode or editor.editMode.displayName ~= editModeName then
        im.SameLine()
        im.PushStyleColor2(im.Col_Button, im.ImColorByRGB(255,0,0,255).Value)
        if im.Button("Switch to Notebook Editor Editmode", im.ImVec2(im.GetContentRegionAvailWidth(),0)) then
          editor.selectEditMode(editor.editModes.notebookEditMode)
        end
        im.PopStyleColor(1)
      end
      im.SameLine()
      im.Text(""..tostring(currentPath.fname))

      im.Text("Mission: "..tostring(currentPath:missionId()))
      im.SameLine()
      if im.Button("Open Mission Editor") then
        openMission()
      end

      -- im.Text('DragMode: '..pacenotesWindow.pacenote_tools_state.drag_mode)

      local selParts, selMode = pacenotesWindow:selectionString()

      local clr = im.ImVec4(1, 0.6, 1, 1)
      im.PushFont3('robotomono_regular')
      im.TextColored(clr, 'Selection')
      im.TextColored(clr, '  P: '..(selParts[1] or '-'))
      im.TextColored(clr, '  W: '..(selParts[2] or '-'))
      im.PopFont()
      im.EndChild() -- end top-toolbar

      for i = 1,3 do im.Spacing() end

      local windowSize = im.GetWindowSize()
      local windowHeight = windowSize.y
      -- local middleChildHeight = windowHeight - topToolbarHeight - bottomToolbarHeight - heightAdditional
      local middleChildHeight = 1000
      -- middleChildHeight = math.max(middleChildHeight, minMiddleHeight)

      im.BeginChild1("##tabs-child", im.ImVec2(0,middleChildHeight), im.WindowFlags_ChildWindow and im.ImGuiWindowFlags_NoBorder )
      if im.BeginTabBar("modes") then
        for _, window in ipairs(windows) do

          local flags = nil
          if changedWindow and currentWindow.windowDescription == window.windowDescription then
            flags = im.TabItemFlags_SetSelected
            changedWindow = false
          end

          local hasError = false
          if window.isValid then
            hasError = not window:isValid()
          end

          local tabName = (hasError and '[!] ' or '')..' '..window.windowDescription..' '..'###'..window.windowDescription

          if im.BeginTabItem(tabName, nil, flags) then
            if not programmaticTabSelect and currentWindow.windowDescription ~= window.windowDescription then
              select(window)
            end
            im.EndTabItem()
          end

        end -- for loop
        programmaticTabSelect = false
        im.EndTabBar()
      end -- tab bar

      local tabsHeight = 25 * im.uiscale[0]
      local tabContentsHeight = middleChildHeight - tabsHeight
      im.BeginChild1("##tab-contents-child-window", im.ImVec2(0,tabContentsHeight), im.WindowFlags_ChildWindow and im.ImGuiWindowFlags_NoBorder)
      currentWindow:draw(mouseInfo, tabContentsHeight)
      im.EndChild() -- end top-toolbar

      im.EndChild() -- end tabs-child

      -- im.BeginChild1("##bottom-toolbar", im.ImVec2(0,bottomToolbarHeight), im.WindowFlags_ChildWindow)
      -- im.BeginChild1("##bottom-toolbar", nil, im.WindowFlags_ChildWindow)
      prefsCopy.pageGui(editor.preferencesRegistry:findCategory('rallyEditor'))
      -- im.EndChild() -- end bottom-toolbar

      local fg_mgr = editor_flowgraphEditor.getManager()
      local paused = simTimeAuthority.getPause()
      local is_path_cam = core_camera.getActiveCamName() == "path"

      -- if not is_path_cam and not (fg_mgr and fg_mgr.runningState ~= 'stopped' and not paused) then
      if not is_path_cam then
        if currentWindow == pacenotesWindow then
          pacenotesWindow:drawDebugEntrypoint()
        elseif currentWindow == recceWindow then
          recceWindow:drawDebugEntrypoint()
        elseif currentWindow == testWindow then
          testWindow:drawDebugEntrypoint()
        end
      else
        if currentWindow == pacenotesWindow then
          pacenotesWindow:drawDebugCameraPlaying()
        end
      end
    end
  end

  editor.endWindow()

  if not editor.isWindowVisible(toolWindowName) and editor.editModes and editor.editModes.displayName == editModeName then
    editor.selectEditMode(nil)
  end
end

local function onEditorGui()
  updateMouseInfo()
  drawEditorGui()
end

local function showPacenotesTab()
  programmaticTabSelect = true
  select(pacenotesWindow)
end

local function showRallyTool()
  if editor.isWindowVisible(toolWindowName) == false then
    editor.showWindow(toolWindowName)
    showPacenotesTab()
    editor.selectEditMode(editor.editModes.notebookEditMode)
  else
    focusWindow = true
    showPacenotesTab()
    editor.selectEditMode(editor.editModes.notebookEditMode)
  end
end

local function show()
  editor.clearObjectSelection()
  editor.showWindow(toolWindowName)
  editor.selectEditMode(editor.editModes.notebookEditMode)
end

local function onActivate()
  editor.clearObjectSelection()
  for _, win in ipairs(windows) do
    if win.onEditModeActivate then
      win:onEditModeActivate()
    end
  end
end

local function onDeactivate()
  for _, win in ipairs(windows) do
    if win.onEditModeDeactivate then
      win:onEditModeDeactivate()
    end
  end
  editor.clearObjectSelection()
end

local function onDeleteSelection()
  if not editor.isViewportFocused() then return end

  if currentWindow == pacenotesWindow then
    pacenotesWindow:deleteSelected()
  end
end

-- local u = cameraOrbitState.up == 1 and 'U' or '-'
-- local d = cameraOrbitState.down == 1 and 'D' or '-'
-- local r = cameraOrbitState.right == 1 and 'R' or '-'
-- local l = cameraOrbitState.left == 1 and 'L' or '-'
-- local o = u..d..r..l
-- if o ~= '----' then
--   log('D', 'wtf', 'edit mode on update: '..o)
-- end

-- Function to convert Cartesian coordinates to Spherical coordinates
-- local function cartesianToSpherical(x, y, z)
--   local radius = math.sqrt(x*x + y*y + z*z)
--   local theta = math.atan2(y, x)
--   local phi = math.acos(z / radius)
--   return radius, theta, phi
-- end

-- Function to convert Spherical coordinates back to Cartesian
-- local function sphericalToCartesian(radius, theta, phi)
--   local x = radius * math.sin(phi) * math.cos(theta)
--   local y = radius * math.sin(phi) * math.sin(theta)
--   local z = radius * math.cos(phi)
--   return x, y, z
-- end

local function onUpdate()
  -- local u = cameraOrbitState.up == 1
  -- local d = cameraOrbitState.down == 1
  -- local r = cameraOrbitState.right == 1
  -- local l = cameraOrbitState.left == 1
  -- local zi = cameraOrbitState.zoomIn == 1
  -- local zo = cameraOrbitState.zoomOut == 1
  -- local orbitChanged = u or d or r or l
  -- local zoomChanged = zi or zo

  -- if orbitChanged then
  --   local cameraPosition = core_camera.getPosition()
  --   local pn = pacenotesWindow:selectedPacenote()
  --   if pn then
  --     local wp = pn:getCornerStartWaypoint()
  --     local targetPosition = wp.pos
  --
  --     -- Convert to Spherical Coordinates
  --     local radius, theta, phi = cartesianToSpherical(cameraPosition.x - targetPosition.x, cameraPosition.y - targetPosition.y, cameraPosition.z - targetPosition.z)
  --
  --     local orbitSpeed = 0.025
  --
  --     if editor.keyModifiers.shift then
  --       -- orbitSpeed = 0.05
  --       orbitSpeed = orbitSpeed * 2
  --     end
  --
  --     -- Update theta and phi based on input
  --     if r then theta = theta + orbitSpeed end
  --     if l then theta = theta - orbitSpeed end
  --     if u then phi = phi - orbitSpeed end
  --     if d then phi = phi + orbitSpeed end
  --
  --     -- Ensure phi stays within bounds
  --     phi = math.max(0.1, math.min(math.pi - 0.1, phi))
  --
  --     -- Convert back to Cartesian Coordinates
  --     local newX, newY, newZ = sphericalToCartesian(radius, theta, phi)
  --     local newPos = vec3(newX + targetPosition.x, newY + targetPosition.y, newZ + targetPosition.z)
  --
  --     -- Check and adjust the camera position to ensure it's above the terrain
  --     local terrainHeight = core_terrain.getTerrainHeight(vec3(newPos.x, newPos.z, 0))
  --     terrainHeight = terrainHeight + 5
  --     if newPos.z < terrainHeight then
  --       newPos.z = terrainHeight
  --     end
  --
  --     -- Set the new camera position and rotation
  --     core_camera.setPosition(0, newPos)
  --     -- make the camera look at the center point.
  --     core_camera.setRotation(0, quatFromDir(targetPosition - newPos))
  --   end
  -- end

  -- if zoomChanged then
  --   local zoomStep = 1.6
  --   if editor.keyModifiers.shift then
  --     zoomStep = zoomStep * 4
  --   end
  --
  --   local direction = (zo and 1) or -1
  --   local elevation = editor_rallyEditor.getPrefTopDownCameraElevation()
  --   elevation = elevation + zoomStep*direction
  --   editor_rallyEditor.setPrefTopDownCameraElevation(elevation)
  --
  --   local pn = pacenotesWindow:selectedPacenote()
  --   if pn then
  --     local wp = pn:getCornerStartWaypoint()
  --     re_util.setCameraTarget(wp.pos)
  --   end
  -- end

  local wp_fwd = moveWaypointState.forward == 1
  local wp_bak = moveWaypointState.backward == 1
  local wpMoveChanged = wp_fwd or wp_bak

  if wpMoveChanged then
    local diff = re_util.getTime() - moveWaypointState.lastMoveTs
    local debounce = moveWaypointState.debounce
    local steps = 1

    if editor.keyModifiers.shift then
      debounce = debounce / 8
    end

    if editor.keyModifiers.ctrl then
      if editor.keyModifiers.shift then
        debounce = debounce * 2
      end
      steps = 10
    end

    if diff > debounce then
      moveWaypointState.lastMoveTs = re_util.getTime()
      if wp_fwd then
        pacenotesWindow:moveSelectedWaypointForward(steps)
      elseif wp_bak then
        pacenotesWindow:moveSelectedWaypointBackward(steps)
      end
    end
  end
end

-- this is called after you Ctrl+L to reload lua.
local function onEditorInitialized()
  isDev = devTxtExists()
  print('isDev='..tostring(isDev))

  editor.editModes.notebookEditMode =
  {
    displayName = editModeName,
    onUpdate = onUpdate,
    onActivate = onActivate,
    onDeactivate = onDeactivate,
    onDeleteSelection = onDeleteSelection,
    actionMap = "rallyEditor", -- if available, not required
    auxShortcuts = {},
    --icon = editor.icons.tb_close_track,
    --iconTooltip = "Race Editor"
  }
  editor.editModes.notebookEditMode.auxShortcuts[editor.AuxControl_LMB] = "Select"
  editor.registerWindow(toolWindowName, im.ImVec2(500, 500))
  editor.addWindowMenuItem("Rally Editor", function() show() end,{groupMenuName="Gameplay"})

  prefsCopy.setupCopy()

  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/notebookInfo')(M))

  pacenotesWindow = require('/lua/ge/extensions/editor/rallyEditor/pacenotes')(M)
  table.insert(windows, pacenotesWindow)

  recceWindow = require('/lua/ge/extensions/editor/rallyEditor/recceTab')(M)
  table.insert(windows, recceWindow)

  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/missionSettings')(M))
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/static')(M))

  if isDev then
    testWindow = require('/lua/ge/extensions/editor/rallyEditor/testTab')(M)
    table.insert(windows, testWindow)
  end

  for _,win in pairs(windows) do
    win:setPath(currentPath)
  end

  pacenotesWindow:attemptToFixMapEdgeIssue()

  currentWindow = pacenotesWindow
  currentWindow:selected()
end

local function onEditorToolWindowHide(windowName)
  if windowName == toolWindowName then
    editor.selectEditMode(editor.editModes.objectSelect)
  end
end

local function onWindowGotFocus(windowName)
  if windowName == toolWindowName then
    editor.selectEditMode(editor.editModes.notebookEditMode)
  end
end

local function onSerialize()
  local data = {}

  if currentPath then
    data = {
      path = currentPath:onSerialize(),
      currentPathFname = (currentPath and currentPath.fname) or nil
      -- previousFilepath = previousFilepath,
      -- previousFilename = previousFilename
    }
  end
  return data
end

local function onDeserialized(data)
  if data then
    if data.path then
      currentPath = require('/lua/ge/extensions/gameplay/notebook/path')()
      currentPath:onDeserialized(data.path)
      currentPath:setFname(data.currentPathFname)
    end
    -- previousFilename = data.previousFilename  or "NewNotebook.notebook.json"
    -- previousFilepath = data.previousFilepath or "/gameplay/missions/"
    -- currentPath._dir = previousFilepath
    -- local dir, filename, ext = path.splitWithoutExt(previousFilename, true)
    -- currentPath._fnWithoutExt = filename
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("rallyEditor")

  prefsRegistry:registerSubCategory("rallyEditor", "editing", nil, {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {lockWaypoints = {"bool", false, "Lock position of non-AudioTrigger waypoints.", "Lock non-AudioTrigger waypoints", nil, nil, true}},
    {showAudioTriggers = {"bool", true, "Render audio triggers in the viewport.", nil, nil, nil, true}},
    {showPreviousPacenote = {"bool", true, "When a pacenote is selected, also render the previous pacenote for reference."}},
    {showNextPacenote = {"bool", true, "When a pacenote is selected, also render the next pacenote for reference."}},
  })

  prefsRegistry:registerSubCategory("rallyEditor", "waypoints", nil, {
    {defaultRadius = {"int", 8, "The radius used for displaying waypoints.", "Visual Radius", 1, 50}},
  })

  prefsRegistry:registerSubCategory("rallyEditor", "ui", nil, {
    {pacenoteNoteFieldWidth = {"int", 300, "Width of pacenote notes.note field.", nil, 1, 1000}},
  })
end

local function getPreference(key, default)
  if editor and editor.getPreference then
    return editor.getPreference(key)
  else
    return default
  end
end

local function getPrefShowAudioTriggers()
  return getPreference('rallyEditor.editing.showAudioTriggers', true)
end
local function setPrefShowAudioTriggers(val)
  editor.setPreference("rallyEditor.editing.showAudioTriggers", val)
end

local function getPrefShowPreviousPacenote()
  return getPreference('rallyEditor.editing.showPreviousPacenote', true)
end

local function getPrefShowNextPacenote()
  return getPreference('rallyEditor.editing.showNextPacenote', true)
end

local function getPrefDefaultRadius()
  return getPreference('rallyEditor.waypoints.defaultRadius', re_util.default_waypoint_intersect_radius)
end

local function getPrefUiPacenoteNoteFieldWidth()
  return getPreference('rallyEditor.ui.pacenoteNoteFieldWidth', 300)
end

local function getPrefLockWaypoints()
  return getPreference("rallyEditor.editing.lockWaypoints", false)
end

local function setPrefLockWaypoints(val)
  editor.setPreference("rallyEditor.editing.lockWaypoints", val)
end

local function listNotebooks(folder)
  if not folder then
    folder = currentPath:getMissionDir()
  end
  local notebooksFullPath = folder..'/'..re_util.notebooksPath
  local paths = {}
  log('I', logTag, 'loading all notebook names from '..notebooksFullPath)
  local files = FS:findFiles(notebooksFullPath, '*.notebook.json', -1, true, false)
  for _,fname in pairs(files) do
    table.insert(paths, fname)
  end
  table.sort(paths)

  log("D", logTag, dumps(paths))

  return paths
end

local function detectNotebookToLoad(folder)
  log('D', 'wtf', 'detectNotebookToLoad folder param: '..tostring(folder))
  if not folder then
    folder = currentPath:getMissionDir()
  end
  log('D', 'wtf', 'detectNotebookToLoad folder: '..folder)
  local settings, err = SettingsManager.loadMissionSettingsForMissionDir(folder)
  if err then
    log('D', 'wtf', err)
  end

  -- step 1: detect the notebook name from settings file
  -- if mission.settings.json exists, then read it and use the specified notebook fname.
  local notebooksFullPath = folder..'/'..re_util.notebooksPath
  log('D', 'wtf', 'detectNotebookToLoad notebooksfullpath: '..notebooksFullPath)
  local notebookFname = nil

  if settings and settings.notebook and settings.notebook.filename then
    local settingsAbsName = notebooksFullPath..'/'..settings.notebook.filename
    -- log('D', logTag, 'step 1: '..tostring(settingsAbsName))
    if FS:fileExists(settingsAbsName) then
      log('D', logTag, 'step 1: file exists '..tostring(settingsAbsName))
      notebookFname = settingsAbsName
    end
  end

  log('D', logTag, 'step 1: '..tostring(notebookFname))

  -- step 2: if cant detect from settings file, or it doesnt exist, detect from listing the dir
  if not notebookFname then
    local paths = listNotebooks(folder)
    notebookFname = paths[#paths]
  end

  log('D', logTag, 'step 2: '..tostring(notebookFname))

  -- step 3: if mission settings file doesnt exist, then use the dir-listed name and create the settings file, including reading the first co-driver name.
  -- although, that should be done after the notebook file is read, so maybe this should be done in the rally editor.
  if not notebookFname then
    local defaultNotebookBasename = re_util.default_notebook_basename
    notebookFname = notebooksFullPath..'/'..defaultNotebookBasename
  end

  log('D', logTag, 'detected notebook: '..notebookFname)

  return notebookFname
end

local function getCurrentFilename()
  if currentPath then
    return currentPath.fname
  else
    return nil
  end
end

M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.allowGizmo = function() return editor.editMode and editor.editMode.displayName == editModeName or false end
-- M.getCurrentFilename = function() return previousFilepath..previousFilename end
M.getCurrentFilename = getCurrentFilename
M.getCurrentPath = function() return currentPath end
M.isVisible = function() return editor.isWindowVisible(toolWindowName) end

M.show = show
M.showRallyTool = showRallyTool
M.showPacenotesTab = showPacenotesTab
M.loadNotebook = loadNotebook
M.loadOrCreateNotebook = loadOrCreateNotebook
M.saveNotebook = saveNotebook
M.onEditorGui = onEditorGui
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onWindowGotFocus = onWindowGotFocus

M.detectNotebookToLoad = detectNotebookToLoad
M.listNotebooks = listNotebooks

M.selectPrevPacenote = selectPrevPacenote
M.selectNextPacenote = selectNextPacenote
-- M.cycleDragMode = cycleDragMode
M.insertMode = insertMode

M.setFreeCam = setFreeCam

M.deselect = deselect
M.selectNextWaypoint = selectNextWaypoint
M.moveSelectedWaypointForward = moveSelectedWaypointForward
M.moveSelectedWaypointBackward = moveSelectedWaypointBackward
-- M.moveSelectedWaypointForwardFast = moveSelectedWaypointForwardFast
-- M.moveSelectedWaypointBackwardFast = moveSelectedWaypointBackwardFast
M.cameraPathPlay = cameraPathPlay
M.toggleCornerCalls = toggleCornerCalls

M.onEditorInitialized = onEditorInitialized
-- M.getTranscriptsWindow = function() return recceWindow end
-- M.getPacenotesWindow = function() return pacenotesWindow end

M.getPrefDefaultRadius = getPrefDefaultRadius

M.getPrefLockWaypoints = getPrefLockWaypoints
M.setPrefLockWaypoints = setPrefLockWaypoints

M.getPrefShowAudioTriggers = getPrefShowAudioTriggers
M.setPrefShowAudioTriggers = setPrefShowAudioTriggers

M.getPrefShowNextPacenote = getPrefShowNextPacenote
M.getPrefShowPreviousPacenote = getPrefShowPreviousPacenote

M.getPrefUiPacenoteNoteFieldWidth = getPrefUiPacenoteNoteFieldWidth

return M
