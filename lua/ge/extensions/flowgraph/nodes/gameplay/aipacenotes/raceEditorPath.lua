-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

C.name = 'AI Pacenotes Race Editor Path'
C.description = 'Gets the currently loaded Race Editor race.race.json path.'
C.category = 'once_p_duration'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}

C.pinSchema = {
  -- {dir = 'in', type = 'string', name = 'file', default='race.race.json', description = 'File of the race'},

  {dir = 'out', type = 'string', name = 'fname', description = 'The race filename.'},
}

function C:init(mgr, ...)
  -- self.path = nil
  -- self.clearOutPinsOnStart = false
  self.data.useEditor = false
end

-- function C:postInit()
--   self.pinInLocal.file.allowFiles = {
--     {"Race Files",".race.json"},
--   }
-- end

function C:getRaceEditorPath()
  local fname = 'race.race.json'
  if editor_raceEditor and self.data.useEditor then
    local fn = editor_raceEditor.getCurrentFilename()
    if fn then
      fname = fn
    end
  end

  return fname
end

function C:drawCustomProperties()
--   if editor_raceEditor then
--     local fn = editor_raceEditor.getCurrentFilename()
--     if fn then
      im.Text("Race Editor file:")
      im.Text(self:getRaceEditorPath())
--       im.Text(fn)
--       if im.Button("Hardcode to File Pin") then
--         self:_setHardcodedDummyInputPin(self.pinInLocal.file, fn)
--       end
--     end
--   end
end

-- function C:onNodeReset()
--   self.path = nil
-- end
--
-- function C:_executionStopped()
--   self.path = nil
-- end

function C:work(args)
  self.pinOut.fname.value = self:getRaceEditorPath()
end

return _flowgraph_createNode(C)
