-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

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

local previousFilepath = "/gameplay/missions/"
local previousFilename = "NewNotebook.notebook.json"
local currentPath = require('/lua/ge/extensions/gameplay/notebook/path')("New Notebook")
currentPath._fnWithoutExt = 'NewNotebook'
currentPath._dir = previousFilepath

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
  data.previousFilepath = previousFilepath
  data.previousFilename = previousFilename

  previousFilename = data.filename
  previousFilepath = data.filepath
  currentPath = data.path
  currentPath._dir = previousFilepath
  local dir, filename, ext = path.splitWithoutExt(previousFilename, true)
  currentPath._fnWithoutExt = filename
  for _, window in ipairs(windows) do
    window:setPath(currentPath)
    -- window:unselect()
  end
  -- currentWindow:selected()
  -- select(notebookInfoWindow)
end

local function setNotebookUndo(data)
  currentPath = data.previous
  previousFilename = data.previousFilename
  previousFilepath = data.previousFilepath
  for _, window in ipairs(windows) do
    window:setPath(currentPath)
    -- window:unselect()
  end
  -- currentWindow:selected()
  -- select(notebookInfoWindow)
end

local function strip_basename(thepath)
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
  local notebooksDir = currentPath._dir
  -- log('D', 'wtf', 'notebooksDir: '..notebooksDir)
  local aipDir = strip_basename(notebooksDir)
  -- log('D', 'wtf', 'aipDir: '..aipDir)
  -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2\aipacenotes
  local missionDir = strip_basename(aipDir)
  -- log('D', 'wtf', 'missionDir: '..missionDir)
  -- now looks like: C:\...gameplay\missions\pikespeak\rallyStage\aip-pikes-peak-2

  return missionDir
end

local function saveNotebook(notebook, savePath)
  if not notebook then notebook = currentPath end
  -- local json = notebook:onSerialize()
  -- jsonWriteFile(savePath, json, true)
  if not notebook:save(savePath) then
    return
  end
  local dir, filename, ext = path.split(savePath)
  previousFilepath = dir
  previousFilename = filename
  notebook._dir = dir
  local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  notebook._fnWithoutExt = fn2

  -- log('D', 'wtf', 'getMD: '..getMissionDir())
  -- log('D', 'wtf', 'aipPath: '..re_util.aipPath)
  -- log('D', 'wtf', 'missionSettigsFname: '..re_util.missionSettingsFname)
  local settingsFname = getMissionDir()..'/'..re_util.aipPath..'/'..re_util.missionSettingsFname
  if not FS:fileExists(settingsFname) then
    log('I', logTag, 'creating mission.settings.json at '..settingsFname)
    local settings = require('/lua/ge/extensions/gameplay/notebook/pathMissionSettings')(settingsFname)
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
    { path = p, filepath = dir, filename = filename },
    setNotebookUndo,
    setNotebookRedo
  )

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

    im.BeginChild1("##top-toolbar", im.ImVec2(0,topToolbarHeight), im.WindowFlags_ChildWindow)

    im.PushStyleColor2(im.Col_Button, im.ImColorByRGB(0,100,0,255).Value)
    if im.Button("Save") then
      saveNotebook(currentPath, previousFilepath .. previousFilename)
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

    -- for i = 1,3 do im.Spacing() end

    -- im.SameLine()
    -- if im.Button("Reset Camera") then
      -- resetCameraFix()
    -- end
    -- im.tooltip("There is a bug where the camera rotation can get weird. Fix the camera with this button.")

    -- im.SameLine()
    -- if im.Button("Reload Snap Roads") then
    --   snaproads.loadSnapRoads()
    -- end
    -- im.tooltip("Reload AI roads for snapping.\nHappens automatically when you enter Notebook edit mode.")

    -- im.Text("Currently Loaded Notebook:")
    im.Text("Notebook: "..previousFilepath .. previousFilename)
    -- im.Separator()

    im.Text('DragMode: '..pacenotesWindow.dragMode)
    -- im.SameLine()
    local selParts, selMode = pacenotesWindow:selectionString()

    local clr = im.ImVec4(1, 0.6, 1, 1)
    im.PushFont3('robotomono_regular')
    -- im.TextColored(clr, 'Selection ['..selMode..']: '..selStr)
    -- im.TextColored(clr, 'Selection ['..selMode..']')
    im.TextColored(clr, 'Selection')
    im.TextColored(clr, '  P: '..(selParts[1] or '-'))
    im.TextColored(clr, '  W: '..(selParts[2] or '-'))
    im.PopFont()
    -- im.Separator()
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
          -- log('D', 'wtf', 'currentWindow: '..tostring(currentWindow.windowDescription))
          -- log('D', 'wtf', 'changedWindow')
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
            -- log('D', 'wtf', 'clicked on: '..tostring(window.windowDescription))
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
  -- snaproads.loadSnapRoads()
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
  prefsRegistry:registerSubCategory("rallyEditor", "editing", nil, {
    -- {name = {type, default value, desc, label (nil for auto Sentence Case), min, max, hidden, advanced, customUiFunc, enumLabels}}
    {lockWaypoints = {"bool", false, "Lock position of non-AudioTrigger waypoints."}},
    {showPreviousPacenote = {"bool", true, "When a pacenote is selected, also render the previous pacenote for reference."}},
    {showNextPacenote = {"bool", true, "When a pacenote is selected, also render the next pacenote for reference."}},
    {showAudioTriggers = {"bool", true, "Render audio triggers in the viewport."}},
    {showDistanceMarkers = {"bool", true, "Render distance markers in the viewport."}},
    -- {showRaceSegments = {"bool", false, "When a pacenote is selected, also render the race segments for reference.\nRequires race to be loaded in the Race Tool."}},
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

-- local function getPrefShowRaceSegments()
--     return getPreference('rallyEditor.general.showRaceSegments', false)
-- end

local function getPrefDefaultRadius()
  return getPreference('rallyEditor.waypoints.defaultRadius', 8)
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
  -- local settingsFname = folder..'/'..re_util.aipPath..'/'..re_util.missionSettingsFname
  -- local settings = require('/lua/ge/extensions/gameplay/notebook/pathMissionSettings')(settingsFname)
  --
  -- if FS:fileExists(settingsFname) then
  --   local json = jsonReadFile(settingsFname)
  --   if not json then
  --     log('E', 'aipacenotes', 'error reading mission.settings.json file: ' .. tostring(settingsFname))
  --     return nil
  --   else
  --     settings:onDeserialized(json)
  --   end
  -- end
  --
  -- return settings
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
    -- local paths = {}
    -- local files = FS:findFiles(notebooksFullPath, '*.notebook.json', -1, true, false)
    -- for _,fname in pairs(files) do
    --   table.insert(paths, fname)
    -- end
    -- table.sort(paths)
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

M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.allowGizmo = function() return editor.editMode and editor.editMode.displayName == editModeName or false end
M.getCurrentFilename = function() return previousFilepath..previousFilename end
M.getCurrentPath = function() return currentPath end
M.isVisible = function() return editor.isWindowVisible(toolWindowName) end
-- M.changedFromExternal = function() currentWindow:setPath(currentPath) end
M.show = show
M.showRallyTool = showRallyTool
M.showPacenotesTab = showPacenotesTab
M.loadNotebook = loadNotebook
M.saveNotebook = saveNotebook
M.saveCurrent = saveCurrent
M.onEditorGui = onEditorGui
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onWindowGotFocus = onWindowGotFocus
-- M.select = select

M.loadMissionSettings = loadMissionSettings
M.detectNotebookToLoad = detectNotebookToLoad

M.selectPrevPacenote = selectPrevPacenote
M.selectNextPacenote = selectNextPacenote
M.cycleDragMode = cycleDragMode
M.insertMode = insertMode

M.onEditorInitialized = onEditorInitialized
M.getTranscriptsWindow = function() return transcriptsWindow end
M.getPacenotesWindow = function() return pacenotesWindow end
M.getMissionDir = getMissionDir

M.getPrefShowDistanceMarkers = getPrefShowDistanceMarkers
M.getPrefShowAudioTriggers = getPrefShowAudioTriggers
M.getPrefShowPreviousPacenote = getPrefShowPreviousPacenote
M.getPrefShowNextPacenote = getPrefShowNextPacenote
-- M.getPrefShowRaceSegments = getPrefShowRaceSegments
M.getPrefDefaultRadius = getPrefDefaultRadius
M.getPrefTopDownCameraElevation = getPrefTopDownCameraElevation
M.getPrefTopDownCameraFollow = getPrefTopDownCameraFollow
M.getPrefLockWaypoints = getPrefLockWaypoints
M.getPrefLevel1Thresh = getPrefLevel1Thresh
M.getPrefLevel2Thresh = getPrefLevel2Thresh
M.getPrefLevel3Thresh = getPrefLevel3Thresh
M.getPrefLevel1Text = getPrefLevel1Text
M.getPrefLevel2Text = getPrefLevel2Text
M.getPrefLevel3Text = getPrefLevel3Text

M.listNotebooks = listNotebooks

return M
