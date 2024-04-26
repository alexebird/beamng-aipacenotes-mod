// vim: ts=2 sw=2

// angular.module('beamng.apps').directive('focusMe', function($timeout) {
//   return {
//     link: function(scope, element, attrs) {
//       scope.$watch(attrs.focusMe, function(value) {
//         if(value === true) {
//           // Using $timeout to ensure focus is called within Angular's digest cycle,
//           // can be omitted if focusing after certain events where Angular's digest cycle is already in process.
//           $timeout(function() {
//             element[0].focus();
//           });
//           scope[attrs.focusMe] = false; // Optionally reset the condition
//         }
//       });
//     }
//   };
// });

angular.module('beamng.apps').directive('aiPacenotesRecce', ['$interval', '$sce', '$timeout', function ($interval, $sce, $timeout) {
  return {
    templateUrl: '/ui/modules/apps/AiPacenotesRecce/app.html',
    replace: true,
    controller: ['$log', '$scope', function ($log, $scope) {
      'use strict'

      // load the lua extension backing this UI app.
      bngApi.engineLua('extensions.load("ui_aipacenotes_recceApp")')

      // var streamsList = ['electrics']
      // StreamsManager.add(streamsList)

      // let defaultCornerCall = 'c'
      let transcriptRefreshIntervalMs = 250

      // $scope.transcripts = []
      $scope.isRecording = false
      // $scope.network_ok = false
      $scope.showNotes = false
      $scope.drawDebugSnaproads = false
      // $scope.insertMode = false

      // $scope.cornerCall = defaultCornerCall
      // $scope.wheelDegrees =  0

      // $scope.cornerCallStyle = null

      $scope.missionIsLoaded = false
      $scope.loadedMissionName = null

      $scope.clear1Enabled = false

      $scope.recordDriveline = false
      $scope.recordVoice = false
      // $scope.pacenoteText = ""

      $scope.missions = []
      $scope.dropdownMissionNames = []
      $scope.selectedMission = null
      $scope.selectedMissionName = null

      $scope.codriverWaitValues = [
        'none',
        'small',
        'medium',
        'large',
      ]
      $scope.selectedCodriverWait = 'none'

      let transcriptInterval = null

      // function updateCornerCall() {
        // var textElement = document.getElementById('cornerCall')
        // textElement.textContent = $scope.cornerCall

        // var textElement = document.getElementById('wheelDegrees')
        // textElement.textContent =  '' + $scope.wheelDegrees + '°'
      // }

      function refreshRecceApp() {
        bngApi.engineLua('ui_aipacenotes_recceApp.refresh()')
      }

      function updateLuaShowNotes() {
        bngApi.engineLua('ui_aipacenotes_recceApp.setShowNotes('+$scope.showNotes+')')
      }

      function updateLuaDrawDebugSnaproads() {
        bngApi.engineLua('ui_aipacenotes_recceApp.setDrawDebugSnaproads('+$scope.drawDebugSnaproads+')')
      }

      $scope.allowPacenoteTextEditing = function() {
        if ($scope.showNotes) {
          return $scope.drawDebugSnaproads
        } else {
          return false
        }
      }

      // $scope.handleKeyDown = function(event) {
      //   console.log(event.key)
      //   // Prevent default behavior and stop propagation
      //   // event.preventDefault();
      //   // event.stopPropagation();
      // };

      $scope.$on('$destroy', function () {
        // StreamsManager.remove(streamsList)
        bngApi.engineLua('extensions.unload("ui_aipacenotes_recceApp")')
      })

      $scope.$on('aiPacenotes.recceApp.onExtensionLoaded', function (event, response) {
        refreshRecceApp()
      })

      $scope.$on('aiPacenotes.recceApp.refreshed', function (event, response) {
        // console.log('recce missions loaded: ' + JSON.stringify(response))

        // $scope.cornerCallStyle = response.corner_angles_style

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

      // $scope.$on('aiPacenotesTranscriptsLoaded', function (event, response) {
      //   if (response.ok) {
      //     $scope.transcripts = response.transcripts
      //     $scope.transcriptsError = null
      //   } else {
      //     $scope.transcripts = []
      //     $scope.transcriptsError = $sce.trustAsHtml(response.error)
      //   }
      // })
      //
      // $scope.$on('aiPacenotesInputActionDesktopCallNotOk', function (event, errMsg) {
      //   // $scope.network_ok = false
      //   $scope.transcriptsError = $sce.trustAsHtml(errMsg)
      // })

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

      // $scope.$on('aiPacenotesInputActionToggleDrawDebug', function (event) {
      //   $scope.btnToggleShowNotes()
      // })

      $scope.$on('aiPacenotesInputActionRecceMovePacenoteForward', function (event) {
        $scope.btnMovePacenoteATForward()
      })

      $scope.$on('aiPacenotesInputActionRecceMovePacenoteBackward', function (event) {
        $scope.btnMovePacenoteATBackward()
      })

      $scope.$on('aiPacenotesInputActionRecceMoveVehicleForward', function (event) {
        $scope.btnMoveVehicleForward()
      })

      $scope.$on('aiPacenotesInputActionRecceMoveVehicleBackward', function (event) {
        $scope.btnMoveVehicleBackward()
      })

      $scope.$on('aiPacenotes.recceApp.pacenoteTextChanged', function (event, resp) {
        // $scope.pacenoteText = resp.pacenoteText

        var pacenoteText = document.getElementById('pacenoteInput')
        pacenoteText.value = resp.pacenoteText

        // console.log(resp.pacenoteCodriverWait)
        $scope.selectedCodriverWait = resp.pacenoteCodriverWait
      })

      // $scope.$on('aiPacenotes.InputAction.RecceInsertMode', function (event, resp) {
      //   // $scope.insertMode = true
      //
      //   var el = document.getElementById('pacenote-input')
      //   el.focus()
      // })

      $scope.btnRefreshMissions = function() {
        refreshRecceApp()
      }

      $scope.btnLoadMission = function() {
        if ($scope.selectedMission) {
          const loadedMissionId = $scope.selectedMission.missionID
          const loadedMissionDir = $scope.selectedMission.missionDir
          $scope.loadedMissionName = $scope.selectedMission.missionName
          $scope.missionIsLoaded = true
          bngApi.engineLua('ui_aipacenotes_recceApp.loadMission("'+loadedMissionId+'", "'+loadedMissionDir+'")')
          $scope.showNotes = true
          $scope.drawDebugSnaproads = false
          // $scope.pacenoteText = ""
          updateLuaShowNotes()
          updateLuaDrawDebugSnaproads()
          bngApi.engineLua('ui_aipacenotes_recceApp.setLastLoadState(true)')
        }
      }

      $scope.btnUnloadMission = function() {
        bngApi.engineLua('ui_aipacenotes_recceApp.unloadMission()')
        bngApi.engineLua('ui_aipacenotes_recceApp.setLastLoadState(false)')
        $scope.showNotes = false
        $scope.drawDebugSnaproads = false
        $scope.missionIsLoaded = false
        // $scope.pacenoteText = ""
        var pacenoteText = document.getElementById('pacenoteInput')
        pacenoteText.value = ""
        $scope.selectedCodriverWait = "none"
        updateLuaShowNotes()
        updateLuaDrawDebugSnaproads()
      }

      $scope.btnRecordStart = function() {
        $scope.isRecording = true

        transcriptInterval = $interval(() => {
          bngApi.engineLua('ui_aipacenotes_recceApp and ui_aipacenotes_recceApp.desktopGetTranscripts()')
        }, transcriptRefreshIntervalMs)

        bngApi.engineLua(`ui_aipacenotes_recceApp.transcribe_recording_start(${$scope.recordDriveline}, ${$scope.recordVoice})`)
      }

      $scope.btnRecordStop = function() {
        $scope.isRecording = false

        if (angular.isDefined(transcriptInterval)) {
          $interval.cancel(transcriptInterval)
        }

        bngApi.engineLua("ui_aipacenotes_recceApp.transcribe_recording_stop()")
      }

      $scope.btnRecordCut = function() {
        if ($scope.isRecording) {
          bngApi.engineLua("ui_aipacenotes_recceApp.transcribe_recording_cut()")
        }
      }

      $scope.btnClearAll = function() {
        $scope.clear1Enabled = false
        bngApi.engineLua("ui_aipacenotes_recceApp.transcribe_clear_all()")
      }

      $scope.btnClear1 = function() {
        if ($scope.clear1Enabled) {
          $scope.clear1Enabled = false
        } else {
          $scope.clear1Enabled = true
        }
      }

      $scope.submitPacenoteForm = function() {
        var savedNotifier = document.getElementById('savedNotifier')
        savedNotifier.style.visibility = 'visible'

        var pacenoteText = document.getElementById('pacenoteInput').value
        // console.log(pacenoteText)
        bngApi.engineLua(`ui_aipacenotes_recceApp.setSelectedPacenoteText("${pacenoteText}")`)

        $timeout(function() {
          var savedNotifier = document.getElementById('savedNotifier')
          savedNotifier.style.visibility = 'hidden'
        }, 1000);
      }

      $scope.btnToggleShowNotes = function() {
        $scope.showNotes = !$scope.showNotes

        // if (!$scope.showNotes) {
        //   $scope.pacenoteText = ""
        // }
        updateLuaShowNotes()
      }

      $scope.btnToggleSnaproadsDrawDebug = function() {
        $scope.drawDebugSnaproads = !$scope.drawDebugSnaproads
        // if (!$scope.drawDebugSnaproads) {
          // $scope.pacenoteText = ""
        // }
        updateLuaDrawDebugSnaproads()
      }

      // NOTE these are proxying a lua call through the recce app in order to stay on one pattern.
      // ie: inputAction(lua) -> JS(js) -> engineLua(lua)
      // this pattern is good in case some frontend state needs to be updated.
      $scope.btnMovePacenoteATForward = function() {
        if ($scope.showNotes) {
          bngApi.engineLua('ui_aipacenotes_recceApp.movePacenoteATForward()')
        }
      }
      $scope.btnMovePacenoteATBackward = function() {
        if ($scope.showNotes) {
          bngApi.engineLua('ui_aipacenotes_recceApp.movePacenoteATBackward()')
        }
      }

      $scope.btnMovePacenoteSelectionForward = function() {
        bngApi.engineLua('ui_aipacenotes_recceApp.movePacenoteSelectionForward()')
      }
      $scope.btnMovePacenoteSelectionBackward = function() {
        bngApi.engineLua('ui_aipacenotes_recceApp.movePacenoteSelectionBackward()')
      }
      $scope.btnMovePacenoteSelectionToVehicle = function() {
        bngApi.engineLua('ui_aipacenotes_recceApp.movePacenoteSelectionToVehicle()')
      }

      $scope.btnMoveVehicleForward = function() {
        bngApi.engineLua('ui_aipacenotes_recceApp.moveVehicleForward()')
      }
      $scope.btnMoveVehicleBackward = function() {
        bngApi.engineLua('ui_aipacenotes_recceApp.moveVehicleBackward()')
      }
      $scope.btnMoveVehicleToSelectedPacenote = function() {
        bngApi.engineLua('ui_aipacenotes_recceApp.moveVehicleToSelectedPacenote()')
      }

      // Use vehicle reset to trigger a reload of the corner_angles.json file.
      // $scope.$on('VehicleReset', function (event, data) {
      //   $scope.$evalAsync(function () {
      //     // $scope.btnRefreshCornerAngles()
      //   })
      // })

      $scope.$watch('selectedMissionName', function(newValue, oldValue) {
        if (newValue !== oldValue) {
          $scope.selectedMission = $scope.missions.find(mission => mission.missionName === $scope.selectedMissionName)
          if ($scope.selectedMission) {
            let missionId = $scope.selectedMission.missionID
            bngApi.engineLua('ui_aipacenotes_recceApp.setLastMissionId("'+missionId+'")')
          }
        }
      });

      $scope.$watch('selectedCodriverWait', function(newValue, oldValue) {
        console.log(newValue)
        if (newValue !== oldValue) {
          $scope.selectedCodriverWait = newValue
          bngApi.engineLua('ui_aipacenotes_recceApp.setSelectedPacenoteCodriverWait("'+$scope.selectedCodriverWait+'")')
        }
      });

      // $scope.$on('streamsUpdate', function (event, streams) {
      //   if (!streams.electrics) return
      //   if (!$scope.cornerCallStyle) return
      //
      //   // console.log(JSON.stringify($scope.selectedStyle))
      //
      //   let steering = streams.electrics.steering
      //   // let steeringUnassisted = steering-streams.electrics.steeringUnassisted
      //   // let steeringInput = streams.electrics.steering_input
      //
      //   let steeringVal = steering
      //   let absSteeringVal = Math.abs(steeringVal)
      //   // $scope.wheelDegrees = Math.round(steeringVal) + ''
      //
      //   for (let item of $scope.cornerCallStyle.angles) {
      //     if (absSteeringVal >= item.fromAngleDegrees && absSteeringVal < item.toAngleDegrees) {
      //       let direction = steeringVal >= 0 ? "L" : "R"
      //       let cornerCallWithDirection = item.cornerCall + direction
      //
      //       if (item.cornerCall === "_deadzone") {
      //         cornerCallWithDirection = "c"
      //       }
      //
      //       $scope.cornerCall = cornerCallWithDirection
      //       // updateCornerCall()
      //     }
      //   }
      // }) // $scope.$on('streamsUpdate')

    }] // end controller
  } // end directive
}])
