#!/bin/bash

set -euo pipefail

BEAM_USER_HOME="/mnt/c/Users/bird/AppData/Local/BeamNG.drive/"
BEAM_VERSION="0.28" 

BEAM_HOME="${BEAM_USER_HOME}/${BEAM_VERSION}"

MISSION_ID="east_coast_usa/rallyStage/001-East"
#MISSION_ID="utah/rallyStage/bird-moab-tarmac-2"

echo "creating pacenotes for: ${MISSION_ID}"

VOICE="british_female"
SPEAKING_RATE="1.0"
I18N="en-uk"
PACENOTES_AUDIO_OUTDIR="${BEAM_HOME}/art/sound/aipacenotes/${MISSION_ID}/audio_files/${I18N}"

mkdir -p "${PACENOTES_AUDIO_OUTDIR}"

rm -vf out.zip
curl -H'Content-Type: application/json' \
  "https://beam-2csssbmhlq-uw.a.run.app?voice=${VOICE}&speaking_rate=${SPEAKING_RATE}" \
  -d@"${BEAM_HOME}/gameplay/missions/${MISSION_ID}/race.race.json" > \
  "${PACENOTES_AUDIO_OUTDIR}/out.zip"

cd "${PACENOTES_AUDIO_OUTDIR}"
rm -vf *.wav
unzip out.zip 
rm -vf out.zip

echo
echo "re-created pacenotes at: ${PACENOTES_AUDIO_OUTDIR}"

