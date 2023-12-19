local json = require('dkjson')  -- Replace 'dkjson' with your JSON library if using a different one

-- Function to add a top-level 'version' field
local function addVersionField(jsonObject)
    if jsonObject["version"] ~= "2" then
        jsonObject["version"] = "2"
    end
end

-- Function to check if 'notes' is already wrapped
local function isNotesWrapped(notes)
    for _, note in pairs(notes) do
        if type(note) ~= "table" or not note["note"] then
            return false
        end
    end
    return true
end

-- Function to wrap each 'notes' value in an object with key 'note'
local function wrapNotes(jsonObject)
    for _, pacenote in ipairs(jsonObject["pacenotes"]) do
        if pacenote["notes"] and not isNotesWrapped(pacenote["notes"]) then
            for lang, note in pairs(pacenote["notes"]) do
                pacenote["notes"][lang] = { note = note }
            end
        end
    end
end

-- Main function
local function main(filename, toStdout)
    -- Read the file
    local file = io.open(filename, "r")
    if not file then
        error("File not found: " .. filename)
    end

    local content = file:read("*a")
    file:close()

    -- Decode JSON content
    local jsonObject, pos, err = json.decode(content)
    if err then
        error("Error parsing JSON: " .. err)
    end

    -- Apply transformations
    addVersionField(jsonObject)
    wrapNotes(jsonObject)

    -- Encode JSON
    local updatedJson = json.encode(jsonObject)

    -- Output based on the toStdout flag
    if toStdout then
        print(updatedJson)
    else
        -- Overwrite the file
        file = io.open(filename, "w")
        file:write(updatedJson)
        file:close()
    end
end

-- Get the filename and output option from the command line arguments
local toStdout = arg[1] == 't'
local filename = arg[2]

if not filename then
    error("No file name provided.")
end

main(filename, toStdout)
