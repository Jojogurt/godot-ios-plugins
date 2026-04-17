# DeepLink (iOS)

Godot iOS plugin that forwards custom URL scheme opens and Universal Link activations to GDScript.

## Exposed singleton: `DeepLink`

| Member | Kind | Description |
|---|---|---|
| `link_received(url: String, source: String)` | signal | Emitted whenever the app receives a link. `source` is `"scheme"` or `"universal_link"`. |
| `get_initial_url() -> String` | method | Returns the URL that cold-launched the app (if any), then clears it. Empty string if none. |
| `get_initial_source() -> String` | method | Companion to `get_initial_url()` — `"scheme"` or `"universal_link"`. Cleared on read. |

## GDScript usage

```gdscript
func _ready() -> void:
    if Engine.has_singleton("DeepLink"):
        var dl := Engine.get_singleton("DeepLink")
        dl.link_received.connect(_on_link_received)
        var pending: String = dl.get_initial_url()
        if pending != "":
            _on_link_received(pending, dl.get_initial_source())

func _on_link_received(url: String, source: String) -> void:
    print("Got link: %s (%s)" % [url, source])
```

## Project setup

### Custom URL scheme

Add to your iOS export preset's plist (or `Info.plist`):

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array><string>memomaze</string></array>
    </dict>
</array>
```

### Universal Links

1. Enable the *Associated Domains* capability in your Apple developer account for the bundle ID.
2. Add to the plist:

```xml
<key>com.apple.developer.associated-domains</key>
<array><string>applinks:memomaze.example</string></array>
```

3. Host `/.well-known/apple-app-site-association` on the domain (JSON, no extension, served with `Content-Type: application/json`).

## Build

```
scons target=release_debug arch=arm64 simulator=no plugin=deeplink version=4.0
./scripts/generate_xcframework.sh deeplink release_debug 4.0
```
