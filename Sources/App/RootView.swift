import SwiftUI

struct RootView: View {
    @State private var selectedModule: ModuleAccent = .worldClock

    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            List(ModuleAccent.allCases, selection: $selectedModule) { module in
                Label(module.displayName, systemImage: module.symbolName)
                    .tag(module)
                    .foregroundStyle(module.color)
            }
            .navigationTitle("DeedSlacker")
        } detail: {
            moduleContent(for: selectedModule)
                .animation(FluidAnimation.gentle, value: selectedModule)
        }
        .preferredColorScheme(.dark)
        #else
        ZStack(alignment: .top) {
            AmbientBackground().ignoresSafeArea()

            moduleContent(for: selectedModule)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
                .animation(FluidAnimation.gentle, value: selectedModule)
                .safeAreaInset(edge: .top) {
                    Color.clear.frame(height: 68)
                }

            FloatingModuleSwitcher(selectedModule: $selectedModule)
                .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        #endif
    }

    @ViewBuilder
    private func moduleContent(for module: ModuleAccent) -> some View {
        switch module {
        case .worldClock:
            WorldClockView()
        case .actions:
            ActionsListView()
        case .timepage:
            TimepageView()
        case .account:
            AccountView()
        }
    }
}

/// A floating, glass, Dynamic-Island-style tab bar hovering at the top of
/// the screen — icons only until selected, when the label slides in
/// alongside a soft gradient glow behind it.
private struct FloatingModuleSwitcher: View {
    @Binding var selectedModule: ModuleAccent
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(ModuleAccent.allCases) { module in
                let isSelected = selectedModule == module
                Button {
                    withAnimation(FluidAnimation.snappy) {
                        selectedModule = module
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: module.symbolName)
                            .font(.system(size: 16, weight: .semibold))
                        if isSelected {
                            Text(module.displayName)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                                .fixedSize()
                                .transition(.opacity.combined(with: .scale(scale: 0.7)))
                        }
                    }
                    .padding(.horizontal, isSelected ? 15 : 11)
                    .padding(.vertical, 10)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(module.gradient)
                                .matchedGeometryEffect(id: "floating-indicator", in: indicatorNamespace)
                                .shadow(color: module.color.opacity(0.7), radius: 12, y: 3)
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.4), radius: 24, y: 10)
        .padding(.horizontal, 16)
        .animation(FluidAnimation.snappy, value: selectedModule)
    }
}

#Preview {
    RootView()
}
