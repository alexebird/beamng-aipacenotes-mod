local httpClient = require("socket.http")

local M = {}

local base_url = 'http://localhost:27872'

local function jsonRequestGet(uri, data)
    -- GET
    local respbody = {}
    local body, code, headers, status = httpClient.request {
        method = 'GET',
        url = uri,
        sink = ltn12.sink.table(respbody)
    }

    if code ~= 200 then
        return {ok = false, error = code}
    end

    --print('body:' .. tostring(body))
    --print('code:' .. tostring(code))
    --print('headers:' .. dumps(headers))
    --print('status:' .. tostring(status))
    return jsonDecode(table.concat(respbody), 'json request response')
end

-- local function jsonRequestPost(uri, data)
--     -- POST
--     local respbody = {}
--     local reqbody = "data=" .. jsonEncode(data)
--     local body, code, headers, status = httpClient.request {
--         method = 'POST',
--         url = uri,
--         source = ltn12.source.string(reqbody),
--         headers = {
--             ["Accept"] = "*/*",
--             --["Accept-Encoding"] = "gzip, deflate",
--             --["Accept-Language"] = "en-us",
--             ["Content-Type"] = "application/x-www-form-urlencoded",
--             ["content-length"] = string.len(reqbody)
--         },
--         sink = ltn12.sink.table(respbody)
--     }
--     if code ~= 200 then
--         return {ok = false, error = code}
--     end

--     --print('body:' .. tostring(body))
--     --print('code:' .. tostring(code))
--     --print('headers:' .. dumps(headers))
--     --print('status:' .. tostring(status))
--     return jsonDecode(table.concat(respbody), 'json request response')
-- end

local function jsonRequestPost(uri, data)
    -- POST
    local respbody = {}
    local reqbody = jsonEncode(data)
    local body, code, headers, status = httpClient.request {
        method = 'POST',
        url = uri,
        source = ltn12.source.string(reqbody),
        headers = {
            ["Accept"] = "*/*",
            --["Accept-Encoding"] = "gzip, deflate",
            --["Accept-Language"] = "en-us",
            ["Content-Type"] = "application/json",
            ["content-length"] = string.len(reqbody)
        },
        sink = ltn12.sink.table(respbody)
    }
    if code ~= 200 then
        return {ok = false, error = code}
    end

    return jsonDecode(table.concat(respbody), 'json request response')
end

local function getVehiclePosForRequest()
  local vehicle = be:getPlayerVehicle(0)
  -- local vehicle = be:getObjectByID(id)
  local vehiclePos = vehicle:getPosition()
  local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
  local x,y,z = vRot * vec3(1,0,0),vRot * vec3(0,1,0),vRot * vec3(0,0,1)
  local vehicle_position = {
    ["pos"] = vehiclePos,
    ["rot"] = {x, y, z},
  }
  -- log('D', 'wtf', dumps(vehicle_position))
  return vehicle_position
end

local function hello_world(dir)
  log('W', 'hello_world', 'hello, '..dir..' world!')
end

local function recording_start()
  local url = base_url..'/recordings/actions/start'
  local resp = jsonRequestPost(url, getVehiclePosForRequest())
  log('D', 'wtf', dumps(resp))
end

local function recording_stop()
  local url = base_url..'/recordings/actions/stop'
  local resp = jsonRequestPost(url, getVehiclePosForRequest())
  log('D', 'wtf', dumps(resp))
  -- guihooks.trigger('MenuHide')
end

local function recording_cut()
  local url = base_url..'/recordings/actions/cut'
  local resp = jsonRequestPost(url, getVehiclePosForRequest())
  log('D', 'wtf', dumps(resp))
end

local function recording_get()
  local url = base_url..'/recordings/latest'
  local resp = jsonRequestGet(url)
  log('D', 'wtf', dumps(resp))
end

M.hello_world = hello_world
M.recording_start = recording_start
M.recording_stop = recording_stop
M.recording_cut = recording_cut

return M