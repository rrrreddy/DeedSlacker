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
        #else
        VStack(spacing: 0) {
            ModuleSwitcher(selectedModule: $selectedModule)
                .padding(.top, 8)

            moduleContent(for: selectedModule)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.98)),
                    removal: .opacity
                ))
                .animation(FluidAnimation.gentle, value: selectedModule)
        }
        .background(Theme.backgroundGradient.ignoresSafeArea())
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

/// A pill-shaped, spring-animated module switcher — the horizontal
/// equivalent of Timepage's fluid tab bar.
private struct ModuleSwitcher: View {
    @Binding var selectedModule: ModuleAccent
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ModuleAccent.allCases) { module in
                Button {
                    withAnimation(FluidAnimation.snappy) {
                        selectedModule = module
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: module.symbolName)
                            .font(.system(size: 18, weight: .semibold))
                        Text(module.displayName)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selectedModule == module {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(module.color.opacity(0.22))
                                .matchedGeometryEffect(id: "indicator", in: indicatorNamespace)
                        }
                    }
                    .foregroundStyle(selectedModule == module ? module.color : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal)
    }
}

#Preview {
    RootView()
}
