local M = {}

-- Mapping table for digits to written-out numbers
-- local replacement_map = {
--   ["0"] = "zero",
--   ["1"] = "one",
--   ["2"] = "two",
--   ["3"] = "three",
--   ["4"] = "four",
--   ["5"] = "five",
--   ["6"] = "six",
--   ["7"] = "seven",
--   ["8"] = "eight",
--   ["9"] = "nine",
--   ["10"] = "ten",
--   ["-"] = "minus",
--   ["for right"] = "four right",
--   ["for left"] = "four left",
--   ["write"] = "right",
-- }

-- local function replaceEnglishWords(note)
--   if not note then return note end
--   for from, to in pairs(replacement_map) do
--     note = note:gsub(from, to)
--   end
--   return note
-- end

local function replaceWords(word_map, note)
  if not note then return note end

  local newnote, count

  for _,mapping in ipairs(word_map) do
    local from, to = mapping[1], mapping[2]
    newnote, count = note:gsub(from, to)
    -- note = note:gsub(from, to)
  end
  return newnote
end

-- M.replaceEnglishWords = replaceEnglishWords
M.replaceWords = replaceWords

return M
