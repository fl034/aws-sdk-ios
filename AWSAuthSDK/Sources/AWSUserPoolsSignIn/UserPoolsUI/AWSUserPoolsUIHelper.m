//
// Copyright 2010-2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
// http://aws.amazon.com/apache2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

#import <AWSAuthCore/AWSUIConfiguration.h>
#import "AWSUserPoolsUIHelper.h"

@implementation AWSUserPoolsUIHelper

static id<AWSUIConfiguration> awsUIConfiguration;

+ (void) setUpFormShadowForView:(UIView *)view {
    view.layer.shadowColor = [UIColor blackColor].CGColor;
    view.layer.shadowOffset = CGSizeZero;
    view.layer.shadowOpacity = 0.25;
    view.layer.shadowRadius = 6;
    view.layer.cornerRadius = 10.0;
    view.layer.borderColor = [[UIColor grayColor] colorWithAlphaComponent:0.7].CGColor;
    view.layer.borderWidth = 0.5;
    view.layer.masksToBounds = NO;
}

+ (UIColor *) getBackgroundColor:(id<AWSUIConfiguration>)config {
    if (config != nil && config.backgroundColor != nil) {
        return config.backgroundColor;
    } else if (@available(iOS 13.0, *)) {
        return [UIColor systemBackgroundColor];
    }
    return [UIColor darkGrayColor];
}

+ (UIColor *) getDefaultBackgroundColor {
    if (@available(iOS 13.0, *)) {
        return [UIColor secondarySystemBackgroundColor];
    }
    return [UIColor whiteColor];
}

+ (void) applyTintColorFromConfig:(id<AWSUIConfiguration>)config
                           toView:(UIView *) view {
    [self applyTintColorFromConfig:config toView:view background:YES];
}

+ (void) applyTintColorFromConfig:(id<AWSUIConfiguration>)config
                           toView:(UIView *) view
                       background:(BOOL) background {
    if (config.tintColor) {
        if (background) {
            view.backgroundColor = config.tintColor;
        } else {
            view.tintColor = config.tintColor;
        }
    }
}

+ (UIFont *) getFont:(id<AWSUIConfiguration>)config {
    if (config != nil && config.font != nil) {
        return config.font;
    } else {
        return nil;
    }
}

+ (BOOL) isBackgroundColorFullScreen:(id<AWSUIConfiguration>)config {
    if (config != nil) {
        return config.isBackgroundColorFullScreen;
    } else {
        return false;
    }
}

+ (void) setAWSUIConfiguration:(id<AWSUIConfiguration>)config {
    awsUIConfiguration = config;
}

+ (id<AWSUIConfiguration>) getAWSUIConfiguration {
    return awsUIConfiguration;
}

@end
