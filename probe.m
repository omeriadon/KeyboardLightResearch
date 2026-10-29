#import <Foundation/Foundation.h>
#import <dlfcn.h>
@interface NSObject (KeyboardAPI)
- (id)copyAllPrefereneces;
- (NSArray *)copyKeyboardBacklightIDs;
- (float)brightnessForKeyboard:(uint64_t)keyboard;
- (float)backlightLevelForKeyboard:(uint64_t)keyboard;
- (BOOL)isAutoBrightnessEnabledForKeyboard:(uint64_t)keyboard;
- (BOOL)isBacklightSuppressedOnKeyboard:(uint64_t)keyboard;
- (BOOL)isBacklightDimmedOnKeyboard:(uint64_t)keyboard;
- (id)copyPropertyForKey:(NSString *)key keyboardID:(uint64_t)keyboard;
@end
int main(void) {
    @autoreleasepool {
        if (!dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)) return 1;
        id client = [[NSClassFromString(@"KeyboardBrightnessClient") alloc] init];
        id preferences = [[NSClassFromString(@"CBKeyboardPreferencesManager") alloc] init];
        NSLog(@"Preferences=%@", [preferences copyAllPrefereneces]);
        NSArray *ids = [client copyKeyboardBacklightIDs];
        NSLog(@"Keyboard IDs: %@", ids);
        id system = [[NSClassFromString(@"BrightnessSystemClient") alloc] init];
        for (NSNumber *identifier in ids) {
            uint64_t keyboard = identifier.unsignedLongLongValue;
            NSLog(@"ID=%llu brightness=%f level=%f auto=%d suppressed=%d dimmed=%d", keyboard, [client brightnessForKeyboard:keyboard], [client backlightLevelForKeyboard:keyboard], [client isAutoBrightnessEnabledForKeyboard:keyboard], [client isBacklightSuppressedOnKeyboard:keyboard], [client isBacklightDimmedOnKeyboard:keyboard]);
            for (NSString *key in @[@"KeyboardBacklightBrightness", @"KeyboardBacklightLevel", @"KeyboardBacklightFadeSpeed", @"KeyboardBacklightCapabilities", @"KeyboardBacklightAutoBrightness", @"KeyboardBacklightIdleDimTime"]) {
                NSLog(@"%@=%@", key, [system copyPropertyForKey:key keyboardID:keyboard]);
            }
        }
    }
    return 0;
}
