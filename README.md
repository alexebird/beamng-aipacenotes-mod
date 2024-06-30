# beamng-aipacenotes-mod

## Releasing

1. Make a .zip file:

```
git tag vX.Y.Z
git push
git push --tag
./build.sh
```

2. Test the .zip by moving the mod out of the game folder.

3. Create Github Release and upload zip.

4. Update Mod Repo page.


## docs

```
cd docs
jekyll serve -l --force_polling
```

```
veh = getPlayerVehicle(0)
veh = be:getObjectByID(be:getPlayerVehicleID(0))
core_vehicleBridge.registerValueChangeNotification(be:getObjectByID(be:getPlayerVehicleID(0)), 'odometer')
core_vehicleBridge.getCachedVehicleData(be:getPlayerVehicleID(0), 'odometer')
seems to be in meters
i think it works for any electrics key
```

core_environment.dumpGroundModels()
core_environment.groundModels['WOOD']

settings.getValue("restrictScenarios")

map.objects[vehid].damage

core_environment.getGravity()
should be: -9.8100004196167

jsonReadFile('/settings/aipacenotes/racelink/tick.json')
{"last_tick_at":"2024-06-26T21:24:47.391Z","version":"dev"}

readFile('/aip-version.txt') (and remove trailing newline) OR if doesnt exist use string "dev"

```
core_input_bindings.bindings
veh:getFFBID('steering')
be:getFFBConfig(0)

core_input_bindings.devices
{
  joystick0 = { "{0006346E-0000-0000-0000-504944564944}", "MOZA R12 Base\2?", "0006346E" },
  joystick1 = { "{100130B7-0000-0000-0000-504944564944}", "Heusinkveld Sim Pedals Sprint", "100130B7" },
  keyboard0 = { "{6F1D2B61-D5A0-11CF-BFC7-444553540000}", "Keyboard", "6F1D2B61" },
  mouse0 = { "{6F1D2B60-D5A0-11CF-BFC7-444553540000}", "Mouse", "6F1D2B60" }
}

core_input_bindings.getAssignedPlayers() // returns which player IDs are assigned to each device?
{
  joystick0 = 0,
  joystick1 = 0,
  keyboard0 = 0,
  mouse0 = 0
}
```
