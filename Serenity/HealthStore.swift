import Foundation
import HealthKit

/// Read-only snapshot of recent Apple Health metrics, used to enrich AI
/// insights ("after short-sleep nights your mood tends to dip").
struct HealthSnapshot: Codable, Equatable {
    var avgSleepHours: Double?      // mean nightly sleep over the window
    var restingHeartRate: Double?   // mean resting HR (bpm)
    var avgSteps: Int?              // mean daily step count
    var shortSleepLowersMood: Bool? // simple signal: low-mood days follow short sleep
    var moreStepsLiftsMood: Bool?   // simple signal: high-step days have better mood
    var updated: Date = Date()

    var hasAnything: Bool {
        avgSleepHours != nil || restingHeartRate != nil || avgSteps != nil
    }
}

/// Thin wrapper over HealthKit. All reads are best-effort: missing permission
/// or no data simply yields nils, never an error the user sees.
@MainActor
final class HealthStore {
    static let isAvailable = HKHealthStore.isHealthDataAvailable()

    private let store = HKHealthStore()

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleep) }
        if let hr = HKObjectType.quantityType(forIdentifier: .restingHeartRate) { types.insert(hr) }
        if let steps = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(steps) }
        return types
    }

    /// Asks for read permission. Returns false if Health is unavailable.
    func requestAuthorization() async -> Bool {
        guard Self.isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            return true
        } catch {
            return false
        }
    }

    /// Builds a snapshot from the last `days` days. Mood entries (start-of-day
    /// keyed) let us compute the short-sleep/low-mood signal.
    func snapshot(days: Int = 14, moodByDay: [Date: Int] = [:]) async -> HealthSnapshot {
        async let sleep = nightlySleepHours(days: days)
        async let hr     = averageRestingHeartRate(days: days)
        async let steps  = dailySteps(days: days)

        let sleepByDay = await sleep
        let avgSleep = sleepByDay.isEmpty ? nil :
            sleepByDay.values.reduce(0, +) / Double(sleepByDay.count)

        let stepsByDay = await steps
        let avgSteps = stepsByDay.isEmpty ? nil :
            Int(stepsByDay.values.reduce(0, +) / Double(stepsByDay.count))

        return HealthSnapshot(
            avgSleepHours: avgSleep,
            restingHeartRate: await hr,
            avgSteps: avgSteps,
            shortSleepLowersMood: shortSleepSignal(sleepByDay: sleepByDay, moodByDay: moodByDay),
            moreStepsLiftsMood: moreStepsSignal(stepsByDay: stepsByDay, moodByDay: moodByDay)
        )
    }

    // MARK: - Sleep

    /// Hours asleep per night (keyed by the calendar day the sleep ended).
    private func nightlySleepHours(days: Int) async -> [Date: Double] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return [:] }
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }

        var perDay: [Date: Double] = [:]
        for s in samples where Self.isAsleep(s.value) {
            let day = cal.startOfDay(for: s.endDate)
            perDay[day, default: 0] += s.endDate.timeIntervalSince(s.startDate) / 3600
        }
        return perDay
    }

    private static func isAsleep(_ value: Int) -> Bool {
        if #available(iOS 16.0, *) {
            switch HKCategoryValueSleepAnalysis(rawValue: value) {
            case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: return true
            default: return false
            }
        } else {
            return value == HKCategoryValueSleepAnalysis.asleep.rawValue
        }
    }

    // MARK: - Heart rate

    private func averageRestingHeartRate(days: Int) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else { return nil }
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, stats, _ in
                let bpm = stats?.averageQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                cont.resume(returning: bpm)
            }
            store.execute(q)
        }
    }

    // MARK: - Steps

    /// Step count per calendar day over the window.
    private func dailySteps(days: Int) async -> [Date: Double] {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return [:] }
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: cal.date(byAdding: .day, value: -days, to: Date()) ?? Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDay, end: Date())

        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: startDay,
                intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, results, _ in
                var perDay: [Date: Double] = [:]
                results?.enumerateStatistics(from: startDay, to: Date()) { stat, _ in
                    if let sum = stat.sumQuantity()?.doubleValue(for: .count()), sum > 0 {
                        perDay[cal.startOfDay(for: stat.startDate)] = sum
                    }
                }
                cont.resume(returning: perDay)
            }
            store.execute(q)
        }
    }

    // MARK: - Signal

    /// True when nights with below-average sleep are followed by below-average
    /// mood — a gentle, explainable heuristic, not a clinical claim.
    private func shortSleepSignal(sleepByDay: [Date: Double], moodByDay: [Date: Int]) -> Bool? {
        let paired = sleepByDay.compactMap { day, hours -> (Double, Int)? in
            guard let mood = moodByDay[day] else { return nil }
            return (hours, mood)
        }
        guard paired.count >= 5 else { return nil }

        let avgSleep = paired.map(\.0).reduce(0, +) / Double(paired.count)
        let avgMood  = Double(paired.map(\.1).reduce(0, +)) / Double(paired.count)

        let shortNights = paired.filter { $0.0 < avgSleep }
        guard shortNights.count >= 2 else { return nil }
        let moodOnShortNights = Double(shortNights.map(\.1).reduce(0, +)) / Double(shortNights.count)

        return moodOnShortNights < avgMood - 0.25
    }

    /// True when days with above-average steps carry better-than-average mood.
    private func moreStepsSignal(stepsByDay: [Date: Double], moodByDay: [Date: Int]) -> Bool? {
        let paired = stepsByDay.compactMap { day, steps -> (Double, Int)? in
            guard let mood = moodByDay[day] else { return nil }
            return (steps, mood)
        }
        guard paired.count >= 5 else { return nil }

        let avgSteps = paired.map(\.0).reduce(0, +) / Double(paired.count)
        let avgMood  = Double(paired.map(\.1).reduce(0, +)) / Double(paired.count)

        let activeDays = paired.filter { $0.0 > avgSteps }
        guard activeDays.count >= 2 else { return nil }
        let moodOnActiveDays = Double(activeDays.map(\.1).reduce(0, +)) / Double(activeDays.count)

        return moodOnActiveDays > avgMood + 0.25
    }
}
