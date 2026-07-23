import SwiftUI
import SwiftData

struct ActionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActionItem.sortOrder) private var items: [ActionItem]

    @State private var quickAddText = ""
    @FocusState private var quickAddFocused: Bool

    private var accent: Color { ModuleAccent.actions.color }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if items.isEmpty {
                    Spacer()
                    EmptyModuleState(
                        symbolName: "checkmark.circle",
                        title: "Nothing to do",
                        subtitle: "Type below to capture your next action."
                    )
                    Spacer()
                } else {
                    List {
                        ForEach(items) { item in
                            ActionRow(item: item)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                quickAddBar
            }
            .background(AmbientBackground().ignoresSafeArea())
            .navigationTitle("Actions")
        }
    }

    private var quickAddBar: some View {
        HStack {
            TextField("Add an action…", text: $quickAddText)
                .focused($quickAddFocused)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .onSubmit(addQuickItem)

            Button(action: addQuickItem) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(accent)
            }
            .disabled(quickAddText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    private func addQuickItem() {
        let trimmed = quickAddText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        withAnimation(FluidAnimation.snappy) {
            let item = ActionItem(title: trimmed, sortOrder: items.count)
            modelContext.insert(item)
        }
        quickAddText = ""
    }

    private func delete(at offsets: IndexSet) {
        withAnimation(FluidAnimation.snappy) {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

private struct ActionRow: View {
    @Bindable var item: ActionItem

    var body: some View {
        FluidCard(accent: ModuleAccent.actions.color) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(FluidAnimation.bouncy) {
                        item.isCompleted.toggle()
                        item.completedAt = item.isCompleted ? .now : nil
                    }
                } label: {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(item.isCompleted ? ModuleAccent.actions.color : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .strikethrough(item.isCompleted)
                        .foregroundStyle(item.isCompleted ? .secondary : .primary)
                    if let dueDate = item.dueDate {
                        Text(dueDate, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }
}
