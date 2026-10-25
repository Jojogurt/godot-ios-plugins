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

	// Same sheet with a PNG/JPEG image (absolute file path) as the first item,
	// then the text and URL. Falls back to text + URL when the image can't be
	// loaded. Returns true if presentation was initiated.
	bool share_image(String text, String url, String image_path);

	bool is_available();

	// Presents UIActivityViewController for `items` (NSArray, as void* so the
	// header stays free of Objective-C types).
	bool present_items(void *items);

	// Called by the delegate when the activity sheet finishes.
	void dispatch_result(String result, String activity_type);

	SharePlugin();
	~SharePlugin();
};

#endif
