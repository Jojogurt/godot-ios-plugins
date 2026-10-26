/*************************************************************************/
/*  accessibility.h                                                      */
/*************************************************************************/

#ifndef godot_accessibility_implementation_h
#define godot_accessibility_implementation_h

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/object/class_db.h"
#include "core/variant/dictionary.h"
#else
#include "core/object.h"
#include "core/dictionary.h"
#endif

class AccessibilityPlugin : public Object {
	GDCLASS(AccessibilityPlugin, Object);

	static void _bind_methods();

	// NSArray of NSNotificationCenter observer tokens (void* keeps the header
	// free of Objective-C types).
	void *observers;

public:
	static AccessibilityPlugin *get_singleton();

	// Settings > Accessibility > Motion > Reduce Motion.
	bool is_reduce_motion_enabled();
	// Reduce Motion > Prefer Cross-Fade Transitions (iOS 14+, false before).
	bool prefers_cross_fade_transitions();
	bool is_voice_over_running();
	bool is_switch_control_running();
	// Settings > Accessibility > Display & Text Size.
	bool should_differentiate_without_color();
	bool is_bold_text_enabled();
	bool is_darker_system_colors_enabled();
	bool is_reduce_transparency_enabled();
	bool is_invert_colors_enabled();
	bool is_mono_audio_enabled();
	// UIContentSizeCategory raw value, e.g. "UICTContentSizeCategoryL".
	String get_preferred_content_size_category();
	// Every flag above in one Dictionary (keys = method names without is_/get_).
	Dictionary get_state();

	// Called on the main thread when any watched system setting changes.
	void dispatch_changed();

	AccessibilityPlugin();
	~AccessibilityPlugin();
};

#endif
