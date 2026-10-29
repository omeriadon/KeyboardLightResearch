#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>
#import <dlfcn.h>
#import <math.h>
#import <signal.h>
#import <unistd.h>

@interface NSObject (KeyboardAPI)
- (BOOL)suspendIdleDimming:(BOOL)suspend forKeyboard:(uint64_t)keyboard;
- (BOOL)isIdleDimmingSuspendedOnKeyboard:(uint64_t)keyboard;
- (NSArray *)copyKeyboardBacklightIDs;
- (float)brightnessForKeyboard:(uint64_t)keyboard;
- (float)backlightLevelForKeyboard:(uint64_t)keyboard;
- (BOOL)setBrightness:(float)value fadeSpeed:(int)duration commit:(BOOL)commit forKeyboard:(uint64_t)keyboard;
@end

static volatile sig_atomic_t interrupted;

static void handleSignal(int signalNumber) {
    interrupted = signalNumber;
}

static long long pwmProperty(io_service_t service, CFStringRef key) {
    CFTypeRef value = IORegistryEntryCreateCFProperty(service, key, kCFAllocatorDefault, 0);
    long long result = -1;
    if (value && CFGetTypeID(value) == CFNumberGetTypeID()) {
        CFNumberGetValue(value, kCFNumberLongLongType, &result);
    }
    if (value) {
        CFRelease(value);
    }
    return result;
}

static void record(id client, uint64_t keyboard, io_service_t pwm, NSString *stage, double start) {
    float brightness = [client brightnessForKeyboard:keyboard];
    float level = [client backlightLevelForKeyboard:keyboard];
    long long high = pwmProperty(pwm, CFSTR("high-period"));
    long long low = pwmProperty(pwm, CFSTR("low-period"));
    double elapsed = (NSProcessInfo.processInfo.systemUptime - start) * 1000;
    printf("%s,%.3f,%.6f,%.6f,%lld,%lld\n", stage.UTF8String, elapsed, brightness, level, high, low);
    fflush(stdout);
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2 || strcmp(argv[1], "--test") != 0) {
            fprintf(stderr, "Explicit --test required. Brief bounded brightness changes; original restored.\n");
            return 2;
        }
        if (!dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)) {
            return 1;
        }
        id client = [[NSClassFromString(@"KeyboardBrightnessClient") alloc] init];
        for (NSString *name in @[@"copyKeyboardBacklightIDs", @"brightnessForKeyboard:",
            @"backlightLevelForKeyboard:", @"suspendIdleDimming:forKeyboard:",
            @"isIdleDimmingSuspendedOnKeyboard:", @"setBrightness:fadeSpeed:commit:forKeyboard:"]) {
            if (![client respondsToSelector:NSSelectorFromString(name)]) {
                return 1;
            }
        }
        NSArray *ids = [client copyKeyboardBacklightIDs];
        if (ids.count != 1) {
            return 1;
        }
        io_service_t pwm = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("kbd-backlight"));
        if (!pwm) {
            return 1;
        }
        uint64_t keyboard = [ids.firstObject unsignedLongLongValue];
        BOOL originalSuspension = [client isIdleDimmingSuspendedOnKeyboard:keyboard];
        float original = NAN;
        int result = 0;
        signal(SIGINT, handleSignal);
        signal(SIGTERM, handleSignal);
        @try {
            if (![client suspendIdleDimming:YES forKeyboard:keyboard]) {
                return 1;
            }
            usleep(200000);
            original = [client brightnessForKeyboard:keyboard];
            if (!isfinite(original) || original <= 0 || original > 1 || interrupted) {
                fprintf(stderr, "Backlight unavailable; no brightness test performed.\n");
                original = NAN;
                return 1;
            }
            // Settle the wake-from-idle ramp before comparing equal starting states.
            if (![client setBrightness:original fadeSpeed:0 commit:NO forKeyboard:keyboard]) {
                return 1;
            }
            usleep(500000);
            float target = original > 0.4f ? original - 0.2f : original + 0.2f;
            printf("stage,elapsed_ms,brightness,backlight_level,pwm_high,pwm_low\n");
            for (NSNumber *duration in @[@350, @0]) {
                if (interrupted) {
                    break;
                }
                NSString *stage = [NSString stringWithFormat:@"fade_%@", duration];
                double start = NSProcessInfo.processInfo.systemUptime;
                record(client, keyboard, pwm, [stage stringByAppendingString:@"_before"], start);
                BOOL accepted = [client setBrightness:target fadeSpeed:duration.intValue commit:NO forKeyboard:keyboard];
                fprintf(stderr, "%s accepted=%d original=%.6f target=%.6f\n", stage.UTF8String, accepted, original, target);
                if (!accepted) {
                    result = 1;
                    break;
                }
                for (int sample = 0; sample < 25 && !interrupted; sample++) {
                    record(client, keyboard, pwm, stage, start);
                    usleep(20000);
                }
                [client setBrightness:original fadeSpeed:0 commit:NO forKeyboard:keyboard];
                usleep(300000);
            }
        } @finally {
            if (isfinite(original)) {
                BOOL restored = [client setBrightness:original fadeSpeed:0 commit:NO forKeyboard:keyboard];
                usleep(100000);
                float readback = [client brightnessForKeyboard:keyboard];
                fprintf(stderr, "restore accepted=%d brightness=%.6f original=%.6f\n", restored, readback, original);
                if (!restored || fabsf(readback - original) > 0.001f) {
                    result = 1;
                }
            }
            BOOL suspensionRestored = [client suspendIdleDimming:originalSuspension forKeyboard:keyboard];
            fprintf(stderr, "idle suspension restored=%d original=%d\n", suspensionRestored, originalSuspension);
            if (!suspensionRestored) {
                result = 1;
            }
            IOObjectRelease(pwm);
        }
        return interrupted ? 128 + interrupted : result;
    }
}
