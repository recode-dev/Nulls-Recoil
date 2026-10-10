TARGET := iphone:clang:latest:15.0
ARCHS := arm64

RECOIL := Recoil

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Recoil

Recoil_FILES = $(shell find src -name "*.mm")
Recoil_FILES += $(shell find $(RECOIL)/recoil_hook -name "*.c" -o -name "*.mm" 2>/dev/null | sort)

COMMON_INCLUDES = \
	-Isrc \
	-I$(RECOIL)/recoil_hook

Recoil_CFLAGS = -Isrc -I$(RECOIL)/recoil_hook

Recoil_OBJCFLAGS = -fobjc-arc -std=c++17 $(COMMON_INCLUDES) \
	-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter \
	-Wno-everything

Recoil_LDFLAGS = -Wl,-undefined,dynamic_lookup

Recoil_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
