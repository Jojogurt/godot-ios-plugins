/*************************************************************************/
/*  accessibility_plugin.cpp                                             */
/*************************************************************************/

#import "accessibility_plugin.h"
#import "accessibility.h"

#if VERSION_MAJOR == 4
#import "core/config/engine.h"
#else
#import "core/engine.h"
#endif

AccessibilityPlugin *accessibility_plugin;

void godot_accessibility_init() {
	accessibility_plugin = memnew(AccessibilityPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Accessibility", accessibility_plugin));
}

void godot_accessibility_deinit() {
	if (accessibility_plugin) {
		memdelete(accessibility_plugin);
	}
}
