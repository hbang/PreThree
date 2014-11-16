ARCHS = arm64

include theos/makefiles/common.mk

TWEAK_NAME = PreThree
PreThree_FILES = Tweak.xm
PreThree_FRAMEWORKS = Accelerate CoreGraphics UIKit

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 SpringBoard"
