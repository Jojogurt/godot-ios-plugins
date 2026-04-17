/*************************************************************************/
/*  godot_deeplink_delegate.mm                                           */
/*************************************************************************/

#import "godot_deeplink_delegate.h"

#include "deeplink.h"

#if VERSION_MAJOR == 4
#if VERSION_MINOR >= 5
#import "drivers/apple_embedded/godot_app_delegate.h"
#else
#import "platform/ios/godot_app_delegate.h"
#endif
#else
#import "platform/iphone/godot_app_delegate.h"
#endif

struct DeepLinkInitializer {
	DeepLinkInitializer() {
#if VERSION_MAJOR == 4 && VERSION_MINOR >= 5
		[GDTApplicationDelegate addService:[GodotDeepLinkAppDelegate shared]];
#elif VERSION_MAJOR == 4 && VERSION_MINOR == 4
		[GodotApplicationDelegate addService:[GodotDeepLinkAppDelegate shared]];
#else
		[GodotApplicalitionDelegate addService:[GodotDeepLinkAppDelegate shared]];
#endif
	}
};
static DeepLinkInitializer initializer;

static String nsstring_to_godot(NSString *s) {
	String out;
	if (s == nil) {
		return out;
	}
#if VERSION_MAJOR == 4 && VERSION_MINOR >= 5
	out.append_utf8([s UTF8String]);
#else
	out.parse_utf8([s UTF8String]);
#endif
	return out;
}

static void deliver_url(NSURL *url, NSString *source) {
	if (url == nil) {
		return;
	}

	String url_str = nsstring_to_godot([url absoluteString]);
	String source_str = nsstring_to_godot(source);

	DeepLinkPlugin *plugin = DeepLinkPlugin::get_singleton();
	if (plugin == NULL) {
		return;
	}

	// If the engine's scene hasn't initialised yet (cold launch before _ready on the
	// autoload that connects link_received), stash the URL so GDScript can pull it
	// via get_initial_url() on start.
	plugin->_set_initial(url_str, source_str);
	plugin->dispatch_url(url_str, source_str);
}

@implementation GodotDeepLinkAppDelegate

+ (instancetype)shared {
	static GodotDeepLinkAppDelegate *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[GodotDeepLinkAppDelegate alloc] init];
	});
	return sharedInstance;
}

// Custom URL scheme entry point (e.g. memomaze://share?d=...).
- (BOOL)application:(UIApplication *)application
			openURL:(NSURL *)url
			options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
	deliver_url(url, @"scheme");
	return YES;
}

// Cold-launch via custom URL scheme on older iOS versions.
- (BOOL)application:(UIApplication *)application
	didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	NSURL *launch_url = launchOptions[UIApplicationLaunchOptionsURLKey];
	if (launch_url != nil) {
		deliver_url(launch_url, @"scheme");
	}
	return YES;
}

// Universal Links entry point (e.g. https://memomaze.example/share?d=...).
- (BOOL)application:(UIApplication *)application
	continueUserActivity:(NSUserActivity *)userActivity
	restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
	if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
		deliver_url(userActivity.webpageURL, @"universal_link");
		return YES;
	}
	return NO;
}

@end
