local C = {}
local logTag = 'recce'

local cc = require('/lua/ge/extensions/editor/rallyEditor/colors')
local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local normalizer = require('/lua/ge/extensions/editor/rallyEditor/normalizer')
local waypointTypes = require('/lua/ge/extensions/gameplay/notebook/waypointTypes')

function C:init(missionDir)
  self.missionDir = missionDir
  self.loaded = false
  self:_resetState()
end

function C:_resetState()
  self.driveline = nil
  self.cuts = nil
end

function C:load()
  self:_resetState()
  self:loadDriveline()
  self:loadCuts()
  self.loaded = true
end

function C:loadCuts()
  -- load the transcripts
  local fname = re_util.transcriptsFile(self.missionDir)


  local transcripts = {}
  local tscCount = 0

  if FS:fileExists(fname) then
    for line in io.lines(fname) do
      local obj = jsonDecode(line)
      if obj.cutId > 0 then
        transcripts[obj.cutId] = obj
        tscCount = tscCount + 1
      else
        log('W', logTag, 'loadCuts: skipping transcript with cutId <= 0')
      end
    end
  end

  log('I', logTag, 'loaded '..tostring(tscCount)..' transcripts')

  -- load the cuts
  fname = re_util.cutsFile(self.missionDir)
  if not FS:fileExists(fname) then
    self.cuts = nil
    return
  end

  self.cuts = {}

  for line in io.lines(fname) do
    local obj = jsonDecode(line)
    obj.pos = vec3(obj.pos)
    obj.quat = quat(obj.quat)
    local tsc = transcripts[obj.id]
    if tsc then
      obj.transcript = {
        error = tsc.resp.error,
        text = tsc.resp.text,
      }
    else
      obj.transcript = {}
    end

    table.insert(self.cuts, obj)
  end

  log('I', logTag, 'loaded '..tostring(#self.cuts)..' cuts')
end

function C:loadDriveline()
  local fname = re_util.drivelineFile(self.missionDir)
  local points = {}

  if not FS:fileExists(fname) then
    self.driveline = nil
    return
  end

  for line in io.lines(fname) do
    local obj = jsonDecode(line)
    obj.pos = vec3(obj.pos)
    obj.quat = quat(obj.quat)
    obj.prev = nil
    obj.next = nil
    obj.id = nil
    obj.partition = nil
    table.insert(points, obj)
  end

  for i,point in ipairs(points) do
    point.id = i
    if i > 1 then
      point.prev = points[i-1]
    end
    if i < #points then
      point.next = points[i+1]
    end
  end

  log('I', logTag, 'loaded driveline with '..tostring(#points)..' points')
  self.driveline = require('/lua/ge/extensions/gameplay/aipacenotes/driveline')(points)
end

function C:drawDebugRecce()
  if not self.driveline then return end
  self.driveline:drawDebugDriveline()
  self:drawDebugCuts()
end

function C:drawDebugCuts()
  for _,point in ipairs(self.cuts) do
    local pos = point.pos
    local quat = point.quat
    local txt = nil
    if point.transcript.text then
      txt = point.transcript.text
    end
    self:drawLittleCar(pos, quat, txt)
  end
end

function C:drawLittleCar(pos, quat, txt)
  local h = 1.6
  local w = 1.8
  local l = 4.4

  local forwardVector = vec3(0,1,0)
  local rotatedForwardVector = quat * forwardVector * (l/2) -- assume pos is the center of car so divide length by 2
  local frontOfCar = pos + rotatedForwardVector
  local backOfCar = pos - rotatedForwardVector

  local raise = vec3(0,0,h/2)
  frontOfCar = frontOfCar + raise
  backOfCar = backOfCar + raise

  local wheelPositions = {
    {0.5, vec3(-(w/2*0.9),   l/2 * 0.6,  0.4)}, -- Front left
    {0.5, vec3( (w/2*0.9),   l/2 * 0.6,  0.4)}, -- Front right
    {0.6, vec3(-(w/2*1.1), -(l/2 * 0.6), 0.4)}, -- Rear left
    {0.6, vec3( (w/2*1.1), -(l/2 * 0.6), 0.4)}, -- Rear right
  }

  -- Function to rotate and translate a local position to a world position
  local function toWorldPosition(localPos)
    local rotatedPos = quat * localPos  -- Rotate by car's orientation
    return pos + rotatedPos            -- Translate to car's world position
  end

  -- Draw the wheels
  for _, wheelPos in ipairs(wheelPositions) do
    local worldWheelPos = toWorldPosition(wheelPos[2])
    debugDrawer:drawSphere(worldWheelPos, wheelPos[1], ColorF(0,0,0,1))
  end

  local clr_base = cc.clr_teal
  local clr = clr_base
  local textAlpha = 1.0
  local clr_text_fg = cc.clr_black
  local clr_text_bg = cc.clr_teal

  debugDrawer:drawSquarePrism(
    frontOfCar,
    backOfCar,
    Point2F(h*0.7, w*0.7), -- make the car look more aero
    Point2F(h, w),
    ColorF(clr[1], clr[2], clr[3], 1)
  )

  if txt then
    debugDrawer:drawTextAdvanced(
      backOfCar + vec3(0,0,h/2),
      String(txt),
      ColorF(clr_text_fg[1], clr_text_fg[2], clr_text_fg[3], textAlpha),
      true,
      false,
      ColorI(clr_text_bg[1]*255, clr_text_bg[2]*255, clr_text_bg[3]*255, textAlpha*255)
    )
  end
end

function C:createPacenotesData(notebook)
  if not self.loaded then return end
  if not self.cuts then return end

  log('I', logTag, 'import pacenotes to notebook')

  local importIdent = notebook:nextImportIdent()
  local import_language = re_util.default_codriver_language

  local snaproad = require('/lua/ge/extensions/gameplay/aipacenotes/snaproad')(self)

  local pacenotes = {}

  for _,cut in ipairs(self.cuts) do
    local note = cut.transcript.text
    note = normalizer.replaceEnglishWords(note)

    local pos = cut.pos
    local radius = editor_rallyEditor.getPrefDefaultRadius()

    -- set the pacenote name
    local pacenoteNewId = notebook:getNextUniqueIdentifier()
    local name = "Pacenote "..pacenoteNewId
    if importIdent then
      name = "Import_"..importIdent.." " .. pacenoteNewId
    end

    -- set some metadata
    local metadata = {}
    -- if transcript.beamng_file then
    -- metadata['success'] = transcript.success
    -- metadata['beamng_file'] = transcript.beamng_file
    -- end

    -- print(dumps(pos))
    local pointCe = snaproad:closestSnapPoint(pos)
    local posCe = pointCe.pos
    -- local pointCs = snaproad:pointsBackwards(pointCe, 2)
    local pointCs = snaproad:distanceBackwards(pointCe, 2*radius)
    local posCs = pointCs.pos
    -- local pointAt = snaproad:pointsBackwards(pointCs, 2)
    local pointAt = snaproad:distanceBackwards(pointCs, 2*radius)
    local posAt = pointAt.pos

    local normalAt = snaproad:forwardNormalVec(pointAt)

    -- local posCs = posCe + (vec3(1,0,0) * (radius * 2))
    -- local posAt = posCs + (vec3(1,0,0) * (radius * 2))

    -- set the Cs pos based on last pacenote direction vector
    -- local lastPacenote = pacenotes[#pacenotes]
    -- if lastPacenote then
    --   local lastPnCe = lastPacenote.pacenoteWaypoints[2]
    --   local lastCePos = vec3(lastPnCe.pos)
    --   local directionVec = lastCePos - posCe
    --   directionVec = vec3(directionVec):normalized()
    --   posCs = posCe + (directionVec * (radius * 2))
    -- end

    local pn = {
      name = name,
      notes = { [import_language] = {note = note}},
      metadata = metadata,
      oldId = pacenoteNewId,
      pacenoteWaypoints = {
        {
          name = "audio trigger",
          normal = normalAt,
          oldId = notebook:getNextUniqueIdentifier(),
          pos = posAt,
          radius = radius,
          waypointType = waypointTypes.wpTypeFwdAudioTrigger,
        },
        {
          name = "corner start",
          normal = {0.0, 1.0, 0.0},
          oldId = notebook:getNextUniqueIdentifier(),
          pos = posCs,
          radius = radius,
          waypointType = waypointTypes.wpTypeCornerStart,
        },
        {
          name = "corner end",
          normal = {0.0, 1.0, 0.0},
          oldId = notebook:getNextUniqueIdentifier(),
          pos = posCe,
          radius = radius,
          waypointType = waypointTypes.wpTypeCornerEnd,
        }
      }
    }

    table.insert(pacenotes, pn)
  end

  return pacenotes
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end

