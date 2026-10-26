/*************************************************************************/
/*  accessibility.mm                                                     */
/*************************************************************************/

#include "accessibility.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#if VERSION_MAJOR == 4
#include "core/object/callable_method_pointer.h"
#include "core/object/class_db.h"
#else
#include "core/class_db.h"
#endif

static AccessibilityPlugin *singleton;

AccessibilityPlugin *AccessibilityPlugin::get_singleton() {
	return singleton;
}

void AccessibilityPlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_reduce_motion_enabled"), &AccessibilityPlugin::is_reduce_motion_enabled);
	ClassDB::bind_method(D_METHOD("prefers_cross_fade_transitions"), &AccessibilityPlugin::prefers_cross_fade_transitions);
	ClassDB::bind_method(D_METHOD("is_voice_over_running"), &AccessibilityPlugin::is_voice_over_running);
	ClassDB::bind_method(D_METHOD("is_switch_control_running"), &AccessibilityPlugin::is_switch_control_running);
	ClassDB::bind_method(D_METHOD("should_differentiate_without_color"), &AccessibilityPlugin::should_differentiate_without_color);
	ClassDB::bind_method(D_METHOD("is_bold_text_enabled"), &AccessibilityPlugin::is_bold_text_enabled);
	ClassDB::bind_method(D_METHOD("is_darker_system_colors_enabled"), &AccessibilityPlugin::is_darker_system_colors_enabled);
	ClassDB::bind_method(D_METHOD("is_reduce_transparency_enabled"), &AccessibilityPlugin::is_reduce_transparency_enabled);
	ClassDB::bind_method(D_METHOD("is_invert_colors_enabled"), &AccessibilityPlugin::is_invert_colors_enabled);
	ClassDB::bind_method(D_METHOD("is_mono_audio_enabled"), &AccessibilityPlugin::is_mono_audio_enabled);
	ClassDB::bind_method(D_METHOD("get_preferred_content_size_category"), &AccessibilityPlugin::get_preferred_content_size_category);
	ClassDB::bind_method(D_METHOD("get_state"), &AccessibilityPlugin::get_state);
#if VERSION_MAJOR != 4
	ClassDB::bind_method(D_METHOD("dispatch_changed"), &AccessibilityPlugin::dispatch_changed);
#endif

	// Emitted (deferred, on the game thread) after any watched system
	// accessibility setting changes. Read the new values with get_state().
	ADD_SIGNAL(MethodInfo("accessibility_changed"));
}

bool AccessibilityPlugin::is_reduce_motion_enabled() {
	return UIAccessibilityIsReduceMotionEnabled();
}

bool AccessibilityPlugin::prefers_cross_fade_transitions() {
	if (@available(iOS 14.0, *)) {
		return UIAccessibilityPrefersCrossFadeTransitions();
	}
	return false;
}

bool AccessibilityPlugin::is_voice_over_running() {
	return UIAccessibilityIsVoiceOverRunning();
}

bool AccessibilityPlugin::is_switch_control_running() {
	return UIAccessibilityIsSwitchControlRunning();
}

bool AccessibilityPlugin::should_differentiate_without_color() {
	if (@available(iOS 13.0, *)) {
		return UIAccessibilityShouldDifferentiateWithoutColor();
	}
	return false;
}

bool AccessibilityPlugin::is_bold_text_enabled() {
	return UIAccessibilityIsBoldTextEnabled();
}

bool AccessibilityPlugin::is_darker_system_colors_enabled() {
	return UIAccessibilityDarkerSystemColorsEnabled();
}

bool AccessibilityPlugin::is_reduce_transparency_enabled() {
	return UIAccessibilityIsReduceTransparencyEnabled();
}

bool AccessibilityPlugin::is_invert_colors_enabled() {
	return UIAccessibilityIsInvertColorsEnabled();
}

bool AccessibilityPlugin::is_mono_audio_enabled() {
	return UIAccessibilityIsMonoAudioEnabled();
}

String AccessibilityPlugin::get_preferred_content_size_category() {
	NSString *category = [UIApplication sharedApplication].preferredContentSizeCategory;
	if (category == nil) {
		return String();
	}
	return String::utf8([category UTF8String]);
}

Dictionary AccessibilityPlugin::get_state() {
	Dictionary d;
	d["reduce_motion_enabled"] = is_reduce_motion_enabled();
	d["prefers_cross_fade_transitions"] = prefers_cross_fade_transitions();
	d["voice_over_running"] = is_voice_over_running();
	d["switch_control_running"] = is_switch_control_running();
	d["differentiate_without_color"] = should_differentiate_without_color();
	d["bold_text_enabled"] = is_bold_text_enabled();
	d["darker_system_colors_enabled"] = is_darker_system_colors_enabled();
	d["reduce_transparency_enabled"] = is_reduce_transparency_enabled();
	d["invert_colors_enabled"] = is_invert_colors_enabled();
	d["mono_audio_enabled"] = is_mono_audio_enabled();
	d["preferred_content_size_category"] = get_preferred_content_size_category();
	return d;
}

void AccessibilityPlugin::dispatch_changed() {
	emit_signal("accessibility_changed");
}

AccessibilityPlugin::AccessibilityPlugin() :
		observers(NULL) {
	singleton = this;

	NSMutableArray *names = [NSMutableArray arrayWithArray:@[
		UIAccessibilityReduceMotionStatusDidChangeNotification,
		UIAccessibilityVoiceOverStatusDidChangeNotification,
		UIAccessibilitySwitchControlStatusDidChangeNotification,
		UIAccessibilityBoldTextStatusDidChangeNotification,
		UIAccessibilityDarkerSystemColorsStatusDidChangeNotification,
		UIAccessibilityReduceTransparencyStatusDidChangeNotification,
		UIAccessibilityInvertColorsStatusDidChangeNotification,
		UIAccessibilityMonoAudioStatusDidChangeNotification,
		UIContentSizeCategoryDidChangeNotification,
	]];
	if (@available(iOS 13.0, *)) {
		[names addObject:UIAccessibilityShouldDifferentiateWithoutColorDidChangeNotification];
	}
	if (@available(iOS 14.0, *)) {
		[names addObject:UIAccessibilityPrefersCrossFadeTransitionsStatusDidChangeNotification];
	}

	NSMutableArray *tokens = [NSMutableArray array];
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	for (NSString *name in names) {
		id token = [center addObserverForName:name
									   object:nil
										queue:[NSOperationQueue mainQueue]
								   usingBlock:^(NSNotification *note) {
									   AccessibilityPlugin *plugin = AccessibilityPlugin::get_singleton();
									   if (plugin != NULL) {
										   // Deferred so GDScript handlers run inside the
										   // engine's frame, not from a UIKit callback.
#if VERSION_MAJOR == 4
										   callable_mp(plugin, &AccessibilityPlugin::dispatch_changed).call_deferred();
#else
										   plugin->call_deferred("dispatch_changed");
#endif
									   }
								   }];
		[tokens addObject:token];
	}
	observers = (__bridge_retained void *)tokens;
}

AccessibilityPlugin::~AccessibilityPlugin() {
	if (observers != NULL) {
		NSArray *tokens = (__bridge_transfer NSArray *)observers;
		for (id token in tokens) {
			[[NSNotificationCenter defaultCenter] removeObserver:token];
		}
		observers = NULL;
	}
	singleton = NULL;
}
