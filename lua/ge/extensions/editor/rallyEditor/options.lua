-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local im  = ui_imgui
local logTag = 'aipacenotes'

local C = {}
C.windowDescription = 'Tools'

function C:init(rallyEditor)
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

function C:draw(mouseInfo)
  if not self.path then return end
  -- self.mouseInfo = mouseInfo

  -- self:input()


  im.HeaderText("Tools")

  -- if im.Checkbox("Show distance markers (orange waypoints)", im.BoolPtr(self.options_data.show_distance_markers)) then
  --   self.options_data.show_distance_markers = not self.options_data.show_distance_markers
  -- end
  -- im.tooltip("Show/Hide orange waypoints, which are called Distance Markers.")

  -- local editEnded = im.BoolPtr(false)
  -- local editTxt = im.ArrayChar(1024, tostring(self.options_data.default_radius))
  -- editor.uiInputText("Default Radius", editTxt, nil, nil, nil, nil, editEnded)
  -- if editEnded[0] then
  --   local newVal = tonumber(ffi.string(editTxt))
  --   self.options_data.default_radius = newVal
  -- end
  -- im.tooltip("Default radius of all waypoints.")

  if im.Button("Set All Radii") then
    if self.path then
      self.path:setAllRadii(self:getPrefDefaultRadius())
    end
  end
  im.tooltip("Force the radius of all waypoints to the default value.")

  -- if im.Button("Load Snap Road") then
  --   self:loadSnapRoads()
  -- end

  -- self:drawSnapRoad()
end

function C:getPrefShowDistanceMarkers()
  return editor.getPreference('rallyEditor.general.showDistanceMarkers')
end

function C:getPrefShowPreviousPacenote()
  return editor.getPreference('rallyEditor.general.showPreviousPacenote')
end

function C:getPrefShowRaceSegments()
  return editor.getPreference('rallyEditor.general.showRaceSegments')
end

function C:getPrefDefaultRadius()
  return editor.getPreference('rallyEditor.general.defaultWaypointRadius')
end

function C:getPrefTopDownCameraElevation()
  return editor.getPreference('rallyEditor.general.topDownCameraElevation')
end

function C:getPrefTopDownCameraFollow()
  return editor.getPreference('rallyEditor.general.topDownCameraFollow')
end

function C:getPrefFlipSnaproadNormal()
  return editor.getPreference('rallyEditor.general.flipSnaproadNormal')
end

-- function C:loadSnapRoads()
--   -- local objs = scenetree.findClassObjects('DecalRoad')
--
--   self.options_data.snap_road_positions_dense = {}
--   self.options_data.snap_road_positions_sparse = {}
--
--   for roadID, _ in pairs(editor.getAllRoads()) do
--     local road = scenetree.findObjectById(roadID)
--     if road and not road:isHidden() then
--       if road.drivability > 0 then -- ie, it's an AI road.
--         self:loadSnapRoad(road)
--         -- local aip_road = road:getDynDataFieldbyName("aip_road", "0")
--         -- aip_road = tostring(aip_road)
--         -- if aip_road == "1" or aip_road == "t" or aip_road == "true" then
--         --   self:loadSnapRoad(road)
--         -- end
--       end
--     end
--   end
-- end

-- function C:loadSnapRoad(road)
--   local edgeCount = road:getEdgeCount()
--
--   for index = 0, edgeCount - 1 do
--     local currentMiddleEdge = road:getMiddleEdgePosition(index)
--     -- log("D", "wtf", dumps(currentMiddleEdge))
--     table.insert(self.options_data.snap_road_positions_dense, currentMiddleEdge)
--   end
--
--   for i,node in ipairs(editor.getNodes(road)) do
--     local pos = node.pos
--     table.insert(self.options_data.snap_road_positions_sparse, pos)
--   end
-- end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end
