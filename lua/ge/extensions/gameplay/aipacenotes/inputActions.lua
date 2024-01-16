-- local httpClient = require("socket.http")
-- local socket = require("socket")
-- socket.TIMEOUT = 1

local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local M = {}

local logTag = 'aip-client'
-- local base_url = 'http://localhost:27872'
-- local timeout_msg = 'network activity disabled due to timeout.<br>is the desktop app running?'
-- local timeout_occurred = false

-- local last_transcript_cut_ts = re_util.getTime()
-- local double_tap_threshold_sec = 0.5

-- local function action_transcribe_recording_start()
--   log('I', logTag, 'action_transcribe_recording_start')
-- end

local function is_recceApp_loaded()
  return extensions.isExtensionLoaded("ui_aipacenotes_recceApp")
end

local function action_transcribe_recording_stop()
  log('I', logTag, 'action_transcribe_recording_stop')
  if not is_recceApp_loaded() then return end

  local resp = extensions.gameplay_aipacenotes_client.transcribe_recording_stop()
  if not resp.ok then
    guihooks.trigger('aiPacenotesDesktopCallNotOk', resp.client_msg)
  end
end

local function action_transcribe_recording_cut()
  log('I', logTag, 'action_transcribe_recording_cut')
  if not is_recceApp_loaded() then return end

  local resp = extensions.gameplay_aipacenotes_client.transcribe_recording_cut()
  if not resp.ok then
    guihooks.trigger('aiPacenotesDesktopCallNotOk', resp.client_msg)
  end
end

local function action_toggle_recce_drawDebug()
  log('I', logTag, 'action_toggle_recce_drawDebug')
  if not is_recceApp_loaded() then return end

  guihooks.trigger('aiPacenotesToggleDrawDebug')
end

-- M.action_transcribe_recording_start = action_transcribe_recording_start
M.action_transcribe_recording_stop = action_transcribe_recording_stop
M.action_transcribe_recording_cut = action_transcribe_recording_cut
M.action_toggle_recce_drawDebug = action_toggle_recce_drawDebug

return M
