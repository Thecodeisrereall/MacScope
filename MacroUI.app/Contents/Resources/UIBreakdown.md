# MacroUI - UI Scaling and Position Limits Breakdown

## Overview

This document provides an in-depth analysis of the UI scaling and positioning system implemented in the MacroUI application. The app uses SwiftUI with advanced material effects (Liquid Glass) and sophisticated constraint management to create a responsive, professional interface.

## 1. Window-Level Scaling and Constraints

### Window Size Management
The application implements strict window size limitations to ensure optimal user experience across different screen sizes.

```swift
// ContentView.swift - Window size controls
private static let minWindowSize = CGSize(width: 800, height: 600)
private static let maxWindowSize = CGSize(width: 1400, height: 1000)
```

### Implementation Strategy
- **Minimum Constraints**: 800×600 prevents UI elements from becoming unusable
- **Maximum Constraints**: 1400×1000 maintains design proportions and readability
- **Platform-Specific**: macOS-only implementation using custom `limitWindowSize` modifier

### Code Implementation
```swift
.frame(minWidth: Self.minWindowSize.width, minHeight: Self.minWindowSize.height)
#if os(macOS)
.limitWindowSize(minWidth: Self.minWindowSize.width,
                 maxWidth: Self.maxWindowSize.width,
                 minHeight: Self.minWindowSize.height,
                 maxHeight: Self.maxWindowSize.height)
#endif
```

### Custom Window Size Limiter
The app includes a custom `WindowSizeLimiter` ViewModifier that directly interfaces with AppKit:

```swift
private struct WindowSizeLimiter: ViewModifier {
    var minWidth: CGFloat?
    var maxWidth: CGFloat?
    var minHeight: CGFloat?
    var maxHeight: CGFloat?

    func body(content: Content) -> some View {
        content.background(WindowAccessor { window in
            var min = window.minSize
            var max = window.maxSize

            if let minWidth { min.width = minWidth }
            if let minHeight { min.height = minHeight }
            if let maxWidth { max.width = maxWidth }
            if let maxHeight { max.height = maxHeight }

            window.minSize = min
            window.maxSize = max
        })
    }
}
```

## 2. Liquid Glass Material System

### Background Implementation
The app uses a sophisticated Liquid Glass background system for modern visual appeal:

```swift
private struct LiquidGlassBackground: View {
    let cornerRadius: CGFloat
    let insets: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(shineOverlay)
                .frame(width: max(0, size.width - insets * 2),
                       height: max(0, size.height - insets * 2),
                       alignment: .center)
                .position(x: size.width / 2, y: size.height / 2)
        }
    }
}
```

### Key Features
- **Geometry-Aware**: Uses `GeometryReader` for responsive positioning
- **Inset Management**: Consistent spacing across different screen sizes
- **Material Effects**: `.ultraThinMaterial` with custom shine overlay
- **Platform Enhancement**: Advanced effects on macOS 15+ with `GlassUpgradeIfAvailable`

### Shine Overlay System
```swift
private var shineOverlay: some View {
    LinearGradient(
        gradient: Gradient(stops: [
            .init(color: Color.white.opacity(0.22), location: 0.0),
            .init(color: Color.white.opacity(0.06), location: 0.25),
            .init(color: Color.white.opacity(0.03), location: 0.5),
            .init(color: Color.white.opacity(0.10), location: 1.0),
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    .blendMode(.plusLighter)
}
```

## 3. Navigation and Layout Architecture

### NavigationSplitView Structure
The app uses a split-view design that automatically adapts to different screen sizes:

- **Sidebar**: Fixed-width navigation with adaptive menu items
- **Detail Area**: Flexible content area with liquid glass background
- **Transition System**: Smooth animations between different views

### Responsive Layout Code
```swift
NavigationSplitView {
    sidebar
} detail: {
    Group {
        ZStack {
            LiquidGlassBackground(cornerRadius: 18, insets: 24)
                .ignoresSafeArea(edges: .bottom)

            detailView
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .contentTransition(.opacity)
    }
    .animation(.easeInOut(duration: 0.25), value: selection)
}
```

## 4. Sidebar Interactive Elements

### SidebarRow Component
Interactive sidebar elements with hover effects and scaling:

```swift
private struct SidebarRow: View {
    let item: MenuItem
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        // Background effects based on state
        if isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        } else if isHovering {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.thinMaterial)
                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        }

        // Interactive scaling
        Image(systemName: item.systemImage)
            .scaleEffect(isHovering ? 1.08 : 1.0)
            .brightness(isHovering ? 0.08 : 0.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.9), value: isHovering)
    }
}
```

### Interactive Scaling Features
- **Hover Scale**: 1.08x scale effect on hover
- **Brightness Adjustment**: +0.08 brightness on hover
- **Spring Animation**: Smooth transitions with dampening
- **Content Shape**: Proper hit-testing boundaries

## 5. Content-Specific Scaling: BiomesUI

### Console Log Management
The BiomesUI demonstrates sophisticated content scaling with console log constraints:

```swift
// Log sizing parameters
private let consoleMaxLines = 500
private let consoleMinLines: Int = 20
private let consoleLineHeight: CGFloat = 14.0
private let consoleMinHeight: CGFloat = 320
private let consoleMaxHeight: CGFloat = 480
```

### Viewport Control System
```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(filteredConsole) { line in
                Text(formattedConsoleText(line))
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .id(line.id)
            }
            Color.clear
                .frame(height: 1)
                .id("BOTTOM_ANCHOR")
        }
        .background(GeometryReader { geo -> Color in
            // Position tracking for auto-scroll logic
            DispatchQueue.main.async {
                let maxY = geo.frame(in: .named("BiomeConsoleScroll")).maxY
                // Auto-scroll position management
            }
            return Color.clear
        })
    }
}
```

### Auto-Scroll Management
```swift
.onChange(of: filteredConsole.count) { _ in
    if isPinnedToBottom {
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo("BOTTOM_ANCHOR", anchor: .bottom)
        }
    }
}
```

## 6. Card-Based Layout System

### RoundedCard Component
Provides consistent scaling and spacing for content cards:

```swift
private struct RoundedCard<Content: View>: View {
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
```

### Material Usage Strategy
- **Regular Material**: `.regularMaterial` for card backgrounds
- **Ultra Thin Material**: `.ultraThinMaterial` for selected states
- **Thin Material**: `.thinMaterial` for hover states

## 7. Frame-Based Positioning Strategies

### Maximum Width Patterns
The app uses various frame strategies for different layout needs:

```swift
// Full-width with specific alignment
.frame(maxWidth: .infinity, alignment: .leading)
.frame(maxWidth: .infinity, alignment: .center)

// Fixed-width elements
.frame(width: 52)     // Toggle switches
.frame(height: 20)    // Dividers  
.frame(minWidth: 180) // Search fields
```

### Biome Row Layout
```swift
HStack(spacing: 12) {
    Text(state.biome.displayName)
        .font(.body.weight(.bold))
        .foregroundColor(color)
    Spacer()
    Text("Total: \(state.triggerCount)")
        .font(.body.weight(.bold))
        .monospacedDigit()
    Toggle("", isOn: $state.webhookEnabled)
        .frame(width: 52)
        .accessibilityLabel("Send webhooks")
}
.contentShape(Rectangle())
```

## 8. Typography and Font Scaling

### System Font Usage
Consistent typography scaling across the application:

```swift
// Header typography
Text("Biomes Detection")
    .font(.headline)

Text("Live detection from Roblox logs with optional webhooks")
    .font(.caption)
    .foregroundStyle(.secondary)

// Monospaced content for logs
Text(formattedConsoleText(line))
    .font(.system(.caption, design: .monospaced))

// Icon sizing with font weights
Image(systemName: item.systemImage)
    .font(.system(size: 16, weight: .semibold))
```

### Gradient Text Effects
```swift
Image(systemName: "globe.americas.fill")
    .font(.system(size: 22, weight: .semibold))
    .foregroundStyle(
        LinearGradient(colors: [.green, .blue], 
                      startPoint: .topLeading, 
                      endPoint: .bottomTrailing)
    )
```

## 9. Animation and Transition System

### Content Transitions
```swift
.contentTransition(.opacity)
.animation(.easeInOut(duration: 0.25), value: selection)

// Spring animations for interactive elements
.animation(.spring(response: 0.35, dampingFraction: 0.85), value: selection)
```

### Hover Animations
```swift
.onHover { hovering in
    withAnimation(.easeInOut(duration: 0.18)) {
        isHovering = hovering
    }
}
```

## 10. Constraint Management Principles

### Hard Constraints
- Window size limits prevent unusable layouts
- Fixed element dimensions maintain consistency
- Minimum heights ensure content visibility

### Soft Constraints
- Content adapts within defined boundaries
- Flexible spacing adjusts to available space
- Material effects respond to container size

### Proportional Scaling
- Elements scale relative to available space
- Consistent spacing ratios across screen sizes
- Adaptive corner radius and padding values

## 11. Platform-Specific Adaptations

### macOS-Specific Features
```swift
#if os(macOS)
.limitWindowSize(minWidth: Self.minWindowSize.width,
                 maxWidth: Self.maxWindowSize.width,
                 minHeight: Self.minWindowSize.height,
                 maxHeight: Self.maxWindowSize.height)

// Sidebar toggle functionality
func toggleSidebar() {
    NSApp.keyWindow?.firstResponder?.tryToPerform(
        #selector(NSSplitViewController.toggleSidebar(_:)), with: nil
    )
}
#endif
```

### Enhanced Glass Effects (macOS 15+)
```swift
private struct GlassUpgradeIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            content
                .background(.ultraThinMaterial)
                .compositingGroup()
                .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 4)
                .transition(.opacity)
        } else {
            content
        }
        #else
        content
        #endif
    }
}
```

## Key Architectural Decisions

1. **Window Constraints**: Hard limits ensure usability across different screen sizes
2. **Material System**: Consistent use of system materials for native feel
3. **Responsive Design**: Geometry-aware layouts that adapt to available space
4. **Interactive Feedback**: Subtle animations provide immediate user feedback
5. **Content-Aware Scaling**: Different scaling strategies for different content types
6. **Platform Integration**: Leverages platform-specific features where available

## Performance Considerations

- Uses `@MainActor` for UI updates
- Implements view recycling with `ForEach` and identifiable data
- Limits console log retention (500 lines max)
- Uses `DispatchQueue.main.async` for background geometry calculations
- Implements efficient scroll position tracking

This UI system demonstrates professional-level constraint management, creating a robust and scalable interface that maintains visual consistency while adapting to different screen sizes and user interactions.