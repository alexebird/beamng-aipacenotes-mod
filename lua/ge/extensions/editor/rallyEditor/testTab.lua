local im  = ui_imgui
local logTag = 'aipacenotes'

local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
C.windowDescription = 'Test'

function C:init(rallyEditor)
  self.path = nil
  self.rallyEditor = rallyEditor

  self.driveline = nil
end

function C:setPath(path)
  self.path = path
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end

  local missionDir = self.path:getMissionDir()
  self.driveline = require('/lua/ge/extensions/gameplay/aipacenotes/driveline')(missionDir)
  if not self.driveline:load() then
    self.driveline = nil
    return
  end

  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

-- called by RallyEditor when this tab is unselected.
function C:unselect()
  if not self.path then return end
  -- force redraw of shortcutLegend window
  extensions.hook("onEditorEditModeChanged", nil, nil)
end

function C:draw()
  if not self.path then return end

  if im.Button("Test 1") then
    self:test1()
  end

  if im.Button("Load Recce Mission") then
    local mid = self.path:missionId()
    local missionDir = self.path:getMissionDir()
    extensions.unload("ui_aipacenotes_recceApp")
    extensions.load("ui_aipacenotes_recceApp")
    ui_aipacenotes_recceApp.loadMission(mid, missionDir)
  end

  if im.Button("Unload Recce Mission") then
    extensions.unload("ui_aipacenotes_recceApp")
  end
end

function C:test1()
  print('-- test1 --------------------------------------------------------')

  local pnName = self.path:getRandomStaticPacenote('firstnoteintro')
  print(tostring(pnName))

  pnName = self.path:getRandomStaticPacenote('firstnoteoutro')
  print(tostring(pnName))

  pnName = self.path:getRandomStaticPacenote('finish')
  print(tostring(pnName))
end

function C:drawDebugEntrypoint()
  -- if self.driveline then
  --   self.driveline:drawDebugDriveline()
  -- end
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end


