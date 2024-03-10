// vim: ts=2 sw=2

angular.module('beamng.apps').directive('aiPacenotesCornerCalls', ['$interval', '$sce', '$timeout', function ($interval, $sce, $timeout) {
  return {
    templateUrl: '/ui/modules/apps/aiPacenotesCornerCalls/app.html',
    replace: true,
    controller: ['$log', '$scope', function ($log, $scope) {
      'use strict'

      var streamsList = ['electrics']
      StreamsManager.add(streamsList)

      let defaultCornerCall = 'c'
      let transcriptRefreshIntervalMs = 250
      const steeringAngleColors = [
        "#ff0f59", // pink
        "#0dff59", // green
        "#00e3ff", // blue
        "#fffe1f", // yellow
      ]

      $scope.transcripts = []
      $scope.cornerCall = defaultCornerCall
      $scope.wheelDegrees =  0
      $scope.cornerCallStyle = null
      $scope.cornerCallColor = 0
      $scope.steeringAngleStyle = {
        color: steeringAngleColors[$scope.cornerCallColor]
      }

      let transcriptInterval = null

      function updateCornerCall() {
        var textElement = document.getElementById('cornerCall')
        textElement.textContent = $scope.cornerCall

        textElement = document.getElementById('wheelDegrees')
        textElement.textContent =  '' + $scope.wheelDegrees + '°'
      }

      updateCornerCall()

      $scope.cycleColor = function() {
        let colorIdx = $scope.cornerCallColor
        colorIdx++
        if (colorIdx >= steeringAngleColors.length) {
          colorIdx = 0
        }

        $scope.cornerCallColor = colorIdx
        $scope.steeringAngleStyle = {
          color: steeringAngleColors[$scope.cornerCallColor]
        }
      }

      $scope.$on('$destroy', function () {
        StreamsManager.remove(streamsList)
      })

      $scope.$on('aiPacenotes.recceApp.refreshed', function (event, response) {
        $scope.cornerCallStyle = response.corner_angles_style
      })

      $scope.$on('aiPacenotesTranscriptsLoaded', function (event, response) {
        if (response.ok) {
          $scope.transcripts = response.transcripts
          $scope.transcriptsError = null
        } else {
          $scope.transcripts = []
          $scope.transcriptsError = $sce.trustAsHtml(response.error)
        }
      })

      $scope.$on('aiPacenotesInputActionDesktopCallNotOk', function (event, errMsg) {
        $scope.transcriptsError = $sce.trustAsHtml(errMsg)
      })

      $scope.$on('streamsUpdate', function (event, streams) {
        if (!streams.electrics) return
        if (!$scope.cornerCallStyle) return

        // console.log(JSON.stringify($scope.selectedStyle))

        let steering = streams.electrics.steering
        // let steeringUnassisted = steering-streams.electrics.steeringUnassisted
        // let steeringInput = streams.electrics.steering_input

        let steeringVal = steering
        let absSteeringVal = Math.abs(steeringVal)
        $scope.wheelDegrees = Math.round(steeringVal) + ''

        for (let item of $scope.cornerCallStyle.angles) {
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
