import SwiftUI
import Contacts

/// A trimmed-down, `Identifiable`, `Sendable` view of a device contact —
/// keeps SwiftUI code from holding onto `CNContact` (a non-Sendable
/// Objective-C class) across actor boundaries.
struct PickerContact: Identifiable, Equatable {
    let id: String
    let name: String
    let thumbnailData: Data?

    /// Up to two uppercase letters (first name + last name) used when
    /// there's no photo — every contact is pinnable, not just ones with
    /// a picture.
    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first }.map(String.init)
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }
}

/// Thin wrapper over the Contacts framework. Deliberately local-only —
/// this pins a device contact's name/photo to a city card, it does not
/// share anyone's location.
enum ContactsService {
    static func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    /// All contacts, photo or not — a contact without a picture still
    /// gets an initials avatar, so nothing is filtered out here. Runs off
    /// the main actor: `CNContactStore` enumeration is a blocking, synchronous
    /// call and must never happen directly inside a SwiftUI `.task`.
    static func fetchContacts() async -> [PickerContact] {
        await Task.detached(priority: .userInitiated) {
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var results: [PickerContact] = []
            try? CNContactStore().enumerateContacts(with: request) { contact, _ in
                let fullName = [contact.givenName, contact.familyName]
                    .filter { !$0.isEmpty }
                    .joined(separator: " ")
                guard !fullName.isEmpty else { return }
                results.append(PickerContact(id: contact.identifier, name: fullName, thumbnailData: contact.thumbnailImageData))
            }
            return results.sorted { $0.name < $1.name }
        }.value
    }

    static func contact(forIdentifier identifier: String) async -> PickerContact? {
        await Task.detached(priority: .utility) {
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            guard let contact = try? CNContactStore().unifiedContact(withIdentifier: identifier, keysToFetch: keys) else {
                return nil
            }
            let fullName = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return PickerContact(id: contact.identifier, name: fullName, thumbnailData: contact.thumbnailImageData)
        }.value
    }
}

/// The "shelf" drawer described in the spec: a semi-transparent overlay
/// listing contacts from the device address book, tap to select/deselect
/// with a glowing green checkmark.
struct ContactPickerSheet: View {
    @Bindable var zone: TrackedTimeZone
    @Environment(\.dismiss) private var dismiss

    @State private var contacts: [PickerContact] = []
    @State private var selectedIDs: Set<String> = []
    @State private var accessDenied = false
    @State private var isLoading = true
    @State private var searchText = ""

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 16)]

    private var filteredContacts: [PickerContact] {
        guard !searchText.isEmpty else { return contacts }
        return contacts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if accessDenied {
                    EmptyModuleState(
                        symbolName: "person.crop.circle.badge.exclamationmark",
                        title: "Contacts access needed",
                        subtitle: "Enable Contacts access in Settings to pin people to this city."
                    )
                } else if isLoading {
                    ProgressView("Loading contacts…").padding()
                } else if contacts.isEmpty {
                    EmptyModuleState(
                        symbolName: "person.crop.circle.badge.questionmark",
                        title: "No contacts found",
                        subtitle: "Add someone to Contacts first, then come back to pin them here."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredContacts) { contact in
                                ContactAvatarButton(
                                    contact: contact,
                                    isSelected: selectedIDs.contains(contact.id)
                                ) {
                                    withAnimation(FluidAnimation.bouncy) {
                                        if selectedIDs.contains(contact.id) {
                                            selectedIDs.remove(contact.id)
                                        } else {
                                            selectedIDs.insert(contact.id)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $searchText, prompt: "Search contacts")
                }
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Pin a Contact")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        zone.pinnedContactIdentifiers = Array(selectedIDs)
                        dismiss()
                    }
                }
            }
            .task {
                selectedIDs = Set(zone.pinnedContactIdentifiers)
                guard await ContactsService.requestAccess() else {
                    accessDenied = true
                    isLoading = false
                    return
                }
                contacts = await ContactsService.fetchContacts()
                isLoading = false
            }
        }
    }
}

private struct ContactAvatarButton: View {
    let contact: PickerContact
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomTrailing) {
                    ContactThumbnailImage(data: contact.thumbnailData, initials: contact.initials, size: 64)
                        .overlay(Circle().strokeBorder(isSelected ? TradingPalette.up : .clear, lineWidth: 3))

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.white, TradingPalette.up)
                            .shadow(color: TradingPalette.up.opacity(0.8), radius: 4)
                    }
                }
                Text(contact.name)
                    .font(Typography.caption)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1)
        .animation(FluidAnimation.snappy, value: isSelected)
    }
}

/// A contact avatar that falls back to a colored initials badge when
/// there's no photo, so every contact — not just ones with a picture —
/// is fully usable across the picker and the arc.
struct ContactThumbnailImage: View {
    let data: Data?
    let initials: String
    let size: CGFloat

    private var initialsBackground: LinearGradient {
        let seed = initials.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let palettes: [[Color]] = [
            [Color(hex: "#8C5CFF"), Color(hex: "#3AA6FF")],
            [Color(hex: "#FF6B4A"), Color(hex: "#FFB86B")],
            [Color(hex: "#2FCE8F"), Color(hex: "#3AA6FF")],
            [Color(hex: "#FF5F9E"), Color(hex: "#8C5CFF")]
        ]
        return LinearGradient(colors: palettes[seed % palettes.count], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        Group {
            if let data, let image = platformImage(from: data) {
                image.resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Circle().fill(initialsBackground)
                    Text(initials)
                        .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(iOS)
        UIImage(data: data).map(Image.init(uiImage:))
        #else
        NSImage(data: data).map(Image.init(nsImage:))
        #endif
    }
}

#if os(iOS)
import UIKit
#else
import AppKit
#endif
