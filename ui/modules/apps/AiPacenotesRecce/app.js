// vim: ts=2 sw=2
angular.module('beamng.apps').directive('aiPacenotesRecce', ['$interval', '$sce', function ($interval, $sce) {
  return {
    templateUrl: '/ui/modules/apps/AiPacenotesRecce/app.html',
    replace: true,
    controller: ['$log', '$scope', function ($log, $scope) {
      'use strict'

      var streamsList = ['electrics']
      StreamsManager.add(streamsList)

      bngApi.engineLua('extensions.load("ui_aipacenotes_recceApp")')

      function updateCornerCall() {
        var textElement = document.getElementById('cornerCall')
        textElement.textContent = $scope.cornerCall

        textElement = document.getElementById('wheelDegrees')
        textElement.textContent =  '' + $scope.wheelDegrees + '°'
      }

      let defaultCornerCall = 'c'

      $scope.transcripts = []
      $scope.is_recording = false
      $scope.network_ok = false

      $scope.cornerCall = defaultCornerCall
      $scope.wheelDegrees =  0

      $scope.cornerAnglesData = []
      $scope.selectedStyle = null

      $scope.dropdownStyleNames = []
      $scope.selectedStyleName = null

      var transcriptInterval = $interval(() => {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.desktopGetTranscripts()')
      }, 500)
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.desktopGetTranscripts()')

      $scope.$on('$destroy', function () {
        if (angular.isDefined(transcriptInterval)) {
          $interval.cancel(transcriptInterval);
        }
        StreamsManager.remove(streamsList)
        bngApi.engineLua('extensions.unload("ui_aipacenotes_recceApp")')
      })

      $scope.$on('aiPacenotesMissionsLoaded', function (event, response) {
        // console.log(JSON.stringify(response))
          $scope.missions = response
          $scope.selectedMission = $scope.missions[0]
          $scope.dropdownMissionNames = $scope.missions.map((mission) => mission.missionName)
          $scope.selectedMissionName = $scope.dropdownMissionNames[0]
      })

      $scope.$on('aiPacenotesTranscriptsLoaded', function (event, response) {
        // console.log(JSON.stringify(response))
        if (response.ok) {
          $scope.network_ok = true
          $scope.is_recording = response.is_recording
          $scope.transcripts = response.transcripts
          $scope.transcriptsError = null
        } else {
          $scope.network_ok = false
          $scope.transcripts = []
          $scope.transcriptsError = $sce.trustAsHtml(response.error)
        }
      })

      $scope.$on('aiPacenotesDesktopCallNotOk', function (event, errMsg) {
          $scope.network_ok = false
          $scope.transcriptsError = $sce.trustAsHtml(errMsg)
      })

      $scope.$on('aiPacenotesCornerAnglesLoaded', function (event, cornerAnglesData, errMsg) {
        if (errMsg) {
          console.error(errMsg)
          return
        }

        // console.log('reloaded corner angles')
        // console.log(JSON.stringify(cornerAnglesData))

        $scope.cornerAnglesData = cornerAnglesData
        $scope.selectedStyle = $scope.cornerAnglesData.pacenoteStyles[0]

        $scope.dropdownStyleNames = $scope.cornerAnglesData.pacenoteStyles.map((style) => style.name)
        $scope.selectedStyleName = $scope.dropdownStyleNames[0]

        // $scope.$digest()
      })

      $scope.btnRefreshCornerAngles = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.loadCornerAnglesFile()')
        // bngApi.engineLua('extensions.ui_aipacenotes_recceApp.loadCornerAnglesFile()', (response) => {
        // $scope.pacenoteStyles = response
        // $scope.cornerCall = '-'
        // })
      }

      $scope.btnRefreshMissions = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.listMissionsForLevel()')
      }

      $scope.btnLoadMission = function() {
        let missionId = $scope.selectedMission.missionId
        let missionDir = $scope.selectedMission.missionDir
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.initRallyManager("'+missionId+'", "'+missionDir+'")')
      }

      $scope.btnUnloadMission = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.clearRallyManager()')
      }

      $scope.btnRetryNetwork = function() {
        $scope.transcriptsError = $sce.trustAsHtml('connecting to desktop app...')
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.clearTimeout()')
      }

      $scope.btnRefreshCornerAngles()
      $scope.btnRefreshMissions()

      // Use vehicle reset to trigger a reload of the cornerAngles.json file.
      $scope.$on('VehicleReset', function (event, data) {
        $scope.$evalAsync(function () {
          $scope.btnRefreshCornerAngles()
        })
      })

      $scope.$watch('selectedStyleName', function(newValue, oldValue) {
        if (newValue !== oldValue) {
          $scope.selectedStyle = $scope.cornerAnglesData.pacenoteStyles.find(style => style.name === $scope.selectedStyleName)
        }
      });

      $scope.$watch('selectedMissionName', function(newValue, oldValue) {
        if (newValue !== oldValue) {
          $scope.selectedMission = $scope.missions.find(mission => mission.missionName === $scope.selectedMissionName)
        }
      });

      $scope.$on('streamsUpdate', function (event, streams) {
        if (!streams.electrics) return
        if (!$scope.selectedStyle) return

        // console.log(JSON.stringify($scope.selectedStyle))

        let steering = streams.electrics.steering
        // let steeringUnassisted = steering-streams.electrics.steeringUnassisted
        // let steeringInput = streams.electrics.steering_input

        let steeringVal = steering
        let absSteeringVal = Math.abs(steeringVal)
        $scope.wheelDegrees = Math.round(steeringVal) + ''

        for (let item of $scope.selectedStyle.angles) {
          if (absSteeringVal >= item.fromAngleDegrees && absSteeringVal < item.toAngleDegrees) {
            let direction = steeringVal >= 0 ? "L" : "R"
            let cornerCallWithDirection = item.cornerCall + direction

            if (item.cornerCall === "_deadzone") {
              cornerCallWithDirection = "c"
            }

            $scope.cornerCall = cornerCallWithDirection
            updateCornerCall()
          }
        }
      }) // $scope.$on('streamsUpdate')

    }] // end controller
  } // end directive
}])
