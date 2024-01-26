local M = {}
local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local logTag = 'aipacenotes'

local startingMinDist = 4294967295

local radius = cc.snaproads_radius

local handle_points = {}
local spline_points = {}

local function loadSnapRoad(road)
  local edgeCount = road:getEdgeCount()

  for index = 0, edgeCount - 1 do
    local currentMiddleEdge = road:getMiddleEdgePosition(index)
    table.insert(spline_points, currentMiddleEdge)
  end

  for i,node in ipairs(editor.getNodes(road)) do
    local pos = node.pos
    table.insert(handle_points, pos)
  end
end

local function loadSnapRoads()
  handle_points = {}
  spline_points = {}

  for roadID, _ in pairs(editor.getAllRoads()) do
    local road = scenetree.findObjectById(roadID)
    if road and not road:isHidden() then
      if road.drivability > 0 then -- ie, it's an AI road.
        loadSnapRoad(road)
        -- local aip_road = road:getDynDataFieldbyName("aip_road", "0")
        -- aip_road = tostring(aip_road)
        -- if aip_road == "1" or aip_road == "t" or aip_road == "true" then
        --   self:loadSnapRoad(road)
        -- end
      end
    end
  end

  log('I', logTag, 'snaproads loaded '..#spline_points..' spline_points and '..#handle_points..' handle_points')
end

local function mouseOverSnapRoad(mouseInfo)
  local minNoteDist = startingMinDist
  local closestWp = nil

  local sphereRadius = radius / 2
  for _,node in ipairs(spline_points) do
    local pos = node
    local distNoteToCam = (pos - mouseInfo.camPos):length()
    local noteRayDistance = (pos - mouseInfo.camPos):cross(mouseInfo.rayDir):length() / mouseInfo.rayDir:length()
    if noteRayDistance <= sphereRadius then
      if distNoteToCam < minNoteDist then
        minNoteDist = distNoteToCam
        closestWp = node
      end
    end
  end

  return closestWp
end

local function drawSnapRoads(mouseInfo)
  local closest_snap_for_hover = mouseOverSnapRoad(mouseInfo)
  local clr = nil
  local alpha = nil

  local small_radius = radius/2
  for _,pos in pairs(spline_points) do
    if pos == closest_snap_for_hover then
      clr = cc.snaproads_clr_hover
      alpha = cc.snaproads_alpha_hover
    -- elseif pos == snap_pos then
    --   clr = clr_blue
    else
      clr = cc.snaproads_clr
      alpha = cc.snaproads_alpha
    end
    debugDrawer:drawSphere(
      (pos),
      small_radius,
      ColorF(clr[1],clr[2],clr[3], alpha)--,false)
    )
  end
end

-- use this in case you still want a point for orienting a normal
-- but it's the last point in the spline list.
local function extrapolateLine(point1, point2)
  -- Calculate direction vector from point1 to point2
  local dirVector = {
    x = point2.x - point1.x,
    y = point2.y - point1.y,
    z = point2.z - point1.z
  }

  -- Normalize the direction vector
  local length = math.sqrt(dirVector.x^2 + dirVector.y^2 + dirVector.z^2)
  local normVector = {
    x = dirVector.x / length,
    y = dirVector.y / length,
    z = dirVector.z / length
  }

  -- Calculate the new point (point3)
  local point3 = {
    point2.x + normVector.x * length,
    point2.y + normVector.y * length,
    point2.z + normVector.z * length
  }

  return vec3(point3)
end

local function closestSnapPos(source_pos)
  -- local snaps = handle_points
  local snaps = spline_points

  local minDist = startingMinDist
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

  local posAfter = nil
  if closest_i and closest_i + 1 <= #snaps then
    posAfter = snaps[closest_i + 1]
  elseif #snaps >= 2 then
    posAfter = extrapolateLine(snaps[#snaps-1], snaps[#snaps])
  end

  return closestPos, posAfter
end

M.loadSnapRoads = loadSnapRoads
M.drawSnapRoads = drawSnapRoads
M.closestSnapPos = closestSnapPos

return M










