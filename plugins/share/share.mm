/*************************************************************************/
/*  share.mm                                                             */
/*************************************************************************/

#include "share.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#else
#include "core/class_db.h"
#endif

static SharePlugin *singleton;

static NSString *godot_string_to_ns(const String &s) {
	if (s.is_empty()) {
		return nil;
	}
	return [NSString stringWithUTF8String:s.utf8().get_data()];
}

SharePlugin *SharePlugin::get_singleton() {
	return singleton;
}

void SharePlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("share", "text", "url"), &SharePlugin::share);
	ClassDB::bind_method(D_METHOD("is_available"), &SharePlugin::is_available);

	// result: "ok" (user completed a share), "cancelled" (dismissed), "error" (presentation failed).
	// activity_type: the NSString identifier the user picked (e.g. "com.apple.UIKit.activity.Message")
	// or empty for cancel/error.
	ADD_SIGNAL(MethodInfo("share_completed",
			PropertyInfo(Variant::STRING, "result"),
			PropertyInfo(Variant::STRING, "activity_type")));
}

bool SharePlugin::is_available() {
	// UIActivityViewController exists on every supported iOS version.
	return NSClassFromString(@"UIActivityViewController") != nil;
}

bool SharePlugin::share(String text, String url) {
	if (!is_available()) {
		return false;
	}

	NSMutableArray *items = [NSMutableArray array];
	NSString *text_ns = godot_string_to_ns(text);
	if (text_ns != nil) {
		[items addObject:text_ns];
	}
	NSString *url_ns = godot_string_to_ns(url);
	if (url_ns != nil) {
		NSURL *nsurl = [NSURL URLWithString:url_ns];
		if (nsurl != nil) {
			[items addObject:nsurl];
		} else {
			// Fallback — share as plain text if URL parse failed.
			[items addObject:url_ns];
		}
	}
	if (items.count == 0) {
		return false;
	}

	UIViewController *root_controller = [[UIApplication sharedApplication] delegate].window.rootViewController;
	if (root_controller == nil) {
		return false;
	}

	UIActivityViewController *vc = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:nil];

	vc.completionWithItemsHandler = ^(UIActivityType _Nullable activityType, BOOL completed, NSArray *_Nullable returnedItems, NSError *_Nullable activityError) {
		SharePlugin *plugin = SharePlugin::get_singleton();
		if (plugin == NULL) {
			return;
		}
		String result;
		String activity_str;
		if (activityError != nil) {
			result = String("error");
		} else if (completed) {
			result = String("ok");
		} else {
			result = String("cancelled");
		}
		if (activityType != nil) {
			const char *c = [activityType UTF8String];
			if (c != NULL) {
#if VERSION_MAJOR == 4 && VERSION_MINOR >= 5
				activity_str.append_utf8(c);
#else
				activity_str.parse_utf8(c);
#endif
			}
		}
		plugin->dispatch_result(result, activity_str);
	};

	// iPad popover anchoring — Apple crashes the app if popoverPresentationController isn't configured.
	if (vc.popoverPresentationController != nil) {
		vc.popoverPresentationController.sourceView = root_controller.view;
		CGRect bounds = root_controller.view.bounds;
		vc.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 0, 0);
		vc.popoverPresentationController.permittedArrowDirections = 0;
	}

	[root_controller presentViewController:vc animated:YES completion:nil];
	return true;
}

void SharePlugin::dispatch_result(String result, String activity_type) {
	emit_signal("share_completed", result, activity_type);
}

SharePlugin::SharePlugin() {
	singleton = this;
}

SharePlugin::~SharePlugin() {
	singleton = NULL;
}
