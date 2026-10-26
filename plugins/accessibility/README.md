# Accessibility (iOS)

Godot iOS plugin that exposes the system accessibility settings (`UIAccessibility`) to GDScript, so a game can follow Reduce Motion and friends. Used by godot-mobile-kit's `MobileKitAccessibilityProviderIOS`.

## Exposed singleton: `Accessibility`

| Member | Kind | Description |
|---|---|---|
| `is_reduce_motion_enabled() -> bool` | method | Settings > Accessibility > Motion > Reduce Motion. |
| `prefers_cross_fade_transitions() -> bool` | method | Reduce Motion > Prefer Cross-Fade Transitions (iOS 14+). |
| `is_voice_over_running() -> bool` | method | VoiceOver on. |
| `is_switch_control_running() -> bool` | method | Switch Control on. |
| `should_differentiate_without_color() -> bool` | method | Display & Text Size > Differentiate Without Colour. |
| `is_bold_text_enabled()`, `is_darker_system_colors_enabled()`, `is_reduce_transparency_enabled()`, `is_invert_colors_enabled()`, `is_mono_audio_enabled()` | methods | The matching system switches. |
| `get_preferred_content_size_category() -> String` | method | Dynamic Type size, e.g. `UICTContentSizeCategoryL`. |
| `get_state() -> Dictionary` | method | All of the above in one dictionary (`reduce_motion_enabled`, `prefers_cross_fade_transitions`, `voice_over_running`, `switch_control_running`, `differentiate_without_color`, `bold_text_enabled`, `darker_system_colors_enabled`, `reduce_transparency_enabled`, `invert_colors_enabled`, `mono_audio_enabled`, `preferred_content_size_category`). |
| `accessibility_changed()` | signal | Any of the watched settings changed (deferred to the game thread). Read the new values with the getters. |

## GDScript usage

```gdscript
func _ready() -> void:
    if Engine.has_singleton("Accessibility"):
        var a11y := Engine.get_singleton("Accessibility")
        a11y.accessibility_changed.connect(_apply_motion)
        _apply_motion()

func _apply_motion() -> void:
    var reduced: bool = Engine.get_singleton("Accessibility").is_reduce_motion_enabled()
    print("Reduce Motion: ", reduced)
```

## Build

```
./scripts/generate_xcframework.sh accessibility release 4.0
```

Copy `bin/accessibility.release.xcframework` to the game as `ios/plugins/accessibility.xcframework`, next to `plugins/accessibility/accessibility.gdip`, and enable `plugins/Accessibility=true` in the iOS export preset.
