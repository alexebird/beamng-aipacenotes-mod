local httpClient = require("socket.http")
local socket = require("socket")
socket.TIMEOUT = 1

local M = {}

local logTag = 'aip-client'
local base_url = 'http://localhost:27872'
local timeout_msg = 'network activity disabled due to timeout.<br>is the desktop app running?'
local timeout_occurred = false

local function clear_timeout()
  timeout_occurred = false
end

local function check_timeout(code)
  if code == 'connection refused' then
    timeout_occurred = true
    log('E', logTag, 'aip client detected timeout '..dumps(code))
  end
end

local function has_timeout()
  return timeout_occurred
end

local function jsonRequestGet(uri)
  if timeout_occurred then
    return {ok = false, error = timeout_msg}
  end

  local respbody = {}
  local body, code, headers, status = httpClient.request {
    method = 'GET',
    url = uri,
    sink = ltn12.sink.table(respbody)
  }

  if code ~= 200 then
    log('E', logTag, 'aip client error: '..dumps(code))
    check_timeout(code)
    return {ok = false, error = tostring(code)}
  else
    --print('body:' .. tostring(body))
    --print('code:' .. tostring(code))
    --print('headers:' .. dumps(headers))
    --print('status:' .. tostring(status))
    local rv = jsonDecode(table.concat(respbody), 'json request response')
    return rv
  end
end

local function jsonRequestPost(uri, data)
  if timeout_occurred then
    return {ok = false, error = timeout_msg}
  end

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
    log('E', logTag, 'aip client error: '..dumps(code))
    check_timeout(code)
    return {ok = false, error = tostring(code)}
  else
    local rv = jsonDecode(table.concat(respbody), 'json request response')
    return rv
  end
end

local function getVehiclePosForRequest()
  local vehicle = be:getPlayerVehicle(0)
  local vehiclePos = vehicle:getPosition()
  local vRot = quatFromDir(vehicle:getDirectionVector(), vehicle:getDirectionVectorUp())
  local x,y,z = vRot * vec3(1,0,0),vRot * vec3(0,1,0),vRot * vec3(0,0,1)
  local vehicle_position = { pos = vehiclePos, rot = {x, y, z} }
  return vehicle_position
end

local function transcribe_recording_start()
  local url = base_url..'/recordings/actions/start'
  local resp = jsonRequestPost(url, getVehiclePosForRequest())
  return resp
end

local function transcribe_recording_stop()
  local url = base_url..'/recordings/actions/stop'
  local resp = jsonRequestPost(url, getVehiclePosForRequest())
  -- guihooks.trigger('MenuHide')
  return resp
end

local function transcribe_recording_cut()
  local url = base_url..'/recordings/actions/cut'
  local resp = jsonRequestPost(url, getVehiclePosForRequest())
  return resp
end

local function transcribe_transcripts_get(count)
  local url = base_url..'/transcripts/'..count
  local resp = jsonRequestGet(url)
  return resp
end

M.transcribe_recording_start = transcribe_recording_start
M.transcribe_recording_stop = transcribe_recording_stop
M.transcribe_recording_cut = transcribe_recording_cut
M.transcribe_transcripts_get = transcribe_transcripts_get
M.clear_timeout = clear_timeout
M.has_timeout = has_timeout

return M
