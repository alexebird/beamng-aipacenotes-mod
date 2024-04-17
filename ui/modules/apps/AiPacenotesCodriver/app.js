// vim: ts=2 sw=2
//
// based on the included RadioTest UI app by BeamNG.
//

angular.module('beamng.apps')
  .directive('aiPacenotesCodriver', [function () {
    return {
      templateUrl: '/ui/modules/apps/AiPacenotesCodriver/app.html',
      replace: true,
      restrict: 'EA',
      link: function (scope, element, attrs) {
        let currentSource = null; // Track the currently playing source
        scope.volumeSetting = 0.8
        scope.timingSetting = 10.0

        scope.$watch('timingSetting', function(value) {
          // console.log(scope.timingSetting)
          bngApi.engineLua(`extensions.ui_aipacenotes_recceApp.setTimingSetting(${scope.timingSetting})`)
        })

        scope.$on('aiPacenotesInputActionCodriverVolumeUp', function (event) {
          // if (scope.volumeSetting < 1.0) {
          let curr = scope.volumeSetting
          curr += 0.1
          scope.volumeSetting = Math.min(curr, 1.0)
          // }
        })

        scope.$on('aiPacenotesInputActionCodriverVolumeDown', function (event) {
          // if (scope.volumeSetting > 0.0) {
          let curr = scope.volumeSetting
          curr -= 0.1
          scope.volumeSetting = Math.max(curr, 0.1)
          // }
        })

        scope.$on('aiPacenotesInputActionCodriverTimingEarlier', function (event) {
          // if (scope.timingSetting < 10.0) {
          let curr = scope.timingSetting
          curr += 0.5
          scope.timingSetting = Math.min(curr, 20.0)
          // }
        })

        scope.$on('aiPacenotesInputActionCodriverTimingLater', function (event) {
          // if (scope.timingSetting > 0.1) {
          let curr = scope.timingSetting
          curr -= 0.5
          scope.timingSetting = Math.max(curr, 1.0)
          // }
        })

        scope.$on('aiPacenotesSetCodriverTimingThreshold', function (event, resp) {
          console.log(`timingSetting=${resp}`)
          scope.timingSetting = resp
        })

        async function playAudio(url, volume) {
          if (currentSource) {
            currentSource.stop();
          }

          async function loadAndPlay(data) {
            const audioCtx = new AudioContext({ latencyHint: "playback" });
            const audioBuffer = await audioCtx.decodeAudioData(data);

            currentSource = audioCtx.createBufferSource();
            currentSource.buffer = audioBuffer;

            const gainNode = audioCtx.createGain();
            gainNode.gain.value = scope.volumeSetting || 0.5;

            currentSource.connect(gainNode).connect(audioCtx.destination);
            currentSource.start(0);

            // Handle automatically stopping the source when it ends
            currentSource.onended = () => {
              currentSource = null;
            };
          }

          try {
            let xhr = new XMLHttpRequest();
            xhr.onload = function () {
              if (xhr.status === 200) {
                loadAndPlay(xhr.response)
                  .then(() => {
                    // console.log('played')
                  })
                  .catch((err) => {
                    console.error("error in xhr.onload:", err);
                  })
              } else {
                console.error("xhr status not 200", xhr.status);
              }
            };
            xhr.responseType = "arraybuffer";
            xhr.open("GET", url, true);
            xhr.send();
          } catch (err) {
            console.error("Error loading or playing audio:", err);
            currentSource = null;
          }
        }

        function stopPlaying() {
          if (currentSource) {
            currentSource.stop();
            currentSource = null;
          }
        }

        scope.$on('aiPacenotes.codriverApp.playAudio', (event, {name, url, volume}) => {
          console.log(`Received playAudio event name=${name} url=${url} volume=${volume}`);
          playAudio(url, volume);
        });

        scope.$on('aiPacenotes.codriverApp.stopAudio', () => {
          console.log("Received stopAudio event");
          stopPlaying();
        });
      } // link
    } // return
  }]) // directive
