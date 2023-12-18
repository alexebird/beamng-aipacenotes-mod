-- gameplay_rally_cornerAngles
local M = {}

local function load()
  local filename = '/settings/aipacenotes/cornerAngles.json'
  local json = jsonReadFile(filename)
  if not json then
    log('E', 'aipacenotes', 'unable to find cornerAngles file: ' .. tostring(filename))
    return nil
  end
  return json
end

M.load = load

return M
