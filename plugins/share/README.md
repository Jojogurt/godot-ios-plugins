# Share (iOS)

Godot iOS plugin that exposes the native iOS share sheet (`UIActivityViewController`) to GDScript.

## Exposed singleton: `Share`

| Member | Kind | Description |
|---|---|---|
| `share(text: String, url: String) -> bool` | method | Presents the share sheet. Pass `""` for unused fields. Returns `true` if the sheet was presented. |
| `is_available() -> bool` | method | Always `true` on iOS 12+. Use to guard the call. |
| `share_completed(result: String, activity_type: String)` | signal | Emitted when the sheet finishes. `result` is `"ok"` / `"cancelled"` / `"error"`. `activity_type` is the selected UTI (e.g. `com.apple.UIKit.activity.Message`) or empty. |

## GDScript usage

```gdscript
func _ready() -> void:
    if Engine.has_singleton("Share"):
        Engine.get_singleton("Share").share_completed.connect(_on_share_completed)

func share_level(url: String) -> void:
    if Engine.has_singleton("Share"):
        var s := Engine.get_singleton("Share")
        if s.is_available():
            s.share("Play my level!", url)

func _on_share_completed(result: String, activity_type: String) -> void:
    print("Share: %s via %s" % [result, activity_type])
```

## Notes

- `UIActivityViewController` requires iPad popover anchoring. The plugin centres the popover on the root view; if your UI needs a specific anchor, extend the `share` method to accept a screen rect.
- The plugin never mutates text/URL content — whatever you pass is what iOS hands to the target app.

## Build

```
scons target=release_debug arch=arm64 simulator=no plugin=share version=4.0
./scripts/generate_xcframework.sh share release_debug 4.0
```
