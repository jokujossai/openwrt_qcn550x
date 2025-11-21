VERSION := 23.05.6
GCC_VERSION := 12.3.0_musl
BOARD := ath79
SUBTARGET := generic
ARCH := mips_24kc
BUILDER := openwrt-imagebuilder-$(VERSION)-$(BOARD)-$(SUBTARGET).Linux-x86_64
SDK := openwrt-sdk-$(VERSION)-$(BOARD)-$(SUBTARGET)_gcc-$(GCC_VERSION).Linux-x86_64
PROFILES := asus_rt-ac59u asus_rt-ac59u-v2
PACKAGES := luci-ssl uboot-envtools kmod-mac80211 kmod-cfg80211 kmod-ath kmod-ath9k kmod-ath9k-common
EXTRA_IMAGE_NAME := custom

BUILDER_URL := https://downloads.openwrt.org/releases/$(VERSION)/targets/$(BOARD)/$(SUBTARGET)/$(BUILDER).tar.xz
SDK_URL := https://downloads.openwrt.org/releases/$(VERSION)/targets/$(BOARD)/$(SUBTARGET)/$(SDK).tar.xz

# Snapshot build
#BUILDER := openwrt-imagebuilder-ath79-generic.Linux-x86_64
#SDK := openwrt-sdk-ath79-generic_gcc-12.3.0_musl.Linux-x86_64
#BUILDER_URL := https://downloads.openwrt.org/snapshots/targets/$(BOARD)/$(SUBTARGET)/$(BUILDER).tar.xz
#SDK_URL := https://downloads.openwrt.org/snapshots/targets/$(BOARD)/$(SUBTARGET)/$(SDK).tar.xz

TOPDIR := $(CURDIR)/$(BUILDER)
SDKDIR := $(CURDIR)/$(SDK)
KDIR := $(TOPDIR)/build_dir/target-$(ARCH)_musl/linux-$(BOARD)_$(SUBTARGET)
BUILDER_PATH := $(TOPDIR)/staging_dir/host/bin:$(SDKDIR)/staging_dir/toolchain-$(ARCH)_gcc-$(GCC_VERSION)/bin:$(PATH)
LINUX_VERSION = $(shell sed -n -e '/Linux-Version: / {s/Linux-Version: //p;q}' $(BUILDER)/.targetinfo)

all: images

$(BUILDER).tar.xz:
	curl -sfLO $(BUILDER_URL)

$(BUILDER)/.stamp: $(BUILDER).tar.xz $(SDK)/.stamp patches/*.patch
	rm -rf $(BUILDER) $(BUILDER).tmp
	mkdir $(BUILDER).tmp
	tar -xf $(BUILDER).tar.xz -C $(BUILDER).tmp --strip-components=1

	# Apply all patches
	$(foreach file, $(sort $(wildcard patches/*.patch)), echo Applying patch $(file); patch -d $(BUILDER).tmp -p1 < $(file);)

	# Update .targetinfo
	cp -f $(SDK)/.targetinfo $(BUILDER).tmp/.targetinfo
	mv $(BUILDER).tmp $(BUILDER)

	touch $(BUILDER)/.stamp

$(SDK).tar.xz:
	curl -sfLO $(SDK_URL)

$(SDK)/.stamp: $(SDK).tar.xz patches/*.patch
	rm -rf $(SDK) $(SDK).tmp
	mkdir $(SDK).tmp
	tar -xf $(SDK).tar.xz -C $(SDK).tmp --strip-components=1

	# Apply all patches
	$(foreach file, $(sort $(wildcard patches/*.patch)), echo Applying patch $(file); patch -d $(SDK).tmp -p1 < $(file);)

	# Regenerate .targetinfo
	cd $(SDK).tmp && make -j1 -f include/toplevel.mk TOPDIR="$(SDKDIR).tmp" prepare-tmpinfo || true
	cp -f $(SDK).tmp/tmp/.targetinfo $(SDK).tmp/.targetinfo
	mv $(SDK).tmp $(SDK)

	touch $(SDK)/.stamp

$(SDK)/package/feeds/.stamp: $(SDK)/.stamp patches/sdk/*.patch
	rm -rf $(SDK)/package/feeds $(SDK)/feeds $(SDK)/package/.stamp

	cd $(SDK) && ./scripts/feeds update -a
	cd $(SDK) && ./scripts/feeds install uboot-envtools
	cd $(SDK) && ./scripts/feeds install mac80211

	cd $(SDK) && $(MAKE) defconfig

	sed -i 's/^PKG_RELEASE:=\([0-9]\+\)$$/PKG_RELEASE:=\1+qcn5502/' \
		$(SDK)/package/feeds/base/uboot-envtools/Makefile \
		$(SDK)/package/feeds/base/mac80211/Makefile

	# Apply all patches
	$(foreach file, $(sort $(wildcard patches/sdk/*.patch)), echo Applying patch $(file); patch -d $(SDK) -p1 < $(file);)

	touch $(SDK)/package/feeds/.stamp

$(SDK)/package/feeds/base/.stamp: $(BUILDER)/.stamp $(SDK)/package/feeds/.stamp
	cd $(SDK) && $(MAKE) package/uboot-envtools/compile package/mac80211/compile
	touch $(SDK)/package/feeds/base/.stamp

$(BUILDER)/packages/.stamp: $(BUILDER)/.stamp $(SDK)/package/feeds/base/.stamp
	cp $(SDK)/bin/targets/$(BOARD)/$(SUBTARGET)/packages/*+qcn5502*.ipk $(BUILDER)/packages/
	touch $(BUILDER)/packages/.stamp

linux-include: $(BUILDER)/.stamp
	# Fetch DTS include dependencies
	curl -sfL --create-dirs "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/dt-bindings/clock/ath79-clk.h?h=v$(LINUX_VERSION)" -o linux-include.tmp/dt-bindings/clock/ath79-clk.h
	curl -sfL --create-dirs "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/dt-bindings/gpio/gpio.h?h=v$(LINUX_VERSION)" -o linux-include.tmp/dt-bindings/gpio/gpio.h
	curl -sfL --create-dirs "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/dt-bindings/input/input.h?h=v$(LINUX_VERSION)" -o linux-include.tmp/dt-bindings/input/input.h
	curl -sfL --create-dirs "https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/include/uapi/linux/input-event-codes.h?h=v$(LINUX_VERSION)" -o linux-include.tmp/dt-bindings/input/linux-event-codes.h
	curl -sfL --create-dirs "https://github.com/openwrt/openwrt/raw/v$(VERSION)/target/linux/generic/files/include/dt-bindings/mtd/partitions/uimage.h" -o linux-include.tmp/dt-bindings/mtd/partitions/uimage.h
	rm -rf linux-include
	mv -T linux-include.tmp linux-include

$(KDIR)/.stamp: $(BUILDER)/.stamp $(SDK)/.stamp linux-include
	# Build this device's DTB and firmware kernel image. Uses the official kernel build as a base.
	cp -Trf linux-include $(KDIR)/linux-$(LINUX_VERSION)/include

	cd $(BUILDER) && $(foreach PROFILE,$(PROFILES),\
		env PATH=$(BUILDER_PATH) $(MAKE) --trace -C $(TOPDIR)/target/linux/$(BOARD)/image \
			$(KDIR)/$(PROFILE)-kernel.bin \
			TOPDIR="$(TOPDIR)" \
			INCLUDE_DIR="$(TOPDIR)/include" \
			TARGET_BUILD=1 \
			BOARD="$(BOARD)" \
			SUBTARGET="$(SUBTARGET)" \
			PROFILE="$(PROFILE)" \
			TARGET_DEVICES="$(PROFILE)" \
	;)

	touch $(KDIR)/.stamp

images: $(BUILDER)/.stamp $(KDIR)/.stamp $(BUILDER)/packages/.stamp
	# Use ImageBuilder as normal
	cd $(BUILDER) && $(foreach PROFILE,$(PROFILES),\
		$(MAKE) image PROFILE="$(PROFILE)" EXTRA_IMAGE_NAME="$(EXTRA_IMAGE_NAME)" PACKAGES="$(PACKAGES)" FILES="$(TOPDIR)/target/linux/$(BOARD)/$(SUBTARGET)/base-files/"\
	;)
	cat $(BUILDER)/bin/targets/$(BOARD)/$(SUBTARGET)/sha256sums
	ls -hs $(BUILDER)/bin/targets/$(BOARD)/$(SUBTARGET)/openwrt-*.bin


clean:
	rm -rf openwrt-imagebuilder-*
	rm -rf openwrt-sdk-*
	rm -rf linux-include

openwrt-version:
	@echo $(VERSION)
