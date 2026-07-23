import SwiftUI
import Contacts

/// A trimmed-down, `Identifiable`, `Sendable` view of a device contact —
/// keeps SwiftUI code from holding onto `CNContact` (a non-Sendable
/// Objective-C class) across actor boundaries.
struct PickerContact: Identifiable, Equatable {
    let id: String
    let name: String
    let thumbnailData: Data?
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

    /// Contacts with a photo only, per the "photo-contacts filter" spec —
    /// an unlabeled avatar picker isn't useful for this feature. Runs off
    /// the main actor: `CNContactStore` enumeration is a blocking, synchronous
    /// call and must never happen directly inside a SwiftUI `.task`.
    static func fetchPhotoContacts() async -> [PickerContact] {
        await Task.detached(priority: .userInitiated) {
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var results: [PickerContact] = []
            try? CNContactStore().enumerateContacts(with: request) { contact, _ in
                guard let thumbnail = contact.thumbnailImageData else { return }
                results.append(PickerContact(id: contact.identifier, name: contact.givenName, thumbnailData: thumbnail))
            }
            return results.sorted { $0.name < $1.name }
        }.value
    }

    static func contact(forIdentifier identifier: String) async -> PickerContact? {
        await Task.detached(priority: .utility) {
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactThumbnailImageDataKey as CNKeyDescriptor
            ]
            guard let contact = try? CNContactStore().unifiedContact(withIdentifier: identifier, keysToFetch: keys) else {
                return nil
            }
            return PickerContact(id: contact.identifier, name: contact.givenName, thumbnailData: contact.thumbnailImageData)
        }.value
    }
}

/// The "shelf" drawer described in the spec: a semi-transparent overlay
/// listing photo-contacts from the device address book, tap to
/// select/deselect with a glowing green checkmark.
struct ContactPickerSheet: View {
    @Bindable var zone: TrackedTimeZone
    @Environment(\.dismiss) private var dismiss

    @State private var contacts: [PickerContact] = []
    @State private var selectedIDs: Set<String> = []
    @State private var accessDenied = false
    @State private var isLoading = true

    private let columns = [GridItem(.adaptive(minimum: 84), spacing: 16)]

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
                        title: "No photo contacts found",
                        subtitle: "Add a photo to a contact in the Contacts app first — only contacts with a photo show up here."
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(contacts) { contact in
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
                }
            }
            .background(Theme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Pin Local Contact")
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
                contacts = await ContactsService.fetchPhotoContacts()
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
                    ContactThumbnailImage(data: contact.thumbnailData, size: 64)
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

private struct ContactThumbnailImage: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        Group {
            #if os(iOS)
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage).resizable()
            } else {
                Circle().fill(.gray.opacity(0.4))
            }
            #else
            if let data, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage).resizable()
            } else {
                Circle().fill(.gray.opacity(0.4))
            }
            #endif
        }
        .aspectRatio(contentMode: .fill)
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// The overlapping-avatars cluster shown on a city card, plus the count
/// label and "Pin Local Contact" entry point.
struct PinnedContactsCluster: View {
    let zone: TrackedTimeZone
    let onManage: () -> Void

    @State private var contacts: [PickerContact] = []

    var body: some View {
        Button(action: onManage) {
            HStack(spacing: 8) {
                if contacts.isEmpty {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 13))
                    Text("Pin a contact")
                        .font(Typography.caption)
                } else {
                    HStack(spacing: -10) {
                        ForEach(contacts.prefix(4)) { contact in
                            ContactThumbnailImage(data: contact.thumbnailData, size: 26)
                                .overlay(Circle().strokeBorder(.black.opacity(0.4), lineWidth: 1.5))
                        }
                    }
                    Text("\(contacts.count)")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .task(id: zone.pinnedContactIdentifiers) {
            var loaded: [PickerContact] = []
            for identifier in zone.pinnedContactIdentifiers {
                if let contact = await ContactsService.contact(forIdentifier: identifier) {
                    loaded.append(contact)
                }
            }
            contacts = loaded
        }
    }
}
