#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
int main(void) {
    @autoreleasepool {
        void *handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW);
        if (!handle) { fprintf(stderr, "%s\n", dlerror()); return 1; }
        unsigned int count = 0;
        Class *classes = objc_copyClassList(&count);
        for (unsigned int i = 0; i < count; i++) {
            NSString *name = NSStringFromClass(classes[i]);
            if (![name containsString:@"Keyboard"] && ![name isEqualToString:@"BrightnessSystemClient"]) continue;
            printf("CLASS %s\n", class_getName(classes[i]));
            unsigned int methodCount = 0;
            Method *methods = class_copyMethodList(classes[i], &methodCount);
            for (unsigned int j = 0; j < methodCount; j++) {
                printf("  %s %s\n", sel_getName(method_getName(methods[j])), method_getTypeEncoding(methods[j]));
            }
            free(methods);
        }
        free(classes);
    }
    return 0;
}
