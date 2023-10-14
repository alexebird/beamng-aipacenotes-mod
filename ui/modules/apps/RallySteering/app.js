angular.module('beamng.apps')
.directive('rallySteering', [function () {
  return {
    template:
      '<object style="width:100%; height:100%; pointer-events: none" type="image/svg+xml" data="/ui/modules/apps/RallySteering/simple-steering.svg"></object>',
    replace: true,
    link: function (scope, element, attrs) {
      var streamsList = ['electrics']
      StreamsManager.add(streamsList)
      scope.$on('$destroy', function () {
        StreamsManager.remove(streamsList)
      })

      scope.cornerAngles = null
      scope.history = []
      scope.maxHist = 5

      element.on('load', function () {

        bngApi.engineLua('extensions.gameplay_rally_cornerAngles.load()', (response) => {
          scope.cornerAngles = response
          // console.log(JSON.stringify(response, null, 2))
        })

        var svg    = element[0].contentDocument
          // , wheel  = svg.getElementById('wheel')
          // , helper = svg.getElementById('bounding-rect')
          // , bbox   = wheel.getBBox()
          // , rotateOriginStr = ' ' + (bbox.x + bbox.width/2) + ' ' + (bbox.y + bbox.height/2)
          // , barSteering = svg.getElementById('barSteering')
          // , barSteeringUnassisted = svg.getElementById('barSteeringUnassisted')
          // , barFFB = svg.getElementById('barFFB')
          // , barFFBclip = svg.getElementById('barFFBclip')
          , textFFB = svg.getElementById('textFFB')
          // , hFactor = svg.getElementById('bar-outer').getAttribute('width') / 2
          // , label1 = svg.getElementById('label1')
          // , label2 = svg.getElementById('label2')
          // , label3 = svg.getElementById('label3')
          // , label4 = svg.getElementById('label4')
        // let center = +barSteering.getAttribute('x')

        scope.$on('streamsUpdate', function (event, streams) {
          if (!streams.electrics) return
          if (!scope.cornerAngles) return

          let steering = streams.electrics.steering
          let steeringUnassisted = steering-streams.electrics.steeringUnassisted
          let steeringInput = streams.electrics.steering_input
          // console.log(`steering=${steering} steeringUnassisted=${steeringUnassisted} steeringInput=${steeringInput}`)

          // let steeringVal = steering
          // // cornerCall
          // // fromAngleDegrees // inclusive
          // // toAngleDegrees // exclusive

          // let selectedStyle = null;

          // scope.cornerAngles.pacenoteStyles.forEach(style => {
          //   if (style.use === true) {
          //     selectedStyle = style;
          //   }
          // });

          // selectedStyle.angles.forEach(item => {
          //   if (steeringVal >= item.fromAngleDegrees && steeringVal < item.toAngleDegrees) {
          //     console.log(item.cornerCall);
          //   }
          // });


          let steeringVal = steering
          let absSteeringVal = Math.abs(steeringVal)
          let selectedStyle = scope.cornerAngles.pacenoteStyles.find(style => style.use === true)
          let updated = false

          if (selectedStyle) {
            for (let item of selectedStyle.angles) {
              if (absSteeringVal >= item.fromAngleDegrees && absSteeringVal < item.toAngleDegrees) {
                let direction = steeringVal >= 0 ? "L" : "R"
                let cornerCallWithDirection = item.cornerCall + direction
                let cornerCall = null

                if (item.cornerCall === "_deadzone") {
                  // If steeringVal is in the deadzone, break without updating the history
                  // break
                  cornerCall = "c"
                } else {
                  cornerCall = cornerCallWithDirection
                }

                if (scope.history.length === 0 || scope.history[0] !== cornerCall) {
                  scope.history.unshift(cornerCall)  // Add the new cornerCall to the history
                  updated = true

                  while (scope.history.length > scope.maxHist) {
                    scope.history.pop()  // Remove the oldest value
                  }
                }
                // break  // Assuming the angle ranges are mutually exclusive and sorted
              }
            }
          } else {
            console.error("No pacenotes style with 'use: true' found. Beamng.drive/settings/aipacenotes/cornerAngles.json must have exactly one pacenotesStyle with use: true.")
          }

          if (updated) {
            console.log(`${steeringVal.toFixed(1)}° ` + JSON.stringify(scope.history))
            let textContent = scope.history[0]
            let textFFB = svg.getElementById('textFFB')
            let tspan = textFFB.querySelector('tspan')
            tspan.textContent = textContent

          }
        })

        // Use vehicle reset to trigger a reload of the cornerAngles.json file.
        scope.$on('VehicleReset', function (event, data) {
          scope.$evalAsync(function () {
            bngApi.engineLua('extensions.gameplay_rally_cornerAngles.load()', (response) => {
              scope.cornerAngles = response
              // console.log(JSON.stringify(response, null, 2))
            })
          })
        })
      })
    }
  }
}]);
