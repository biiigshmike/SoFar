# SoFar

## View Conventions

New SwiftUI views should apply the app's standard screen background to their root container:

```swift
struct ExampleView: View {
    var body: some View {
        VStack {
            // content
        }
        .screenBackground()
    }
}
```

Calling `screenBackground()` ensures the view uses `DS.Colors.containerBackground` across the full screen and ignores the safe area.
