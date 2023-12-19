local M = {}

-- Mapping table for digits to written-out numbers
local number_map = {
  ["0"] = "zero",
  ["1"] = "one",
  ["2"] = "two",
  ["3"] = "three",
  ["4"] = "four",
  ["5"] = "five",
  ["6"] = "six",
  ["7"] = "seven",
  ["8"] = "eight",
  ["9"] = "nine",
  ["10"] = "ten",
  ["-"] = "minus",
  ["for right"] = "four right",
  ["for left"] = "four left",
}
-- local boundary = "(%W)"

local function replaceDigits(note)
  -- Replace digits with written-out numbers
  for digit, word in pairs(number_map) do
    note = note:gsub(digit, word)
    -- note = note:gsub(boundary .. digit .. boundary, "%1" .. word .. "%1")
  end
  return note
end

M.replaceDigits = replaceDigits

return M
