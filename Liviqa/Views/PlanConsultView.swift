// PlanConsultView.swift — citizen-side consultation planning (Design v2).
// The patient picks a preferred time, requests the consult (the clinician sees it
// on their side), and can add it to their own device calendar with a reminder.
// EventKit write-only: Liviqa never reads the user's existing events.
import SwiftUI
import EventKit

struct PlanConsultView: View {
    var recipientName: String
    var recipientId: String? = nil
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    private let days: [Date] = {
        let cal = Calendar.current
        let t0 = cal.startOfDay(for: Date())
        return (1...14).compactMap { cal.date(byAdding: .day, value: $0, to: t0) }
    }()
    private let slots = ["08:30", "09:00", "09:30", "10:00", "10:30", "11:00", "11:30",
                         "13:00", "13:30", "14:00", "14:30", "15:00", "15:30", "16:00"]

    @State private var day: Date = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
    @State private var slot = "09:00"
    @State private var duration = 30
    @AppStorage("consultFallbackPhone") private var phone = ""
    @State private var requested = false
    @State private var calendarAdded = false
    @State private var submitting = false
    @State private var showCheck = false
    @State private var error: String?

    private var startDate: Date {
        let parts = slot.split(separator: ":").map { Int($0) ?? 0 }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: day) ?? day
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NavBackHeader(onBack: { dismiss() }) {
                    Text("Plan a consultation").font(.lato(15, .black)).foregroundStyle(LiviqaTheme.ink)
                }
                .padding(.top, 6)

                if requested {
                    confirmation
                } else {
                    picker
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(LiviqaTheme.paper)
        .sheet(isPresented: $showCheck) {
            PreVisitCheckView(recipientName: recipientName, recipientId: recipientId)
        }
    }

    // MARK: — Picker

    private var picker: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A7 verdict header: recipient kicker + serif question.
            Text("With \(recipientName)".uppercased())
                .font(.liviqaKicker(10)).tracking(1.2)
                .foregroundStyle(LiviqaTheme.moss)
            Text("When suits you for a video call?")
                .font(.liviqaSerif(22)).kerning(-0.2).foregroundStyle(LiviqaTheme.ink)
                .padding(.top, 5)

            kicker("Day").padding(.top, 18)
            // The day strip runs edge to edge and carries the page gutter as
            // its own content inset, so the last chip can never be sliced in
            // half by the container's padding (design-QA 2026-08-13).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { d in
                        let on = Calendar.current.isDate(d, inSameDayAs: day)
                        Button { day = d } label: {
                            VStack(spacing: 2) {
                                Text(d.formatted(.dateTime.weekday(.abbreviated))).font(.liviqaKicker(9)).tracking(0.5)
                                Text(d.formatted(.dateTime.day())).font(.lato(15, .heavy))
                            }
                            .foregroundStyle(on ? LiviqaTheme.invertFG : LiviqaTheme.ink)
                            .frame(width: 46, height: 52)
                            .background(on ? LiviqaTheme.invertBG : LiviqaTheme.paper2)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(on ? Color.clear : LiviqaTheme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.horizontal, -20)
            .padding(.top, 6)

            kicker("Time").padding(.top, 16)
            FlowRow(spacing: 8) {
                ForEach(slots, id: \.self) { s in
                    let busy = isBusy(s, on: day)
                    let on = s == slot && !busy
                    Button { if !busy { slot = s } } label: {
                        Text(s).font(.lato(14, .bold))
                            .strikethrough(busy, color: LiviqaTheme.ink4)
                            .foregroundStyle(busy ? LiviqaTheme.ink4 : (on ? .white : LiviqaTheme.ink))
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(on ? LiviqaTheme.moss : (busy ? LiviqaTheme.line2.opacity(0.5) : LiviqaTheme.paper2))
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(on ? Color.clear : LiviqaTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(busy)
                }
            }
            .padding(.top, 6)
            .onChange(of: day) { ensureFreeSlot() }
            .onAppear { ensureFreeSlot() }
            Text("Suggested times — your clinician will confirm.")
                .font(.lato(11)).foregroundStyle(LiviqaTheme.ink4).padding(.top, 5)

            kicker("How long").padding(.top, 16)
            HStack(spacing: 8) {
                ForEach([15, 30, 45], id: \.self) { m in
                    let on = m == duration
                    Button { duration = m } label: {
                        Text("\(m) min").font(.lato(14, .bold))
                            .foregroundStyle(on ? LiviqaTheme.invertFG : LiviqaTheme.ink)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(on ? LiviqaTheme.invertBG : LiviqaTheme.paper2)
                            .clipShape(RoundedRectangle(cornerRadius: 11))
                            .overlay(RoundedRectangle(cornerRadius: 11).stroke(on ? Color.clear : LiviqaTheme.line, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 6)

            // Fallback phone — its own card (A7 canvas): the clinician can reach
            // the citizen if the video connection drops (Min Læge pattern).
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "phone").font(.system(size: 13)).foregroundStyle(LiviqaTheme.moss)
                    kicker("If the video drops")
                }
                TextField("Phone number (optional) — for fallback", text: $phone)
                    .keyboardType(.phonePad)
                    .font(.lato(13.5)).foregroundStyle(LiviqaTheme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(LiviqaTheme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .overlay(RoundedRectangle(cornerRadius: 11).stroke(LiviqaTheme.line, lineWidth: 1))
                    .padding(.top, 8)
                Text("\(recipientName) can call you if the connection fails. Stored on your device, shared only if the call drops.")
                    .font(.lato(11.5)).lineSpacing(2).foregroundStyle(LiviqaTheme.ink3).padding(.top, 8)
            }
            .padding(14)
            .background(LiviqaTheme.paper2)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay(RoundedRectangle(cornerRadius: 13).stroke(LiviqaTheme.line, lineWidth: 0.5))
            .padding(.top, 16)

            // Summary
            HStack(spacing: 8) {
                Image(systemName: "calendar").font(.system(size: 13)).foregroundStyle(LiviqaTheme.moss)
                Text("\(startDate.formatted(.dateTime.weekday(.wide).day().month(.wide))) · \(slot)")
                    .font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.ink)
                Text("· \(duration) min").font(.lato(13)).foregroundStyle(LiviqaTheme.ink3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LiviqaTheme.moss2)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LiviqaTheme.moss3, lineWidth: 1))
            .padding(.top, 18)

            Button {
                Task { await submitRequest() }
            } label: {
                Text(submitting ? "Requesting…" : "Request this consultation")
                    .font(.lato(15, .bold))
                    // In flight = unavailable, and it says so by changing
                    // treatment rather than by dimming the live slab.
                    .foregroundStyle(submitting ? LiviqaTheme.primaryOffLabel : LiviqaTheme.invertFG)
                    .frame(maxWidth: .infinity).padding(.vertical, 15)
                    .background(submitting ? LiviqaTheme.primaryOffFill : LiviqaTheme.invertBG)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .disabled(submitting)
            .padding(.top, 14)

            // A7 canvas under-button line, kept honest: the calendar add is the
            // citizen's own tap on the next screen, never automatic.
            Text("\(recipientName) will confirm your \(startDate.formatted(.dateTime.weekday(.wide).day().month(.wide))) · \(slot) consultation. We'll notify you here, and you can add it to your calendar.")
                .font(.lato(11.5)).lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(LiviqaTheme.ink3)
                .frame(maxWidth: .infinity)
                .padding(.top, 10).padding(.horizontal, 6)

            if let error {
                Text(error).font(.lato(12.5)).foregroundStyle(LiviqaTheme.rust)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: — Confirmation

    private var confirmation: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(LiviqaTheme.moss2).frame(width: 64, height: 64)
                Image(systemName: "checkmark").font(.system(size: 26, weight: .bold)).foregroundStyle(LiviqaTheme.moss)
            }
            .padding(.top, 14)
            Text("Request sent.")
                .font(.liviqaSerif(23)).kerning(-0.2).foregroundStyle(LiviqaTheme.ink).padding(.top, 16)
            Text("\(recipientName) will confirm your \(startDate.formatted(.dateTime.weekday(.wide).day().month())) · \(slot) consultation. We'll notify you here.")
                .font(.lato(14)).lineSpacing(2).multilineTextAlignment(.center)
                .foregroundStyle(LiviqaTheme.ink2).padding(.top, 10).padding(.horizontal, 8)

            if let error {
                Text(error).font(.lato(12.5)).foregroundStyle(LiviqaTheme.rust).padding(.top, 10)
            }

            Button { addToCalendar() } label: {
                HStack(spacing: 8) {
                    Image(systemName: calendarAdded ? "checkmark.circle.fill" : "calendar.badge.plus")
                    Text(calendarAdded ? "Added to your calendar" : "Add to my calendar").font(.lato(15, .bold))
                }
                .foregroundStyle(calendarAdded ? LiviqaTheme.moss : .white)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(calendarAdded ? LiviqaTheme.moss2 : LiviqaTheme.moss)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .buttonStyle(.plain)
            .disabled(calendarAdded)
            .padding(.top, 22)

            Button { showCheck = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield")
                    Text("Test your camera & connection").font(.lato(15, .bold))
                }
                .foregroundStyle(LiviqaTheme.ink)
                .frame(maxWidth: .infinity).padding(.vertical, 14)
                .background(LiviqaTheme.paper2)
                .clipShape(RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(LiviqaTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            Button { dismiss() } label: {
                Text("Done").font(.lato(14, .bold)).foregroundStyle(LiviqaTheme.ink2)
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
    }

    private func kicker(_ t: String) -> some View {
        Text(t.uppercased()).font(.liviqaKicker(10)).tracking(1.2).foregroundStyle(LiviqaTheme.ink3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Simulated EMR/HIS free/busy — deterministic (stable across launches) so the
    /// same day reads consistently. Swaps to a live SMART-Slot feed later (spec §A).
    private func isBusy(_ slot: String, on day: Date) -> Bool {
        let d = Calendar.current.component(.day, from: day)
        let idx = slots.firstIndex(of: slot) ?? 0
        let k = (d &+ idx) % 7
        return k == 0 || k == 3
    }

    /// Keep the selection on a free slot (e.g. after changing day).
    private func ensureFreeSlot() {
        if isBusy(slot, on: day) {
            slot = slots.first { !isBusy($0, on: day) } ?? slot
        }
    }

    private func submitRequest() async {
        // Real backend: post the request (status proposed:citizen) and refresh
        // the care inbox so it surfaces as "awaiting the clinician". Demo mode
        // (no careConnect / no recipient) keeps the local confirmation.
        if let rid = recipientId, let care = appState.careConnect {
            submitting = true; error = nil
            do {
                _ = try await care.requestConsult(recipientId: rid, at: startDate, kind: "consultation")
                await appState.refreshCareInbox()
                withAnimation { requested = true }
            } catch {
                self.error = "Couldn't send the request — please try again."
            }
            submitting = false
        } else {
            withAnimation { requested = true }
        }
    }

    private func addToCalendar() {
        let store = EKEventStore()
        let done: (Bool, Error?) -> Void = { granted, _ in
            DispatchQueue.main.async {
                guard granted else { self.error = "Calendar access is off — enable it in Settings to add this."; return }
                let ev = EKEvent(eventStore: store)
                ev.title = "Liviqa video consultation · \(recipientName)"
                // App deep link (Stage C): tapping the event reopens the consult in Liviqa.
                let deepLink = "liviqa://consult"
                ev.url = URL(string: deepLink)
                ev.notes = "Secure video consultation in Liviqa.\nOpen in the app: \(deepLink)"
                ev.startDate = startDate
                ev.endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))
                // Reminder ladder (spec Stage D), reused as calendar alarms so push
                // and calendar don't double-fire: day before · 1 hour · 10 minutes.
                ev.addAlarm(EKAlarm(relativeOffset: -86_400))
                ev.addAlarm(EKAlarm(relativeOffset: -3_600))
                ev.addAlarm(EKAlarm(relativeOffset: -600))
                ev.calendar = store.defaultCalendarForNewEvents
                do { try store.save(ev, span: .thisEvent); withAnimation { self.calendarAdded = true } }
                catch { self.error = "Couldn't add to your calendar." }
            }
        }
        if #available(iOS 17.0, *) { store.requestWriteOnlyAccessToEvents(completion: done) }
        else { store.requestAccess(to: .event, completion: done) }
    }
}
