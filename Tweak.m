#import <Foundation/Foundation.h>
#import "DLGMem.h"
#import "MEStore.h"
#import "MESpeedHack.h"
#if !JAILED
#import "il2cpp/il2cpp_helper.h"
#import "il2cpp/DLGUnityHookManager.h"
#endif

static bool shouldEnableForBundleIdentifier(NSString *bundleIdentifier)
{
#ifdef JAILED
    return true;
#else
    if (bundleIdentifier.length == 0) {
        return false;
    }

    // The preference bundle writes "apps" through the defaults system, so read it the same way first;
    // a sandboxed game may not be allowed to open the plist file directly.
    NSArray *apps = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("apps"), CFSTR("dev.mineek.memedit")));
    if ([apps isKindOfClass:NSArray.class]) {
        NSLog(@"[memedit] apps list read through preferences (%lu entries)", (unsigned long)apps.count);
        return [apps containsObject:bundleIdentifier];
    }

    NSDictionary *preferences = [NSDictionary dictionaryWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/dev.mineek.memedit.plist"];
    NSLog(@"[memedit] no apps list from preferences; plist file is %s", preferences ? "readable" : "not readable");
    return [preferences[@"apps"] containsObject:bundleIdentifier];
#endif
}

__attribute__((constructor))
static void entry(void)
{
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    if (!shouldEnableForBundleIdentifier(bundleIdentifier)) {
        NSLog(@"[memedit] not enabled for %@", bundleIdentifier);
        return;
    }
    NSLog(@"[memedit] enabled for %@, button will be added in 3s", bundleIdentifier);

    MEStore *store = MEStore.shared;
    MESpeedHackInstall();
    MESpeedHackSetMultiplier(store.speedMultiplier);
    MESpeedHackSetEnabled(store.speedEnabled);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"tweak start, build from %@", @__DATE__);
        [[[DLGMem alloc] init] launchDLGMem];

#if !JAILED
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            if (il2cpp_helper_init()) {
                [[DLGUnityHookManager sharedManager] loadAndReinstallHooks];
            }
        });
#endif
    });
}
