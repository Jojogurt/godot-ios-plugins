/*************************************************************************/
/*  godot_app_delegate_extension.h  (deeplink)                           */
/*************************************************************************/

#include "core/version.h"

#if VERSION_MAJOR == 4
#if VERSION_MINOR >= 5
#import "drivers/apple_embedded/godot_app_delegate.h"
#else
#import "platform/ios/godot_app_delegate.h"
#endif
#else
#import "platform/iphone/godot_app_delegate.h"
#endif

#if VERSION_MAJOR == 4 && VERSION_MINOR >= 5
@interface GDTApplicationDelegate (DeepLink)
#elif VERSION_MAJOR == 4 && VERSION_MINOR == 4
@interface GodotApplicationDelegate (DeepLink)
#else
@interface GodotApplicalitionDelegate (DeepLink)
#endif

@end
