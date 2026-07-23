# Build and validate the complete RyukGram dylib with the newest installed
# iPhoneOS SDK while retaining iOS 15+ runtime compatibility.
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = Instagram

# arm64 is required for sideloaded/App Store app injection. arm64e is required
# when the tweak is injected into pointer-authenticated platform binaries on
# A12-and-newer devices, including iPhone 17 Pro Max.
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RyukGram

$(TWEAK_NAME)_FILES = $(shell find src -type f \( -iname \*.x -o -iname \*.xm -o -iname \*.m \)) $(wildcard modules/JGProgressHUD/*.m) modules/fishhook/fishhook.c
$(TWEAK_NAME)_FRAMEWORKS = UIKit Foundation CoreGraphics Photos CoreServices SystemConfiguration SafariServices Security QuartzCore AVFoundation UniformTypeIdentifiers CoreLocation MapKit
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -Wno-unsupported-availability-guard -Wno-unused-value -Wno-deprecated-declarations -Wno-nullability-completeness -Wno-unused-function -Wno-incompatible-pointer-types -include src/SCIPrefix.h
$(TWEAK_NAME)_LOGOSFLAGS = --c warnings=none

CCFLAGS += -std=c++11

include $(THEOS_MAKE_PATH)/tweak.mk

# Build FLEXing for sideloading (not building in dev-mode)
ifdef SIDELOAD
	$(TWEAK_NAME)_SUBPROJECTS += modules/flexing
endif
