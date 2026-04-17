/*************************************************************************/
/*  share.h                                                              */
/*************************************************************************/

#ifndef godot_share_implementation_h
#define godot_share_implementation_h

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#else
#include "core/object.h"
#endif

class SharePlugin : public Object {
	GDCLASS(SharePlugin, Object);

	static void _bind_methods();

public:
	static SharePlugin *get_singleton();

	// Presents UIActivityViewController with text and/or URL. Either parameter may be empty.
	// Returns true if presentation was initiated, false if no content or presentation failed.
	bool share(String text, String url);

	bool is_available();

	// Called by the delegate when the activity sheet finishes.
	void dispatch_result(String result, String activity_type);

	SharePlugin();
	~SharePlugin();
};

#endif
