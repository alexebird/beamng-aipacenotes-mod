#!/bin/bash
set -euo pipefail

# echo doesnt work yet
# exit 1

# joined_lines="$(cat gameplay/missionTypes/timeTrial/customLuaNodeCode.lua | dos2unix | awk '{printf "%s\\n", $0}')"
joined_lines="$(cat gameplay/missionTypes/timeTrial/customLuaNodeCode.lua | dos2unix)"

flowgraph_file="gameplay/missionTypes/timeTrial/ttFg.flow.json"
cp -v $flowgraph_file "${flowgraph_file}.bak.$(date +%s)"

cat $flowgraph_file | jq --arg joined_lines "$joined_lines" '.graphs["35"].nodes["106"].code.work = $joined_lines' > tmp.json

mv -v tmp.json $flowgraph_file