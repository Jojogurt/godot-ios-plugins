/*************************************************************************/
/*  deeplink.h                                                           */
/*************************************************************************/

#ifndef godot_deeplink_implementation_h
#define godot_deeplink_implementation_h

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#else
#include "core/object.h"
#endif

class DeepLinkPlugin : public Object {
	GDCLASS(DeepLinkPlugin, Object);

	static void _bind_methods();

	String initial_url;
	String initial_source;

public:
	static DeepLinkPlugin *get_singleton();

	// Called by the Objective-C delegate when a URL arrives.
	void dispatch_url(String url, String source);

	// Set at launch if the app was cold-started via a link. Cleared by first read.
	String get_initial_url();
	String get_initial_source();
	void _set_initial(String url, String source);

	DeepLinkPlugin();
	~DeepLinkPlugin();
};

#endif
