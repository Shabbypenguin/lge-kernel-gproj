#!/bin/bash

    # This is my usage information
    #[ $# -eq 0 ] && { echo "Usage:
	# $0 Kernel-name"; exit 1; }

    # These setup our build enviroment
    THREADS=$(expr 2 + $(grep processor /proc/cpuinfo | wc -l))
    MAKE="make -j${THREADS}"
    ARCH="ARCH=arm"
    CROSS="CROSS_COMPILE=/home/shabbypenguin/Android/CM/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6/bin/arm-eabi-"
    STRIP="/home/shabbypenguin/Android/CM/prebuilts/gcc/linux-x86/arm/arm-eabi-4.6/bin/arm-eabi-strip"

    # Setup our directories now
    DIR=~/Android/Kernels
    KERNEL=$DIR/lge-kernel-gproj
    PACK=$KERNEL/package
    OUT=$KERNEL/arch/arm/boot
    TOOLS=$DIR/Kernel-Tools

    # Set the Device
    DEFCONFIG='cyanogenmod_e980_defconfig'
    DEVICE=e980

    # Set our Ramdisk locations
    RAMDISK=$DIR/Ramdisks/e980-CM
 
    # These are for mkbootimg
    PAGE=2048
    BASE=0x80200000
    RAMADDR=0x02000000
    CMDLINE='"vmalloc=600M console=ttyHSL0,115200,n8 lpj=67677 user_debug=31 msm_rtb.filter=0x0 ehci-hcd.park=3 coresight-etm.boot_enable=0 androidboot.hardware=geefhd"'
 
    # These are extra variables designed to make things nicer/easier

    NOW=$(date +"%m-%d-%y")
    UPDATER=$TOOLS/Updater-Scripts/e980
    #MODULES=$RAMDISK/lib/modules
    MODULES=$UPDATER/system/lib/modules

    # -----------------------------------------------------------------------------------------------
    # Dont mess with below here unless you know what you are doing
    # -----------------------------------------------------------------------------------------------

    export USE_CCACHE=1
    export $ARCH
    export $CROSS

    # This cleans out crud and makes new config
    $MAKE clean
    $MAKE mrproper
    rm -rf $MODULES && rm -rf $PACK
    [ -d "$PACK" ] || mkdir "$PACK"
    [ -d "$MODULES" ] || mkdir -p "$MODULES"
    exec > >(tee $PACK/buildlog.txt) 2>&1 
    $MAKE $DEFCONFIG

    # Finally making the kernel
    $MAKE zImage
    $MAKE modules

    # These move files to easier locations
    find -name '*.ko' -exec cp -av {} $MODULES/ \;
    sleep 5
    for x in `find $MODULES -name "*.ko"`; do $STRIP --strip-unneeded $x; done

    # -----------------------------------------------------------------------------------------------
    # This part packs the img up :)
    # In order for this part to work you need the mkbootimg tools
    # -----------------------------------------------------------------------------------------------

    cd $PACK
	cp $OUT/zImage $PACK
	mkbootfs $RAMDISK | gzip > $PACK/ramdisk.gz
	mkbootimg --cmdline "$CMDLINE" --kernel $PACK/zImage --ramdisk $PACK/ramdisk.gz --pagesize $PAGE --base $BASE --ramdisk_offset $RAMADDR -o $PACK/boot.img  
	#$TOOLS/loki patch boot $TOOLS/E980-aboot.img $PACK/boot.img $PACK/boot.lok
	#rm -rf boot.img 
	rm -rf ramdisk.gz && rm -rf zImage
	cp -R $UPDATER/* $PACK
	zip -r "CM-"$NOW".zip" * -x "*.txt"
    # -----------------------------------------------------------------------------------------------
    # All Done
    # -----------------------------------------------------------------------------------------------
    echo "CM-"$NOW" was made!"
