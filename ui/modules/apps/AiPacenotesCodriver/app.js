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
