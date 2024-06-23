local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local socket = require('socket')
local mime = require("mime")

local C = {}
local logTag = 'aipacenotes-fg'

C.name = 'AI Pacenotes Track Timing'
C.description = 'Track timing data.'
C.color = re_util.aip_fg_color
C.tags = {'aipacenotes'}
C.category = 'once_instant'

C.pinSchema = {
  { dir = 'in', type = 'number', name = 'vehId', description = 'Vehicle id.'},
  { dir = 'in', type = 'table',  name = 'raceData', tableType = 'raceData', description = 'Race data.'},
  { dir = 'in', type = 'table',  name = 'pathData', tableType = 'pathData', description = 'Path data.'},
}

function C:workOnce()
  self.path = self.pinIn.pathData.value
  if not self.path then
    log('W', logTag, 'no pathData')
    return
  end

  self.race = self.pinIn.raceData.value
  if not self.race then
    log('W', logTag, 'no raceData')
    return
  end

  self.vehId = self.pinIn.vehId.value
  if not self.vehId then
    log('W', logTag, 'no vehId')
    return
  end

  local state = self.race.states[self.vehId]
  --
  -- this is what we want:
  -- log(logTag, 'D', dumps(socket.gettime()))
  -- log(logTag, 'D', dumps(state.historicTimes[#state.historicTimes]))

  local vdata = core_vehicle_manager.getPlayerVehicleData()
  local vehicleConfig = vdata.config
  -- log(logTag, 'D', dumps(vehicleConfig))

  -- includes level id
  local missionId = gameplay_missions_missionManager.getForegroundMissionId()
  -- log(logTag, 'D', dumps(missionId))

  local pathnodesExtracted = {}
  for i,pn in ipairs(self.path.pathnodes.sorted) do
    local pnData = {
      i = i,
      id = pn.id,
      name = pn.name,
      pos = pn.pos,
      normal = pn.normal,
      radius = pn.radius,
      visible = pn.visible,
      recovery = pn.recovery,
    }

    table.insert(pathnodesExtracted, pnData)
  end

  local spExtracted = {}
  for i,sp in ipairs(self.path.startPositions.sorted) do
    local spData = {
      i = i,
      id = sp.id,
      name = sp.name,
      pos = sp.pos,
      rot = sp.rot,
    }

    table.insert(spExtracted, spData)
  end

  local pathData = {
    defaultStartPosition = self.path.defaultStartPosition,
    startPositions = spExtracted,
    startNode = self.path.startNode,
    endNode = self.path.endNode,
    pathnodes = pathnodesExtracted,
  }
  -- log(logTag, 'D', dumps(pathData))

  local jsonData = {
    finished_at = socket.gettime(),
    timing_data = state.historicTimes[#state.historicTimes],
    vehicle_config = vehicleConfig,
    mission_id = missionId,
    race_course = pathData,
  }

  log(logTag, 'D', dumps(jsonData))

  -- local function v5(v1)
  --   local v2 = 0xABCDEF
  --   for v3 = 1, #v1 do
  --     local v4 = v1:byte(v3)
  --     v2 = (v2 ~ v4) * 3
  --     v2 = v2 ~ (v2 >> 16)
  --   end
  --   return v2
  -- end

  local fname = '/settings/aipacenotes/results/latest_results.txt'
  local contents = jsonEncode(jsonData)
  -- local v6 = v5(contents)
  contents = mime.b64(contents)

  local f = io.open(fname, "w")
  if f then
    -- f:write(v6.."\n")
    f:write('nG#Jma@i^Q2gt#'.."\n")
    f:write("---".."\n")
    f:write(contents.."\n")
    f:close()
  else
    log(logTag, 'E', 'error opening file')
  end

  -- local saveOk = jsonWriteFile(, jsonData, true)
  -- if not saveOk then
    -- log(logTag, 'E', 'save failed')
  -- end
end

return _flowgraph_createNode(C)
