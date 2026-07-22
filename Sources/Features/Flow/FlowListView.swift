import SwiftUI
import SwiftData

struct FlowListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FlowAutomation.createdAt) private var automations: [FlowAutomation]

    @State private var isPresentingEditor = false

    var body: some View {
        NavigationStack {
            Group {
                if automations.isEmpty {
                    EmptyModuleState(
                        symbolName: "arrow.triangle.branch",
                        title: "No automations yet",
                        subtitle: "Create a flow that reacts to a trigger with an action."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(automations) { automation in
                                FluidCard(accent: ModuleAccent.flow.color) {
                                    AutomationRow(automation: automation)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Flow")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isPresentingEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $isPresentingEditor) {
                FlowEditorSheet()
            }
        }
    }
}

private struct AutomationRow: View {
    @Bindable var automation: FlowAutomation

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(automation.name)
                    .font(.headline)
                HStack(spacing: 6) {
                    Label(automation.trigger.displayName, systemImage: "bolt.fill")
                    Image(systemName: "arrow.right")
                    Label(automation.action.displayName, systemImage: "play.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $automation.isEnabled)
                .labelsHidden()
                .tint(ModuleAccent.flow.color)
        }
    }
}

private struct FlowEditorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var trigger: FlowTriggerType = .timeOfDay
    @State private var action: FlowActionType = .sendNotification

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Automation name", text: $name)
                }
                Section("When") {
                    Picker("Trigger", selection: $trigger) {
                        ForEach(FlowTriggerType.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Then") {
                    Picker("Action", selection: $action) {
                        ForEach(FlowActionType.allCases) { Text($0.displayName).tag($0) }
                    }
                }
            }
            .navigationTitle("New Flow")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let automation = FlowAutomation(name: name, trigger: trigger, action: action)
        modelContext.insert(automation)
        dismiss()
    }
}
