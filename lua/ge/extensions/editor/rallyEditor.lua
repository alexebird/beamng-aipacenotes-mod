local im = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local prefsCopy = require('/lua/ge/extensions/editor/rallyEditor/prefsCopy')
-- local snaproads = require('/lua/ge/extensions/editor/rallyEditor/snaproads')

local M = {}
local logTag = 'rally_editor'

local toolWindowName = "rallyEditor"
local editModeName = "Edit Notebook"
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
local notebookInfoWindow, pacenotesWindow, transcriptsWindow, missionSettingsWindow, staticPacenotesWindow
local currentWindow = {}
local changedWindow = false
local programmaticTabSelect = false

local function select(window)
  currentWindow:unselect()
  currentWindow = window
  currentWindow:setPath(currentPath)
  currentWindow:selected()
  changedWindow = true
end

local function setNotebookRedo(data)
  data.previous = currentPath
  -- data.previousFilepath = previousFilepath
  -- data.previousFilename = previousFilename

  -- previousFilename = data.filename
  -- previousFilepath = data.filepath
  currentPath = data.path
  -- currentPath._dir = previousFilepath
  -- local dir, filename, ext = path.splitWithoutExt(previousFilename, true)
  -- currentPath._fnWithoutExt = filename
  for _, window in ipairs(windows) do
    window:setPath(currentPath)
    -- window:unselect()
  end
  -- currentWindow:selected()
  -- select(notebookInfoWindow)
end

local function setNotebookUndo(data)
  currentPath = data.previous
  -- previousFilename = data.previousFilename
  -- previousFilepath = data.previousFilepath
  for _, window in ipairs(windows) do
    window:setPath(currentPath)
    -- window:unselect()
  end
  -- currentWindow:selected()
  -- select(notebookInfoWindow)
end

local function strip_basename(thepath)
  if not thepath then return nil end

  if thepath:sub(-1) == "/" then
    thepath = thepath:sub(1, -2)
  end
  local dirname, fn, e = path.split(thepath)

  if dirname:sub(-1) == "/" then
    dirname = dirname:sub(1, -2)
  end
  return dirname
end

local function getMissionDir()
  if not currentPath then return nil end
  -- log('D', 'wtf', 'has currentPath')

  -- looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes\notebooks\
  local notebooksDir = currentPath:dir()
  -- log('D', 'wtf', 'notebooksDir: '..notebooksDir)
  local aipDir = strip_basename(notebooksDir)
  -- log('D', 'wtf', 'aipDir: '..aipDir)
  -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes
  local missionDir = strip_basename(aipDir)
  -- log('D', 'wtf', 'missionDir: '..missionDir)
  -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2

  return missionDir
end

-- local function saveNotebook(savePath)
local function saveNotebook()
  -- local notebook = currentPath

  -- if not savePath then
    -- savePath = previousFilepath..previousFilename
    -- savePath = currentPath.fname
  -- end

  if not currentPath then
    log('W', logTag, 'cant save; no notebook loaded.')
    return
  end

  if not currentPath:save() then
    return
  end

  -- local dir, filename, ext = path.split(savePath)
  -- previousFilepath = dir
  -- previousFilename = filename
  -- notebook._dir = dir
  -- local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  -- notebook._fnWithoutExt = fn2

  -- log('D', 'wtf', 'getMD: '..getMissionDir())
  -- log('D', 'wtf', 'aipPath: '..re_util.aipPath)
  -- log('D', 'wtf', 'missionSettigsFname: '..re_util.missionSettingsFname)
  local md = getMissionDir()
  if md then
    local settingsFname = md..'/'..re_util.aipPath..'/'..re_util.missionSettingsFname
    if not FS:fileExists(settingsFname) then
      log('I', logTag, 'creating mission.settings.json at '..settingsFname)
      local settings = require('/lua/ge/extensions/gameplay/notebook/pathMissionSettings')(settingsFname)
      settings.notebook.filename = currentPath:basename()
      local assumedCodriverName = currentPath.codrivers.sorted[1].name
      settings.notebook.codriver = assumedCodriverName
      jsonWriteFile(settingsFname, settings:onSerialize(), true)
    end
  end
end

local function selectPrevPacenote()
  if currentWindow == pacenotesWindow then
    pacenotesWindow:selectPrevPacenote()
  end
end

local function selectNextPacenote()
  if currentWindow == pacenotesWindow then
    pacenotesWindow:selectNextPacenote()
  end
end

local function cycleDragMode()
  if currentWindow == pacenotesWindow then
    pacenotesWindow:cycleDragMode()
  end
end

local function insertMode()
  if currentWindow == pacenotesWindow then
    pacenotesWindow:insertMode()
  end
end

local cameraOrbitState = {
  up = 0,
  down = 0,
  right = 0,
  left = 0,
}
local function cameraOrbitRight(v)
  if pacenotesWindow:selectedPacenote() then
    -- log('D', 'wtf', 'right '..tostring(v))
    cameraOrbitState.right = v
  end
end

local function cameraOrbitLeft(v)
  if pacenotesWindow:selectedPacenote() then
    -- log('D', 'wtf', 'left '..tostring(v))
    cameraOrbitState.left = v
  end
end

local function cameraOrbitUp(v)
  if pacenotesWindow:selectedPacenote() then
    -- log('D', 'wtf', 'up '..tostring(v))
    cameraOrbitState.up = v
  end
end

local function cameraOrbitDown(v)
  if pacenotesWindow:selectedPacenote() then
    -- log('D', 'wtf', 'down '..tostring(v))
    cameraOrbitState.down = v
  end
end

local function loadNotebook(full_filename)
  if not full_filename then
    return
  end
  -- local dir, filename, ext = path.split(full_filename)
  -- log('I', logTag, 'creating empty notebook file at ' .. tostring(dir))
  local json = jsonReadFile(full_filename)
  if not json then
    log('E', logTag, 'couldnt find notebook file')
  end
  -- previousFilepath = dir
  -- previousFilename = filename
  local newPath = require('/lua/ge/extensions/gameplay/notebook/path')()
  newPath:setFname(full_filename)
  newPath:onDeserialized(json)
  -- p._dir = dir
  -- local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  -- p._fnWithoutExt = fn2

  editor.history:commitAction("Set path to " .. newPath.fname,
    -- { path = p, filepath = dir, filename = filename },
    { path = newPath },
    setNotebookUndo,
    setNotebookRedo
  )
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
    local path = require('/lua/ge/extensions/gameplay/notebook/path')()
    editor.history:commitAction(
      "Set path to new path.",
      -- {path = path, filepath = previousFilepath, filename = "new.notebook.json"},
      {path = path},
      setNotebookUndo,
      setNotebookRedo
    )
end

local function drawEditorGui()
  if focusWindow == true then
    im.SetNextWindowFocus()
    focusWindow = false
  end

  local topToolbarHeight = 135 * im.uiscale[0]
  local bottomToolbarHeight = 200 * im.uiscale[0]
  local minMiddleHeight = 500 * im.uiscale[0]
  local heightAdditional = 110-- * im.uiscale[0]

  if editor.beginWindow(toolWindowName, "Rally Editor", im.WindowFlags_MenuBar) then
    if im.BeginMenuBar() then
      if im.BeginMenu("File") then
        -- im.Text(previousFilepath .. previousFilename)
        -- im.Separator()
        if im.MenuItem1("New Notebook") then
          newEmptyNotebook()
        end
        local defaultFileDialogPath = '/gameplay/missions'
        if im.MenuItem1("Load...") then
          editor_fileDialog.openFile(
            function(data)
              loadNotebook(data.filepath)
            end,
            {{"Notebook files",".notebook.json"}},
            false,
            (currentPath and currentPath:dir()) or defaultFileDialogPath
          )
        end
        -- local canSave = currentPath and previousFilepath
        if im.MenuItem1("Save") then
          saveNotebook()
        end
        if im.MenuItem1("Save as...") then
          extensions.editor_fileDialog.saveFile(
            function(data)
              if currentPath then
                currentPath:setFname(data.filepath)
                saveNotebook()
              else
                log('W', logTag, 'cant Save As; no notebook loaded.')
              end
            end,
            {{"Notebook files",".notebook.json"}},
            false,
            (currentPath and currentPath:dir()) or defaultFileDialogPath
          )
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

      if not editor.editMode or editor.editMode.displayName ~= editModeName then
        im.SameLine()
        im.PushStyleColor2(im.Col_Button, im.ImColorByRGB(255,0,0,255).Value)
        if im.Button("Switch to Notebook Editor Editmode", im.ImVec2(im.GetContentRegionAvailWidth(),0)) then
          editor.selectEditMode(editor.editModes.notebookEditMode)
        end
        im.PopStyleColor(1)
      end

      im.Text("Notebook: "..tostring(currentPath.fname))

      im.Text('DragMode: '..pacenotesWindow.dragMode)
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
      local middleChildHeight = windowHeight - topToolbarHeight - bottomToolbarHeight - heightAdditional
      middleChildHeight = math.max(middleChildHeight, minMiddleHeight)

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

      im.BeginChild1("##bottom-toolbar", im.ImVec2(0,bottomToolbarHeight), im.WindowFlags_ChildWindow)
      prefsCopy.pageGui(editor.preferencesRegistry:findCategory('rallyEditor'))
      im.EndChild() -- end bottom-toolbar

      local fg_mgr = editor_flowgraphEditor.getManager()
      local paused = simTimeAuthority.getPause()
      local is_path_cam = core_camera.getActiveCamName() == "path"

      if not is_path_cam and not (fg_mgr and fg_mgr.runningState ~= 'stopped' and not paused) then
        if currentWindow == pacenotesWindow then
          pacenotesWindow:drawDebugEntrypoint()
        elseif currentWindow == transcriptsWindow then
          transcriptsWindow:drawDebugEntrypoint()
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
local function cartesianToSpherical(x, y, z)
  local radius = math.sqrt(x*x + y*y + z*z)
  local theta = math.atan2(y, x)
  local phi = math.acos(z / radius)
  return radius, theta, phi
end

-- Function to convert Spherical coordinates back to Cartesian
local function sphericalToCartesian(radius, theta, phi)
  local x = radius * math.sin(phi) * math.cos(theta)
  local y = radius * math.sin(phi) * math.sin(theta)
  local z = radius * math.cos(phi)
  return x, y, z
end

local function onUpdate()
  local u = cameraOrbitState.up == 1
  local d = cameraOrbitState.down == 1
  local r = cameraOrbitState.right == 1
  local l = cameraOrbitState.left == 1
  local changed = u or d or r or l

  if changed then
    local cameraPosition = core_camera.getPosition()
    local pn = pacenotesWindow:selectedPacenote()
    local wp = pn:getCornerStartWaypoint()
    local targetPosition = wp.pos

    -- Convert to Spherical Coordinates
    local radius, theta, phi = cartesianToSpherical(cameraPosition.x - targetPosition.x, cameraPosition.y - targetPosition.y, cameraPosition.z - targetPosition.z)

    local orbitSpeed = 0.02 -- Adjust as needed

    if editor.keyModifiers.shift then
      orbitSpeed = 0.05
    end

    -- Update theta and phi based on input
    if r then theta = theta + orbitSpeed end
    if l then theta = theta - orbitSpeed end
    if u then phi = phi - orbitSpeed end
    if d then phi = phi + orbitSpeed end

    -- Ensure phi stays within bounds
    phi = math.max(0.1, math.min(math.pi - 0.1, phi))

    -- Convert back to Cartesian Coordinates
    local newX, newY, newZ = sphericalToCartesian(radius, theta, phi)
    local newPos = vec3(newX + targetPosition.x, newY + targetPosition.y, newZ + targetPosition.z)

    -- Set the new camera position and rotation
    core_camera.setPosition(0, newPos)
    -- make the camera look at the center point.
    core_camera.setRotation(0, quatFromDir(targetPosition - newPos))
  end
end

-- works, kinda.
-- local function onUpdate()
--   local u = cameraOrbitState.up == 1
--   local d = cameraOrbitState.down == 1
--   local r = cameraOrbitState.right == 1
--   local l = cameraOrbitState.left == 1
--   local changed = u or d or r or l
--
--   if changed then
--     local cameraPosition = core_camera.getPosition()
--     local pn = pacenotesWindow:selectedPacenote()
--     local wp = pn:getCornerStartWaypoint()
--     local targetPosition = wp.pos
--
--     -- Convert to Spherical Coordinates
--     local radius, theta, phi = cartesianToSpherical(cameraPosition.x, cameraPosition.y, cameraPosition.z)
--
--     local orbitSpeed = 0.01 -- Adjust as needed
--
--     -- Update theta and phi based on input
--     if r then theta = theta + orbitSpeed end
--     if l then theta = theta - orbitSpeed end
--     if u then phi = phi + orbitSpeed end
--     if d then phi = phi - orbitSpeed end
--
--     -- Ensure phi stays within bounds to prevent camera flip
--     phi = math.max(0.1, math.min(math.pi - 0.1, phi))
--
--     -- Convert back to Cartesian Coordinates
--     local newX, newY, newZ = sphericalToCartesian(radius, theta, phi)
--     local newPos = vec3(newX,newY,newZ)
--
--     -- Set the new camera position
--     core_camera.setPosition(0, newPos)
--     core_camera.setRotation(0, quatFromDir(targetPosition - newPos))
--   end
-- end
--
-- this is called after you Ctrl+L to reload lua.
local function onEditorInitialized()
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
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/pacenotes')(M))
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/transcripts')(M))
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/missionSettings')(M))
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/static')(M))

  notebookInfoWindow, pacenotesWindow, transcriptsWindow, missionSettingsWindow, staticPacenotesWindow = windows[1], windows[2], windows[3], windows[4], windows[5]

  for _,win in pairs(windows) do
    win:setPath(currentPath)
  end

  pacenotesWindow:attemptToFixMapEdgeIssue()

  currentWindow = pacenotesWindow
  -- currentWindow:setPath(currentPath) -- redundant?
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
  local data = {
    path = currentPath:onSerialize(),
    currentPathFname = (currentPath and currentPath.fname) or nil
    -- previousFilepath = previousFilepath,
    -- previousFilename = previousFilename
  }
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
    {lockWaypoints = {"bool", false, "Lock position of non-AudioTrigger waypoints.", "Lock non-AudioTrigger waypoints"}},
    {showPreviousPacenote = {"bool", true, "When a pacenote is selected, also render the previous pacenote for reference."}},
    {showNextPacenote = {"bool", true, "When a pacenote is selected, also render the next pacenote for reference."}},
    {showAudioTriggers = {"bool", true, "Render audio triggers in the viewport."}},
    {showDistanceMarkers = {"bool", true, "Render distance markers in the viewport."}},
    {language = {"string", re_util.default_codriver_language, "Language for rally editor display and debug."}},
    {punctuation = {"string", re_util.default_punctuation, "Punctuation character for Normalize."}},
  })

  prefsRegistry:registerSubCategory("rallyEditor", "distanceCalls", "Autofill Distance Calls", {
    {level1Thresh = {"int", 10, "Threshold for level 1", nil, 0, 100}},
    {level2Thresh = {"int", 20, "Threshold for level 2", nil, 0, 100}},
    {level3Thresh = {"int", 40, "Threshold for level 3", nil, 0, 100}},
    {level1Text = {"string", re_util.autodist_internal_level1, "Text for level 1."}},
    {level2Text = {"string", "into", "Text for level 2."}},
    {level3Text = {"string", "and", "Text for level 3."}},
  })

  prefsRegistry:registerSubCategory("rallyEditor", "topDownCamera", nil, {
    {elevation = {"int", 200, "Elevation for the top-down camera view.", nil, 1, 1000}},
    {shouldFollow = {"bool", true, "Make the camera follow pacenote selection with a top-down view."}},
  })

  prefsRegistry:registerSubCategory("rallyEditor", "waypoints", nil, {
    {defaultRadius = {"int", 8, "The default radius for waypoints.", nil, 1, 50}},
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

local function getPrefShowDistanceMarkers()
  return getPreference('rallyEditor.editing.showDistanceMarkers', true)
end

local function getPrefShowAudioTriggers()
  return getPreference('rallyEditor.editing.showAudioTriggers', true)
end

local function getPrefShowPreviousPacenote()
  return getPreference('rallyEditor.editing.showPreviousPacenote', true)
end

local function getPrefShowNextPacenote()
  return getPreference('rallyEditor.editing.showNextPacenote', true)
end

local function getPrefEditingLanguage()
  return getPreference('rallyEditor.editing.language', re_util.default_codriver_language)
end

local function getPrefDefaultPunctuation()
  return getPreference('rallyEditor.editing.punctuation', re_util.default_punctuation)
end

local function getPrefDefaultRadius()
  return getPreference('rallyEditor.waypoints.defaultRadius', 8)
end

local function getPrefUiPacenoteNoteFieldWidth()
  return getPreference('rallyEditor.ui.pacenoteNoteFieldWidth', 300)
end

local function getPrefTopDownCameraElevation()
  return getPreference('rallyEditor.topDownCamera.elevation', 200)
end

local function getPrefTopDownCameraFollow()
  return getPreference('rallyEditor.topDownCamera.shouldFollow', true)
end

local function getPrefLockWaypoints()
  return getPreference('rallyEditor.editing.lockWaypoints', false)
end

local function getPrefLevel1Thresh()
  return getPreference('rallyEditor.distanceCalls.level1Thresh', 10)
end
local function getPrefLevel2Thresh()
  return getPreference('rallyEditor.distanceCalls.level2Thresh', 20)
end
local function getPrefLevel3Thresh()
  return getPreference('rallyEditor.distanceCalls.level3Thresh', 40)
end
local function getPrefLevel1Text()
  return getPreference('rallyEditor.distanceCalls.level1Text', re_util.autodist_internal_level1)
end
local function getPrefLevel2Text()
  return getPreference('rallyEditor.distanceCalls.level2Text', 'into')
end
local function getPrefLevel3Text()
  return getPreference('rallyEditor.distanceCalls.level3Text', 'and')
end

local function loadMissionSettings(folder)
  return re_util.loadMissionSettings(folder)
end

local function listNotebooks(folder)
  if not folder then
    folder = getMissionDir()
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
    folder = getMissionDir()
  end
  log('D', 'wtf', 'detectNotebookToLoad folder: '..folder)
  local settings = loadMissionSettings(folder)

  -- step 1: detect the notebook name from settings file
  -- if mission.settings.json exists, then read it and use the specified notebook fname.
  local notebooksFullPath = folder..'/'..re_util.notebooksPath
  log('D', 'wtf', 'detectNotebookToLoad notebooksfullpath: '..notebooksFullPath)
  local notebookFname = nil

  if settings and settings.notebook and settings.notebook.filename then
    local settingsAbsName = notebooksFullPath..'/'..settings.notebook.filename
    log('D', logTag, 'step 1: '..tostring(settingsAbsName))
    if FS:fileExists(settingsAbsName) then
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
    local defaultNotebookBasename = settings:defaultSettings().notebook.filename
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
M.saveNotebook = saveNotebook
M.onEditorGui = onEditorGui
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onWindowGotFocus = onWindowGotFocus

M.loadMissionSettings = loadMissionSettings
M.detectNotebookToLoad = detectNotebookToLoad
M.listNotebooks = listNotebooks

M.selectPrevPacenote = selectPrevPacenote
M.selectNextPacenote = selectNextPacenote
M.cycleDragMode = cycleDragMode
M.insertMode = insertMode
M.cameraOrbitRight = cameraOrbitRight
M.cameraOrbitLeft = cameraOrbitLeft
M.cameraOrbitUp = cameraOrbitUp
M.cameraOrbitDown = cameraOrbitDown

M.onEditorInitialized = onEditorInitialized
M.getTranscriptsWindow = function() return transcriptsWindow end
M.getPacenotesWindow = function() return pacenotesWindow end
M.getMissionDir = getMissionDir

M.getPrefDefaultRadius = getPrefDefaultRadius
M.getPrefEditingLanguage = getPrefEditingLanguage
M.getPrefDefaultPunctuation = getPrefDefaultPunctuation
M.getPrefLevel1Text = getPrefLevel1Text
M.getPrefLevel1Thresh = getPrefLevel1Thresh
M.getPrefLevel2Text = getPrefLevel2Text
M.getPrefLevel2Thresh = getPrefLevel2Thresh
M.getPrefLevel3Text = getPrefLevel3Text
M.getPrefLevel3Thresh = getPrefLevel3Thresh
M.getPrefLockWaypoints = getPrefLockWaypoints
M.getPrefShowAudioTriggers = getPrefShowAudioTriggers
M.getPrefShowDistanceMarkers = getPrefShowDistanceMarkers
M.getPrefShowNextPacenote = getPrefShowNextPacenote
M.getPrefShowPreviousPacenote = getPrefShowPreviousPacenote
M.getPrefTopDownCameraElevation = getPrefTopDownCameraElevation
M.getPrefTopDownCameraFollow = getPrefTopDownCameraFollow
M.getPrefUiPacenoteNoteFieldWidth = getPrefUiPacenoteNoteFieldWidth

return M
