local im  = ui_imgui
local logTag = 'aipacenotes'

local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}
C.windowDescription = 'Test'

function C:init(rallyEditor)
  self.path = nil
  self.rallyEditor = rallyEditor
end

function C:setPath(path)
  self.path = path
end

-- called by RallyEditor when this tab is selected.
function C:selected()
  if not self.path then return end
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

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end


