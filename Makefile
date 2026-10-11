TARGET := iphone:clang:latest:15.0
ARCHS := arm64

RECOIL_HOOK_DIR := Recoil/recoil_hook

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := Recoil

Recoil_FILES := $(shell find src -name "*.mm" | sort)
Recoil_FILES += $(shell find $(RECOIL_HOOK_DIR) -name "*.c" -o -name "*.mm" 2>/dev/null | sort)

RECOIL_INCLUDE_FLAGS := -Isrc -I$(RECOIL_HOOK_DIR)
RECOIL_WARNING_FLAGS := -Wall -Wextra -Wno-unused-function

Recoil_CFLAGS := $(RECOIL_WARNING_FLAGS) $(RECOIL_INCLUDE_FLAGS)
Recoil_OBJCFLAGS := -fobjc-arc -std=c++17 $(RECOIL_WARNING_FLAGS) $(RECOIL_INCLUDE_FLAGS)

Recoil_FRAMEWORKS := Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
