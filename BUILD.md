# Build FrontVCam

## GitHub Actions

Upload/commit cac file nay len repo:

```text
Makefile
Tweak.xm
FrontVCam.plist
control
README.md
BUILD.md
.github/workflows/build.yml
```

Sau do vao `Actions` -> `Build FrontVCam` -> `Run workflow`.

## macOS local

```sh
bash -c "$(curl -fsSL https://raw.githubusercontent.com/roothide/theos/master/bin/install-theos)"
export THEOS=$HOME/theos
make clean package THEOS_PACKAGE_SCHEME=roothide
```

File `.deb` nam trong:

```text
packages/
```

## Cach dung sau khi cai

1. Cai `.deb` bang Sileo.
2. Respring.
3. Mo app can dung camera truoc.
4. Bam nhanh `+` roi `-`.
5. Bam `Chon video`.
6. Chon file `.mp4` trong `/var/mobile/Media/DCIM/100APPLE`.
