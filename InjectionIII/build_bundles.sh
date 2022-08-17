#!/bin/bash -x
#
#  build_bundles.sh
#  InjectionIII
#
#  Created by John Holdsworth on 04/10/2019.
#  Copyright © 2019 John Holdsworth. All rights reserved.
#
#  $Id: //depot/ResidentEval/InjectionIII/build_bundles.sh#63 $
#

# Injection has to assume a fixed path for Xcode.app as it uses
# Swift and the user's project may contain only Objective-C.
# The second "rpath" is to be able to find XCTest.framework.
FIXED_XCODE_DEVELOPER_PATH=/Applications/Xcode.app/Contents/Developer

function build_bundle () {
    FAMILY=$1
    PLATFORM=$2
    SDK=$3
    ARCHSValue=$4
    BUNDLE_CONFIG=Release
    
    if [ $ARCHSValue ] ;then
        echo "使用指定架构 - ：$ARCHSValue"
    else
        echo "未指定架构 - 使用默认的：$ARCHS"
        ARCHSValue=$ARCHS
    fi
    
    SWIFT_DYLIBS_PATH="$FIXED_XCODE_DEVELOPER_PATH/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/$SDK"
    XCTEST_FRAMEWORK_PATH="$FIXED_XCODE_DEVELOPER_PATH/Platforms/$PLATFORM.platform/Developer/Library/Frameworks"
    if [ ! -d "$SWIFT_DYLIBS_PATH" -o ! -d "${XCTEST_FRAMEWORK_PATH}/XCTest.framework" ]; then
        echo "Missing RPATH $SWIFT_DYLIBS_PATH $XCTEST_FRAMEWORK_PATH"
        exit 1
    fi
    "$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT ARCHS="$ARCHSValue" -sdk $SDK -config $BUNDLE_CONFIG -target SwiftTrace &&
    "$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT ARCHS="$ARCHSValue" PRODUCT_NAME="${FAMILY}Injection" LD_RUNPATH_SEARCH_PATHS="$SWIFT_DYLIBS_PATH $XCTEST_FRAMEWORK_PATH @loader_path/Frameworks" -sdk $SDK -config $BUNDLE_CONFIG -target InjectionBundle &&
    "$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT ARCHS="$ARCHSValue" PRODUCT_NAME="${FAMILY}SwiftUISupport" -sdk $SDK -config $BUNDLE_CONFIG -target SwiftUISupport &&

    rsync -au $SYMROOT/$BUNDLE_CONFIG-$SDK/*.bundle "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&
    mkdir -p "$CODESIGNING_FOLDER_PATH/Contents/Resources/${FAMILY}Injection.bundle/Frameworks/SwiftTrace.framework/Versions/A/Resources" &&
    rsync -au $SYMROOT/$BUNDLE_CONFIG-$SDK/SwiftTrace.framework/{Headers,Modules,SwiftTrace} "$CODESIGNING_FOLDER_PATH/Contents/Resources/${FAMILY}Injection.bundle/Frameworks/SwiftTrace.framework/Versions/A" &&
    ln -s A "$CODESIGNING_FOLDER_PATH/Contents/Resources/${FAMILY}Injection.bundle/Frameworks/SwiftTrace.framework/Versions/Current"
    for thing in SwiftTrace Modules Resources Headers; do
        ln -sf Versions/Current/$thing "$CODESIGNING_FOLDER_PATH/Contents/Resources/${FAMILY}Injection.bundle/Frameworks/SwiftTrace.framework"
    done
}

build_bundle iOS iPhoneSimulator iphonesimulator &&

# iphoneOS
build_bundle iOSDevice iPhoneOS iphoneos arm64 &&

build_bundle macOS MacOSX macosx &&
#build_bundle iOS iPhoneSimulator iphonesimulator &&
build_bundle tvOS AppleTVSimulator appletvsimulator &&

# iphoneos on M1 mac (requires Sanbox switched off)
build_bundle maciOS iPhoneOS iphoneos &&

# macOSSwiftUISupport needs to be built separately from the main app
"$DEVELOPER_BIN_DIR"/xcodebuild SYMROOT=$SYMROOT ARCHS="$ARCHS" -sdk macosx -config $CONFIGURATION -target SwiftUISupport &&

rsync -au $SYMROOT/$CONFIGURATION/macOSSwiftUISupport.bundle "$CODESIGNING_FOLDER_PATH/Contents/Resources" &&

# Copy across bundles and .swiftinterface files
rsync -au $SYMROOT/$CONFIGURATION/SwiftTrace.framework/Versions/A/{Headers,Modules} "$CODESIGNING_FOLDER_PATH/Contents/Resources/macOSInjection.bundle/Contents/Frameworks/SwiftTrace.framework/Versions/A" &&

for thing in Modules Resources Headers; do
    ln -sf Versions/Current/$thing $CODESIGNING_FOLDER_PATH/Contents/Resources/macOSInjection.bundle/Contents/Frameworks/SwiftTrace.framework
done &&

# This seems to be a bug producing .swiftinterface files.
perl -pi.bak -e 's/SwiftTrace.(Swift(Trace|Meta)|dyld_interpose_tuple|rebinding)/$1/g' $CODESIGNING_FOLDER_PATH/Contents/Resources/{macOSInjection.bundle/Contents,{i,maci,tv}OSInjection.bundle}/Frameworks/SwiftTrace.framework/Modules/*/*.swiftinterface &&
perl -pi.bak -e 's@(import _Concurrency)@// $1@g' $CODESIGNING_FOLDER_PATH/Contents/Resources/{macOSInjection.bundle/Contents,{i,maci,tv}OSInjection.bundle}/Frameworks/SwiftTrace.framework/Modules/*/*.swiftinterface &&
find $CODESIGNING_FOLDER_PATH/Contents/Resources/*.bundle -name '*.bak' -delete

# setup InjectionSetup
rsync -au "$SRCROOT/InjectionIII/InjectionSetup" "$CODESIGNING_FOLDER_PATH/Contents/Resources"
