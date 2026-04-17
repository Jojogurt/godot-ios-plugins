/*************************************************************************/
/*  share_plugin.cpp                                                     */
/*************************************************************************/

#import "share_plugin.h"
#import "share.h"

#if VERSION_MAJOR == 4
#import "core/config/engine.h"
#else
#import "core/engine.h"
#endif

SharePlugin *share_plugin;

void godot_share_init() {
	share_plugin = memnew(SharePlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("Share", share_plugin));
}

void godot_share_deinit() {
	if (share_plugin) {
		memdelete(share_plugin);
	}
}
