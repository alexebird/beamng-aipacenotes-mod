  -- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
-- local u_32_max_int = 4294967295
local logTag = 'rally_editor'
local toolWindowName = "rallyEditor"
local editModeName = "Edit Notebook"
local im = ui_imgui
-- local ffi = require('ffi')
-- local roadRiverGui = extensions.editor_roadRiverGui
-- local currentMode = 'Pathnodes'
local previousFilepath = "/gameplay/missions/"
local previousFilename = "NewNotebook.notebook.json"
local windows = {}
local currentWindow = {}
-- local testingWindow
local currentPath = require('/lua/ge/extensions/gameplay/notebook/path')("New Notebook")
currentPath._fnWithoutExt = 'NewNotebook'
currentPath._dir = previousFilepath
-- local allFiles = {}

local notebookInfoWindow, pacenotesWindow, importWindow, optionsWindow

local mouseInfo = {}
-- local nameText = im.ArrayChar(1024, "")

local function setNotebookRedo(data)
  data.previous = currentPath
  data.previousFilepath = previousFilepath
  data.previousFilename = previousFilename

  previousFilename = data.fn
  previousFilepath = data.fp
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
    local settings = require('/lua/ge/extensions/gameplay/notebook/path_mission_settings')()
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
  -- if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:selectPrevPacenote()
end

local function selectNextPacenote()
  -- if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:selectNextPacenote()
end

local function cycleDragMode()
  -- if currentWindow ~= pacenotesWindow then return end
  pacenotesWindow:cycleDragMode()
end

local function loadNotebook(full_filename)
  if not full_filename then
    return
  end
  local dir, filename, ext = path.split(full_filename)
  -- log('I', logTag, 'creating empty notebook file at ' .. tostring(dir))
  local json = readJsonFile(full_filename)
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
  {path = p, fp = dir, fn = filename},
   setNotebookUndo, setNotebookRedo)

  return currentPath
end

-- local function mouseOverPacenotes(mouseInfo)
--   local minNodeDist = 4294967295
--   local closestNode = nil
--   for idx, pacenote in pairs(currentPath.pacenotes.objects) do
--     local node = pacenote:getCornerStartWaypoint()
--     local distNodeToCam = (node.pos - mouseInfo.camPos):length()
--     local nodeRayDistance = (node.pos - mouseInfo.camPos):cross(mouseInfo.rayDir):length() / mouseInfo.rayDir:length()
--     local sphereRadius = node.radius
--     if nodeRayDistance <= sphereRadius then
--       if distNodeToCam < minNodeDist then
--         minNodeDist = distNodeToCam
--         closestNode = node
--       end
--     end
--   end
--   return closestNode
-- end

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
    -- mouseInfo.closestNodeHovered = nil
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

    -- mouseInfo.closestNodeHovered = mouseOverPacenotes(mouseInfo)
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

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "Rally Editor", im.WindowFlags_MenuBar) then
    if im.BeginMenuBar() then
      if im.BeginMenu("File") then
        im.Text(previousFilepath .. previousFilename)
        im.Separator()
        if im.MenuItem1("Load...") then
          editor_fileDialog.openFile(function(data) loadNotebook(data.filepath) end, {{"Notebook files",".notebook.json"}}, false, previousFilepath)
        end
        local canSave = currentPath and previousFilepath
        if im.MenuItem1("Save") then
          saveNotebook(currentPath, previousFilepath .. previousFilename)
        end
        if im.MenuItem1("Save as...") then
          extensions.editor_fileDialog.saveFile(function(data) saveNotebook(currentPath, data.filepath) end,
                                        {{"Notebook files",".notebook.json"}}, false, previousFilepath)
        end
        if im.MenuItem1("Clear") then
          local path = require('/lua/ge/extensions/gameplay/notebook/path')("New Notebook")
          editor.history:commitAction("Set path to new path.",
            {path = path, fp = "/gameplay/missions/", fn = "new.notebook.json"},
            setNotebookUndo, setNotebookRedo)
        end
        -- local canConvert =  extensions.scenario_waypoints and extensions.scenario_waypoints.state
        --                     and extensions.scenario_scenarios and extensions.scenario_scenarios.getScenario()
        --                     and extensions.scenario_scenarios.getScenario().track
        --                     and not extensions.scenario_scenarios.getScenario().track.raceFile
        --                     and extensions.scenario_scenarios.getScenario().track.originalInfo
        -- if canConvert then
          -- im.Separator()
          -- if im.MenuItem1("Copy from current Time Trials") then
            -- copyFromTimeTrials()
          -- end
          -- im.tooltip(#(extensions.scenario_waypoints.state.originalBranches or {}) .. " elements")
        -- end

        -- im.Separator()
        -- if im.BeginMenu("All Rallies...") then
        --   if im.SmallButton("Refresh (!)") then
        --     table.clear(allFiles)
        --     for _, f in ipairs(FS:findFiles("/", '*.notebook.json', -1, true,true)) do
        --       local dir, filename, ext = path.split(f)
        --       table.insert(allFiles,{
        --         name = string.sub(filename,1,-11),
        --         file = f
        --       })
        --     end
        --   end
        --   im.tooltip("This might take a few seconds.")
        --   im.Separator()
        --   for _,f in ipairs(allFiles) do
        --     if im.MenuItem1(f.name..'##'..f.file) then
        --       loadRace(f.file)
        --     end
        --     im.tooltip(f.file)
        --   end
        --   im.EndMenu()
        -- end
        im.EndMenu()
      end

      -- if im.BeginMenu("Preferences") then
      --   local ptr = im.BoolPtr(editor.getPreference("raceEditor.general.directionalNodes"))
      --   if im.Checkbox('Directional Nodes', ptr) then
      --     editor.setPreference("raceEditor.general.directionalNodes", ptr[0])
      --   end
      --   im.tooltip("Created pathnodes have a direction or not.")
      --   local ptr2 = im.BoolPtr(editor.getPreference("raceEditor.general.showAiRoute") or false)
      --   if im.Checkbox('Show AI Route', ptr2) then
      --     editor.setPreference("raceEditor.general.showAiRoute", ptr2[0])
      --   end
      --   im.tooltip("Previews the AI Route for this racepath.")
      --   im.EndMenu()
      -- end

      -- if im.BeginMenu("Tools") then
      --   local add = nil
      --   if im.MenuItem1("Add Missing Recovery Positions") then
      --     add = 'newOnly'
      --   end
      --   if im.MenuItem1("Re-Add All Recovery Positions") then
      --     add = 'all'
      --   end
      --   if add then
      --     local newPath = require('/lua/ge/extensions/gameplay/rally/path')("New Rally")
      --     newPath:onDeserialized(currentPath:onSerialize())
      --     for _, pn in ipairs(newPath.pathnodes.sorted) do
      --       if add == 'all' then
      --         newPath.startPositions:remove(newPath.startPositions.objects[pn.recovery or -1])
      --         pn.recovery = -1
      --       end
      --       if pn.hasNormal and (pn.recovery == -1 or newPath.startPositions.objects[pn.recovery].missing) then
      --         local sp = newPath.startPositions:create()
      --         sp:set(pn.pos, quatFromDir(pn.normal):normalized())
      --         sp.name = pn.name .. " Recovery Forward"
      --         pn.recovery = sp.id

      --         local spr = newPath.startPositions:create()
      --         spr:set(pn.pos, quatFromDir(pn.normal*-1):normalized())
      --         spr.name = pn.name .. " Recovery Reverse"
      --         pn.reverseRecovery = spr.id
      --       end
      --     end

      --     editor.history:commitAction("Add Missing Recovery Positions",{
      --       path = newPath, fp =previousFilepath, fn = previousFilename
      --     }, setRaceUndo, setRaceRedo)
      --   end
      --   im.EndMenu()
      -- end


      -- local issues = findIssues()
      -- if #issues == 0 then
      --   im.BeginDisabled()
      --   if im.BeginMenu("No Issues!") then im.EndMenu() end
      --   im.EndDisabled()
      -- else
      --   if im.BeginMenu(#issues..' Issues') then
      --     for i, issue in ipairs(issues) do
      --       if im.MenuItem1(issue[1]) then
      --         --issue[2]()
      --       end
      --     end
      --     im.EndMenu()
      --   end
      -- end
      im.EndMenuBar()
    end
    if not editor.editMode or editor.editMode.displayName ~= editModeName then
      if im.Button("Switch to Notebook Editor Editmode", im.ImVec2(im.GetContentRegionAvailWidth(),0)) then
        editor.selectEditMode(editor.editModes.notebookEditMode)
      end
    end

    if im.Button("Save") then
      saveNotebook(currentPath, previousFilepath .. previousFilename)
    end
    im.SameLine()
    if im.Button("Reset Camera") then
      resetCameraFix()
    end
    im.tooltip("There is a bug where the camera rotation can get weird. Fix the camera with this button.")
    im.SameLine()
    im.Text('DragMode: '..pacenotesWindow.dragMode)
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

    updateMouseInfo()

    -- currentPath:drawDebug()
    -- if editor.getPreference("raceEditor.general.showAiRoute") then
      -- currentPath:drawAiRouteDebug()
    -- end
    pacenotesWindow:drawDebugNotebookEntrypoint()
    currentWindow:draw(mouseInfo)
  end

  editor.endWindow()

  if not editor.isWindowVisible(toolWindowName) and editor.editModes and editor.editModes.displayName == editModeName then
    editor.selectEditMode(nil)
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
  table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/options')(M))

  -- table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/segments')(M))
  -- table.insert(windows, require('/lua/ge/extensions/editor/raceEditor/startPositions')(M))
  -- table.insert(windows, require('/lua/ge/extensions/editor/rallyEditor/pacenotes')(M))
  -- table.insert(windows, require('/lua/ge/extensions/editor/raceEditor/trackLayout')(M))
  -- table.insert(windows, require('/lua/ge/extensions/editor/raceEditor/timeTrials')(M))
  -- table.insert(windows, require('/lua/ge/extensions/editor/raceEditor/tools')(M))
  -- testingWindow =  require('/lua/ge/extensions/editor/raceEditor/testing')(M)
  -- pnWindow, segWindow, spWindow, pacenotesWindow, tlWindow, toolsWindow = windows[1], windows[2], windows[3], windows[4], windows[5], windows[7]
  notebookInfoWindow, pacenotesWindow, importWindow, optionsWindow = windows[1], windows[2], windows[3], windows[4]

  currentWindow = notebookInfoWindow

  for i,win in pairs(windows) do
    win:setPath(currentPath)
  end

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
    {showPreviousPacenote = {"bool", true, "When a pacenote is selected, also render the previous pacenote for reference."}},
    {showRaceSegments = {"bool", false, "When a pacenote is selected, also render the race segments for reference."}},
    {defaultWaypointRadius = {"int", 10, "The default radius for waypoints.", nil, 1, 50}},
    {topDownCameraElevation = {"int", 100, "Elevation for the top-down camera view.", nil, 1, 1000}},
    {topDownCameraFollow = {"bool", true, "Make the camera follow pacenote selection with a top-down view."}},
  })
end

M.onEditorRegisterPreferences = onEditorRegisterPreferences
M.onSerialize = onSerialize
M.onDeserialized = onDeserialized

M.allowGizmo = function() return editor.editMode and editor.editMode.displayName == editModeName or false end
M.getCurrentFilename = function() return previousFilepath..previousFilename end
M.getCurrentPath = function() return currentPath end
M.isVisible = function() return editor.isWindowVisible(toolWindowName) end
M.changedFromExternal = function() currentWindow:setPath(currentPath) end
-- M.setupRace = setupRace
M.show = show
M.loadNotebook = loadNotebook
M.saveNotebook = saveNotebook
M.saveCurrent = saveCurrent
M.onEditorGui = onEditorGui
M.onEditorToolWindowHide = onEditorToolWindowHide
M.onWindowGotFocus = onWindowGotFocus

M.selectPrevPacenote = selectPrevPacenote
M.selectNextPacenote = selectNextPacenote
M.cycleDragMode = cycleDragMode

-- M.onUpdate = raceTest
M.onEditorInitialized = onEditorInitialized
-- M.getToolsWindow = function() return toolsWindow end
-- M.getPathnodesWindow = function() return pnWindow end
-- M.getPacenotesWindow = function() return pacenotesWindow end
-- M.getSegmentsWindow = function() return segWindow end
M.getOptionsWindow = function() return optionsWindow end
M.getMissionDir = getMissionDir

-- M.wpTypeFwdAudioTrigger = "fwdAudioTrigger"
-- M.wpTypeRevAudioTrigger = "revAudioTrigger"
-- M.wpTypeCornerStart = "cornerStart"
-- M.wpTypeCornerEnd = "cornerEnd"
-- M.wpTypeDistanceMarker = "distanceMarker"

return M
