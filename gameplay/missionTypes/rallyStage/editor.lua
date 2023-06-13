-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

local C = {}
C.__index = C

function C:init()
  self:addDecoHeader("Mission Screen Text",'orange')
  self:addString("Start Screen Text","startScreenText","",9000, {tooltip = "The text that displays on the start-screen. For Example, 'Drive to the destination, and try not to damage the vehicle!'", isTranslation = true})
  self:addDecoSpacer()

  --self:addString("End Screen Title","outroTitleText","For example, 'Finished' or 'Mission Complete'",9000)
  self:addString("End Screen Text","endScreenText","",9000, {tooltip = "The text that displays on the end-screen. For example, 'You Did It!'", isTranslation = true})

  self:addDecoSeparator()

  self:addDecoHeader("Mission Settings",'orange')

  self:addNumeric("Bronze Time", "bronzeTime", 180,{associatedStars="bronzeTime"})
  self:addNumeric("Silver Time", "silverTime", 120,{associatedStars="silverTime"})
  self:addNumeric("Gold Time",   "goldTime",   60,{associatedStars="goldTime"})
  self:addDecoSeparator()
  self:addNumeric("Default Laps", "defaultLaps", 1)
  self:addBool("Can Reverse", "reversible", false,{},{tooltip = 'Is this track playable in reverse?',optional=true})
  self:addBool("Can Rolling Start", "allowRollingStart", false,{},{tooltip = 'Allow rolling start?',optional=true})
  self:addBool("Closed Circuit", "closed", true,{},{tooltip = 'Required for multiple laps',optional=true})

  self:addDecoSeparator()

  self:addFixedFile("Race File","/race.race.json",{tooltip = 'This is the main race file that contains the race.'})
  self:addFixedFile("Prefab",{"/mainPrefab.prefab","/mainPrefab.prefab.json"},{tooltip = 'This prefab is always loaded.', optional=true})
  self:addFixedFile("Forward Prefab",{"/forwardPrefab.prefab","/forwardPrefab.prefab.json"},{tooltip = 'This prefab is only loaded in forward mode.',optional=true})
  self:addFixedFile("Reverse Prefab",{"/reversePrefab.prefab","/reversePrefab.prefab.json"},{tooltip = 'This prefab is only loaded in reverse mode.',optional=true})

  self:addDecoSeparator()
  self:addDropdown("Map Preview", "mapPreviewMode", {"none","waypoints","navgraph"}, 'navgraph')
end

return function(...) return gameplay_missions_missions.editorHelper(C, ...) end