local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')
local im  = ui_imgui

local C = {}

C.name = 'AI Pacenotes Countdown'
C.icon = "timer"
C.description = 'Manages a Countdown. Displays it on the screen as well, using both Message and FlashMessage.'
C.color = re_util.aip_fg_color
--C.category = 'repeat'

C.pinSchema = {
  { dir = 'in', type = 'flow', name = 'flow', description = 'Inflow for this node.' },
  { dir = 'in', type = 'flow', name = 'reset', description = 'Reset the countdown.', impulse = true },
  { dir = 'in', type = 'number', name = 'duration', default = 4, description = 'Duration of countdown.' },
  { dir = 'in', type = 'number', name = 'maxAnnounced', default = 3, description = 'When to start speaking the count.' },
  { dir = 'in', type = 'string', name = 'countdownMsg', hardcoded = true, hidden = true, default = '%d', description = 'Message to show before the countdown message; %d is the number.' },
  { dir = 'in', type = 'string', name = 'finishMsg', default = 'Go!', description = 'Message to flash at the end of countdown; leave blank to use default translation string.' },
  { dir = 'in', type = 'number', name = 'finishMsgDuration', hardcoded = true, hidden = true, default = 1, description = 'Duration of finish message.' },

  { dir = 'out', type = 'flow', name = 'flow', description = 'Outflow for this node.' },
  { dir = 'out', type = 'flow', name = 'finished', description = 'Triggers when countdown has finished.', impulse = true },
  { dir = 'out', type = 'flow', name = 'ongoing', description = 'Triggers when countdown is in progress.' },
}
C.tags = {'scenario'}

function C:init(mgr, ...)
  self.data.useImgui = false
  self.data.useMessages = false
  self.data.playSounds = true
  self.data.bigFinishMsg = true
  self.data.visualCountdown = true

  self.duration = 1
  self.maxAnnounced = 1
  self.timer = 1
  self.msg = "Go!"
  self.done = false
  self.running = false
  self.flags = {
    finished = false
  }
end

function C:onExecutionStarted()
  self.duration = 1
  self.timer = 1
  self.msg = "Go!"
end

function C:_executionStopped()
  self:stopTimer()
end

function C:reset()
  self:stopTimer()
  extensions.gameplay_aipacenotes.getRallyManager().audioManager:resetAudioQueue()
  self.pinOut.flow.value = false
  self.pinOut.finished.value = false
  self.pinOut.ongoing.value = false
end

function C:stopTimer()
  self.done = false
  self.running = false
  self.flags = {
    finished = false
  }
end

function C:startTimer()
  self.duration = self.pinIn.duration.value or 5
  self.maxAnnounced = self.pinIn.maxAnnounced.value or 5
  self.timer = self.duration
  self.running = true
  self.msg = self.pinIn.finishMsg.value or "ui.scenarios.go"
  guihooks.trigger('ScenarioFlashMessageClear')
  self.flags.finished = false
  self.pinOut.flow.value = false
end

function C:enqueueStaticPacenoteByName(pacenote_name)
  if self.data.playSounds then
    return extensions.gameplay_aipacenotes.getRallyManager().audioManager:enqueueStaticPacenoteByName(pacenote_name)
  else
    return nil
  end
end

function C:show(msg, big, duration, force)
  --ui_message(msg, 1, "")
  duration = duration or (big and 1.4 or 0.95)
  if force or self.data.visualCountdown then
    guihooks.trigger('ScenarioFlashMessage', {{msg, duration , "", big}})
    if self.data.useMessages then
      guihooks.trigger('Message', {
        ttl = 1,
        msg = tostring(msg),
        category =  ("countdown__"..self.id),
        icon = 'timer'}
      )
    end
  end
end

function C:countdown()
  if not self.running then return end

  local old = math.floor(self.timer)
  self.timer = self.timer - self.mgr.dtSim
  if self.timer <= 0 then
    local forceVisual = false
    if not self:enqueueStaticPacenoteByName('go_1/c') then
      forceVisual = true
      if self.data.playSounds then
        Engine.Audio.playOnce('AudioGui', 'event:UI_CountdownGo')
      end
    end
    self:show(self.msg, self.data.bigFinishMsg, self.pinIn.finishMsgDuration.value, forceVisual)

    self.flags.finished = true
    self.running = false
    self.pinOut.flow.value = true
    self.done = true
  else
    if old ~= math.floor(self.timer) and old <= self.maxAnnounced then
      self.countdownMsg = self.pinIn.countdownMsg.value or "%d"
      local countdownMsg = string.format(self.countdownMsg, old)
      local bigMsg = self.countdownMsg == "%d"

      local forceVisual = false
      if not self:enqueueStaticPacenoteByName('countdown_'..countdownMsg..'/c') then
        forceVisual = true
        if self.data.playSounds  then
          Engine.Audio.playOnce('AudioGui', 'event:UI_Countdown1')
        end
      end
      self:show(countdownMsg, bigMsg, 0.95, forceVisual)
    end
    if self.data.useImgui then
      local avail = im.GetContentRegionAvail()
      local txt = " - " .. (math.ceil(old)+1) .. " - "
      local tWidth = im.CalcTextSize(txt)
      if tWidth.x < avail.x then
        im.Dummy(im.ImVec2((avail.x-tWidth.x)/2 -10,0))
        im.SameLine()
      end
      im.Text(txt)
    end
  end
end

function C:drawMiddle(builder, style)
  builder:Middle()
  im.ProgressBar((self.duration - self.timer) / self.duration, im.ImVec2(100,0))
  if not self.running then
    if self.done then
      im.Text("Done")
    else
      im.Text("Stopped")
    end
  else
    im.Text("Running")
  end
end

function C:work(args)
  if self.pinIn.reset.value then
    self:reset()
  end
  if self.pinIn.flow.value and not self.running and not self.done then
    self:startTimer()
  end
  self:countdown()
  self.pinOut.flow.value = self.done
  self.pinOut.ongoing.value = self.running
  -- set out pins according to flags and reset flags
  for pName, val in pairs(self.flags) do
    self.pinOut[pName].value = val
    self.flags[pName] = false
  end
end

return _flowgraph_createNode(C)
