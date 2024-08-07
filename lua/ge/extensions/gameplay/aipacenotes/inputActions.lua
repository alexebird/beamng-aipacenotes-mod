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

local function is_recceApp_loaded()
  return extensions.isExtensionLoaded("ui_aipacenotes_recceApp")
end

-- local function action_transcribe_recording_start()
--   if not is_recceApp_loaded() then return end
--   extensions.ui_aipacenotes_recceApp.transcribe_recording_start()
-- end
--
-- local function action_transcribe_recording_stop()
--   if not is_recceApp_loaded() then return end
--   extensions.ui_aipacenotes_recceApp.transcribe_recording_stop()
-- end

local function action_transcribe_recording_cut()
  if not is_recceApp_loaded() then return end
  guihooks.trigger('aiPacenotesInputActionCutRecording')
end

-- local function action_toggle_recce_drawDebug()
--   log('I', logTag, 'action_toggle_recce_drawDebug')
--   if not is_recceApp_loaded() then return end
--   guihooks.trigger('aiPacenotesInputActionToggleDrawDebug')
-- end

local function action_recce_move_pacenote_forward()
  log('I', logTag, 'action_recce_move_pacenote_forward')
  if not is_recceApp_loaded() then return end
  -- NOTE re: gui hooks that simply proxy back to lua
  -- were going back to the frontend because the keybinding is meant to perform
  -- a frontend interaction. therefore take the same codepath.
  guihooks.trigger('aiPacenotesInputActionRecceMovePacenoteForward')
end

local function action_recce_move_pacenote_backward()
  log('I', logTag, 'action_recce_move_pacenote_backward')
  if not is_recceApp_loaded() then return end
  guihooks.trigger('aiPacenotesInputActionRecceMovePacenoteBackward')
end

local function action_recce_move_vehicle_forward()
  log('I', logTag, 'action_recce_move_vehicle_forward')
  if not is_recceApp_loaded() then return end
  guihooks.trigger('aiPacenotesInputActionRecceMoveVehicleForward')
end

local function action_recce_move_vehicle_backward()
  log('I', logTag, 'action_recce_move_vehicle_backward')
  if not is_recceApp_loaded() then return end
  guihooks.trigger('aiPacenotesInputActionRecceMoveVehicleBackward')
end

local function action_recce_toggle_debug_mode()
  log('I', logTag, 'action_recce_toggle_debug_mode')

  if extensions.isExtensionLoaded("gameplay_aipacenotes") then
    gameplay_aipacenotes.toggleDrawDebug()
  end

  if extensions.isExtensionLoaded("ui_aipacenotes_recceApp") then
    ui_aipacenotes_recceApp.toggleDrawDebug()
  end
end

local function action_codriver_volume_up()
  log('I', logTag, 'action_codriver_volume_up')
  guihooks.trigger('aiPacenotesInputActionCodriverVolumeUp')
end
local function action_codriver_volume_down()
  log('I', logTag, 'action_codriver_volume_down')
  guihooks.trigger('aiPacenotesInputActionCodriverVolumeDown')
end
local function action_codriver_calls_earlier()
  log('I', logTag, 'action_codriver_calls_earlier')
  guihooks.trigger('aiPacenotesInputActionCodriverTimingEarlier')
end
local function action_codriver_calls_later()
  log('I', logTag, 'action_codriver_calls_later')
  guihooks.trigger('aiPacenotesInputActionCodriverTimingLater')
end

-- local function action_recce_insert_mode()
  -- log('I', logTag, 'action_recce_insert_mode')
  -- if not is_recceApp_loaded() then return end
  -- guihooks.trigger('aiPacenotes.InputAction.RecceInsertMode')
-- end

-- M.action_transcribe_recording_start = action_transcribe_recording_start
-- M.action_transcribe_recording_stop = action_transcribe_recording_stop
-- M.action_toggle_recce_drawDebug = action_toggle_recce_drawDebug
-- M.action_recce_insert_mode = action_recce_insert_mode
M.action_transcribe_recording_cut = action_transcribe_recording_cut
M.action_recce_move_pacenote_forward = action_recce_move_pacenote_forward
M.action_recce_move_pacenote_backward = action_recce_move_pacenote_backward
M.action_recce_move_vehicle_forward = action_recce_move_vehicle_forward
M.action_recce_move_vehicle_backward = action_recce_move_vehicle_backward

M.action_codriver_volume_up = action_codriver_volume_up
M.action_codriver_volume_down = action_codriver_volume_down
M.action_codriver_calls_earlier = action_codriver_calls_earlier
M.action_codriver_calls_later = action_codriver_calls_later
M.action_recce_toggle_debug_mode = action_recce_toggle_debug_mode

return M
