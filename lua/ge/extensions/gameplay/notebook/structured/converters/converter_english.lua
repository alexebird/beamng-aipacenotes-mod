-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local re_util = require('/lua/ge/extensions/editor/rallyEditor/util')

local C = {}

function C:init(lang)
  -- self.corner_angles_data = nil
  self.lang = lang or 'english'

  self.translation = re_util.loadPacenotesTranslationFile(self.lang)
end

-- function C:loadCornerAnglesFile()
--   self.corner_angles_data = nil

--   local json, err = re_util.loadCornerAnglesFile()
--   if json then
--     self.corner_angles_data = json
--   end
-- end

function C:getCornerCall(cornerSeverity, cornerDirection)
  -- local abs_degrees = math.abs(degrees)

  -- Assuming we're using the first pacenote style for simplicity
  -- local angle_data = self.corner_angles_data.pacenoteStyles[1].angles

  -- for _, angle in ipairs(angle_data) do
  --   if abs_degrees >= angle.fromAngleDegrees and abs_degrees < angle.toAngleDegrees then
  --     local cornerCall = angle.cornerCall
  --     if degrees < 0 then
  --       return cornerCall .. " left"
  --     else
  --       return cornerCall .. " right"
  --     end
  --   end
  -- end

  -- dump(translation)

  local dirStr = cornerDirection > 0 and "right" or "left"

  local targetNum = tonumber(cornerSeverity)
  if not targetNum or targetNum < -1 then
    log('E', 'converter', 'Invalid corner severity: ' .. tostring(cornerSeverity))
    return nil
  end

  local closest = nil
  local minDiff = math.huge

  local pacenoteStyle = re_util.getStructuredPacenoteStyle()

  local style = self.translation.styles[pacenoteStyle]

  for _, img in ipairs(style) do
    local imgNum = tonumber(img.cornerSeverity)
    local diff = math.abs(imgNum - targetNum)

    if diff < minDiff then
      minDiff = diff
      closest = img
    end
  end

  -- TODO here we can create either "right three" or "three right".
  return closest.name .. " " .. dirStr
end

-- cornerLength = 0,      -- enum: 10=short, 20=normal, 30=long, 40=extra_long
function C:getCornerLength(length)
  if length == 10 then
    return 'short'
  elseif length == 20 then
    return ''
  elseif length == 30 then
    return 'long'
  elseif length == 40 then
    return 'extra long'
  else
    return nil
  end
end

-- cornerChange = 0,      -- enum: 10=opens, 20=tightens
function C:getCornerChange(change)
  if change == 10 then
    return 'opens'
  elseif change == 20 then
    return 'tightens'
  else
    return nil
  end
end

function C:convert(structured)
  local notesOut = {}

  local note = ""

  -- Generate the corner call
  if structured.fields.modSquare then
    if structured.fields.cornerDirection == -1 then
      note = 'square left'
    elseif structured.fields.cornerDirection == 1 then
      note = 'square right'
    end
  else
    if structured.fields.cornerSeverity and structured.fields.cornerDirection then
      if structured.fields.cornerDirection == 0 then
        note = ''
      else
        local cornerSeverity = structured.fields.cornerSeverity

        if cornerSeverity ~= '-1' then
          local cornerCall = self:getCornerCall(cornerSeverity, structured.fields.cornerDirection)
          note = cornerCall

          if structured.fields.cornerLength then
            local cornerLength = self:getCornerLength(structured.fields.cornerLength)
            if cornerLength then
              note = note .. ' ' .. cornerLength
            end
          end

          if structured.fields.cornerChange then
            local cornerChange = self:getCornerChange(structured.fields.cornerChange)
            if cornerChange then
              note = note .. ' ' .. cornerChange
            end
          end

        end
      end
    end
  end

  note = note or ''

  -- add question mark if note is not empty
  if note ~= '' then
    note = note .. "?"
    table.insert(notesOut, note)
  end

  -- if structured.crest then
  --   note = note .. " over crest"
  -- end

  -- Create the _out array based on structured data
  -- if structured.distance_after then
    -- table.insert(out, tostring(structured.distance_after) .. ".")
  -- end

  -- Build the english format
  -- english["_out"] = out
  -- english["before"] = "into"
  -- english["note"] = note
  -- english["after"] = tostring(structured.distance_after) or ""

  return notesOut
end

return function(...)
  local o = {}
  setmetatable(o, C)
  C.__index = C
  o:init(...)
  return o
end