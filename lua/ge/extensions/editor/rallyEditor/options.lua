-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'

local C = {}
C.windowDescription = 'Options'

function C:init(rallyEditor)
  self.rallyEditor = rallyEditor
  -- self.mouseInfo = {}
  self.options_data = {
    default_radius = 10,
    show_distance_markers = true,
    snap_road_positions_sparse = {},
    snap_road_positions_dense = {},
  }

  self._hover_pos = nil
  self._snap_pos = nil
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

function C:onEditModeActivate()
end

function C:input()
  self._hover_pos = nil
  self._hover_pos = self:mouseOverSnapRoad()

  self._snap_pos = nil
  if self.mouseInfo.rayCast then
    local pos = self.mouseInfo.rayCast.pos
    self._snap_pos = self:closestSnapPos(pos)
  end
end

function C:mouseOverSnapRoad()
  if not self.path then return end

  local minNoteDist = 4294967295
  local closestWp = nil
  local radius = 2

  for i,node in ipairs(self.options_data.snap_road_positions_sparse) do
    local pos = node
    local distNoteToCam = (pos - self.mouseInfo.camPos):length()
    local noteRayDistance = (pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
    local sphereRadius = radius
    if noteRayDistance <= sphereRadius then
      if distNoteToCam < minNoteDist then
        minNoteDist = distNoteToCam
        closestWp = node
      end
    end
  end

  radius = radius/2
  for i,node in ipairs(self.options_data.snap_road_positions_dense) do
    local pos = node
    local distNoteToCam = (pos - self.mouseInfo.camPos):length()
    local noteRayDistance = (pos - self.mouseInfo.camPos):cross(self.mouseInfo.rayDir):length() / self.mouseInfo.rayDir:length()
    local sphereRadius = radius
    if noteRayDistance <= sphereRadius then
      if distNoteToCam < minNoteDist then
        minNoteDist = distNoteToCam
        closestWp = node
      end
    end
  end

  return closestWp
end

function C:closestSnapPos(source_pos)
  if not self.path then return end

  -- local snaps = self.options_data.snap_road_positions_sparse
  local snaps = self.options_data.snap_road_positions_dense

  local minDist = 4294967295
  local closestPos = nil
  local closest_i = nil

  for i,node in ipairs(snaps) do
    local pos = node
    local distToMouse = (pos - source_pos):length()
    if distToMouse < minDist then
      minDist = distToMouse
      closestPos = node
      closest_i = i
    end
  end

  -- for i,node in ipairs(self.options_data.snap_road_positions_dense) do
  --   local pos = node
  --   local distToMouse = (pos - source_pos):length()
  --   if distToMouse < minDist then
  --     minDist = distToMouse
  --     closestPos = node
  --     closest_i = i
  --   end
  -- end

  -- get the preceeding position in order to calculate the normal
  -- local pos_before = nil
  -- if closest_i - 1 >= 1 then
  --   pos_before = snaps[closest_i - 1]
  -- end
  local pos_after = nil
  if closest_i and closest_i + 1 <= #snaps then
    pos_after = snaps[closest_i + 1]
  end

  return closestPos, pos_after
end

function C:draw(mouseInfo)
  self.mouseInfo = mouseInfo

  self:input()

  if not self.path then return end

  im.HeaderText("Options")

  if im.Checkbox("Show distance markers (orange waypoints)", im.BoolPtr(self.options_data.show_distance_markers)) then
    self.options_data.show_distance_markers = not self.options_data.show_distance_markers
  end
  im.tooltip("Show/Hide orange waypoints, which are called Distance Markers.")

  local editEnded = im.BoolPtr(false)
  local editTxt = im.ArrayChar(1024, tostring(self.options_data.default_radius))
  editor.uiInputText("Default Radius", editTxt, nil, nil, nil, nil, editEnded)
  if editEnded[0] then
    local newVal = tonumber(ffi.string(editTxt))
    self.options_data.default_radius = newVal
  end
  im.tooltip("Default radius of all waypoints.")

  if im.Button("Set All Radii") then
    if self.path and self.options_data.default_radius and self.options_data.default_radius > 1 then
      self.path:setAllRadii(self.options_data.default_radius)
    end
  end
  im.tooltip("Force the radius of all waypoints to the default value.")

  if im.Button("Load Snap Road") then
    self:loadSnapRoads()
  end

  self:drawSnapRoad()
end

function C:drawSnapRoad(id)
  local clr_red = {1,0,0}
  local clr = nil
  local radius = 2
  local shapeAlpha = 0.5

  for _,pos in pairs(self.options_data.snap_road_positions_sparse) do
    if pos == self._hover_pos then
      clr = {1,1,1}
    elseif pos == self._snap_pos then
      clr = {0,0,1}
    else
      clr = clr_red
    end
    debugDrawer:drawSphere((pos),
      radius,
      ColorF(clr[1],clr[2],clr[3],shapeAlpha)
    )
  end

  for _,pos in pairs(self.options_data.snap_road_positions_dense) do
    if pos == self._hover_pos then
      clr = {1,1,1}
    elseif pos == self._snap_pos then
      clr = {0,0,1}
    else
      clr = clr_red
    end
    debugDrawer:drawSphere((pos),
      radius/2,
      ColorF(clr[1],clr[2],clr[3],shapeAlpha, false)
    )
  end
end

function C:loadSnapRoads()
  local objs = scenetree.findClassObjects('DecalRoad')

  self.options_data.snap_road_positions_dense = {}
  self.options_data.snap_road_positions_sparse = {}

  for roadID, _ in pairs(editor.getAllRoads()) do
    local road = scenetree.findObjectById(roadID)
    if road and not road:isHidden() then
      if road.drivability > 0 then
        local aip_road = road:getDynDataFieldbyName("aip_road", "0")
        aip_road = tostring(aip_road)
        if aip_road == "1" or aip_road == "t" or aip_road == "true" then
          -- log("D", "WTF", dumps(aip_road))
          self:loadSnapRoad(road)
        end
      end
    end
  end

  -- for i,id in ipairs(objs) do
  --   local road = scenetree.findObjectById(tonumber(id))
  --   if road then
  --     log("D", "WTF", dumps(id))
  --     local dyn = road:getDynamicFields()
  --     log("D", "WTF", dumps(road))
  --   end
  -- end
  -- log("D", 'wtf', dumps(road))
end

function C:loadSnapRoad(road)
  -- local new_sparse = {}
  -- local new_dense = {}

  local edgeCount = road:getEdgeCount()

  -- Loop through the points and draw the lines
  for index = 0, edgeCount - 1 do
    local currentMiddleEdge = road:getMiddleEdgePosition(index)
    -- log("D", "wtf", dumps(currentMiddleEdge))
    table.insert(self.options_data.snap_road_positions_dense, currentMiddleEdge)
  end

  for index, node in ipairs(editor.getNodes(road)) do
    local pos = node.pos
    table.insert(self.options_data.snap_road_positions_sparse, pos)
  end

  -- self.options_data.snap_road_positions_sparse = new_sparse
  -- self.options_data.snap_road_positions_dense = new_dense
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
