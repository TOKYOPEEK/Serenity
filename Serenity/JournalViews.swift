import SwiftUI

// MARK: - JournalView
struct JournalView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var showNewEntry   = false
    @State private var searchText     = ""
    @State private var selectedEntry: JournalEntry?
    @State private var entryToEdit:   JournalEntry?

    private var filtered: [JournalEntry] {
        if searchText.isEmpty { return appVM.journalEntries }
        return appVM.journalEntries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                journalNavBar
                searchBar
                Divider().background(DS.strokeSubtle)
                journalList
            }
        }
        .sheet(isPresented: $showNewEntry) {
            NewJournalEntryView(existingEntry: nil)
        }
        .sheet(item: $selectedEntry) { entry in
            JournalEntryView(entry: entry)
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $entryToEdit) { entry in
            NewJournalEntryView(existingEntry: entry)
        }
    }

    // MARK: Nav bar
    private var journalNavBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.s4) {
                Text(L("journal.title"))
                    .font(.app(size: 26, weight: .bold))
                    .foregroundColor(DS.textPrimary)
            }
            Spacer()
            Button(action: { showNewEntry = true }) {
                ZStack {
                    Circle()
                        .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "plus")
                        .font(.app(size: 14, weight: .semibold))
                        .foregroundColor(appVM.selectedTheme.primaryColor)
                }
            }
            .accessibilityLabel(L("journal.new_entry"))
        }
        .padding(.horizontal, DS.s20)
        .padding(.top, DS.s16)
        .padding(.bottom, DS.s12)
    }

    // MARK: Search
    private var searchBar: some View {
        HStack(spacing: DS.s10) {
            Image(systemName: "magnifyingglass")
                .font(.app(size: 14))
                .foregroundColor(DS.textTertiary)
            TextField(L("journal.search"), text: $searchText)
                .font(.app(size: 14, design: .rounded))
                .foregroundColor(DS.textPrimary)
                .tint(appVM.selectedTheme.primaryColor)
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.app(size: 14))
                        .foregroundColor(DS.textTertiary)
                }
                .accessibilityLabel(L("common.clear"))
            }
        }
        .padding(.horizontal, DS.s14)
        .padding(.vertical, DS.s10)
        .background(
            RoundedRectangle(cornerRadius: DS.r12, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: DS.r12).strokeBorder(DS.strokeSubtle, lineWidth: 1))
        )
        .padding(.horizontal, DS.s20)
        .padding(.bottom, DS.s8)
    }

    // MARK: List
    private var journalList: some View {
        Group {
            if filtered.isEmpty {
                EmptyStateView(icon: "book.closed.fill", title: L("journal.empty.title"), subtitle: L("journal.empty.subtitle"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filtered) { entry in
                        JournalRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                HapticManager.impact(.light)
                                selectedEntry = entry
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation { appVM.deleteJournalEntry(entry) }
                                } label: {
                                    Label(L("common.delete"), systemImage: "trash.fill")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    entryToEdit = entry
                                } label: {
                                    Label(L("common.edit"), systemImage: "pencil")
                                }
                                .tint(appVM.selectedTheme.primaryColor)
                            }
                            .contextMenu {
                                Button {
                                    entryToEdit = entry
                                } label: {
                                    Label(L("common.edit"), systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    withAnimation { appVM.deleteJournalEntry(entry) }
                                } label: {
                                    Label(L("common.delete"), systemImage: "trash.fill")
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: DS.s6, leading: DS.s20, bottom: DS.s6, trailing: DS.s20))
                    }
                    Color.clear
                        .frame(height: 96)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .padding(.top, DS.s10)
            }
        }
    }
}

// MARK: - JournalRow
struct JournalRow: View {
    @EnvironmentObject var appVM: AppViewModel
    let entry: JournalEntry

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("d"); return f
    }()
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("MMM"); return f
    }()

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: DS.s14) {
                VStack(spacing: DS.s2) {
                    Text(Self.dayFormatter.string(from: entry.date))
                        .font(.app(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(appVM.selectedTheme.gradient)
                    Text(Self.monthFormatter.string(from: entry.date))
                        .font(.app(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                }
                .frame(width: 36)

                VStack(alignment: .leading, spacing: DS.s6) {
                    Text(entry.title.isEmpty ? L("journal.untitled") : entry.title)
                        .font(.app(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                        .lineLimit(1)
                    Text(entry.content)
                        .font(.app(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                        .lineLimit(2)
                        .lineSpacing(2)
                }

                Spacer()

                if let mood = entry.mood {
                    MoodOrbView(moodIndex: mood, size: 22, isSelected: false)
                }
            }
            .padding(DS.s16)
        }
    }
}

// MARK: - JournalEntryView (read)
struct JournalEntryView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss
    let entry: JournalEntry

    @State private var showEdit          = false
    @State private var showDeleteConfirm = false

    // Always reflect the latest version after an edit
    private var currentEntry: JournalEntry {
        appVM.journalEntries.first { $0.id == entry.id } ?? entry
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                entryHeader
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.s20) {
                        Text(currentEntry.title.isEmpty ? L("journal.untitled") : currentEntry.title)
                            .font(Font.custom("Georgia", size: 22, relativeTo: .title2).bold())
                            .foregroundColor(DS.textPrimary)

                        Text(formattedDate)
                            .font(.app(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textTertiary)

                        Divider().background(DS.strokeSubtle)

                        Text(currentEntry.content)
                            .font(.app(size: 15, weight: .regular, design: .rounded))
                            .foregroundColor(DS.textSecondary)
                            .lineSpacing(7)
                    }
                    .padding(DS.s24)
                    Spacer(minLength: 60)
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            NewJournalEntryView(existingEntry: currentEntry)
        }
        .confirmationDialog(L("journal.delete.confirm.title"), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(L("common.delete"), role: .destructive) {
                appVM.deleteJournalEntry(currentEntry)
                dismiss()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("journal.delete.confirm.body"))
        }
    }

    private var entryHeader: some View {
        HStack {
            Button(action: { dismiss() }) {
                HStack(spacing: DS.s4) {
                    Image(systemName: "chevron.left")
                        .font(.app(size: 14, weight: .medium))
                    Text(L("journal.title"))
                        .font(.app(size: 14, weight: .medium, design: .rounded))
                }
                .foregroundColor(DS.textSecondary)
            }
            Spacer()
            Menu {
                Button {
                    showEdit = true
                } label: {
                    Label(L("common.edit"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(L("common.delete"), systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.app(size: 17, weight: .medium))
                    .foregroundColor(DS.textSecondary)
            }
            .accessibilityLabel(L("common.edit"))
        }
        .padding(DS.s20)
    }

    private var formattedDate: String {
        let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .short
        return f.string(from: currentEntry.date)
    }
}

// MARK: - NewJournalEntryView (create & edit)
struct NewJournalEntryView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss

    let existingEntry: JournalEntry?

    @State private var title   = ""
    @State private var content = ""
    @State private var mood: Int?
    @State private var showDiscardDialog = false

    private var isEditing: Bool { existingEntry != nil }
    private var wordCount: Int { content.split(separator: " ").count }
    private var charCount: Int { content.count }

    private var hasUnsavedChanges: Bool {
        if let entry = existingEntry {
            let originalTitle = entry.title == L("journal.untitled") ? "" : entry.title
            return title != originalTitle || content != entry.content || mood != entry.mood
        }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || mood != nil
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                newEntryHeader
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s16) {
                        titleField
                        contentField
                        counterRow
                        moodPicker
                        PrimaryButton(title: L("common.save")) { saveEntry() }
                        Spacer(minLength: 80)
                    }
                    .padding(DS.s24)
                }
            }
        }
        .onAppear {
            if let entry = existingEntry {
                title   = entry.title == L("journal.untitled") ? "" : entry.title
                content = entry.content
                mood    = entry.mood
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .confirmationDialog(L("journal.discard.title"), isPresented: $showDiscardDialog, titleVisibility: .visible) {
            Button(L("journal.discard.confirm"), role: .destructive) { dismiss() }
            Button(L("common.cancel"), role: .cancel) {}
        }
    }

    private var newEntryHeader: some View {
        SheetHeader(
            title: isEditing ? L("journal.edit_entry") : L("journal.new_entry"),
            onClose: {
                if hasUnsavedChanges {
                    showDiscardDialog = true
                } else {
                    dismiss()
                }
            }
        )
    }

    private var titleField: some View {
        GlassCard {
            TextField(L("journal.title_placeholder"), text: $title)
                .font(.app(size: 18, weight: .semibold))
                .foregroundColor(DS.textPrimary)
                .tint(appVM.selectedTheme.primaryColor)
                .padding(DS.s16)
        }
    }

    private var contentField: some View {
        GlassCard {
            TextField(L("journal.content_placeholder"), text: $content, axis: .vertical)
                .lineLimit(6...20)
                .font(.app(size: 15, design: .rounded))
                .foregroundColor(DS.textPrimary)
                .tint(appVM.selectedTheme.primaryColor)
                .padding(DS.s16)
        }
    }

    private var counterRow: some View {
        HStack {
            Spacer()
            Text("\(wordCount) \(L("journal.words")) · \(charCount) \(L("journal.chars"))")
                .font(.app(size: 11, design: .rounded))
                .foregroundColor(DS.textTertiary)
        }
        .padding(.horizontal, DS.s4)
    }

    private var moodPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DS.s12) {
                Text(L("journal.mood_optional"))
                    .font(.app(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                HStack(spacing: DS.s16) {
                    ForEach(0 ..< 5, id: \.self) { i in
                        Button(action: {
                            HapticManager.impact(.light)
                            mood = (mood == i) ? nil : i
                        }) {
                            MoodOrbView(moodIndex: i, size: 36, isSelected: mood == i)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(DS.s16)
        }
    }

    private func saveEntry() {
        let finalTitle = title.isEmpty ? L("journal.untitled") : title
        if isEditing, var updated = existingEntry {
            updated.title   = finalTitle
            updated.content = content
            updated.mood    = mood
            appVM.updateJournalEntry(updated)
        } else {
            let entry = JournalEntry(title: finalTitle, content: content, mood: mood)
            appVM.addJournalEntry(entry)
        }
        dismiss()
    }
}
