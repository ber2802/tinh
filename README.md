# FrontVCam

Tweak roothide/Theos cho iOS 15, iPhone arm64.

## Cach dung

1. Cai `.deb` bang Sileo.
2. Respring.
3. Mo app can dung camera.
4. Chuyen sang camera truoc.
5. Bam nhanh volume `+` roi `-` trong 1 giay.
6. Menu `FrontVCam` hien len.
7. Bam `Chon video`.
8. Chon mot file `.mp4` trong `/var/mobile/Media/DCIM/100APPLE`.

Tweak se copy video da chon vao:

```text
/var/mobile/Media/VCam/video.mp4
```

Sau do camera truoc se duoc thay bang video nay trong cac app dung `AVCaptureVideoDataOutput`.

## Build

```sh
make clean package THEOS_PACKAGE_SCHEME=roothide
```

File `.deb` nam trong `packages/`.
