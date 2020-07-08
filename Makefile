# This is the main makefile for MistExample firmware

# _______________________ User overridable configuration _______________________

PROJECT_NAME            ?= mistexample

VERSION_MAJOR           ?= 1
VERSION_MINOR           ?= 0
VERSION_PATCH           ?= 0
VERSION_DEVEL           ?= "-dev"

DEFAULT_RADIO_CHANNEL   ?= 16

# Set device address at compile time for cases where a signature is not present
DEFAULT_AM_ADDR         ?= 1
DEFAULT_PAN_ID          ?= 0x22
# No bootloader, app starts at 0
APP_START               = 0

#include beatstack
INCLUDE_BEATSTACK	 ?= 0

# Common build options - some of these should be moved to targets/boards
CFLAGS                  += -Wall -std=c99
CFLAGS                  += -ffunction-sections -fdata-sections -ffreestanding -fsingle-precision-constant -Wstrict-aliasing=0
CFLAGS                  += -DconfigUSE_TICKLESS_IDLE=0
CFLAGS                  += -D__START=main -D__STARTUP_CLEAR_BSS
CFLAGS                  += -DVTOR_START_LOCATION=$(APP_START)
LDFLAGS                 += -nostartfiles -Wl,--gc-sections -Wl,--relax -Wl,-Map=$(@:.elf=.map),--cref -Wl,--wrap=atexit
LDFLAGS                 += -Wl,--undefined=gHeaderData -Wl,--undefined=gHeaderSize
LDFLAGS                 += -Wl,--undefined=uxTopUsedPriority
LDLIBS                  += -lgcc -lm
INCLUDES                += -Xassembler -I$(BUILD_DIR) -I.

# If set, disables asserts and debugging, enables optimization
RELEASE_BUILD           ?= 0

# Set the lll verbosity base level
CFLAGS                  += -DBASE_LOG_LEVEL=0xFFFF

# Enable debug messages
VERBOSE                 ?= 0
# Disable info messages
#SILENT                  ?= 1

# This project contains several Makefiles that reference the project root
ROOT_DIR                ?= $(abspath .)
ZOO                     ?= $(ROOT_DIR)/zoo
# Destination for build results
BUILD_BASE_DIR          ?= build
# Mark the default target
DEFAULT_BUILD_TARGET    ?= $(PROJECT_NAME)

# Configure how image is programmed to target device
PROGRAM_IMAGE           ?= $(BUILD_DIR)/$(PROJECT_NAME).bin
PROGRAM_DEST_ADDR       ?= $(APP_START)

# Silabs SDK location and version, due to licensing terms, the SDK is not
# distributed with this project and must be installed with Simplicity Studio.
# The variable needs to point at the subdirectory with the version number, set
# it in Makefile.private or through the environment.
SILABS_SDKDIR           ?= $(HOME)/SimplicityStudio_v4/developer/sdks/gecko_sdk_suite/v2.7

# Pull in the developer's private configuration overrides and settings
-include Makefile.private

# _______________________ Non-overridable configuration _______________________

BUILD_DIR                = $(BUILD_BASE_DIR)/$(BUILD_TARGET)
BUILDSYSTEM_DIR         := $(ZOO)/thinnect.node-buildsystem/make
PLATFORMS_DIRS          := $(ZOO)/thinnect.node-buildsystem/make $(ZOO)/thinnect.dev-platforms/make $(ZOO)/thinnect.hiot-platforms/make
PHONY_GOALS             := all clean
TARGETLESS_GOALS        += clean
UUID_APPLICATION        := b765981d-fb13-4644-be61-6c4f77f7c109

VERSION_BIN             := $(shell printf "%02X" $(VERSION_MAJOR))$(shell printf "%02X" $(VERSION_MINOR))$(shell printf "%02X" $(VERSION_PATCH))
VERSION_STR             := "$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)"$(VERSION_DEVEL)
SW_MAJOR_VERSION        := $(VERSION_MAJOR)
SW_MINOR_VERSION        := $(VERSION_MINOR)
SW_PATCH_VERSION        := $(VERSION_PATCH)
BUILD_TIMESTAMP         := $(shell date '+%s')
IDENT_TIMESTAMP         := $(BUILD_TIMESTAMP)

# NODE_PLATFORM_DIR is used by targets to add components to INCLUDES and SOURCES
NODE_PLATFORM_DIR       := $(ZOO)/thinnect.node-platform

# ______________ Build components - sources and includes _______________________

SOURCES += main.c
SOURCES += mist_example.c
#SOURCES += FreeRTOS-openocd.c hardfault.c

# FreeRTOS
FREERTOS_DIR ?= $(ZOO)/FreeRTOS-Kernel
FREERTOS_INC = -I$(FREERTOS_DIR)/include \
               -I$(ZOO)/thinnect.cmsis-freertos/CMSIS_5/CMSIS/RTOS2/Include \
               -I$(ZOO)/thinnect.cmsis-freertos/CMSIS-FreeRTOS/CMSIS/RTOS2/FreeRTOS/Include \
               -I$(ZOO)/thinnect.cmsis-freertos/$(MCU_ARCH)

FREERTOS_SRC = $(wildcard $(FREERTOS_DIR)/*.c) \
               $(ZOO)/thinnect.cmsis-freertos/CMSIS-FreeRTOS/CMSIS/RTOS2/FreeRTOS/Source/cmsis_os2.c

INCLUDES += $(FREERTOS_PORT_INC) $(FREERTOS_INC)
SOURCES += $(FREERTOS_PORT_SRC) $(FREERTOS_SRC)

# CMSIS_CONFIG_DIR is used to add default CMSIS and FreeRTOS configs to INCLUDES
CMSIS_CONFIG_DIR ?= $(ZOO)/thinnect.cmsis-freertos/$(MCU_ARCH)/config

INCLUDES += -I$(ZOO)/thinnect.cmsis-ext
SOURCES += $(ZOO)/thinnect.cmsis-ext/cmsis_os2_ext.c

# Silabs EMLIB, RAIL, radio
INCLUDES += \
    -I$(SILABS_SDKDIR)/hardware/kit/common/drivers \
    -I$(SILABS_SDKDIR)/platform/halconfig/inc/hal-config \
    -I$(SILABS_SDKDIR)/platform/emlib/inc \
    -I$(SILABS_SDKDIR)/platform/emdrv/sleep/inc \
    -I$(SILABS_SDKDIR)/platform/radio/rail_lib/hal \
    -I$(SILABS_SDKDIR)/platform/radio/rail_lib/common \
    -I$(SILABS_SDKDIR)/platform/radio/rail_lib/protocol/ieee802154 \
    -I$(SILABS_SDKDIR)/platform/radio/rail_lib/plugin/pa-conversions

SOURCES += \
    $(SILABS_SDKDIR)/hardware/kit/common/drivers/retargetserial.c \
    $(SILABS_SDKDIR)/hardware/kit/common/drivers/retargetio.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_system.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_core.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_emu.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_cmu.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_rmu.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_gpio.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_i2c.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_adc.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_iadc.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_ldma.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_usart.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_msc.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_rtcc.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_timer.c \
    $(SILABS_SDKDIR)/platform/emlib/src/em_wdog.c \
    $(SILABS_SDKDIR)/platform/emdrv/sleep/src/sleep.c \
    $(SILABS_SDKDIR)/platform/radio/rail_lib/hal/hal_common.c

# logging
#CFLAGS += -DLOGGER_TIMESTAMP
#CFLAGS  += -DLOGGER_FWRITE
#SOURCES += $(NODE_PLATFORM_DIR)/silabs/logger_fwrite.c
#CFLAGS  += -DLOGGER_LDMA_BUFFER_LENGTH=16384
CFLAGS  += -DLOGGER_LDMA
SOURCES += $(NODE_PLATFORM_DIR)/silabs/logger_ldma.c
SOURCES += $(ZOO)/thinnect.lll/logging/loggers_ext.c
INCLUDES += -I$(ZOO)/thinnect.lll/logging

# device signature
INCLUDES += -I$(ZOO)/thinnect.device-signature/signature \
            -I$(ZOO)/thinnect.device-signature/area
SOURCES  += $(ZOO)/thinnect.device-signature/signature/DeviceSignature.c \
            $(ZOO)/thinnect.device-signature/area/silabs/SignatureArea.c

# device announcement
INCLUDES += -I$(ZOO)/thinnect.tos-deviceannouncement/include

SOURCES += $(ZOO)/thinnect.tos-deviceannouncement/src/announcement_app.c \
           $(ZOO)/thinnect.tos-deviceannouncement/src/device_announcement.c \
           $(ZOO)/thinnect.tos-deviceannouncement/src/device_features.c

# Generally useful external tools
INCLUDES += -I$(ZOO)/lammertb.libcrc/include \
            -I$(ZOO)/jtbr.endianness \
            -I$(ZOO)/graphitemaster.incbin
SOURCES += $(ZOO)/lammertb.libcrc/src/crcccitt.c

# mistcomm
INCLUDES += -I$(ZOO)/thinnect.mist-comm/include
INCLUDES += -I$(ZOO)/thinnect.mist-comm/include/compat
INCLUDES += -I$(ZOO)/thinnect.mist-comm/addrcache
INCLUDES += -I$(ZOO)/thinnect.mist-comm/am
INCLUDES += -I$(ZOO)/thinnect.mist-comm/cmsis
SOURCES += $(wildcard $(ZOO)/thinnect.mist-comm/am/*.c)
SOURCES += $(wildcard $(ZOO)/thinnect.mist-comm/api/*.c)
SOURCES += $(wildcard $(ZOO)/thinnect.mist-comm/addrcache/*.c)
SOURCES += $(wildcard $(ZOO)/thinnect.mist-comm/routing/*.c)
SOURCES += $(wildcard $(ZOO)/thinnect.mist-comm/cmsis/*.c)

# platform stuff - watchdog, io etc...
INCLUDES += -I$(NODE_PLATFORM_DIR)/include
INCLUDES += -I$(NODE_PLATFORM_DIR)/include/silabs

SOURCES += \
    $(NODE_PLATFORM_DIR)/silabs/radio_rtos.c \
    $(NODE_PLATFORM_DIR)/common/radio_seqNum.c \
    $(NODE_PLATFORM_DIR)/common/eui64.c \
    $(NODE_PLATFORM_DIR)/common/sys_panic.c

# mist library
INCLUDES += -I$(ROOT_DIR)/libmist/
LDLIBS   += $(ROOT_DIR)/libmist/$(MCU_FAMILY)/libmistmiddleware.a


#beatsack
ifeq ("$(INCLUDE_BEATSTACK)", "1")
    ifneq ("$(wildcard libbeat/beatstack.h)","")
           $(info "libbeat found and included")
           INCLUDES += -I$(ROOT_DIR)/libbeat/
           LDLIBS += $(ROOT_DIR)/libbeat/$(MCU_FAMILY)/libbeat.a
    else
           $(warning "Warning: libbeat enabled but not found")
    endif
endif

# MoteXML components
MOTEXML_DIR ?= $(ZOO)/prolab.motexml
DTTYPES_DIR ?= $(ZOO)/prolab.dt-types
INCLUDES += -I$(MOTEXML_DIR)/lib -I$(DTTYPES_DIR)
SOURCES += $(MOTEXML_DIR)/lib/MLE.c $(MOTEXML_DIR)/lib/MLD.c $(MOTEXML_DIR)/lib/MLI.c
CFLAGS += -DLIBEXPORT=""
# ------------------------------------------------------------------------------

# Pull in the grunt work
include $(BUILDSYSTEM_DIR)/Makerules
# ------------------------------------------------------------------------------

# Print some build parameters
$(info DEFAULT_AM_ADDR=$(DEFAULT_AM_ADDR))
$(info DEFAULT_RADIO_CHANNEL=$(DEFAULT_RADIO_CHANNEL))
$(info DEFAULT_PAN_ID=$(DEFAULT_PAN_ID))
$(info DEFAULT_RFPOWER_DBM=$(DEFAULT_RFPOWER_DBM))
# ------------------------------------------------------------------------------

$(call passVarToCpp,CFLAGS,VERSION_MAJOR)
$(call passVarToCpp,CFLAGS,VERSION_MINOR)
$(call passVarToCpp,CFLAGS,VERSION_PATCH)
$(call passVarToCpp,CFLAGS,VERSION_STR)
$(call passVarToCpp,CFLAGS,SW_MAJOR_VERSION)
$(call passVarToCpp,CFLAGS,SW_MINOR_VERSION)
$(call passVarToCpp,CFLAGS,SW_PATCH_VERSION)
$(call passVarToCpp,CFLAGS,IDENT_TIMESTAMP)

$(call passVarToCpp,CFLAGS,DEFAULT_AM_ADDR)
$(call passVarToCpp,CFLAGS,DEFAULT_RADIO_CHANNEL)
$(call passVarToCpp,CFLAGS,DEFAULT_PAN_ID)

ifeq ("$(INCLUDE_BEATSTACK)","1")
    $(call passVarToCpp,CFLAGS,INCLUDE_BEATSTACK)
endif

UUID_APPLICATION_BYTES = $(call uuidToCstr,$(UUID_APPLICATION))
$(call passVarToCpp,CFLAGS,UUID_APPLICATION_BYTES)

$(call passVarToCpp,CFLAGS,BASE_LOG_LEVEL)

# _______________________________ Project rules _______________________________

all: $(BUILD_DIR)/$(PROJECT_NAME).bin

# header.bin should be recreated if a build takes place
$(OBJECTS): $(BUILD_DIR)/header.bin

$(BUILD_DIR)/$(PROJECT_NAME).elf: Makefile | $(BUILD_DIR)

$(BUILD_DIR)/header.bin: Makefile | $(BUILD_DIR)
	$(call pInfo,Creating application header block [$@])
	$(HEADEREDIT) -c -v softtype,1 -v firmaddr,$(APP_START) -v firmsizemax,$(APP_MAX_LEN) \
	    -v version,$(VERSION_STR) -v versionbin,$(VERSION_BIN) \
	    -v uuid,$(UUID_BOARD) -v uuid2,$(UUID_PLATFORM) -v uuid3,$(UUID_APPLICATION) \
	    -v timestamp,$(BUILD_TIMESTAMP) \
	    -v name,$(PROJECT_NAME) \
	    -v size -v crc "$@"

$(BUILD_DIR)/$(PROJECT_NAME).elf: $(OBJECTS)
	$(call pInfo,Linking [$@])
	$(HIDE_CMD)$(CC) $(CFLAGS) $(INCLUDES) $(OBJECTS) $(LDLIBS) $(LDFLAGS) -o $@

$(BUILD_DIR)/$(PROJECT_NAME).bin: $(BUILD_DIR)/$(PROJECT_NAME).elf
	$(call pInfo,Exporting [$@])
	$(HIDE_CMD)$(TC_SIZE) --format=Berkeley $<
	$(HIDE_CMD)$(TC_OBJCOPY) --strip-all -O binary "$<" "$@"
	$(HIDE_CMD)$(HEADEREDIT) -v size -v crc $@

$(PROJECT_NAME): $(BUILD_DIR)/$(PROJECT_NAME).bin

# _______________________________ Utility rules ________________________________

$(BUILD_DIR):
	$(call pInfo,Creating [$@])
	@mkdir -p "$@"

clean:
	$(call pInfo,Nuking everything in [$(BUILD_BASE_DIR)])
	@-rm -rf "$(BUILD_BASE_DIR)"

.PHONY: $(PHONY_GOALS)
