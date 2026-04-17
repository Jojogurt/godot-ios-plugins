/*************************************************************************/
/*  godot_app_delegate_extension.m  (deeplink)                           */
/*************************************************************************/

#include "godot_app_delegate_extension.h"

// Forwards openURL and continueUserActivity (Universal Links) to every registered
// service (our GodotDeepLinkAppDelegate among them). The base GDTApplicationDelegate
// does not dispatch these methods out of the box.

#if VERSION_MAJOR == 4 && VERSION_MINOR >= 5

@implementation GDTApplicationDelegate (DeepLink)

- (BOOL)application:(UIApplication *)application
			openURL:(NSURL *)url
			options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
	BOOL handled = NO;
	for (GDTAppDelegateServiceProtocol *service in GDTApplicationDelegate.services) {
		if (![service respondsToSelector:_cmd]) {
			continue;
		}
		if ([service application:application openURL:url options:options]) {
			handled = YES;
		}
	}
	return handled;
}

- (BOOL)application:(UIApplication *)application
	continueUserActivity:(NSUserActivity *)userActivity
	restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
	BOOL handled = NO;
	for (GDTAppDelegateServiceProtocol *service in GDTApplicationDelegate.services) {
		if (![service respondsToSelector:_cmd]) {
			continue;
		}
		if ([service application:application
				continueUserActivity:userActivity
				  restorationHandler:restorationHandler]) {
			handled = YES;
		}
	}
	return handled;
}

@end

#elif VERSION_MAJOR == 4 && VERSION_MINOR == 4

@implementation GodotApplicationDelegate (DeepLink)

- (BOOL)application:(UIApplication *)application
			openURL:(NSURL *)url
			options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
	BOOL handled = NO;
	for (ApplicationDelegateService *service in GodotApplicationDelegate.services) {
		if (![service respondsToSelector:_cmd]) {
			continue;
		}
		if ([service application:application openURL:url options:options]) {
			handled = YES;
		}
	}
	return handled;
}

- (BOOL)application:(UIApplication *)application
	continueUserActivity:(NSUserActivity *)userActivity
	restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
	BOOL handled = NO;
	for (ApplicationDelegateService *service in GodotApplicationDelegate.services) {
		if (![service respondsToSelector:_cmd]) {
			continue;
		}
		if ([service application:application
				continueUserActivity:userActivity
				  restorationHandler:restorationHandler]) {
			handled = YES;
		}
	}
	return handled;
}

@end

#else

@implementation GodotApplicalitionDelegate (DeepLink)

- (BOOL)application:(UIApplication *)application
			openURL:(NSURL *)url
			options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options {
	BOOL handled = NO;
	for (ApplicationDelegateService *service in GodotApplicalitionDelegate.services) {
		if (![service respondsToSelector:_cmd]) {
			continue;
		}
		if ([service application:application openURL:url options:options]) {
			handled = YES;
		}
	}
	return handled;
}

- (BOOL)application:(UIApplication *)application
	continueUserActivity:(NSUserActivity *)userActivity
	restorationHandler:(void (^)(NSArray<id<UIUserActivityRestoring>> *))restorationHandler {
	BOOL handled = NO;
	for (ApplicationDelegateService *service in GodotApplicalitionDelegate.services) {
		if (![service respondsToSelector:_cmd]) {
			continue;
		}
		if ([service application:application
				continueUserActivity:userActivity
				  restorationHandler:restorationHandler]) {
			handled = YES;
		}
	}
	return handled;
}

@end

#endif
