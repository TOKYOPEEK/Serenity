import SwiftUI

// MARK: - MoodCalendarView
struct MoodCalendarView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss

    @State private var displayedMonth: Date = {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))!
    }()
    @State private var selectedDay: Date?

    private var cal: Calendar { Calendar.current }

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                calendarHeader
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.s20) {
                        monthNavigator
                        weekdayLabels
                        calendarGrid
                        if let day = selectedDay, let entry = moodEntry(for: day) {
                            dayDetailCard(entry)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        legendCard
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, DS.s20)
                    .padding(.top, DS.s12)
                }
            }
        }
    }

    // MARK: Header
    private var calendarHeader: some View {
        SheetHeader(title: L("analytics.calendar.title"))
    }

    // MARK: Month navigator
    private var monthNavigator: some View {
        HStack {
            Button(action: { changeMonth(by: -1) }) {
                Image(systemName: "chevron.left")
                    .font(.app(size: 16, weight: .semibold))
                    .foregroundColor(DS.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            Spacer()
            Text(monthYearString)
                .font(.app(size: 18, weight: .semibold))
                .foregroundColor(DS.textPrimary)
            Spacer()
            Button(action: { changeMonth(by: 1) }) {
                Image(systemName: "chevron.right")
                    .font(.app(size: 16, weight: .semibold))
                    .foregroundColor(DS.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.white.opacity(0.06)))
            }
            .disabled(isCurrentMonth)
            .opacity(isCurrentMonth ? 0.3 : 1)
        }
    }

    // MARK: Weekday labels
    private var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(weekdayAbbreviations, id: \.self) { day in
                Text(day)
                    .font(.app(size: 11, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Calendar grid
    private var calendarGrid: some View {
        let days = daysInMonth
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days.indices, id: \.self) { idx in
                let day = days[idx]
                CalendarDayCell(
                    day: day,
                    moodEntry: moodEntry(for: day),
                    isToday: day.map { cal.isDateInToday($0) } ?? false,
                    isSelected: isSelected(day),
                    theme: appVM.selectedTheme
                )
                .onTapGesture {
                    guard let day, moodEntry(for: day) != nil else { return }
                    HapticManager.impact(.light)
                    withAnimation(DS.springSnappy) {
                        selectedDay = isSelected(day) ? nil : day
                    }
                }
            }
        }
        .padding(DS.s4)
        .background(
            RoundedRectangle(cornerRadius: DS.r20)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: DS.r20).strokeBorder(DS.strokeSubtle, lineWidth: 1))
        )
    }

    // MARK: Legend
    private var legendCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DS.s12) {
                Text(L("analytics.calendar.legend"))
                    .font(.app(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)
                HStack(spacing: DS.s16) {
                    ForEach(0..<5, id: \.self) { i in
                        HStack(spacing: DS.s6) {
                            Circle()
                                .fill(DS.moodColor(i))
                                .frame(width: 10, height: 10)
                            Text(moodShortName(i))
                                .font(.app(size: 10, design: .rounded))
                                .foregroundColor(DS.textSecondary)
                        }
                    }
                }
            }
            .padding(DS.s16)
        }
    }

    // MARK: - Helpers
    private var monthYearString: String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("yMMMM")
        return f.string(from: displayedMonth)
    }

    private var isCurrentMonth: Bool {
        cal.isDate(displayedMonth, equalTo: Date(), toGranularity: .month)
    }

    /// Weekday numbers (1=Sun…7=Sat) ordered by the user's locale, e.g. Mon-first for ru_RU.
    private var orderedWeekdays: [Int] {
        (0 ..< 7).map { ((cal.firstWeekday - 1 + $0) % 7) + 1 }
    }

    private var weekdayAbbreviations: [String] {
        orderedWeekdays.map { weekdayName($0) }
    }

    private var daysInMonth: [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = monthInterval.start
        let firstWeekday = cal.component(.weekday, from: firstDay)
        let offset = (firstWeekday - cal.firstWeekday + 7) % 7  // days to pad before the 1st

        var days: [Date?] = Array(repeating: nil, count: offset)
        let daysInMonth = cal.range(of: .day, in: .month, for: displayedMonth)!.count
        for d in 1...daysInMonth {
            if let date = cal.date(byAdding: .day, value: d - 1, to: firstDay) {
                days.append(date)
            }
        }
        // pad to complete grid rows
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private func moodEntry(for date: Date?) -> MoodEntry? {
        guard let date = date else { return nil }
        return appVM.moodEntries.first { cal.isDate($0.date, inSameDayAs: date) }
    }

    private func isSelected(_ day: Date?) -> Bool {
        guard let day, let selectedDay else { return false }
        return cal.isDate(day, inSameDayAs: selectedDay)
    }

    private func changeMonth(by value: Int) {
        withAnimation(DS.springSnappy) {
            selectedDay = nil
            if let newDate = cal.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newDate
            }
        }
    }

    // MARK: Day detail
    private func dayDetailCard(_ entry: MoodEntry) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DS.s12) {
                Text(detailDateString(entry.date))
                    .font(.app(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)

                HStack(spacing: DS.s10) {
                    MoodOrbView(moodIndex: entry.moodIndex, size: 36, isSelected: true)
                    Text(entry.moodName)
                        .font(.app(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    Spacer()
                    detailStat(label: L("checkin.energy"), value: Int(entry.energyLevel * 100))
                    detailStat(label: L("checkin.stress"), value: Int(entry.stressLevel * 100))
                }

                if !entry.tags.isEmpty {
                    FlowLayout(spacing: DS.s6) {
                        ForEach(entry.tags, id: \.self) { tag in
                            Text(localizedTag(tag))
                                .font(.app(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(DS.textSecondary)
                                .padding(.horizontal, DS.s10)
                                .padding(.vertical, DS.s4)
                                .background(
                                    Capsule().fill(appVM.selectedTheme.primaryColor.opacity(0.10))
                                        .overlay(Capsule().strokeBorder(appVM.selectedTheme.primaryColor.opacity(0.20), lineWidth: 1))
                                )
                        }
                    }
                }

                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.app(size: 13, design: .rounded))
                        .foregroundColor(DS.textSecondary)
                        .lineSpacing(3)
                }
            }
            .padding(DS.s16)
        }
    }

    private func detailStat(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)%")
                .font(.app(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(DS.textSecondary)
            Text(label)
                .font(.app(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(DS.textTertiary)
        }
        .frame(minWidth: 52)
    }

    private func detailDateString(_ date: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .long
        return f.string(from: date)
    }

    private func localizedTag(_ tag: String) -> String {
        let key = "tag.\(tag)"
        let localized = L(key)
        return localized == key ? tag : localized
    }

    private func moodShortName(_ index: Int) -> String {
        [L("mood.veryBad"), L("mood.bad"), L("mood.neutral"), L("mood.good"), L("mood.great")][index]
    }
}

// MARK: - CalendarDayCell
private struct CalendarDayCell: View {
    let day: Date?
    let moodEntry: MoodEntry?
    let isToday: Bool
    let isSelected: Bool
    let theme: AppColorTheme

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()

    private var moodColor: Color {
        guard let entry = moodEntry else { return .clear }
        return DS.moodColor(entry.moodIndex)
    }

    var body: some View {
        ZStack {
            if let day = day {
                // Background
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(moodEntry != nil
                          ? moodColor.opacity(0.22)
                          : isToday ? Color.white.opacity(0.07) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? theme.primaryColor
                                : isToday ? theme.primaryColor.opacity(0.5) : Color.clear,
                                lineWidth: isSelected ? 2 : 1.5
                            )
                    )

                VStack(spacing: 2) {
                    Text(Self.dayFormatter.string(from: day))
                        .font(.app(size: 12, weight: isToday ? .bold : .regular, design: .rounded))
                        .foregroundColor(moodEntry != nil
                                         ? .white
                                         : isToday ? theme.primaryColor : DS.textSecondary)

                    if moodEntry != nil {
                        Circle()
                            .fill(moodColor)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .frame(height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let day else { return "" }
        let dayNumber = Self.dayFormatter.string(from: day)
        if let entry = moodEntry {
            return "\(dayNumber), \(entry.moodName)"
        }
        return dayNumber
    }
}
