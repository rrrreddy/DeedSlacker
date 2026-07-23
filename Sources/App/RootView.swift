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
        ZStack(alignment: .bottom) {
            Theme.backgroundGradient.ignoresSafeArea()

            moduleContent(for: selectedModule)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
                .animation(FluidAnimation.gentle, value: selectedModule)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 74)
                }

            FloatingModuleSwitcher(selectedModule: $selectedModule)
                .padding(.bottom, 12)
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
        case .flow:
            FlowListView()
        case .timepage:
            TimepageView()
        }
    }
}

/// A floating, glass, Dynamic-Island-style tab bar that hovers above the
/// content instead of docking flush with the screen edge.
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
                    VStack(spacing: 3) {
                        Image(systemName: module.symbolName)
                            .font(.system(size: 18, weight: .semibold))
                            .symbolVariant(isSelected ? .fill : .none)
                        if isSelected {
                            Text(module.displayName)
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .fixedSize()
                                .transition(.opacity.combined(with: .scale(scale: 0.7)))
                        }
                    }
                    .padding(.horizontal, isSelected ? 16 : 12)
                    .padding(.vertical, 12)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(module.color.opacity(0.9))
                                .matchedGeometryEffect(id: "floating-indicator", in: indicatorNamespace)
                                .shadow(color: module.color.opacity(0.6), radius: 10, y: 3)
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 20, y: 10)
        .padding(.horizontal, 20)
        .animation(FluidAnimation.snappy, value: selectedModule)
    }
}

#Preview {
    RootView()
}
