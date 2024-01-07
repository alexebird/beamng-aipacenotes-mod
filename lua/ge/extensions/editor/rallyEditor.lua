  -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}

local logTag = 'rally_editor'
local toolWindowName = "rallyEditor"
local editModeName = "Edit Notebook"
local im = ui_imgui
local previousFilepath = "/gameplay/missions/"
local previousFilename = "NewNotebook.notebook.json"
local windows = {}
local currentWindow = {}
local currentPath = require('/lua/ge/extensions/gameplay/notebook/path')("New Notebook")
currentPath._fnWithoutExt = 'NewNotebook'
currentPath._dir = previousFilepath
local snaproads = require('/lua/ge/extensions/editor/rallyEditor/snaproads')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local notebookInfoWindow, pacenotesWindow, importWindow, raceSettingsWindow
local mouseInfo = {}
local showWaypoints = false

local function setNotebookRedo(data)
  data.previous = currentPath
  data.previousFilepath = previousFilepath
  data.previousFilename = previousFilename

  previousFilename = data.filename
  previousFilepath = data.filepath
  currentPath = data.path
  currentPath._dir = previousFilepath
  local dir, filename, ext = path.splitWithoutExt(previousFilename, true)
  currentPath._fnWithoutExt = filename
  for _, window in ipairs(windows) do
    currentWindow:setPath(currentPath)
    currentWindow:unselect()
  end
  currentWindow:selected()
end

local function setNotebookUndo(data)
  currentPath = data.previous
  previousFilename = data.previousFilename
  previousFilepath = data.previousFilepath
  for _, window in ipairs(windows) do
    currentWindow:setPath(currentPath)
    currentWindow:unselect()
  end
  currentWindow:selected()
end

local function strip_basename(thepath)
  if thepath:sub(-1) == "/" then
    thepath = thepath:sub(1, -2)
  end
  local dirname, fn, e = path.split(thepath)
  return dirname
end

local function getMissionDir()
  if not currentPath then return nil end

  -- looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes\notebooks\
  local notebooksDir = currentPath._dir
  local aipDir = strip_basename(notebooksDir)
  -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes
  local missionDir = strip_basename(aipDir)
  -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2

  return missionDir
end

local function saveNotebook(notebook, savePath)
  if not notebook then notebook = currentPath end
  local json = notebook:onSerialize()
  jsonWriteFile(savePath, json, true)
  local dir, filename, ext = path.split(savePath)
  previousFilepath = dir
  previousFilename = filename
  notebook._dir = dir
  local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  notebook._fnWithoutExt = fn2

  local settingsFname = getMissionDir()..'aipacenotes/mission.settings.json'
  if not FS:fileExists(settingsFname) then
    log('I', logTag, 'creating mission.settings.json at '..settingsFname)
    local settings = require('/lua/ge/extensions/gameplay/notebook/path_mission_settings')(settingsFname)
    settings.notebook.filename = filename
    local assumedCodriverName = notebook.codrivers.sorted[1].name
    settings.notebook.codriver = assumedCodriverName
    jsonWriteFile(settingsFname, settings:onSerialize(), true)
  end
end

local function resetCameraFix()
  -- make the camera facing straight out towards the horizon.
  local rot = quatFromAxisAngle(vec3(0, 0, 1), 0.0)
  core_camera.setRotation(0, rot)
end

local function saveCurrent()
  log('I', logTag, 'saving notebook')
  saveNotebook(currentPath, previousFilepath .. previousFilename)
end

local function selectPrevPacenote()
  pacenotesWindow:selectPrevPacenote()
end

local function selectNextPacenote()
  pacenotesWindow:selectNextPacenote()
end

local function cycleDragMode()
  pacenotesWindow:cycleDragMode()
end

local function flipSnaproadNormal()
  pacenotesWindow:flipSnaproadNormal()
end

local function insertMode()
  pacenotesWindow:insertMode()
end

local function loadNotebook(full_filename)
  if not full_filename then
    return
  end
  local dir, filename, ext = path.split(full_filename)
  -- log('I', logTag, 'creating empty notebook file at ' .. tostring(dir))
  local json = jsonReadFile(full_filename)
  if not json then
    log('E', logTag, 'couldnt find notebook file')
  end
  previousFilepath = dir
  previousFilename = filename
  local p = require('/lua/ge/extensions/gameplay/notebook/path')("New Notebook")
  p:onDeserialized(json)
  p._dir = dir
  local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  p._fnWithoutExt = fn2

  editor.history:commitAction("Set path to " .. p.name,
  {path = p, filepath = dir, filename = filename},
   setNotebookUndo, setNotebookRedo)

  return currentPath
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

local changedWindow = false
local function select(window)
  currentWindow:unselect()
  currentWindow = window
  currentWindow:setPath(currentPath)
  currentWindow:selected()
  changedWindow = true
end

local function findIssues()
  local issues = {}
  -- if not editor.getPreference("raceEditor.general.directionalNodes") then
  --   table.insert(issues, {"Directional nodes disabled. Enable for best-quality races.", nop})
  -- end
  -- local missingNormals = 0
  -- for _, pn in ipairs(currentPath.pathnodes.sorted) do
  --   if not pn.hasNormal then
  --     missingNormals = missingNormals + 1
  --   end
  -- end
  -- if missingNormals > 0 then
  --   table.insert(issues, {missingNormals.." Pathnodes are missing normals.", nop})
  -- end

  -- if currentPath.startPositions.objects[currentPath.defaultStartPosition].missing then
  --   table.insert(issues, {"Default Start Position is missing!", function() select(tlWindow) end })
  -- end
  -- if currentPath.pathnodes.objects[currentPath.startNode].missing then
  --   table.insert(issues, {"Start Pathnode is missing!", function() select(tlWindow) end })
  -- end
  -- for _, seg in ipairs(currentPath.segments.sorted) do
  --   if not seg:isValid() then
  --     table.insert(issues, {seg.name .. " is invalid!", function() select(segWindow) segWindow:selectSegment(seg.id) end})
  --   end
  -- end

  return issues
end

local function newEmptyNotebook()
    local path = require('/lua/ge/extensions/gameplay/notebook/path')("New Notebook")
    editor.history:commitAction(
      "Set path to new path.",
      {path = path, filepath = previousFilepath, filename = "new.notebook.json"},
      setNotebookUndo,
      setNotebookRedo
    )
end

local function drawEditorGui()
  if editor.beginWindow(toolWindowName, "Rally Editor", im.WindowFlags_MenuBar) then
    if im.BeginMenuBar() then
      if im.BeginMenu("File") then
        -- im.Text(previousFilepath .. previousFilename)
        -- im.Separator()
        if im.MenuItem1("New Notebook") then
          newEmptyNotebook()
        end
        if im.MenuItem1("Load...") then
          editor_fileDialog.openFile(function(data) loadNotebook(data.filepath) end, {{"Notebook files",".notebook.json"}}, false, previousFilepath)
        end
        local canSave = currentPath and previousFilepath
        if im.MenuItem1("Save") then
          saveNotebook(currentPath, previousFilepath .. previousFilename)
        end
        if im.MenuItem1("Save as...") then
          extensions.editor_fileDialog.saveFile(
            function(data)
              saveNotebook(currentPath, data.filepath)
            end,
            {{"Notebook files",".notebook.json"}},
            false,
            previousFilepath
          )
        end
        im.EndMenu()
      end
      im.EndMenuBar()
    end

    if not editor.editMode or editor.editMode.displayName ~= editModeName then
      if im.Button("Switch to Notebook Editor Editmode", im.ImVec2(im.GetContentRegionAvailWidth(),0)) then
        editor.selectEditMode(editor.editModes.notebookEditMode)
      end
    end

    im.Text(previousFilepath .. previousFilename)
    im.Separator()

    if im.Button("Save") then
      saveNotebook(currentPath, previousFilepath .. previousFilename)
    end
    im.SameLine()
    if im.Button("Reset Camera") then
      resetCameraFix()
    end
    im.tooltip("There is a bug where the camera rotation can get weird. Fix the camera with this button.")
    im.SameLine()
    if im.Button("Reload Snap Roads") then
      snaproads.loadSnapRoads()
    end
    im.tooltip("Reload AI roads for snapping.\nHappens automatically when you enter Notebook edit mode.")
    im.Text('DragMode: '..pacenotesWindow.dragMode)
    im.SameLine()
    im.Text('| Selection: '..pacenotesWindow:selectionString())
    im.Separator()

    if im.BeginTabBar("modes") then
      for _, window in ipairs(windows) do
        local flags = nil
        if changedWindow and currentWindow.windowDescription == window.windowDescription then
          flags = im.TabItemFlags_SetSelected
          changedWindow = false
        end
        if im.BeginTabItem(window.windowDescription, nil, flags) then
          if currentWindow.windowDescription ~= window.windowDescription then
            select(window)
          end
          im.EndTabItem()
        end
      end
      im.EndTabBar()
    end

    currentWindow:draw(mouseInfo)
    if not showWaypoints then
      pacenotesWindow:drawDebugNotebookEntrypoint()
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

local function show()
  editor.clearObjectSelection()
  editor.showWindow(toolWindowName)
  editor.selectEditMode(editor.editModes.notebookEditMode)
end

local function showPacenotesTab()
  select(pacenotesWindow)
end

local function onActivate()
  editor.clearObjectSelection()
  for _, win in ipairs(windows) do
    if win.onEditModeActivate then
      win:onEditModeActivate()
    end
  end
  snaproads.loadSnapRoads()
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

-- this is called after you Ctrl+L to reload lua.
local function onEditorInitialized()
  editor.editModes.notebookEditMode =
  {
    displayName = editModeName,
    onUpdate = nop,
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

  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/notebook_info')(M))
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/pacenotes')(M))
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/import')(M))
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/race_settings')(M))

  notebookInfoWindow, pacenotesWindow, importWindow, raceSettingsWindow = windows[1], windows[2], windows[3], windows[4]

  for _,win in pairs(windows) do
    win:setPath(currentPath)
  end

  currentWindow = notebookInfoWindow
  currentWindow:setPath(currentPath)
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
    previousFilepath = previousFilepath,
    previousFilename = previousFilename
  }
  return data
end

local function onDeserialized(data)
  if data then
    if data.path then
      currentPath:onDeserialized(data.path)
    end
    previousFilename = data.previousFilename  or "NewNotebook.notebook.json"
    previousFilepath = data.previousFilepath or "/gameplay/missions/"
    currentPath._dir = previousFilepath
    local dir, filename, ext = path.splitWithoutExt(previousFilename, true)
    currentPath._fnWithoutExt = filename
  end
end

local function onEditorRegisterPreferences(prefsRegistry)
  prefsRegistry:registerCategory("rallyEditor")
  prefsRegistry:registerSubCategory("rallyEditor", "general", nil,
  {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {showDistanceMarkers = {"bool", true, "Render distance markers in the viewport."}},
    {showAudioTriggers = {"bool", true, "Render audio triggers in the viewport."}},
    {showPreviousPacenote = {"bool", true, "When a pacenote is selected, also render the previous pacenote for reference."}},
    {showNextPacenote = {"bool", true, "When a pacenote is selected, also render the next pacenote for reference."}},
    -- {showRaceSegments = {"bool", false, "When a pacenote is selected, also render the race segments for reference.\nRequires race to be loaded in the Race Tool."}},
    {defaultWaypointRadius = {"int", 10, "The default radius for waypoints.", nil, 1, 50}},
    {topDownCameraElevation = {"int", 150, "Elevation for the top-down camera view.", nil, 1, 1000}},
    {topDownCameraFollow = {"bool", true, "Make the camera follow pacenote selection with a top-down view."}},
    {flipSnaproadNormal = {"bool", false, "Flip the normal for waypoints during roadsnap editing."}},
  })
end

local function getPrefShowDistanceMarkers()
  if editor and editor.getPreference then
    return editor.getPreference('rallyEditor.general.showDistanceMarkers')
  else
    return true
  end
end

local function getPrefShowAudioTriggers()
  if editor and editor.getPreference then
    return editor.getPreference('rallyEditor.general.showAudioTriggers')
  else
    return true
  end
end

local function getPrefShowPreviousPacenote()
  if editor and editor.getPreference then
    return editor.getPreference('rallyEditor.general.showPreviousPacenote')
  else
    return true
  end
end

local function getPrefShowNextPacenote()
  if editor and editor.getPreference then
    return editor.getPreference('rallyEditor.general.showNextPacenote')
  else
    return true
  end
end

-- local function getPrefShowRaceSegments()
--   if editor and editor.getPreference then
--     return editor.getPreference('rallyEditor.general.showRaceSegments')
--   else
--     return false
--   end
-- end

local function getPrefDefaultRadius()
  if editor and editor.getPreference then
    return editor.getPreference('rallyEditor.general.defaultWaypointRadius')
  else
    return 10
  end
end

local function getPrefTopDownCameraElevation()
  if editor and editor.getPreference then
    return editor.getPreference('rallyEditor.general.topDownCameraElevation')
  else
    return 150
  end
end

local function getPrefTopDownCameraFollow()
  if editor and editor.getPreference then
    return editor.getPreference('rallyEditor.general.topDownCameraFollow')
  else
    return true
  end
end

local function getPrefFlipSnaproadNormal()
  if editor and editor.getPreference then
    return editor.getPreference('rallyEditor.general.flipSnaproadNormal')
  else
    return false
  end
end

local function loadMissionSettings(folder)
  local settingsFname = folder..'/aipacenotes/mission.settings.json'
  local settings = require('/lua/ge/extensions/gameplay/notebook/path_mission_settings')(settingsFname)

  if FS:fileExists(settingsFname) then
    local json = jsonReadFile(settingsFname)
    if not json then
      log('E', 'aipacenotes', 'error reading mission.settings.json file: ' .. tostring(settingsFname))
      return nil
    else
      settings:onDeserialized(json)
    end
  end

  return settings
end

local function listNotebooks(folder)
  if not folder then
    folder = getMissionDir()
  end
  local notebooksFullPath = folder..re_util.notebooksPath
  local paths = {}
  local files = FS:findFiles(notebooksFullPath, '*.notebook.json', -1, true, false)
  for _,fname in pairs(files) do
    table.insert(paths, fname)
  end
  table.sort(paths)
  return paths
end

local function detectNotebookToLoad(folder)
  local settings = loadMissionSettings(folder)

  -- step 1: detect the notebook name from settings file
  -- if mission.settings.json exists, then read it and use the specified notebook fname.
  -- local notebookBasename = nil
  local notebooksFullPath = folder..'/'..re_util.notebooksPath
  local notebookFname = nil

  if settings.notebook.filename then
    local settingsAbsName = notebooksFullPath..settings.notebook.filename
    if FS:fileExists(settingsAbsName) then
      notebookFname = settingsAbsName
    end
  end

  -- step 2: if cant detect from settings file, or it doesnt exist, detect from listing the dir
  if not notebookFname then
    -- local paths = {}
    -- local files = FS:findFiles(notebooksFullPath, '*.notebook.json', -1, true, false)
    -- for _,fname in pairs(files) do
    --   table.insert(paths, fname)
    -- end
    -- table.sort(paths)
    local paths = listNotebooks(folder)
    notebookFname = paths[#paths]
  end

  -- step 3: if mission settings file doesnt exist, then use the dir-listed name and create the settings file, including reading the first co-driver name.
  -- although, that should be done after the notebook file is read, so maybe this should be done in the rally editor.
  if not notebookFname then
    local defaultNotebookBasename = settings:defaultSettings().notebook.filename
    notebookFname = notebooksFullPath..defaultNotebookBasename
  end

  return notebookFname
end

M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.allowGizmo = function() return editor.editMode and editor.editMode.displayName == editModeName or false end
M.getCurrentFilename = function() return previousFilepath..previousFilename end
M.getCurrentPath = function() return currentPath end
M.isVisible = function() return editor.isWindowVisible(toolWindowName) end
M.changedFromExternal = function() currentWindow:setPath(currentPath) end
M.show = show
M.showPacenotesTab = showPacenotesTab
M.loadNotebook = loadNotebook
M.saveNotebook = saveNotebook
M.saveCurrent = saveCurrent
M.onEditorGui = onEditorGui
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onWindowGotFocus = onWindowGotFocus

M.loadMissionSettings = loadMissionSettings
M.detectNotebookToLoad = detectNotebookToLoad

M.selectPrevPacenote = selectPrevPacenote
M.selectNextPacenote = selectNextPacenote
M.cycleDragMode = cycleDragMode
M.flipSnaproadNormal = flipSnaproadNormal
M.insertMode = insertMode

M.onEditorInitialized = onEditorInitialized
-- M.getToolsWindow = function() return toolsWindow end
M.getMissionDir = getMissionDir

M.getPrefShowDistanceMarkers = getPrefShowDistanceMarkers
M.getPrefShowAudioTriggers = getPrefShowAudioTriggers
M.getPrefShowPreviousPacenote = getPrefShowPreviousPacenote
M.getPrefShowNextPacenote = getPrefShowNextPacenote
-- M.getPrefShowRaceSegments = getPrefShowRaceSegments
M.getPrefDefaultRadius = getPrefDefaultRadius
M.getPrefTopDownCameraElevation = getPrefTopDownCameraElevation
M.getPrefTopDownCameraFollow = getPrefTopDownCameraFollow
M.getPrefFlipSnaproadNormal = getPrefFlipSnaproadNormal

M.listNotebooks = listNotebooks
M.showWaypoints = function(show) showWaypoints = show end

return M
