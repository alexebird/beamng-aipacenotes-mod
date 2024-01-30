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
  self:addDecoText("The Time values for the stars can be found in the career tab.")
  self:addNumeric("Bronze Time", "bronzeTime", 180,{associatedStars="bronzeTime", unit="time", hidden=true})
  self:addNumeric("Silver Time", "silverTime", 120,{associatedStars="silverTime", unit="time", hidden=true})
  self:addNumeric("Gold Time",   "goldTime",   60,{associatedStars="goldTime", unit="time", hidden=true})
  self:addNumeric("Just Finish Penalty", "justFinishPenalty", 30,{associatedStars="justFinishPenalty", unit="time", hidden=true})
  self:addNumeric("Bronze Time Total", "bronzeTimeTotal", 180,{associatedStars="bronzePenalty", unit="time", hidden=true})
  self:addNumeric("Bronze Time Penalty", "bronzeTimePenalty", 20,{associatedStars="bronzePenalty", unit="time", hidden=true})
  self:addNumeric("Silver Time Total", "silverTimeTotal", 120,{associatedStars="silverPenalty", unit="time", hidden=true})
  self:addNumeric("Silver Time Penalty", "silverTimePenalty", 10,{associatedStars="silverPenalty", unit="time", hidden=true})
  self:addNumeric("Gold Time Total",   "goldTimeTotal", 60,{associatedStars="goldPenalty", unit="time", hidden=true})
  self:addNumeric("Gold Time Penalty",   "goldTimePenalty", 0,{associatedStars="goldPenalty", unit="time", hidden=true})
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
  self:addFixedFile("Intro Cam Fwd", "/introFwd.camPath.json", {optional=true})
  self:addFixedFile("Outro Cam Fwd", "/outroFwd.camPath.json", {optional=true})
  self:addFixedFile("Finish Cam Fwd", "/finishFwd.camPath.json", {optional=true})
  self:addFixedFile("Intro Cam Rev", "/introRev.camPath.json", {optional=true})
  self:addFixedFile("Outro Cam Rev", "/outroRev.camPath.json", {optional=true})
  self:addFixedFile("Finish Cam Rev", "/finishRev.camPath.json", {optional=true})

  self:addDecoSeparator()

  self:addBool("Allow Flip","allowFlip", true, {},{tooltip = "If the player can flip their car using the recovery prompt."})
  self:addNumeric("Flip Limit","flipLimit",-1,{tooltip = "How many times the player can flip their car. Use 0 for unlimited."})
  self:addNumeric("Flip Penalty","flipPenalty",5,{tooltip = "Penalty (in seconds) for using the flip."})
  self:addBool("Allow Recover","allowRecover", true, {},{tooltip = "If the player can Recover their car using the recovery prompt."})
  self:addNumeric("Recover Limit","recoverLimit",-1,{tooltip = "How many times the player can Recover their car. Use 0 for unlimited."})
  self:addNumeric("Recover Penalty","recoverPenalty",5,{tooltip = "Penalty (in seconds) for using the Recover."})

  self:addDecoSeparator()
  self:addDropdown("Map Preview", "mapPreviewMode", {"none","waypoints","navgraph"}, 'navgraph')

end

return function(...) return gameplay_missions_missions.editorHelper(C, ...) end
