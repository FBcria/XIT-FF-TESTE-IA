# ---- Força SDK iOS (host Intel do runner, alvo arm64) ----
export SDKVERSION := $(shell xcrun --sdk iphoneos --show-sdk-version 2>/dev/null || echo 16.5)
export SYSROOT    := $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)

TARGET  := iphone:clang:latest:14.0
ARCHS   := arm64

INSTALL_TARGET_PROCESSES := FreeFire

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := xit

xit_FILES        := xit.xm
xit_FRAMEWORKS   := UIKit Foundation CoreGraphics
xit_CFLAGS       := -fobjc-arc -fmodules -fvisibility=hidden -O2 -std=c++17 -Wall \
                    -isysroot $(SYSROOT) -miphoneos-version-min=14.0 -arch arm64
xit_LDFLAGS      := -Wl,-undefined,dynamic_lookup -Wl,-dead_strip -arch arm64
xit_LIBRARIES    := substrate

# Embute os entitlements no binário final
xit_CODESIGN_FLAGS := -S./entitlements.plist -K./entitlements.plist

include $(THEOS_MAKE_PATH)/library.mk

after-all::
	@echo "[+] Gerado: .theos/obj/arm64/xit.dylib"
	@mkdir -p out
	@cp -f .theos/obj/arm64/xit.dylib out/xit.dylib 2>/dev/null || \
	  cp -f .theos/obj/xit.dylib out/xit.dylib 2>/dev/null || true
	@ldid -S./entitlements.plist out/xit.dylib 2>/dev/null || \
	  $(THEOS)/bin/ldid -S./entitlements.plist out/xit.dylib 2>/dev/null || true
	@file out/xit.dylib 2>/dev/null || true
	@echo "[+] Pronto em out/xit.dylib — arraste no TrollFools."
