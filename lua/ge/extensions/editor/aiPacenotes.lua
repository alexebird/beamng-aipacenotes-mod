-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local M = {}
local logTag = 'editor_ai_pacenotes'
local imgui = ui_imgui
local toolWindowName = "aiPacenotes"
local previousFilepath = "/gameplay/pacenotes/"
local previousFilename = "NewPacenotes.pacenotes.json"
local currentPath = require("/lua/ge/extensions/gameplay/pacenotes/path")("New Pacenotes")
currentPath._fnWithoutExt = 'NewPacenotes'
currentPath._dir = previousFilepath
-- local _dirty = false
local form = nil

-- local imUtils = require('ui/imguiUtils')
-- local icons
-- local size = imgui.ImVec2(32,32)
-- local style
-- local io
-- local filter = imgui.ImGuiTextFilter()

local function loadForm()
  form = require('/lua/ge/extensions/editor/aiPacenotes/form')(M)
  form:setPacenotes(currentPath)
end

local function loadPacenotes(filename)
  if not filename then
    return
  end
  local json = readJsonFile(filename)
  if not json then
    log('E', logTag, 'unable to find pacenotes file: ' .. tostring(filename))
    return
  end
  local dir, filename, ext = path.split(filename)
  previousFilepath = dir
  previousFilename = filename
  local p = require('/lua/ge/extensions/gameplay/pacenotes/path')("New Pacenotes")
  p:onDeserialized(json)
  p._dir = dir
  local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  p._fnWithoutExt = fn2

  currentPath = p

  form:setPacenotes(currentPath)

  return currentPath
end

local function savePacenotes(pacenotes, savePath)
  local json = pacenotes:onSerialize()
  jsonWriteFile(savePath, json, true)
  local dir, filename, ext = path.split(savePath)
  previousFilepath = dir
  previousFilename = filename
  pacenotes._dir = dir
  local a, fn2, b = path.splitWithoutExt(previousFilename, true)
  pacenotes._fnWithoutExt = fn2
end

local function menu()
  if imgui.BeginMenuBar() then
    if imgui.BeginMenu("File") then
      imgui.Text(previousFilepath .. previousFilename)
      imgui.Separator()
      if imgui.MenuItem1("Load...") then
        editor_fileDialog.openFile(function(data) loadPacenotes(data.filepath) end, {{"Pacenotes files",".pacenotes.json"}}, false, previousFilepath)
      end
      if imgui.MenuItem1("Save") then
        savePacenotes(currentPath, previousFilepath .. previousFilename)
      end
      imgui.EndMenu()
    end
    imgui.EndMenuBar()
  end
end

local function onEditorGui()
  if editor.beginWindow(toolWindowName, "AI Pacenotes", imgui.WindowFlags_MenuBar) then
    menu()

    if not form then
      loadForm()
    end

    if form then
      form:draw()
    end

    -- imgui.Columns(2)
    -- imgui.SetColumnWidth(0,150)

    -- imgui.Text("Current version")
    -- imgui.NextColumn()
    -- local editEnded = imgui.BoolPtr(false)
    -- imgui.PushItemWidth(imgui.GetContentRegionAvailWidth() - 35)
    -- editor.uiInputText("##GeneralName", currentPath.current_version, 1024, nil, nil, nil, editEnded)
    -- imgui.PopItemWidth()
    -- if editEnded[0] then
    --   self.mission.name = ffi.string(self.nameText)
    --   _dirty = true
    -- end
    -- imgui.SameLine()
    -- if not self._titleTranslated then
    --   self._titleTranslated = translateLanguage(self.mission.name, noTranslation, true)
    -- end

    -- imgui.Text(dumps(nil or {}))
    -- local txt = dumps({})
    -- local txt = dumps(currentPath:onSerialize())
    -- local txt = 'foo'
    -- print(txt)

    -- local arraySize = 8*(2+math.max(128, 4*txt:len()))
    -- local arrayChar = imgui.ArrayChar(arraySize)
    -- ffi.copy(arrayChar, txt)
    -- local _text = arrayChar

    -- imgui.InputTextMultiline("##pacenotesCurrVerJson", _text, imgui.GetLengthArrayCharPtr(_text))
  end

  editor.endWindow()
end

local function onEditorActivated()
end

local function onWindowMenuItem()
  editor.showWindow(toolWindowName)
end

local function onEditorInitialized()
  editor.registerWindow(toolWindowName, imgui.ImVec2(600, 600))
  editor.addWindowMenuItem("AI Pacenotes", onWindowMenuItem, {groupMenuName = 'Experimental'})
end

local function onExtensionLoaded()
end

M.loadPacenotes = loadPacenotes

M.onEditorInitialized = onEditorInitialized
M.onEditorActivated = onEditorActivated
M.onEditorGui = onEditorGui
M.onExtensionLoaded = onExtensionLoaded

M.form = form

return M