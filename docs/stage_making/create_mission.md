---
layout: default
title: 'Step 1: Create Mission'
parent: Make a Stage
nav_order: 1
---

# Step 1: Create Mission

_This step takes about 1 min._

Create a rallyStage mission.

1. Open the World Editor by pressing the `F11` key.

1. Open the Mission Editor
   ![open mission editor](./img/open_mission_editor.png)

1. Click `File > New Mission...`
   ![new mission](./img/new_mission.png)

1. Fill out the mission info.
   - Make sure you select `rallyStage` for the Missiontype.
   - I like to make all my missions start with the prefix `aip-` so they are easily searchable.

   ![new mission 2](./img/new_mission_2.png)

1. Set the Start Trigger. This determines where the mission activation point is.
   ![start_trigger](./img/start_trigger.png)
   - The red waypoint is the Start Trigger for this mission, which you can edit in the Mission Editor.
   - You can see another mission's Start Trigger, which is blue and white
     marker. It becomes a larger blue circle when you are close enough. It also
     shows up on the Big Map.

1. Set mission settings:
   - author
   - date (click Now)
   - Check Available as Scenario
   - Vehicle Used: Own or Provided Vehicle

   ![mission_settings_1](./img/mission_settings_1.png)

   - Click Add New Provided Vehicle. I usually set it to a rally car. This is the default vehicle for the mission.
   - Check Add Player Vehicle to Selection

   ![mission_settings_2](./img/mission_settings_2.png)

   - Uncheck Closed Circuit (for most stages)

   ![mission_settings_3](./img/mission_settings_3.png)

Scroll to the top of the Mission Editor and click the red save icon.

![save_mission](./img/save_mission.png)

After saving, click `File > Reload Mission System`.

![reload_mission](./img/reload_mission.png)

You're done creating the mission. Now we create the race.
