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
