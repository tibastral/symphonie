# build.mak.  Generated from build.mak.in by configure.
export MACHINE_NAME := auto
export OS_NAME := auto
export HOST_NAME := unix
export CC_NAME := gcc
export TARGET_NAME := i386-apple-darwin8.10.1
export CROSS_COMPILE := 
export LINUX_POLL := select 

# Application can use this
export PJDIR := /Users/danielbraun/devel/sipPhone/pjproject-0.5.10.4
export APP_CC := $(CROSS_COMPILE)$(CC_NAME)
export APP_CFLAGS := -DPJ_AUTOCONF=1\
	-O2\
	-I$(PJDIR)/pjlib/include\
	-I$(PJDIR)/pjlib-util/include\
	-I$(PJDIR)/pjmedia/include\
	-I$(PJDIR)/pjsip/include
export APP_CXXFLAGS := $(APP_CFLAGS)
export APP_LDFLAGS := -L$(PJDIR)/pjlib/lib\
	-L$(PJDIR)/pjlib-util/lib\
	-L$(PJDIR)/pjmedia/lib\
	-L$(PJDIR)/pjsip/lib\
	
export APP_LDLIBS := -lpjsua-$(TARGET_NAME)\
	-lpjsip-ua-$(TARGET_NAME)\
	-lpjsip-simple-$(TARGET_NAME)\
	-lpjsip-$(TARGET_NAME)\
	-lpjmedia-codec-$(TARGET_NAME)\
	-lpjmedia-$(TARGET_NAME)\
	-lpjmedia-codec-$(TARGET_NAME)\
	-lpjlib-util-$(TARGET_NAME)\
	-lpj-$(TARGET_NAME)\
	-lm -lpthread  -framework CoreAudio -framework CoreServices -framework AudioUnit -framework AudioToolbox -lssl -lcrypto

