# ProtonJai
## Small cli (for now) app to download latest version of ProtonGE

### Building

This repo uses gitsubmodules so remember to:
```sh
git submodule update --init
```

```jai
jai build.jai - -release
mv bin/protonJai ~/.local/bin
```
### Dependencies

- [jai-libarchive](https://github.com/Jakenv/jai-libarchive/tree/master)
- [jaison](https://github.com/rluba/jaison)
