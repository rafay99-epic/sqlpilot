import AppKit
import SwiftUI

/// The app's own icon at any size.
struct AppIcon: View {
  var size: CGFloat = 56

  var body: some View {
    Image(nsImage: NSApp.applicationIconImage)
      .resizable()
      .interpolation(.high)
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}

/// Button label that reads "Copied" for a moment after it's pressed.
struct CopyButton: View {
  let title: String
  let action: () -> Void
  @State private var copied = false

  var body: some View {
    Button(copied ? "Copied" : title) {
      action()
      copied = true
      Task {
        try? await Task.sleep(for: .seconds(1.5))
        copied = false
      }
    }
  }
}
