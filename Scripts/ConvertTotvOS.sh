#!/bin/bash

# A script to convert the AWS SDK from an iOS project to a tvOS one

# Pass the base directory of the git checkout as the argument

# Gordon Johnston 2016 - MIT License

BASE_DIR=$1

if [ ! $BASE_DIR ]; then
    echo "Usage $0 <path to git checkout of aws-sdk-ios>"
    exit 1
fi

cd $BASE_DIR

if [ ! -d AWSiOSSDKv2.xcodeproj ]; then

    echo "AWSiOSSDKv2.xcodeproj not found in $BASE_DIR"
    exit 2

fi

git mv AWSiOSSDKv2.xcodeproj AWStvOSSDKv2.xcodeproj

cd AWStvOSSDKv2.xcodeproj

sed -i '' 's/amazonaws.sdk.ios/amazonaws.sdk.tvos/g' project.pbxproj
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 8.0;/TVOS_DEPLOYMENT_TARGET = 9.0; TARGETED_DEVICE_FAMILY = 3;SDKROOT = appletvos;/g' project.pbxproj
sed -i '' 's/iphoneos/appletvos/g' project.pbxproj
sed -i '' 's/\$(ARCHS_STANDARD)/x86_64/g' project.pbxproj
sed -i '' 's/armv7s/arm64/g' project.pbxproj

sed -i '' 's/AWSiOSSDKv2/AWStvOSSDKv2/g' ./project.xcworkspace/contents.xcworkspacedata ./xcshareddata/xcschemes/*

