local C = {}
C.__index = C

local version = 2

function C:init()
  self.latestVersion = version

  self.fgPath = "/gameplay/missionTypes/rallyStage/rallyStage.flow.json"
  -- if self.missionTypeData.customFlowgraph then
  --   self.fgPath = self.missionFolder.."/custom.flow.json"
  -- end

  self.fgVariables = deepcopy(self.missionTypeData)
  self.missionTypeLabel = "Rally Stage"
  local reverse = false
  if self.missionTypeData.reversible then reverse = false end
  local rolling = false
  if self.missionTypeData.allowRollingStart then rolling = false end
  self.defaultProgressKey = string.format("%d-%s-%s",self.missionTypeData.defaultLaps, reverse, rolling)
  self.defaultAggregateValues = {
    all = {
      bestTime = 0
    }
  }
  self.defaultLeaderboardKey = 'highscore'
  self.autoAggregates = {
    {
      type = 'simpleHighscore',
      attemptKey = 'time', -- key in the attempt
      aggregateKey = 'bestTime', -- key in the aggregate
      sorting = 'ascending', -- keeping the lower time
      newBestKey = 'newBestTime',
      leaderboardKey = 'highscore',
      newLeaderboardEntryKey = 'rankedOnLeaderboardIndex'
    }
  }

  self.autoUiAttemptProgress = {
    {
      type = 'simple',
      formatFunction = 'detailledTime',
      attemptKey = 'time',
      columnLabel = 'bigMap.progressLabels.time',
    },
    {
      type = 'simple',
      formatFunction = 'detailledTime',
      attemptKey = 'penalty',
      columnLabel = 'missions.missions.general.penaltyTime',
    },
  }

  self.autoUiAggregateProgress = {
    {
      type = 'simple',
      formatFunction = 'detailledTime',
      aggregateKey = 'bestTime',
      columnLabel = 'bigMap.progressLabels.bestTime',
      newBestKey = 'newBestTime',
    }
  }
  self.autoUiBigmap = {
    aggregates = {
      aggregatePrimary = {
        progressKey = self.defaultProgressKey,
        aggregateKey = 'bestTime', -- select best time from detail progress key
        label = 'Best Time',
        formatFunction = 'detailledTime',
        type = 'simple'
      }
    }
  }

  self.starLabels = {
    justFinish = "missions.timeTrials.stars.justFinish",
    bronzeTime = "missions.timeTrials.stars.bronzeTime",
    silverTime = "missions.timeTrials.stars.silverTime",
    goldTime = "missions.timeTrials.stars.goldTime",

    justFinishPenalty = "missions.timeTrials.stars.justFinishPenalty",
    bronzePenalty = "missions.timeTrials.stars.bronzePenalty",
    silverPenalty = "missions.timeTrials.stars.silverPenalty",
    goldPenalty = "missions.timeTrials.stars.goldPenalty",

    --reverseTime = "Finish in {{reverseTime}} seconds in reversed mode.",
    --lapTime = "Get a single lap in {{lapTime}} seconds.",
    --reverseLapTime = "Get a single reverse lap in {{reverseLapTime}} seconds.",
  }
  self.sortedStarKeys = {'justFinish','bronzeTime','silverTime','goldTime','justFinishPenalty','bronzePenalty','silverPenalty','goldPenalty'}
  self.defaultStarOutroTexts = {
    justFinish = "missions.timeTrials.defaultOutroTexts.justFinish",
    bronzeTime = "missions.timeTrials.defaultOutroTexts.bronzeTime",
    silverTime = "missions.timeTrials.defaultOutroTexts.silverTime",
    goldTime   = "missions.timeTrials.defaultOutroTexts.goldTime",
    justFinishPenalty = "missions.timeTrials.defaultOutroTexts.justFinish",
    bronzePenalty = "missions.timeTrials.defaultOutroTexts.bronzeTime",
    silverPenalty = "missions.timeTrials.defaultOutroTexts.silverTime",
    goldPenalty = "missions.timeTrials.defaultOutroTexts.goldTime",
    noStarUnlocked = "missions.timeTrials.defaultOutroTexts.noStarUnlocked",
    noStarExists = "missions.timeTrials.defaultOutroTexts.justFinish"
  }

  self.bigMapIcon = {icon = "mission_airace02_triangle"}

  self:setBackwardsCompatibility({presetVehicleActive = "provideVehicleActive"})
end

function C:updateAttempt(attempt, newVersion) end

function C:getProgressKeyTranslation(progressKey)

  local keys = split(progressKey,'-',3)

  if         keys[2]=="true" and     keys[3]=="true" then
    return {txt = 'missions.timeTrials.progressKeyLabels.reverseRolling'..(keys[1] == 1 and 'OneLap' or ''), context = {laps = keys[1]}}
  elseif     keys[2]=="true" and keys[3]~="true" then
    return {txt = 'missions.timeTrials.progressKeyLabels.reverse'..(keys[1] == 1 and 'OneLap' or ''), context = {laps = keys[1]}}
  elseif keys[2]~="true" and     keys[3]==true then
    return {txt = 'missions.timeTrials.progressKeyLabels.rolling'..(keys[1] == 1 and 'OneLap' or ''), context = {laps = keys[1]}}
  elseif keys[2]~="true" and     keys[3]~="true" then
    return {txt = 'missions.timeTrials.progressKeyLabels.general'..(keys[1] == 1 and 'OneLap' or ''), context = {laps = keys[1]}}
  end
end


function C:processUserSettings(settings)
  self.userSettings = settings
  self:processCommonSettings(settings)
  self.currentProgressKey = string.format("%d-%s-%s",settings.laps or self.missionTypeData.defaultLaps, (settings.reverse or false) and self.missionTypeData.reversible, (settings.rolling or false) and self.missionTypeData.allowRollingStart)
end

function C:getUserSettingsData()
  local sData = self:getCommonSettingsData() or {}

  if self.missionTypeData.closed then
    table.insert(sData, {
      key = 'laps',
      label = 'missions.missions.general.userSettings.laps',
      type = 'int',
      value = self.missionTypeData.defaultLaps,
      min = 1,
      isProgressKey = true,
    })
  end
  if self.missionTypeData.reversible then
    table.insert(sData,{
      key = 'reverse',
      label = 'missions.missions.timeTrial.userSettings.reverse',
      type = 'bool',
      value = false,
      isProgressKey = true,
    })
  end
  if self.missionTypeData.allowRollingStart then
    table.insert(sData,{
      key = 'rolling',
      label = 'missions.missions.timeTrial.userSettings.rollingStart',
      type = 'bool',
      value = false,
      isProgressKey = true,
    })
  end
  return sData
end

function C:getWorldPreviewRoute()
  if not self.cachedWorldPreviewRoute then
    local mode = "navgraph"
    if self.missionTypeData.mapPreviewMode then
      mode = self.missionTypeData.mapPreviewMode
    end
    if mode == "none" then
      self.cachedWorldPreviewRoute = {}
      return self.cachedWorldPreviewRoute
    end
    -- load path from file
    local path = require('/lua/ge/extensions/gameplay/race/path')("New Path")
    path:onDeserialized(jsonReadFile(self.missionFolder.."/race.race.json"))
    path:autoConfig()
    local ret = {}
    for i, nId in ipairs(path.config.linearSegments) do
      local node = path.pathnodes.objects[nId]
      table.insert(ret, node.pos)
    end
    if self.missionTypeData.closed then
      table.insert(ret, ret[1])
    end
    if mode == "waypoints" then
      self.cachedWorldPreviewRoute = {}
      for _, p in ipairs(ret) do
        table.insert(self.cachedWorldPreviewRoute, {pos = p})
      end
      return self.cachedWorldPreviewRoute
    end
    if mode == "navgraph" then
      -- calculate in-world route
      local route = require('/lua/ge/extensions/gameplay/route/route')()
      route:setupPathMulti(ret)
      self.cachedWorldPreviewRoute = route.path
      return self.cachedWorldPreviewRoute
    end
  end
  return self.cachedWorldPreviewRoute
end

function C:getRandomizedAttempt(progressKey)
  return gameplay_missions_progress.testHelper.randomAttemptType(), {
    time = gameplay_missions_progress.testHelper.randomNumber(20,600),
  }
end

return function(...) return gameplay_missions_missions.flowMission(C, ...) end
