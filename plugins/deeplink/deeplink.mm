/*************************************************************************/
/*  deeplink.mm                                                          */
/*************************************************************************/

#include "deeplink.h"

#import <Foundation/Foundation.h>

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#else
#include "core/class_db.h"
#endif

#import "godot_deeplink_delegate.h"

static DeepLinkPlugin *singleton;

DeepLinkPlugin *DeepLinkPlugin::get_singleton() {
	return singleton;
}

void DeepLinkPlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("get_initial_url"), &DeepLinkPlugin::get_initial_url);
	ClassDB::bind_method(D_METHOD("get_initial_source"), &DeepLinkPlugin::get_initial_source);

	// Emitted every time the app receives a link while running or is opened by one.
	// source is "scheme" (custom URL scheme) or "universal_link" (https associated domain).
	ADD_SIGNAL(MethodInfo("link_received",
			PropertyInfo(Variant::STRING, "url"),
			PropertyInfo(Variant::STRING, "source")));
}

void DeepLinkPlugin::dispatch_url(String url, String source) {
	emit_signal("link_received", url, source);
}

String DeepLinkPlugin::get_initial_url() {
	String url = initial_url;
	initial_url = String();
	return url;
}

String DeepLinkPlugin::get_initial_source() {
	String source = initial_source;
	initial_source = String();
	return source;
}

void DeepLinkPlugin::_set_initial(String url, String source) {
	initial_url = url;
	initial_source = source;
}

DeepLinkPlugin::DeepLinkPlugin() {
	singleton = this;
	// Touch the delegate so its +load / static initializer runs and registers with GDTApplicationDelegate.
	(void)[GodotDeepLinkAppDelegate shared];
}

DeepLinkPlugin::~DeepLinkPlugin() {
	singleton = NULL;
}
