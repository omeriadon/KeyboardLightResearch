#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, KBCoreBrightnessErrorCode) {
    KBCoreBrightnessErrorUnavailable = 1,
    KBCoreBrightnessErrorInvalidABI = 2,
    KBCoreBrightnessErrorOperationFailed = 3,
};

FOUNDATION_EXPORT NSString * const KBCoreBrightnessErrorDomain;

@interface KBCoreBrightnessBridge : NSObject
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (NSArray<NSNumber *> *)keyboardIDsWithError:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(keyboardIDs(error:)) __attribute__((swift_error(none)));
- (BOOL)isKeyboardBuiltIn:(uint64_t)keyboardID error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(isKeyboardBuiltIn(_:error:)) __attribute__((swift_error(none)));
- (float)brightnessForKeyboard:(uint64_t)keyboardID error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(brightness(forKeyboard:error:)) __attribute__((swift_error(none)));
- (BOOL)isAutoBrightnessEnabledForKeyboard:(uint64_t)keyboardID error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(isAutoBrightnessEnabled(forKeyboard:error:)) __attribute__((swift_error(none)));
- (BOOL)isIdleDimmingSuspendedForKeyboard:(uint64_t)keyboardID error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(isIdleDimmingSuspended(forKeyboard:error:)) __attribute__((swift_error(none)));
- (BOOL)enableAutoBrightness:(BOOL)enabled keyboard:(uint64_t)keyboardID error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(enableAutoBrightness(_:keyboard:error:)) __attribute__((swift_error(none)));
- (BOOL)suspendIdleDimming:(BOOL)suspended keyboard:(uint64_t)keyboardID error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(suspendIdleDimming(_:keyboard:error:)) __attribute__((swift_error(none)));
- (BOOL)setBrightness:(float)brightness fadeSpeed:(int32_t)fadeSpeed commit:(BOOL)commit keyboard:(uint64_t)keyboardID error:(NSError * _Nullable * _Nullable)error
    NS_SWIFT_NAME(setBrightness(_:fadeSpeed:commit:keyboard:error:)) __attribute__((swift_error(none)));
@end

NS_ASSUME_NONNULL_END
