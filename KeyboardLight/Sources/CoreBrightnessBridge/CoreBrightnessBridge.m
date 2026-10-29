#import "CoreBrightnessBridge.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <math.h>

NSString * const KBCoreBrightnessErrorDomain = @"KeyboardLight.CoreBrightness";

@interface NSObject (KBPrivateAPI)
- (NSArray *)copyKeyboardBacklightIDs;
- (BOOL)isKeyboardBuiltIn:(uint64_t)keyboard;
- (float)brightnessForKeyboard:(uint64_t)keyboard;
- (BOOL)isAutoBrightnessEnabledForKeyboard:(uint64_t)keyboard;
- (BOOL)isIdleDimmingSuspendedOnKeyboard:(uint64_t)keyboard;
- (BOOL)enableAutoBrightness:(BOOL)enabled forKeyboard:(uint64_t)keyboard;
- (BOOL)suspendIdleDimming:(BOOL)suspended forKeyboard:(uint64_t)keyboard;
- (BOOL)setBrightness:(float)value fadeSpeed:(int)duration commit:(BOOL)commit forKeyboard:(uint64_t)keyboard;
@end

static NSError *KBError(NSString *message) {
    return [NSError errorWithDomain:KBCoreBrightnessErrorDomain
                              code:KBCoreBrightnessErrorOperationFailed
                          userInfo:@{NSLocalizedDescriptionKey: message}];
}

static BOOL KBValidate(Class cls, SEL selector, const char *encoding) {
    Method method = class_getInstanceMethod(cls, selector);
    if (!method) {
        return NO;
    }
    NSMethodSignature *actual = [NSMethodSignature signatureWithObjCTypes:method_getTypeEncoding(method)];
    NSMethodSignature *expected = [NSMethodSignature signatureWithObjCTypes:encoding];
    if (strcmp(actual.methodReturnType, expected.methodReturnType) != 0 ||
        actual.numberOfArguments != expected.numberOfArguments) {
        return NO;
    }
    for (NSUInteger index = 0; index < expected.numberOfArguments; index++) {
        if (strcmp([actual getArgumentTypeAtIndex:index], [expected getArgumentTypeAtIndex:index]) != 0) {
            return NO;
        }
    }
    return YES;
}

@interface KBCoreBrightnessBridge ()
@property (nonatomic, strong) id client;
@end

@implementation KBCoreBrightnessBridge

- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    // Keep the framework loaded: Objective-C class metadata remains registered for process lifetime.
    void *handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW | RTLD_LOCAL);
    if (!handle) {
        return self;
    }
    Class cls = NSClassFromString(@"KeyboardBrightnessClient");
    if (!cls ||
        !KBValidate(cls, @selector(copyKeyboardBacklightIDs), "@@:") ||
        !KBValidate(cls, @selector(isKeyboardBuiltIn:), "B@:Q") ||
        !KBValidate(cls, @selector(brightnessForKeyboard:), "f@:Q") ||
        !KBValidate(cls, @selector(isAutoBrightnessEnabledForKeyboard:), "B@:Q") ||
        !KBValidate(cls, @selector(isIdleDimmingSuspendedOnKeyboard:), "B@:Q") ||
        !KBValidate(cls, @selector(enableAutoBrightness:forKeyboard:), "B@:BQ") ||
        !KBValidate(cls, @selector(suspendIdleDimming:forKeyboard:), "B@:BQ") ||
        !KBValidate(cls, @selector(setBrightness:fadeSpeed:commit:forKeyboard:), "B@:fiBQ")) {
        return self;
    }
    @try {
        _client = [[cls alloc] init];
    } @catch (NSException *exception) {
        _client = nil;
    }
    return self;
}

- (BOOL)ready:(NSError **)error {
    if (!NSThread.isMainThread || !self.client) {
        if (error) {
            *error = KBError(@"Keyboard brightness controls are unavailable or incompatible on this Mac.");
        }
        return NO;
    }
    return YES;
}

- (NSArray<NSNumber *> *)keyboardIDsWithError:(NSError **)error {
    if (![self ready:error]) {
        return @[];
    }
    @try {
        id identifiers = [self.client copyKeyboardBacklightIDs];
        if (![identifiers isKindOfClass:NSArray.class]) {
            if (error) {
                *error = KBError(@"The system returned invalid keyboard information.");
            }
            return @[];
        }
        for (id value in identifiers) {
            if (![value isKindOfClass:NSNumber.class]) {
                if (error) {
                    *error = KBError(@"The system returned an invalid keyboard identifier.");
                }
                return @[];
            }
        }
        return identifiers;
    } @catch (NSException *exception) {
        if (error) {
            *error = KBError(exception.reason ?: @"Could not discover the keyboard.");
        }
        return @[];
    }
}

#define KB_READ_BODY(expression, fallback) \
    if (![self ready:error]) { return fallback; } \
    @try { return expression; } \
    @catch (NSException *exception) { \
        if (error) { *error = KBError(exception.reason ?: @"Could not read keyboard state."); } \
        return fallback; \
    }

- (BOOL)isKeyboardBuiltIn:(uint64_t)keyboardID error:(NSError **)error {
    KB_READ_BODY([self.client isKeyboardBuiltIn:keyboardID], NO)
}

- (float)brightnessForKeyboard:(uint64_t)keyboardID error:(NSError **)error {
    KB_READ_BODY([self.client brightnessForKeyboard:keyboardID], NAN)
}

- (BOOL)isAutoBrightnessEnabledForKeyboard:(uint64_t)keyboardID error:(NSError **)error {
    KB_READ_BODY([self.client isAutoBrightnessEnabledForKeyboard:keyboardID], NO)
}

- (BOOL)isIdleDimmingSuspendedForKeyboard:(uint64_t)keyboardID error:(NSError **)error {
    KB_READ_BODY([self.client isIdleDimmingSuspendedOnKeyboard:keyboardID], NO)
}

#define KB_WRITE_BODY(expression) \
    if (![self ready:error]) { return NO; } \
    @try { \
        BOOL accepted = expression; \
        if (!accepted && error) { *error = KBError(@"The system declined the keyboard brightness change."); } \
        return accepted; \
    } @catch (NSException *exception) { \
        if (error) { *error = KBError(exception.reason ?: @"Could not update keyboard state."); } \
        return NO; \
    }

- (BOOL)enableAutoBrightness:(BOOL)enabled keyboard:(uint64_t)keyboardID error:(NSError **)error {
    KB_WRITE_BODY([self.client enableAutoBrightness:enabled forKeyboard:keyboardID])
}

- (BOOL)suspendIdleDimming:(BOOL)suspended keyboard:(uint64_t)keyboardID error:(NSError **)error {
    KB_WRITE_BODY([self.client suspendIdleDimming:suspended forKeyboard:keyboardID])
}

- (BOOL)setBrightness:(float)brightness fadeSpeed:(int32_t)fadeSpeed commit:(BOOL)commit keyboard:(uint64_t)keyboardID error:(NSError **)error {
    if (!isfinite(brightness) || brightness < 0 || brightness > 1 || fadeSpeed < 0 || fadeSpeed > 3000) {
        if (error) {
            *error = KBError(@"Brightness or fade duration is outside its supported range.");
        }
        return NO;
    }
    KB_WRITE_BODY([self.client setBrightness:brightness fadeSpeed:fadeSpeed commit:commit forKeyboard:keyboardID])
}
@end
