-- custom lua node code

-- base64 encoding
-- function b64enc(data)
--   local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/' -- You will need this for encoding/decoding
--   return ((data:gsub('.', function(x) 
--     local r,b='',x:byte()
--     for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
--     return r;
--   end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
--     if (#x < 6) then return '' end
--     local c=0
--     for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
--     return b:sub(c+1,c+1)
--   end)..({ '', '==', '=' })[#data%3+1])
-- end

function normalize_text(input)
    -- Convert the input to lower case
    input = input:lower()

    -- Substitute any non-alphanumeric character with a hyphen
    input = input:gsub("%W", "-")

    -- Remove any consecutive hyphens
    input = input:gsub("%-+", "-")

    -- Remove any leading or trailing hyphens
    input = input:gsub("^%-", ""):gsub("%-$", "")

    return input
end


function printTable(t)
  for i, v in ipairs(t) do
    print(i, v)
  end
end

function entrypoint()
  local pacenote = self.pinIn.pacenote.value
  local levelName = self.pinIn.levelName.value
  local pathData = self.pinIn.pathData.value
  local missionId = gameplay_missions_missionManager.getForegroundMissionId()

  -- local pacenoteHash = b64enc(pacenote)
  local pacenoteHash = normalize_text(pacenote)
  local volume = 8
  local i18n = 'en-uk'

  --printTable(self)
  print("missionId: " .. missionId)
  print("pacenote: " .. pacenote .. ", hash=" .. pacenoteHash)
  local pacenoteFilePath = 'art/sound/aipacenotes/' .. missionId .. '/audio_files/' .. i18n .. '/pacenote_' .. pacenoteHash .. '.ogg'
  print("audio file path: " .. pacenoteFilePath)

  if file_exists(pacenoteFilePath) then
    -- print("pacenote file exists")
    Engine.Audio.playOnce('AudioGui', pacenoteFilePath, { volume=volume })
  else
    print("pacenote audio file does not exist")
  end
end

function file_exists(filename)
  local file = io.open(filename, "r")
  if file == nil then
    return false
  else
    file:close()
    return true
  end
end


-- for cli running and testing of code only
local isDev = os.getenv("DEV")
if isDev == "t" then
  print(normalize_text("Hello, World!"))
else
  entrypoint()
end