// vim: ts=2 sw=2
angular.module('beamng.apps').directive('aiPacenotesRecce', [function () {
  return {
    templateUrl: '/ui/modules/apps/AiPacenotesRecce/app.html',
    replace: true,
    controller: ['$log', '$scope', function ($log, $scope) {
      'use strict'

      var streamsList = ['electrics']
      StreamsManager.add(streamsList)
      $scope.$on('$destroy', function () {
        StreamsManager.remove(streamsList)
        bngApi.engineLua('extensions.unload("ui_aiPacenotes_recceApp")')
      })

      bngApi.engineLua('extensions.load("ui_aiPacenotes_recceApp")')

      function reloadCornerAngles() {
        bngApi.engineLua('extensions.ui_aiPacenotes_recceApp.loadCornerAnglesFile()')
      }

      function updateCornerCall() {
        var textElement = document.getElementById('cornerCall')
        textElement.textContent = $scope.cornerCall
      }

      let defaultCornerCall = 'c'

      $scope.cornerCall = defaultCornerCall
      $scope.cornerAnglesData = []
      $scope.selectedStyle = null

      $scope.dropdownStyleNames = []
      $scope.selectedStyleName = null

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

        $scope.$digest()
      })

      $scope.btnReloadCornerAngles = function() {
        reloadCornerAngles()
        // bngApi.engineLua('extensions.ui_aiPacenotes_recceApp.loadCornerAnglesFile()', (response) => {
        // $scope.pacenoteStyles = response
        // $scope.cornerCall = '-'
        // })
      }

      reloadCornerAngles()

      // Use vehicle reset to trigger a reload of the cornerAngles.json file.
      $scope.$on('VehicleReset', function (event, data) {
        $scope.$evalAsync(function () {
          reloadCornerAngles()
        })
      })

      $scope.$watch('selectedStyleName', function(newValue, oldValue) {
        if (newValue !== oldValue) {
          $scope.selectedStyle = $scope.cornerAnglesData.pacenoteStyles.find(style => style.name === $scope.selectedStyleName)
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
