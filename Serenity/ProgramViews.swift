import SwiftUI

// MARK: - ProgramsView (catalog, presented as a sheet from Home)
struct ProgramsView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedProgram: WellnessProgram?

    var body: some View {
        ZStack {
            AmbientBackground()
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.s20) {
                    programsHeader
                    activeSection
                    availableSection
                    Spacer(minLength: DS.s40)
                }
                .padding(.horizontal, DS.s20)
                .padding(.top, DS.s8)
            }
        }
        .sheet(item: $selectedProgram) { prog in
            ProgramDetailView(programId: prog.id)
                .presentationDragIndicator(.visible)
        }
    }

    private var programsHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.s4) {
                Text(L("programs.title"))
                    .font(.app(size: 26, weight: .bold))
                    .foregroundColor(DS.textPrimary)
                Text(L("programs.subtitle"))
                    .font(.app(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textTertiary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.app(size: 15, weight: .medium))
                    .foregroundColor(DS.textSecondary)
                    .accessibilityLabel(L("common.close"))
            }
            .padding(.top, DS.s6)
        }
        .padding(.top, DS.s16)
    }

    private var activeSection: some View {
        let active = appVM.programs.filter { $0.isActive }
        return Group {
            if !active.isEmpty {
                VStack(alignment: .leading, spacing: DS.s12) {
                    SectionHeader(title: L("programs.active"))
                    ForEach(active) { prog in
                        ActiveFullCard(program: prog) { selectedProgram = prog }
                    }
                }
            }
        }
    }

    private var availableSection: some View {
        let available = appVM.programs.filter { !$0.isActive }
        return VStack(alignment: .leading, spacing: DS.s12) {
            if !available.isEmpty {
                SectionHeader(title: L("programs.available"))
                ForEach(available) { prog in
                    ProgramCard(program: prog) { selectedProgram = prog }
                }
            }
        }
    }
}

// MARK: - ProgramCard
struct ProgramCard: View {
    @EnvironmentObject var appVM: AppViewModel
    let program: WellnessProgram
    let onTap: () -> Void

    var body: some View {
        Button(action: { HapticManager.impact(.light); onTap() }) {
            GlassCard {
                HStack(spacing: DS.s16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.r16, style: .continuous)
                            .fill(LinearGradient(
                                colors: [categoryColor.opacity(0.30), categoryColor.opacity(0.10)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 52, height: 52)
                        Image(systemName: program.category.icon)
                            .font(.app(size: 22))
                            .foregroundColor(categoryColor)
                    }
                    VStack(alignment: .leading, spacing: DS.s6) {
                        Text(program.localizedName)
                            .font(.app(size: 15, weight: .semibold))
                            .foregroundColor(DS.textPrimary)
                        Text(program.localizedDescription)
                            .font(.app(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                            .lineLimit(2)
                        HStack(spacing: DS.s4) {
                            Image(systemName: "calendar").font(.app(size: 10)).foregroundColor(DS.textTertiary)
                            Text("\(program.duration) \(L("programs.days"))")
                                .font(.app(size: 11, weight: .medium, design: .rounded))
                                .foregroundColor(DS.textTertiary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.app(size: 12, weight: .medium))
                        .foregroundColor(DS.textTertiary)
                }
                .padding(DS.s16)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private var categoryColor: Color {
        switch program.category {
        case .calm:   return appVM.selectedTheme.primaryColor
        case .energy: return Color(hex: "FBBF24")
        case .stress: return Color(hex: "34D399")
        }
    }
}

// MARK: - ActiveFullCard
private struct ActiveFullCard: View {
    @EnvironmentObject var appVM: AppViewModel
    let program: WellnessProgram
    let onTap: () -> Void

    private var progress: Double {
        guard program.duration > 0 else { return 0 }
        return Double(program.currentDay) / Double(program.duration)
    }

    var body: some View {
        Button(action: { HapticManager.impact(.light); onTap() }) {
            GlassCard {
                VStack(spacing: DS.s14) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.r12, style: .continuous)
                                .fill(appVM.selectedTheme.primaryColor.opacity(0.15))
                                .frame(width: 36, height: 36)
                            Image(systemName: program.category.icon)
                                .font(.app(size: 16))
                                .foregroundColor(appVM.selectedTheme.primaryColor)
                        }
                        Text(program.localizedName)
                            .font(.app(size: 15, weight: .semibold))
                            .foregroundColor(DS.textPrimary)
                        Spacer()
                        Text(String(format: L("programs.day_format"), program.currentDay, program.duration))
                            .font(.app(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(DS.textTertiary)
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.08)).frame(height: 5)
                            Capsule()
                                .fill(appVM.selectedTheme.gradient)
                                .frame(width: geo.size.width * CGFloat(progress), height: 5)
                        }
                    }
                    .frame(height: 5)

                    Text(String(format: L("programs.progress_format"), Int(progress * 100)))
                        .font(.app(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(DS.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(DS.s16)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

// MARK: - ProgramDetailView
struct ProgramDetailView: View {
    @EnvironmentObject var appVM: AppViewModel
    @Environment(\.dismiss) var dismiss
    let programId: String
    @State private var showExercise   = false
    @State private var exerciseToShow = ""
    @State private var showResetAlert = false

    private var program: WellnessProgram? {
        appVM.programs.first { $0.id == programId }
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            Group {
                if let prog = program {
                    VStack(spacing: 0) {
                        detailHeader(prog)
                        Divider().background(DS.strokeSubtle)
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: DS.s16) {
                                programInfoCard(prog)
                                tasksList(prog)
                                actionButtons(prog)
                                Spacer(minLength: 100)
                            }
                            .padding(.horizontal, DS.s20)
                            .padding(.top, DS.s16)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showExercise) {
            ExerciseDetailView(exerciseId: exerciseToShow)
                .presentationDragIndicator(.visible)
        }
        .alert(L("programs.reset.confirm.title"), isPresented: $showResetAlert) {
            Button(L("programs.reset"), role: .destructive) {
                appVM.resetProgram(programId)
                dismiss()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(L("programs.reset.confirm.body"))
        }
    }

    private func detailHeader(_ prog: WellnessProgram) -> some View {
        SheetHeader(title: prog.localizedName) {
            if prog.isActive {
                Button(action: { showResetAlert = true }) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.app(size: 14))
                        .foregroundColor(DS.textTertiary)
                }
                .accessibilityLabel(L("programs.reset"))
            }
        }
    }

    private func programInfoCard(_ prog: WellnessProgram) -> some View {
        GlassCard {
            VStack(spacing: DS.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.r20, style: .continuous)
                        .fill(LinearGradient(
                            colors: [appVM.selectedTheme.primaryColor.opacity(0.25), appVM.selectedTheme.secondaryColor.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .frame(width: 64, height: 64)
                    Image(systemName: prog.category.icon)
                        .font(.app(size: 28))
                        .foregroundStyle(appVM.selectedTheme.gradient)
                }
                Text(prog.localizedName)
                    .font(.app(size: 20, weight: .semibold))
                    .foregroundColor(DS.textPrimary)
                Text(prog.localizedDescription)
                    .font(.app(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                HStack(spacing: DS.s24) {
                    InfoBit(icon: "calendar", text: "\(prog.duration) \(L("programs.days"))")
                    InfoBit(icon: "tag.fill",  text: prog.category.displayName)
                }
            }
            .padding(DS.s20)
        }
    }

    private func tasksList(_ prog: WellnessProgram) -> some View {
        VStack(alignment: .leading, spacing: DS.s12) {
            SectionHeader(title: L("programs.daily_tasks"))
            ForEach(prog.tasks) { task in
                ProgramTaskRow(task: task, program: prog) {
                    completeTask(task, program: prog)
                } onExercise: {
                    if let exId = task.exerciseId {
                        exerciseToShow = exId
                        showExercise   = true
                    }
                }
            }
        }
    }

    private func actionButtons(_ prog: WellnessProgram) -> some View {
        VStack(spacing: DS.s12) {
            if !prog.isActive {
                PrimaryButton(title: L("programs.start")) {
                    appVM.startProgram(prog.id)
                    HapticManager.notification(.success)
                }
            } else if prog.currentDay >= prog.duration {
                SecondaryButton(title: L("programs.reset")) { showResetAlert = true }
            }
        }
    }

    private func completeTask(_ task: ProgramTask, program: WellnessProgram) {
        appVM.completeProgramTask(programId: program.id, taskId: task.id)
        HapticManager.notification(.success)
    }
}

// MARK: - ProgramTaskRow
struct ProgramTaskRow: View {
    @EnvironmentObject var appVM: AppViewModel
    let task: ProgramTask
    let program: WellnessProgram
    let onComplete: () -> Void
    let onExercise: () -> Void

    private var isLocked: Bool { task.day > program.currentDay + 1 }

    var body: some View {
        GlassCard(level: isLocked ? .subtle : .card) {
            HStack(spacing: DS.s14) {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.r12, style: .continuous)
                        .fill(task.isCompleted
                              ? appVM.selectedTheme.primaryColor.opacity(0.20)
                              : isLocked ? Color.white.opacity(0.04) : Color.white.opacity(0.08))
                        .frame(width: 36, height: 36)
                    if task.isCompleted {
                        Image(systemName: "checkmark").font(.app(size: 13, weight: .bold)).foregroundColor(appVM.selectedTheme.primaryColor)
                    } else if isLocked {
                        Image(systemName: "lock.fill").font(.app(size: 11)).foregroundColor(DS.textTertiary)
                    } else {
                        Text("\(task.day)").font(.app(size: 12, weight: .semibold, design: .rounded)).foregroundColor(DS.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: DS.s4) {
                    Text(task.localizedTitle)
                        .font(.app(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(isLocked ? DS.textTertiary : DS.textPrimary)
                    Text(task.localizedDescription)
                        .font(.app(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(isLocked ? DS.textTertiary : DS.textSecondary)
                        .lineLimit(2).lineSpacing(2)
                }

                Spacer()

                VStack(spacing: DS.s6) {
                    if !task.isCompleted && !isLocked {
                        Button(action: { HapticManager.impact(.medium); onComplete() }) {
                            Image(systemName: "checkmark.circle").font(.app(size: 20)).foregroundColor(appVM.selectedTheme.primaryColor)
                        }
                    }
                    if task.exerciseId != nil && !isLocked {
                        Button(action: onExercise) {
                            Image(systemName: "play.circle.fill").font(.app(size: 20)).foregroundColor(appVM.selectedTheme.secondaryColor)
                        }
                    }
                }
            }
            .padding(DS.s16)
        }
        .opacity(isLocked ? 0.45 : 1.0)
    }
}

// MARK: - InfoBit
private struct InfoBit: View {
    @EnvironmentObject var appVM: AppViewModel
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: DS.s6) {
            Image(systemName: icon).font(.app(size: 11)).foregroundColor(appVM.selectedTheme.primaryColor)
            Text(text).font(.app(size: 12, weight: .medium, design: .rounded)).foregroundColor(DS.textSecondary)
        }
    }
}
