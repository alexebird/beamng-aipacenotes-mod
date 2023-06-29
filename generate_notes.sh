#!/bin/bash
set -euo pipefail

BEAM_USER_HOME="/mnt/c/Users/bird/AppData/Local/BeamNG.drive/"
BEAM_VERSION="0.28" 

BEAM_HOME="${BEAM_USER_HOME}/${BEAM_VERSION}"
MOD_HOME="${BEAM_HOME}/mods/unpacked/beamng-aipacenotes-mod"

# MISSION_ID="east_coast_usa/timeTrial/aip-stage-dirt"
# MISSION_ID="gravel_rally/timeTrial/api-stage-outer-loop-ccw"
MISSION_ID="utah/timeTrial/aip-stage-tarmac-canyon"

echo "creating pacenotes for: ${MISSION_ID}"

VOICE="british_female"
SPEAKING_RATE="1.0"
I18N="en-uk"
PACENOTES_AUDIO_OUTDIR="${MOD_HOME}/art/sound/aipacenotes/${MISSION_ID}/audio_files/${I18N}"

mkdir -p "${PACENOTES_AUDIO_OUTDIR}"

rm -vf out.zip

curl -H'Content-Type: application/json' \
  "https://pacenotes-mo5q6vt2ea-uw.a.run.app/pacenotes?voice=${VOICE}&speaking_rate=${SPEAKING_RATE}" \
  -d@"${MOD_HOME}/gameplay/missions/${MISSION_ID}/race.race.json" > \
  "${PACENOTES_AUDIO_OUTDIR}/out.zip"

cd "${PACENOTES_AUDIO_OUTDIR}"
pwd
rm -vf *.wav
unzip -o out.zip 
rm -vf out.zip

echo
echo "re-created pacenotes at: ${PACENOTES_AUDIO_OUTDIR}"
