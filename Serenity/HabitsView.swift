import SwiftUI

// MARK: - HabitsView (#48 — manage habits)
/// Create and remove habits. Daily check-off happens on the Home section;
/// here the user shapes their list and picks an icon.
struct HabitsView: View {
    @EnvironmentObject var appVM: AppViewModel
    @State private var newName = ""
    @State private var newIcon = Habit.iconChoices.first ?? "checkmark.circle.fill"
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            AmbientBackground()
            VStack(spacing: 0) {
                SheetHeader(title: L("habits.title"))
                Divider().background(DS.strokeSubtle)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: DS.s16) {
                        Text(L("habits.subtitle"))
                            .font(.app(size: 14, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)

                        ForEach(appVM.habits) { habit in
                            habitRow(habit)
                        }

                        addCard
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, DS.s20)
                    .padding(.top, DS.s16)
                }
            }
        }
    }

    private func habitRow(_ habit: Habit) -> some View {
        GlassCard {
            HStack(spacing: DS.s14) {
                Image(systemName: habit.icon)
                    .font(.app(size: 18))
                    .foregroundColor(appVM.selectedTheme.primaryColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(habit.name)
                        .font(.app(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                    if habit.streak > 0 {
                        Text(String(format: L("habits.streak"), habit.streak))
                            .font(.app(size: 11, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                Button(action: {
                    HapticManager.impact(.light)
                    appVM.deleteHabit(habit)
                }) {
                    Image(systemName: "trash")
                        .font(.app(size: 13))
                        .foregroundColor(DS.textTertiary)
                }
                .accessibilityLabel(L("common.delete"))
            }
            .padding(.horizontal, DS.s16)
            .padding(.vertical, DS.s12)
        }
    }

    private var addCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: DS.s14) {
                Text(L("habits.add"))
                    .font(.app(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(DS.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.s10) {
                        ForEach(Habit.iconChoices, id: \.self) { icon in
                            Button(action: { HapticManager.impact(.light); newIcon = icon }) {
                                Image(systemName: icon)
                                    .font(.app(size: 18))
                                    .foregroundColor(newIcon == icon ? .white : DS.textSecondary)
                                    .frame(width: 42, height: 42)
                                    .background(Circle().fill(newIcon == icon
                                        ? appVM.selectedTheme.primaryColor
                                        : Color.white.opacity(0.06)))
                            }
                        }
                    }
                    .padding(.vertical, DS.s2)
                }

                HStack(spacing: DS.s10) {
                    TextField(L("habits.placeholder"), text: $newName)
                        .font(.app(size: 15, design: .rounded))
                        .foregroundColor(DS.textPrimary)
                        .tint(appVM.selectedTheme.primaryColor)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(addHabit)
                        .padding(.horizontal, DS.s14).padding(.vertical, DS.s12)
                        .background(RoundedRectangle(cornerRadius: DS.r12).fill(Color.white.opacity(0.06))
                            .overlay(RoundedRectangle(cornerRadius: DS.r12).strokeBorder(DS.strokeSubtle, lineWidth: 1)))
                    Button(action: addHabit) {
                        Image(systemName: "plus")
                            .font(.app(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(appVM.selectedTheme.primaryColor))
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(DS.s16)
        }
    }

    private func addHabit() {
        appVM.addHabit(name: newName, icon: newIcon)
        newName = ""
        nameFocused = false
    }
}
