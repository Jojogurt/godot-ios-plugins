/*************************************************************************/
/*  godot_deeplink_delegate.mm                                           */
/*************************************************************************/

#import "godot_deeplink_delegate.h"

#include "deeplink.h"

#import <objc/runtime.h>

#if VERSION_MAJOR == 4
#if VERSION_MINOR >= 5
#import "drivers/apple_embedded/godot_app_delegate.h"
#else
#import "platform/ios/godot_app_delegate.h"
#endif
#else
#import "platform/iphone/godot_app_delegate.h"
#endif

// Forward decl — implementations are further down; must be callable from the
// C++ static-init constructor below.
static void patch_all_scene_delegate_classes(void);

struct DeepLinkInitializer {
	DeepLinkInitializer() {
#if VERSION_MAJOR == 4 && VERSION_MINOR >= 5
		[GDTApplicationDelegate addService:[GodotDeepLinkAppDelegate shared]];
#elif VERSION_MAJOR == 4 && VERSION_MINOR == 4
		[GodotApplicationDelegate addService:[GodotDeepLinkAppDelegate shared]];
#else
		[GodotApplicalitionDelegate addService:[GodotDeepLinkAppDelegate shared]];
#endif
		// Patch SwiftUI's scene delegate class NOW — before UIApplicationMain
		// creates any scenes — so cold-launch Universal Links + URL schemes
		// flow through scene:willConnectToSession:options:.
		patch_all_scene_delegate_classes();
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

// Cold-launch deliveries arrive via scene:willConnectToSession:options: BEFORE
// Godot engine init runs — so DeepLinkPlugin::get_singleton() is still NULL and
// any URL we receive would be dropped. Cache it here instead; DeepLinkPlugin()'s
// constructor drains this into the singleton via deeplink_drain_pending().
static NSString *s_pending_url = nil;
static NSString *s_pending_source = nil;

static void deliver_url(NSURL *url, NSString *source) {
	if (url == nil) {
		return;
	}
	NSString *abs_url = [url absoluteString];

	DeepLinkPlugin *plugin = DeepLinkPlugin::get_singleton();
	if (plugin == NULL) {
		NSLog(@"[DeepLink] deliver_url deferred (plugin not ready): %@ source=%@", abs_url, source);
		s_pending_url = abs_url;
		s_pending_source = source;
		return;
	}

	String url_str = nsstring_to_godot(abs_url);
	String source_str = nsstring_to_godot(source);

	// Stash as initial too so a late-connecting autoload can pull via get_initial_url().
	plugin->_set_initial(url_str, source_str);
	plugin->dispatch_url(url_str, source_str);
}

// Called from DeepLinkPlugin() constructor once the singleton is live, to hand
// over any URL we received before Godot engine init.
extern "C" void deeplink_drain_pending_to_singleton(void) {
	if (s_pending_url == nil) {
		return;
	}
	DeepLinkPlugin *plugin = DeepLinkPlugin::get_singleton();
	if (plugin == NULL) {
		return;
	}
	NSLog(@"[DeepLink] draining pending url into singleton: %@ source=%@", s_pending_url, s_pending_source);
	String url_str = nsstring_to_godot(s_pending_url);
	String source_str = nsstring_to_godot(s_pending_source ?: @"universal_link");
	plugin->_set_initial(url_str, source_str);
	// No dispatch_url — no listeners yet. GDScript autoload will read the cold-launch
	// URL via get_initial_url() on its _ready() and drive the pipeline from there.
	s_pending_url = nil;
	s_pending_source = nil;
}

// Install our scene:continueUserActivity: + scene:openURLContexts: implementations
// onto a scene-delegate class. Godot 4.6 iOS uses SwiftUI `App { WindowGroup { ... } }`
// whose private scene delegate DOES implement these selectors (to support SwiftUI
// `.onContinueUserActivity` / `.onOpenURL` modifiers, which app.swift doesn't use)
// — so the activity is consumed by SwiftUI's no-op dispatch and dropped. We must
// REPLACE those implementations, not add; class_addMethod silently fails when the
// method already exists.
static void patch_scene_delegate_class(Class cls) {
	if (cls == Nil) {
		return;
	}
	NSLog(@"[DeepLink] patching scene delegate class: %@ superclass: %@",
			NSStringFromClass(cls), NSStringFromClass([cls superclass]));

	SEL sel_continue = @selector(scene:continueUserActivity:);
	IMP imp_continue = imp_implementationWithBlock(^(id _self, UIScene *scene, NSUserActivity *activity) {
		NSLog(@"[DeepLink] scene:continueUserActivity: type=%@ url=%@",
				activity.activityType,
				activity.webpageURL ? [activity.webpageURL absoluteString] : @"(nil)");
		if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && activity.webpageURL != nil) {
			deliver_url(activity.webpageURL, @"universal_link");
		}
	});
	IMP prev_continue = class_replaceMethod(cls, sel_continue, imp_continue, "v@:@@");
	NSLog(@"[DeepLink] class_replaceMethod(continueUserActivity) on %@ prev=%p %@",
			NSStringFromClass(cls), prev_continue,
			prev_continue ? @"(replaced existing)" : @"(added new)");

	SEL sel_openurl = @selector(scene:openURLContexts:);
	IMP imp_openurl = imp_implementationWithBlock(^(id _self, UIScene *scene, NSSet<UIOpenURLContext *> *contexts) {
		NSLog(@"[DeepLink] scene:openURLContexts: count=%lu", (unsigned long)contexts.count);
		for (UIOpenURLContext *ctx in contexts) {
			if (ctx.URL != nil) {
				deliver_url(ctx.URL, @"scheme");
			}
		}
	});
	IMP prev_openurl = class_replaceMethod(cls, sel_openurl, imp_openurl, "v@:@@");
	NSLog(@"[DeepLink] class_replaceMethod(openURLContexts) on %@ prev=%p %@",
			NSStringFromClass(cls), prev_openurl,
			prev_openurl ? @"(replaced existing)" : @"(added new)");

	// Patch scene:willConnectToSession:options: for cold-launch activity extraction.
	// CRITICAL: SwiftUI's original impl sets up the window + hosting view controller
	// (WindowGroup → GodotSwiftUIViewController). If we don't forward, the app boots
	// to a black screen. __block IMP captures the prev pointer by reference so our
	// block sees the assignment after class_replaceMethod returns.
	SEL sel_willconnect = @selector(scene:willConnectToSession:options:);
	typedef void (*WillConnectIMP)(id, SEL, UIScene *, UISceneSession *, UISceneConnectionOptions *);
	__block WillConnectIMP prev_willconnect = NULL;
	IMP imp_willconnect = imp_implementationWithBlock(^(id _self, UIScene *scene, UISceneSession *session, UISceneConnectionOptions *options) {
		NSLog(@"[DeepLink] scene:willConnectToSession:options: activities=%lu urls=%lu prev=%p",
				(unsigned long)options.userActivities.count,
				(unsigned long)options.URLContexts.count,
				prev_willconnect);
		for (NSUserActivity *activity in options.userActivities) {
			if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && activity.webpageURL != nil) {
				deliver_url(activity.webpageURL, @"universal_link");
			}
		}
		for (UIOpenURLContext *ctx in options.URLContexts) {
			if (ctx.URL != nil) {
				deliver_url(ctx.URL, @"scheme");
			}
		}
		// Forward to SwiftUI's original so window + hosting controller get set up.
		if (prev_willconnect) {
			prev_willconnect(_self, sel_willconnect, scene, session, options);
		}
	});
	prev_willconnect = (WillConnectIMP)class_replaceMethod(cls, sel_willconnect, imp_willconnect, "v@:@@@");
	NSLog(@"[DeepLink] class_replaceMethod(willConnectToSession) on %@ prev=%p %@",
			NSStringFromClass(cls), prev_willconnect,
			prev_willconnect ? @"(replaced existing — will forward)" : @"(added new — no forward)");
}

// Iterate ALL loaded Obj-C classes and patch every plausible scene delegate.
// Runs at C++ static-init time (before main()). We cast a WIDE net: match any
// class that conforms to UISceneDelegate OR UIWindowSceneDelegate, OR that
// implements scene:willConnectToSession:options:, OR whose name contains
// "Scene" or "SwiftUI". SwiftUI's private scene delegate class name isn't
// documented and may not declare protocol conformance we can query — hence
// the method-based + name-based fallbacks.
static void patch_all_scene_delegate_classes(void) {
	NSLog(@"[DeepLink] patch_all_scene_delegate_classes: starting iteration");
	int num = objc_getClassList(NULL, 0);
	if (num <= 0) {
		NSLog(@"[DeepLink] objc_getClassList returned %d", num);
		return;
	}
	Class *classes = (Class *)malloc(sizeof(Class) * num);
	num = objc_getClassList(classes, num);

	SEL sel_willconnect = @selector(scene:willConnectToSession:options:);
	SEL sel_continue = @selector(scene:continueUserActivity:);
	SEL sel_openurl = @selector(scene:openURLContexts:);

	NSMutableArray *candidates = [NSMutableArray array];
	for (int i = 0; i < num; i++) {
		Class cls = classes[i];
		BOOL conforms_scene = class_conformsToProtocol(cls, @protocol(UISceneDelegate));
		BOOL conforms_window = class_conformsToProtocol(cls, @protocol(UIWindowSceneDelegate));
		BOOL has_willconnect = class_getInstanceMethod(cls, sel_willconnect) != NULL;
		BOOL has_continue = class_getInstanceMethod(cls, sel_continue) != NULL;
		BOOL has_openurl = class_getInstanceMethod(cls, sel_openurl) != NULL;
		if (conforms_scene || conforms_window || has_willconnect || has_continue || has_openurl) {
			NSString *name = NSStringFromClass(cls);
			NSLog(@"[DeepLink] candidate class: %@ (UISceneDelegate=%d UIWindowSceneDelegate=%d willConnect=%d continueActivity=%d openURL=%d)",
					name, conforms_scene, conforms_window, has_willconnect, has_continue, has_openurl);
			[candidates addObject:[NSValue valueWithPointer:(__bridge const void *)cls]];
		}
	}
	free(classes);

	NSLog(@"[DeepLink] found %lu candidate scene delegate classes", (unsigned long)candidates.count);
	for (NSValue *v in candidates) {
		Class cls = (__bridge Class)[v pointerValue];
		patch_scene_delegate_class(cls);
	}
	NSLog(@"[DeepLink] patch_all_scene_delegate_classes: done (%lu patched)", (unsigned long)candidates.count);
}

// Backup path: if static-init-time class iteration missed the delegate's
// class (e.g. SwiftUI's scene delegate is a lazily-registered subclass),
// patch on first sighting via UISceneWillConnect / UISceneDidActivate.
static void patch_scene_delegate_if_needed(id<UISceneDelegate> delegate) {
	if (delegate == nil) {
		return;
	}
	static NSMutableSet *patched_classes = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		patched_classes = [NSMutableSet new];
	});
	Class cls = [delegate class];
	NSString *name = NSStringFromClass(cls);
	@synchronized(patched_classes) {
		if ([patched_classes containsObject:name]) {
			return;
		}
		[patched_classes addObject:name];
	}
	patch_scene_delegate_class(cls);
}

@implementation GodotDeepLinkAppDelegate

+ (instancetype)shared {
	static GodotDeepLinkAppDelegate *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		sharedInstance = [[GodotDeepLinkAppDelegate alloc] init];
		[[NSNotificationCenter defaultCenter] addObserver:sharedInstance
												 selector:@selector(sceneWillConnectNotification:)
													 name:@"UISceneWillConnectNotification"
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:sharedInstance
												 selector:@selector(sceneDidActivateNotification:)
													 name:@"UISceneDidActivateNotification"
												   object:nil];
		NSLog(@"[DeepLink] GodotDeepLinkAppDelegate initialised, observing scene notifications");
	});
	return sharedInstance;
}

// Custom URL scheme via UIApplicationDelegate — kept as fallback; iOS scene-based
// apps generally don't call this. Scene path is scene:openURLContexts: which we
// inject via runtime in patch_scene_delegate_if_needed.
- (BOOL)application:(UIApplication *)application
			openURL:(NSURL *)url
			options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
	NSLog(@"[DeepLink] app-delegate openURL: %@", [url absoluteString]);
	deliver_url(url, @"scheme");
	return YES;
}

- (BOOL)application:(UIApplication *)application
	didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	NSURL *launch_url = launchOptions[UIApplicationLaunchOptionsURLKey];
	NSLog(@"[DeepLink] didFinishLaunchingWithOptions launch_url=%@ all_keys=%@",
			launch_url ? [launch_url absoluteString] : @"(nil)",
			launchOptions ? [[launchOptions allKeys] description] : @"(nil)");
	if (launch_url != nil) {
		deliver_url(launch_url, @"scheme");
	}
	return YES;
}

// Universal Link via UIApplicationDelegate — kept as fallback; scene-based
// apps route these to scene:continueUserActivity: which we patch at runtime.
- (BOOL)application:(UIApplication *)application
	continueUserActivity:(NSUserActivity *)userActivity
	restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
	NSLog(@"[DeepLink] app-delegate continueUserActivity type=%@", userActivity.activityType);
	if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
		deliver_url(userActivity.webpageURL, @"universal_link");
		return YES;
	}
	return NO;
}

// Cold-launch deeplink path for scene-based SwiftUI apps. UISceneConnectionOptions
// carries both user activities (Universal Links) and URL contexts (URL schemes).
- (void)sceneWillConnectNotification:(NSNotification *)notification {
	NSLog(@"[DeepLink] sceneWillConnectNotification userInfo keys=%@",
			notification.userInfo ? [[notification.userInfo allKeys] description] : @"(nil)");

	// The connection options live under "UISceneConnectionOptionsKey" key — try
	// both the concrete and string forms to survive iOS version changes.
	id options = nil;
	if (notification.userInfo != nil) {
		options = notification.userInfo[@"UISceneConnectionOptionsKey"];
		if (options == nil) {
			options = notification.userInfo[@"connectionOptions"];
		}
	}

	if (options != nil) {
		if ([options respondsToSelector:@selector(userActivities)]) {
			NSSet *activities = [options performSelector:@selector(userActivities)];
			for (NSUserActivity *activity in activities) {
				NSLog(@"[DeepLink] cold-launch user activity type=%@ url=%@",
						activity.activityType,
						activity.webpageURL ? [activity.webpageURL absoluteString] : @"(nil)");
				if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && activity.webpageURL != nil) {
					deliver_url(activity.webpageURL, @"universal_link");
				}
			}
		}
		if ([options respondsToSelector:@selector(URLContexts)]) {
			NSSet *contexts = [options performSelector:@selector(URLContexts)];
			for (UIOpenURLContext *ctx in contexts) {
				NSLog(@"[DeepLink] cold-launch url context url=%@", [ctx.URL absoluteString]);
				if (ctx.URL != nil) {
					deliver_url(ctx.URL, @"scheme");
				}
			}
		}
	}

	// Patch scene delegate so subsequent warm-launch events flow through.
	UIScene *scene = notification.object;
	if (scene != nil && [scene respondsToSelector:@selector(delegate)]) {
		patch_scene_delegate_if_needed(scene.delegate);
	}
}

- (void)sceneDidActivateNotification:(NSNotification *)notification {
	UIScene *scene = notification.object;
	if (scene != nil && [scene respondsToSelector:@selector(delegate)]) {
		patch_scene_delegate_if_needed(scene.delegate);
	}
}

@end
