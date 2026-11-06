# ---- SDK iOS real do runner (host arm64, alvo arm64) ----
export SDKVERSION := $(shell xcrun --sdk iphoneos --show-sdk-version 2>/dev/null)

TARGET  := iphone:clang:latest:14.0
ARCHS   := arm64

INSTALL_TARGET_PROCESSES := FreeFire

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME := xit

xit_FILES        := xit.xm
xit_FRAMEWORKS   := UIKit Foundation CoreGraphics
xit_CFLAGS       := -fobjc-arc -fmodules -fvisibility=hidden -O2 -std=c++17 -Wall \
                    -miphoneos-version-min=14.0
xit_LDFLAGS      := -Wl,-undefined,dynamic_lookup -Wl,-dead_strip
xit_LIBRARIES    := substrate

# Embute os entitlements no binário final
xit_CODESIGN_FLAGS := -S./entitlements.plist -K./entitlements.plist

include $(THEOS_MAKE_PATH)/library.mk

after-all::
	@echo "[+] Gerado: .theos/obj/arm64/xit.dylib"
	@mkdir -p out
	@cp -f .theos/obj/arm64/xit.dylib out/xit.dylib 2>/dev/null || \
	  cp -f .theos/obj/xit.dylib out/xit.dylib 2>/dev/null || true
	@$(THEOS)/bin/ldid -S./entitlements.plist out/xit.dylib 2>/dev/null || \
	  ldid -S./entitlements.plist out/xit.dylib 2>/dev/null || true
	@file out/xit.dylib 2>/dev/null || true
	@echo "[+] Pronto em out/xit.dylib — arraste no TrollFools."
