-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui

local C = {}

C.name = 'AI Pacenotes File Path'
C.description = 'Loads a Path from a rally file.'

C.category = 'once_p_duration'
C.color = im.ImVec4(0, 1, 0.87, 0.75) -- rgba cyan

C.pinSchema = {
  {dir = 'in', type = 'string', name = 'file', description = 'File of the rally'},
  {dir = 'in', type = 'bool', name = 'reverse', description = 'If the path should be reversed, if possible.'},

  {dir = 'out', type = 'table', name = 'pathData', tableType = 'pathData', description = 'Data from the path for other nodes to process.'},
  {dir = 'out', type = 'string', name = 'name', description = 'Name of the Rally'},
  {dir = 'out', type = 'string', name = 'desc', description = 'Description of the Rally'},
  {dir = 'out', type = 'bool', name = 'branching', hidden= true, description = 'If the path is branching.'},
  {dir = 'out', type = 'bool', name = 'closed', hidden= true, description = 'If the path is closed.'},
  {dir = 'out', type = 'number', name = 'laps', hidden= true,  description = 'Default number of laps.'},
  {dir = 'out', type = 'number', name = 'checkpointCount', hidden= true,  description = 'Number of checkpoints in total (does nto work for branching)'},
  {dir = 'out', type = 'number', name = 'recoveryCount', hidden= true,  description = 'Number of checkpoints that have a recovery point set up'}
}

C.tags = {'scenario', 'aipacenotes'}


function C:init(mgr, ...)
  self.path = nil
  self.clearOutPinsOnStart = false
end

function C:postInit()
  self.pinInLocal.file.allowFiles = {
    {"Rally Files",".rally.json"},
  }
end

function C:drawCustomProperties()
  if im.Button("Open Rally Editor") then
    if editor_rallyEditor then
      editor_rallyEditor.show()
    end
  end
  if editor_rallyEditor then
    local fn = editor_rallyEditor.getCurrentFilename()
    if fn then
      im.Text("Currently open file in RallyEditor:")
      im.Text(fn)
      if im.Button("Hardcode to File Pin") then
        self:_setHardcodedDummyInputPin(self.pinInLocal.file, fn)
      end
    end
  end
end

function C:onNodeReset()
  self.path = nil
end

function C:_executionStopped()
  self.path = nil
end

function C:work(args)
  if self.path == nil then
    local file, valid = self.mgr:getRelativeAbsolutePath({self.pinIn.file.value, self.pinIn.file.value..'.rally.json'})
    if not valid then
      self:__setNodeError('file', 'unable to find rally file: '..file)
      return
    end

    local path = require('/lua/ge/extensions/gameplay/rally/path')("New Path")
    path:onDeserialized(jsonReadFile(file))
    if self.pinIn.reverse.value then
      path:reverse()
    end
    path:autoConfig()

    self.path = path
    self.pinOut.pathData.value = path
    self.pinOut.desc.value = path.description
    self.pinOut.name.value = path.name
    self.pinOut.branching.value = path.config.branching
    self.pinOut.closed.value = path.config.closed
    self.pinOut.laps.value = path.defaultLaps
    self.pinOut.checkpointCount.value = #(path.pathnodes.sorted)
    local rCount = 0
    for _, pn in ipairs(path.pathnodes.sorted) do
      if self.pinIn.reverse.value then
        if not pn:getReverseRecovery().missing then
          rCount = rCount + 1
        end
      else
        if not pn:getRecovery().missing then
          rCount = rCount + 1
        end
      end
    end

    self.pinOut.recoveryCount.value = rCount
  end
end

return _flowgraph_createNode(C)