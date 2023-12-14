-- Function to calculate 3D distance between two points
local function distance3D(a, b)
  return math.sqrt((a[1] - b[1])^2 + (a[2] - b[2])^2 + (a[3] - b[3])^2)
end

-- Function to find a waypoint by its type in a pacenote
local function findWaypointByType(pacenote, waypointType)
  for _, waypoint in ipairs(pacenote.pacenoteWaypoints) do
    if waypoint.waypointType == waypointType then
      return waypoint
    end
  end
  return nil
end

-- Generalized rounding function
local function custom_round(dist, round_to)
  return math.floor(dist / round_to + 0.5) * round_to
end

-- Function to round the distance based on given rules
local function round_distance(dist)
  if dist >= 1000 then
    return custom_round(dist, 250)/1000, "kilometers"
  elseif dist >= 100 then
    return custom_round(dist, 50)
  -- elseif dist >= 100 then
    -- return custom_round(dist, 10)
  else
    return custom_round(dist, 10)
  end
end

local written_out_numbers = {
  ["10"] = "ten",
  ["20"] = "twenty",
  ["30"] = "thirty",
  ["40"] = "forty",
  ["50"] = "fifty",
  ["60"] = "sixty",
  ["70"] = "seventy",
  ["80"] = "eighty",
  ["90"] = "ninety",
  ["100"] = "one hundred",
  ["150"] = "one fifty",
  ["200"] = "two hundred",
  ["250"] = "two fifty",
  ["300"] = "three hundred",
  ["350"] = "three fifty",
  ["400"] = "four hundred",
  ["450"] = "four fifty",
  ["500"] = "five hundred",
  ["550"] = "five fifty",
  ["600"] = "six hundred",
  ["650"] = "six fifty",
  ["700"] = "seven hundred",
  ["750"] = "seven fifty",
  ["800"] = "eight hundred",
  ["850"] = "eight fifty",
  ["900"] = "nine hundred",
  ["950"] = "nine fifty",
}

-- Function to convert numeric distances to their written-out form
local function normalize_distance(dist)
  local dist_str = tostring(dist)
  return written_out_numbers[dist_str] or dist_str
end

-- Function to convert distance to string
local function distance_to_string(dist)
  local rounded_dist, unit = round_distance(dist)
  local dist_str = tostring(rounded_dist)

  if unit == "kilometers" then
    dist_str = dist_str .. " " .. unit
  elseif rounded_dist >= 100 then
    -- dist_str = dist_str:sub(1, 1) .. " " .. dist_str:sub(2)
  end

  return dist_str
end


-- Function to normalize a note
local function normalize_note(note)
  local last_char = note:sub(-1)
  if not (last_char == "." or last_char == "?" or last_char == "!") then
    note = note .. "?"
  end

  -- Replace digits with written-out numbers
  for digit, word in pairs(number_map) do
    note = note:gsub(digit, word)
  end

  return note
end

local function normalize_notebook(notebook)

  local next_prepend = ""

  for i, pacenote in ipairs(notebook.pacenotes.sorted) do
    local normalized_note = normalize_note(pacenote.note)

    -- Apply any prepended text from the previous iteration
    if next_prepend ~= "" then
      normalized_note = next_prepend .. " " .. normalized_note
      next_prepend = ""
    end

    if i < #notebook.pacenotes then
      local nextPacenote = notebook.pacenotes[i + 1]
      local cornerEnd = findWaypointByType(pacenote, "cornerEnd")
      local cornerStart = findWaypointByType(nextPacenote, "cornerStart")

      if cornerEnd and cornerStart then
        local dist = distance3D(cornerEnd.pos, cornerStart.pos)
        local dist_str = distance_to_string(math.floor(dist))
        dist_str = normalize_distance(dist_str)

        -- Decide what to do based on the distance
        if dist <= 20 then
          next_prepend = "into"
          -- print(normalized_note)
        elseif dist <= 40 then
          next_prepend = "and"
          -- print(normalized_note)
        else
          -- print(normalized_note .. ' ' .. dist_str .. ".")
        end
      else
        -- print(normalized_note)
      end
    else
      -- print(normalized_note)
    end
  end

end
