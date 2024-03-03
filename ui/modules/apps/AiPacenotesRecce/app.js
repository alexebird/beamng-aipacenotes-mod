// vim: ts=2 sw=2
angular.module('beamng.apps').directive('aiPacenotesRecce', ['$interval', '$sce', '$timeout', function ($interval, $sce, $timeout) {
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
      let transcriptRefreshIntervalMs = 250

      $scope.transcripts = []
      $scope.isRecording = false
      // $scope.network_ok = false
      $scope.drawDebug = false
      $scope.drawDebugSnaproads = false

      $scope.cornerCall = defaultCornerCall
      $scope.wheelDegrees =  0

      $scope.cornerAnglesData = []
      $scope.selectedStyle = null

      $scope.dropdownStyleNames = []
      $scope.selectedStyleName = null

      $scope.missionIsLoaded = false
      $scope.loadedMissionName = null

      let transcriptInterval = null

      // dont wait for the first interval to get transcripts.
      // bngApi.engineLua('extensions.ui_aipacenotes_recceApp.desktopGetTranscripts()')

      function updateCornerCall() {
        var textElement = document.getElementById('cornerCall')
        textElement.textContent = $scope.cornerCall

        textElement = document.getElementById('wheelDegrees')
        textElement.textContent =  '' + $scope.wheelDegrees + '°'
      }

      $scope.$on('$destroy', function () {
        StreamsManager.remove(streamsList)
        bngApi.engineLua('extensions.unload("ui_aipacenotes_recceApp")')
      })

      $scope.$on('aiPacenotesMissionsLoaded', function (event, response) {
        console.log('recce missions loaded: ' + JSON.stringify(response))

        let missions = response.missions
        let last_mid = response.last_mission_id
        let last_load_state = response.last_load_state
        console.log(`recce last_mission_id=${last_mid} loaded=${last_load_state}`)

        if (Object.keys(missions).length === 0 && !Array.isArray(missions)) {
          $scope.missions = []
        } else {
          $scope.missions = missions
        }

        if ($scope.missions && $scope.missions.length > 0) {
          $scope.selectedMission = null
          $scope.selectedMissionName = null

          $scope.selectedMission = $scope.missions.find((mission) => mission.missionID === last_mid)

          if (!$scope.selectedMission) {
            $scope.selectedMission = $scope.missions[0]
          }

          $scope.dropdownMissionNames = $scope.missions.map((mission) => mission.missionName)
          $scope.selectedMissionName = $scope.selectedMission.missionName

          if (last_load_state) {
            $scope.btnLoadMission()
          }
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
          // $scope.network_ok = true
          // $scope.isRecording = response.is_recording
          $scope.transcripts = response.transcripts
          $scope.transcriptsError = null
        } else {
          // $scope.network_ok = false
          $scope.transcripts = []
          $scope.transcriptsError = $sce.trustAsHtml(response.error)
        }
      })

      $scope.$on('aiPacenotesInputActionDesktopCallNotOk', function (event, errMsg) {
        // $scope.network_ok = false
        $scope.transcriptsError = $sce.trustAsHtml(errMsg)
      })

      $scope.$on('aiPacenotesInputActionCutRecording', function (event) {
        $scope.btnRecordCut()

        if ($scope.isRecording) {
          var cutBtn = angular.element(document.getElementById('cut-btn'))
          cutBtn.addClass('cut-fake-click')
          $timeout(function() {
            cutBtn.removeClass('cut-fake-click')
          }, 150);
        }
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
        const loadedMissionId = $scope.selectedMission.missionID
        const loadedMissionDir = $scope.selectedMission.missionDir
        $scope.loadedMissionName = $scope.selectedMission.missionName
        $scope.missionIsLoaded = true
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.initRallyManager("'+loadedMissionId+'", "'+loadedMissionDir+'")')
        $scope.drawDebug = true
        updateLuaDrawDebug()
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setLastLoadState(true)')
      }

      $scope.btnUnloadMission = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.clearRallyManager()')
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setLastLoadState(false)')
        $scope.drawDebug = false
        $scope.missionIsLoaded = false
        updateLuaDrawDebug()
      }

      // $scope.btnRetryNetwork = function() {
      //   $scope.transcriptsError = $sce.trustAsHtml('connecting to desktop app...')
      //   bngApi.engineLua('extensions.ui_aipacenotes_recceApp.clearTimeout()')
      // }

      $scope.btnRecordStart = function() {
        $scope.isRecording = true

        transcriptInterval = $interval(() => {
          bngApi.engineLua('extensions.ui_aipacenotes_recceApp.desktopGetTranscripts()')
        }, transcriptRefreshIntervalMs)

        bngApi.engineLua(`extensions.ui_aipacenotes_recceApp.transcribe_recording_start(${$scope.recordDriveline}, ${$scope.recordVoice})`)
      }

      $scope.btnRecordStop = function() {
        $scope.isRecording = false

        if (angular.isDefined(transcriptInterval)) {
          $interval.cancel(transcriptInterval)
        }

        bngApi.engineLua("extensions.ui_aipacenotes_recceApp.transcribe_recording_stop()")
      }

      $scope.btnRecordCut = function() {
        if ($scope.isRecording) {
          bngApi.engineLua("extensions.ui_aipacenotes_recceApp.transcribe_recording_cut()")
        }
      }

      $scope.btnClearAll = function() {
        bngApi.engineLua("extensions.ui_aipacenotes_recceApp.transcribe_clear_all()")
      }

      $scope.submitPacenoteForm = function() {
        console.log($scope.pacenote)
      }

      $scope.recordDriveline = false
      $scope.recordVoice = false
      $scope.pacenote = "TODO: pacenote text"

      function updateLuaDrawDebug() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setDrawDebug('+$scope.drawDebug+')')
      }

      $scope.btnToggleDrawDebug = function() {
        $scope.drawDebug = !$scope.drawDebug
        updateLuaDrawDebug()
      }

      $scope.btnToggleSnaproadsDrawDebug = function() {
        $scope.drawDebugSnaproads = !$scope.drawDebugSnaproads
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setDrawDebugSnaproads('+$scope.drawDebugSnaproads+')')
      }

      // NOTE these are proxying a lua call through the recce app in order to stay on one pattern.
      // ie: inputAction(lua) -> JS(js) -> engineLua(lua)
      // this pattern is good in case some frontend state needs to be updated.
      $scope.btnMovePacenoteForward = function() {
        if ($scope.drawDebug) {
          bngApi.engineLua('extensions.ui_aipacenotes_recceApp.moveNextPacenoteForward()')
        }
      }
      $scope.btnMovePacenoteBackward = function() {
        if ($scope.drawDebug) {
          bngApi.engineLua('extensions.ui_aipacenotes_recceApp.moveNextPacenoteBackward()')
        }
      }

      $scope.btnMoveVehicleForward = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.moveVehicleForward()')
      }
      $scope.btnMoveVehicleBackward = function() {
        bngApi.engineLua('extensions.ui_aipacenotes_recceApp.moveVehicleBackward()')
      }

      $scope.btnRefreshCornerAngles()
      $scope.btnRefreshMissions()

      // Use vehicle reset to trigger a reload of the corner_angles.json file.
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
          if ($scope.selectedMission) {
            let missionId = $scope.selectedMission.missionID
            bngApi.engineLua('extensions.ui_aipacenotes_recceApp.setLastMissionId("'+missionId+'")')
          }
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
