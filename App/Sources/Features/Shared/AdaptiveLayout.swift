import SwiftUI

/// Two peer regions of list sections. On compact width (outer iPhone display, iPhone Duo folded)
/// they stack in one list; with regular width (iPhone Duo inner display, landscape Pro Max) they sit
/// side by side, so the gutter lands over the fold when the device is open.
///
/// The iOS 27.1 `ArrangementView` would do this natively, but CI builds with the iOS 26 SDK, so this
/// is the documented `HStack` fallback. Swap it in once the build moves to Xcode 27.1.
struct SplitSections<Primary: View, Secondary: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder let primary: Primary
    @ViewBuilder let secondary: Secondary

    var body: some View {
        if horizontalSizeClass == .regular && !dynamicTypeSize.isAccessibilitySize {
            HStack(spacing: 0) {
                List { primary }
                    .accessibilitySortPriority(2)
                Divider().ignoresSafeArea(edges: .vertical)
                List { secondary }
                    .accessibilitySortPriority(1)
            }
        } else {
            List {
                primary
                secondary
            }
        }
    }
}

/// Rows that put a label and a value side by side, stacking them at accessibility text sizes so
/// nothing truncates.
struct AdaptiveRow<Leading: View, Trailing: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ViewBuilder let leading: Leading
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 12))
        layout {
            leading
            if !dynamicTypeSize.isAccessibilitySize { Spacer(minLength: 8) }
            trailing
        }
    }
}

extension View {
    /// Bottom action bar. Uses `safeAreaBar` on iOS 26 for the system bar appearance and
    /// scroll-edge effect, and falls back to `safeAreaInset` with a bar material.
    @ViewBuilder
    func bottomActionBar<Bar: View>(@ViewBuilder _ bar: () -> Bar) -> some View {
        if #available(iOS 26, *) {
            safeAreaBar(edge: .bottom) {
                bar()
                    .padding(16)
                    .frame(maxWidth: 600)
            }
        } else {
            safeAreaInset(edge: .bottom) {
                bar()
                    .padding(16)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
    }
}
