# Makefile — RiseInsta
TARGET := iphone:clang:latest:16.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = RiseInsta

RiseInsta_FILES = Tweak.x Menu.x
RiseInsta_CFLAGS = -fobjc-arc -Wno-unused-function -Wno-deprecated-declarations
RiseInsta_FRAMEWORKS = UIKit Foundation Photos

include $(THEOS_MAKE_PATH)/tweak.mk
