// BackgroundRefresh.swift — FR-NOT-02 · the off-session half of the earned-
// attention micro-loop (BGAppRefreshTask).
//
// WHAT THIS HONESTLY IS
// iOS decides if and when a BGAppRefreshTask runs. It is opportunistic: it
// learns when the person actually opens the app and tends to wake it near those
// times, and it does not run at all while the device is in Low Power Mode, is
// short of battery, or has had Background App Refresh switched off in iOS
// Settings. So this loop CANNOT promise a daily alert.
//
// It was still worth building, because every way it fails is SILENCE:
//   • never woken               → no alert.
//   • woken while locked        → HealthKit and the file-protected context store
//                                 are both unreadable, so we do nothing and hand
//                                 the slot back. No alert.
//   • woken outside 09:00–20:00 → no alert (the ladder stays time-shaped).
//   • woken, but nothing earned → no alert.
// There is no branch that delivers something stale or something guessed: the
// alert is derived and delivered inside the SAME wake (`trigger == nil`), from a
// fresh read, or not at all. That is the property that made it shippable.
//
// SAME ENGINE, NOT A COPY: the wake calls `NudgeRun.run(...)` — the identical
// read → arbitrate → `NudgeEngine` sequence the foreground refresh uses. The
// only logic this file adds is *whether to interrupt*, which lives in
// `EarnedAttention` as pure functions (T-NOT-02).
//
// FR-CTX-04: the user's context flags are loaded and handed to the engine as the
// same suppression gate the foreground applies — a day marked travelling/unwell
// must not buzz about a drift from "usual". Because that store is written with
// NSFileProtectionComplete it is unreadable on a locked device, which is the
// second reason the pass refuses to run without protected data: an unreadable
// gate would silently become NO gate.
import Foundation
import BackgroundTasks
import UIKit
import UserNotifications

enum BackgroundRefresh {

    /// Must match the `BGTaskSchedulerPermittedIdentifiers` entry in Info.plist
    /// (declared there as `$(PRODUCT_BUNDLE_IDENTIFIER).refresh`, so the two stay
    /// in step across signing configurations).
    static var taskIdentifier: String {
        (Bundle.main.bundleIdentifier ?? "xyz.ppcn.maude") + ".refresh"
    }

    /// Don't ask to be woken sooner than this — a calm loop, not a poll.
    static let minimumGap: TimeInterval = 2 * 60 * 60

    /// Why a wake did or did not speak. Returned (and logged) rather than
    /// swallowed, so a device QA session can read the reason for silence.
    enum Outcome: String, Sendable {
        case preferenceOff
        case notAuthorized
        case deviceLocked
        case outsideWindow
        case alreadyAlertedToday
        case noRealDataOnDevice
        case nothingEarned
        case delivered
    }

    // MARK: - Registration + scheduling

    @MainActor private static var didRegister = false

    /// Register the launch handler. MUST be called before the app finishes
    /// launching (AppDelegate), or iOS throws when the task fires.
    @MainActor
    static func register() {
        guard !didRegister else { return }
        didRegister = true
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refresh)
        }
    }

    /// Ask iOS for the next wake — or withdraw the request entirely when the
    /// user has turned earned attention off. Safe to call repeatedly.
    @MainActor
    static func schedule(now: Date = Date(), defaults: UserDefaults = .standard) {
        guard EditionNotifications.isOn(EditionNotifications.Pref.earned, defaults: defaults) else {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
            return
        }
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = nextBeginDate(after: now)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Simulator, or Background App Refresh disabled by the user. Both are
            // legitimate states — the loop simply stays silent.
            print("[bg] earned-attention refresh not scheduled: \(error.localizedDescription)")
        }
    }

    /// Earliest sensible wake: at least `minimumGap` away, and never pointed at
    /// the middle of the night — if it would land outside the delivery window,
    /// aim at the start of the next one instead.
    static func nextBeginDate(after now: Date, calendar: Calendar = .current) -> Date {
        let earliest = now.addingTimeInterval(minimumGap)
        if EarnedAttention.isWithinDeliveryWindow(earliest, calendar: calendar) { return earliest }
        var comps = calendar.dateComponents([.year, .month, .day], from: earliest)
        comps.hour = EarnedAttention.deliveryWindow.lowerBound
        comps.minute = 0
        guard let windowStart = calendar.date(from: comps) else { return earliest }
        if windowStart > earliest { return windowStart }
        return calendar.date(byAdding: .day, value: 1, to: windowStart) ?? earliest
    }

    // MARK: - The wake

    static func handle(_ task: BGAppRefreshTask) {
        let work = Task { @MainActor in
            // Chain the next wake FIRST: if the pass below throws or expires,
            // the loop still lives.
            schedule()
            return await runEarnedAttentionPass()
        }
        task.expirationHandler = { work.cancel() }
        Task { @MainActor in
            let outcome = await work.value
            print("[bg] earned-attention pass: \(outcome.rawValue)")
            // "Nothing to say" is a successful run — only an unusable slot
            // (locked device) is reported as a failure worth rescheduling around.
            task.setTaskCompleted(success: outcome != .deviceLocked)
        }
    }

    /// One complete off-session pass. Every gate returns early with its reason;
    /// the only exit that speaks is the last one.
    @MainActor
    static func runEarnedAttentionPass(now: Date = Date(),
                                       defaults: UserDefaults = .standard) async -> Outcome {
        // 1 — the user's preference.
        guard EditionNotifications.isOn(EditionNotifications.Pref.earned, defaults: defaults) else {
            return .preferenceOff
        }

        // 2 — notification permission (never prompt from the background).
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return .notAuthorized }

        // 3 — protected data. Without it HealthKit is closed AND the FR-CTX-04
        //     context store is unreadable; running on would mean deciding with a
        //     silently absent suppression gate. Refuse.
        guard UIApplication.shared.isProtectedDataAvailable else { return .deviceLocked }

        // 4 — the calm window and the one-per-day rule, checked before doing any
        //     work at all.
        guard EarnedAttention.isWithinDeliveryWindow(now) else { return .outsideWindow }
        guard !EarnedAttention.hasAlertedToday(now: now,
                                               lastAlertAt: EarnedAttention.lastAlertAt(defaults: defaults))
        else { return .alreadyAlertedToday }

        // 5 — real data only. A demo/mock provider must never produce a
        //     notification: an alert about fabricated numbers would be the
        //     dishonest failure mode this whole loop was built to avoid.
        let kind = AppState.resolveProviderKind()
        guard kind == .healthKit else { return .noRealDataOnDevice }

        // 6 — the SAME engine the foreground runs, over a fresh read.
        let end = now
        let start = Calendar.current.date(byAdding: .day, value: -30, to: end) ?? end
        let context = (ContextFlagStore.load() ?? []).map(\.window)
        let result: (samples: HealthSamples, nudges: [EngineNudge])
        do {
            result = try await NudgeRun.run(provider: HealthProviderFactory.make(kind),
                                            from: start, to: end,
                                            context: context, now: now)
        } catch {
            // Authorization not granted, or the store was unavailable. Silence.
            print("[bg] health read unavailable: \(error.localizedDescription)")
            return .noRealDataOnDevice
        }
        guard !result.samples.isEmpty else { return .noRealDataOnDevice }
        guard !Task.isCancelled else { return .nothingEarned }

        // 7 — has today earned an interruption?
        guard let pick = EarnedAttention.pick(from: result.nudges,
                                              now: now,
                                              lastAlertAt: EarnedAttention.lastAlertAt(defaults: defaults))
        else { return .nothingEarned }

        // 8 — deliver now, in this same wake, and spend today's single slot.
        do {
            try await UNUserNotificationCenter.current().add(EarnedAttention.request(for: pick))
            EarnedAttention.recordAlert(at: now, defaults: defaults)
            return .delivered
        } catch {
            print("[bg] earned-attention alert not delivered: \(error.localizedDescription)")
            return .nothingEarned
        }
    }
}
