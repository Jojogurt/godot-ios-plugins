/*************************************************************************/
/*  deeplink_plugin.cpp                                                  */
/*************************************************************************/

#import "deeplink_plugin.h"
#import "deeplink.h"

#if VERSION_MAJOR == 4
#import "core/config/engine.h"
#else
#import "core/engine.h"
#endif

DeepLinkPlugin *deeplink_plugin;

void godot_deeplink_init() {
	deeplink_plugin = memnew(DeepLinkPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("DeepLink", deeplink_plugin));
}

void godot_deeplink_deinit() {
	if (deeplink_plugin) {
		memdelete(deeplink_plugin);
	}
}
