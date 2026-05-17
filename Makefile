ARCHS = arm64
TARGET := iphone:clang:latest:15.0
IPHONEOS_DEPLOYMENT_TARGET = 15.0

THEOS_PACKAGE_SCHEME ?= roothide
DEB_ARCH = iphoneos-arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FrontVCam

FrontVCam_FILES = Tweak.xm
FrontVCam_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
FrontVCam_FRAMEWORKS = UIKit Foundation AVFoundation CoreGraphics CoreMedia CoreVideo

include $(THEOS_MAKE_PATH)/tweak.mk
