// vim: ts=2 sw=2
angular.module('beamng.apps').directive('aiPacenotesRecce', ['$interval', '$sce', function ($interval, $sce) {
  return {
    templateUrl: '/ui/modules/apps/AiPacenotesRecce/app.html',
    replace: true,
    controller: ['$log', '$scope', function ($log, $scope) {
      'use strict'

      // load the lua extension backing this UI app.
      bngApi.engineLua('extensions.load("ui_aipacenotes_recceApp")')

      var streamsList = ['electrics']
      StreamsManager.add(streamsList)

      let defaultCornerCall = 'c'
      let transcriptRefreshIntervalMs = 500

      $scope.transcripts = []
      $scope.is_recording = false
      $scope.network_ok = false
      $scope.drawDebug = false
      $scope.drawDebugSnaproads = false

      $scope.cornerCall = defaultCornerCall
      $scope.wheelDegrees =  0

      $scope.cornerAnglesData = []
      $scope.selectedStyle = null

      $scope.dropdownStyleNames = []
      $scope.selectedStyleName = null

      var transcriptInterval = $interval(() => {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.desktopGetTranscripts()')
      }, transcriptRefreshIntervalMs)

      // dont wait for the first interval to get transcripts.
      bngApi.engineLua('extensions.ui_aipacenotes_recceApp.desktopGetTranscripts()')

      function updateCornerCall() {
        var textElement = document.getElementById('cornerCall')
        textElement.textContent = $scope.cornerCall

        textElement = document.getElementById('wheelDegrees')
        textElement.textContent =  '' + $scope.wheelDegrees + '°'
      }

      $scope.$on('$destroy', function () {
        if (angular.isDefined(transcriptInterval)) {
          $interval.cancel(transcriptInterval);
        }
        StreamsManager.remove(streamsList)
        bngApi.engineLua('extensions.unload("ui_aipacenotes_recceApp")')
      })

      $scope.$on('aiPacenotesMissionsLoaded', function (event, response) {
        console.log(JSON.stringify(response))

        if (typeof response === 'object' && Object.keys(response).length === 0 && !Array.isArray(response)) {
          $scope.missions = []
        } else {
          $scope.missions = response
        }

        if ($scope.missions && $scope.missions.length > 0) {
          $scope.selectedMission = $scope.missions[0]
          $scope.dropdownMissionNames = $scope.missions.map((mission) => mission.missionName)
          $scope.selectedMissionName = $scope.dropdownMissionNames[0]
        } else {
          $scope.missions = []
          $scope.selectedMission = null
          $scope.dropdownMissionNames = []
          $scope.selectedMissionName = null
        }
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

      $scope.$on('aiPacenotesInputActionDesktopCallNotOk', function (event, errMsg) {
          $scope.network_ok = false
          $scope.transcriptsError = $sce.trustAsHtml(errMsg)
      })

      $scope.$on('aiPacenotesInputActionToggleDrawDebug', function (event) {
          $scope.btnToggleDrawDebug()
      })

      $scope.$on('aiPacenotesInputActionRecceMovePacenoteForward', function (event) {
          $scope.btnMovePacenoteForward()
      })

      $scope.$on('aiPacenotesInputActionRecceMovePacenoteBackward', function (event) {
          $scope.btnMovePacenoteBackward()
      })

      $scope.$on('aiPacenotesInputActionRecceMoveVehicleForward', function (event) {
          $scope.btnMoveVehicleForward()
      })

      $scope.$on('aiPacenotesInputActionRecceMoveVehicleBackward', function (event) {
          $scope.btnMoveVehicleBackward()
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
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setCornerAnglesStyleName("'+$scope.selectedStyleName+'")')

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

      $scope.btnToggleDrawDebug = function() {
        $scope.drawDebug = !$scope.drawDebug
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setDrawDebug('+$scope.drawDebug+')')
      }

      $scope.btnToggleSnaproadsDrawDebug = function() {
        $scope.drawDebugSnaproads = !$scope.drawDebugSnaproads
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setDrawDebugSnaproads('+$scope.drawDebugSnaproads+')')
      }

      // NOTE these are proxying a lua call through the recce app in order to stay on one pattern.
      // ie: inputAction(lua) -> JS(js) -> engineLua(lua)
      // this pattern is good in case some frontend state needs to be updated.
      $scope.btnMovePacenoteForward = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.moveNextPacenoteForward()')
      }
      $scope.btnMovePacenoteBackward = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.moveNextPacenoteBackward()')
      }

      $scope.btnMoveVehicleForward = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.moveVehicleForward()')
      }
      $scope.btnMoveVehicleBackward = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.moveVehicleBackward()')
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
          bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setCornerAnglesStyleName("'+$scope.selectedStyleName+'")')
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
