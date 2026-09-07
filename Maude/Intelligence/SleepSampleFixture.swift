// SleepSampleFixture.swift — the sample-mode sleep fixture.
//
// Lives OUTSIDE the view layer deliberately (provenance guard T-PROV-01): this
// block CONSTRUCTS HealthSamples with the provenance data field, and view files
// must never touch that field. Same fixture, same deterministic values, same
// designSeed tests — only the file changed (2026-08-19 integration).
import Foundation

enum SleepSampleFixture {

    /// 90 deterministic demo nights (gaps included) + in-bed spans + one nap +
    /// one overlapping second source + breathing-rate dailies — everything the
    /// new anatomy shows, all clearly-simulated (`provenance: .simulated`,
    /// fixture source names that never render in prose).
    static let demoDetail: SleepWeekDetail = {
        var s = HealthSamples()
        let cal = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_755_400_000)
        let today = cal.startOfDay(for: now)
        func day(_ off: Int) -> Date { cal.date(byAdding: .day, value: off, to: today) ?? today }
        func seg(_ stage: SleepStage, night off: Int, fromMidnight startH: Double,
                 hours: Double, source: String = "Sample data") -> SleepReading {
            SleepReading(date: day(off), stage: stage, hours: hours,
                         start: day(off).addingTimeInterval(startH * 3600),
                         source: source, tier: .estimate, provenance: .simulated)
        }
        for off in -89...0 {
            let v = ((off % 5) + 5) % 5
            if off != 0, (((off % 11) + 11) % 11 == 4 || ((off % 17) + 17) % 17 == 9) {
                continue                                    // honest gaps
            }
            let bedH = -1.05 + Double(v) * 0.06             // 22:57 … 23:11
            var t = bedH
            func add(_ st: SleepStage, _ h: Double) {
                s.sleep.append(seg(st, night: off, fromMidnight: t, hours: h))
                t += h
            }
            add(.core, 0.4)
            add(.deep, 1.1 + Double(v) * 0.06)
            add(.core, 2.3)
            if off == 0 { add(.awake, 0.2) } else if v == 2 { add(.awake, 0.15) }
            add(.rem, 1.5 + Double(v) * 0.05)
            add(.core, 1.5 + Double(v) * 0.08)
            s.sleepInBed.append(InBedSpan(
                date: day(off),
                start: day(off).addingTimeInterval((bedH - 0.25) * 3600),
                hours: (t - bedH) + 0.35,
                source: "Sample data", tier: .estimate, provenance: .simulated))
        }
        // An afternoon nap on the last day (the resolver splits it out) and a
        // second, undifferentiated source over the last night (excluded and
        // disclosed — FR-SLP-10/FR-PROV-02).
        s.sleep.append(seg(.asleepUnspecified, night: 0, fromMidnight: 14.2, hours: 0.65))
        s.sleep.append(seg(.asleepUnspecified, night: 0, fromMidnight: -1.0, hours: 7.3,
                           source: "Sample data 2"))
        for off in -9...0 {
            s.heartExtras.append(DailyMetric(
                date: day(off), kind: .respiratoryRate,
                value: 14.1 + Double(((off % 3) + 3) % 3) * 0.2,
                source: "Sample data", tier: .estimate, provenance: .simulated))
        }
        // The fixture is static and deterministic; a nil here would be a broken
        // fixture — the designSeed tests exercise this exact path.
        return SleepDetailDeriver.derive(from: s, now: now)!
    }()
}
