// Maude mobile home — Apple Liquid Glass (iOS 26), the CITIZEN consumer surface.
// Opposite of the matte console: translucent glass layers (blur+saturate), specular
// top-edge highlight + hairline inner stroke, large-title nav condensing on scroll,
// scroll-edge fade under the bar, floating glass tab capsule. White/off-white base — no mint.
// SF Pro + SF-Symbol-style glyphs. This is a reference mock for the prompt's §6.

const SF = '-apple-system, "SF Pro Text", "SF Pro", system-ui, sans-serif';
const SFD = '-apple-system, "SF Pro Display", "SF Pro", system-ui, sans-serif';
const NAVY = "#1D3557";

// ── Glass surface: tint + blur, specular highlight, hairline stroke (concentric radii) ──
function Glass({ radius = 28, tint = "rgba(255,255,255,0.6)", children, style }) {
  return (
    <div style={{ position: "relative", borderRadius: radius, overflow: "hidden",
      boxShadow: "0 1px 3px rgba(16,28,51,0.06), 0 10px 30px -12px rgba(16,28,51,0.18)", ...style }}>
      <div style={{ position: "absolute", inset: 0, borderRadius: radius,
        backdropFilter: "blur(20px) saturate(180%)", WebkitBackdropFilter: "blur(20px) saturate(180%)",
        background: tint }}></div>
      <div style={{ position: "absolute", inset: 0, borderRadius: radius, pointerEvents: "none",
        boxShadow: "inset 1.5px 1.5px 1px rgba(255,255,255,0.85), inset -1px -1px 1px rgba(255,255,255,0.45)",
        border: "0.5px solid rgba(16,28,51,0.07)" }}></div>
      <div style={{ position: "relative", zIndex: 1 }}>{children}</div>
    </div>
  );
}

// minimal SF-Symbol-style glyphs (stroked, rounded)
function Sym({ d, size = 26, fill, stroke = NAVY, sw = 1.9, op = 1 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 28 28" fill={fill || "none"} style={{ opacity: op, display: "block" }}>
      <path d={d} stroke={fill ? "none" : stroke} strokeWidth={sw} strokeLinecap="round" strokeLinejoin="round" fill={fill || "none"}></path>
    </svg>
  );
}
const ICON = {
  drop: "M14 4C14 4 7 12 7 17a7 7 0 0 0 14 0C21 12 14 4 14 4Z",
  heart: "M14 23S5 17.5 5 11.5A4.5 4.5 0 0 1 14 9 4.5 4.5 0 0 1 23 11.5C23 17.5 14 23 14 23Z",
  moon: "M22 16.5A9 9 0 0 1 11.5 6 7 7 0 1 0 22 16.5Z",
  shield: "M14 4 5 7v6c0 5 4 9 9 11 5-2 9-6 9-11V7l-9-3Z",
  home: "M5 13 14 5l9 8M8 11v10h12V11",
  pulse: "M3 14h5l3-7 4 14 3-7h6",
  chat: "M5 6h18v13H14l-5 4v-4H5Z",
  person: "M14 14a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9ZM6 24c0-4.5 3.6-7 8-7s8 2.5 8 7",
};

function MetricCard({ icon, tint, label, value, unit, note, noteColor, noteKind, big }) {
  return (
    <Glass radius={26} tint="rgba(255,255,255,0.55)" style={{ flex: big ? "1 1 100%" : "1 1 0" }}>
      <div style={{ padding: 16 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 9, marginBottom: 12 }}>
          <div style={{ width: 34, height: 34, borderRadius: 10, background: tint, display: "grid", placeItems: "center" }}>
            <Sym d={icon} size={20} />
          </div>
          <span style={{ fontFamily: SF, fontSize: 14, fontWeight: 600, color: "rgba(29,53,87,0.62)" }}>{label}</span>
        </div>
        <div style={{ display: "flex", alignItems: "baseline", gap: 5, whiteSpace: "nowrap" }}>
          <span style={{ fontFamily: SFD, fontSize: big ? 40 : 34, fontWeight: 700, color: NAVY, letterSpacing: "-0.02em", lineHeight: 1 }}>{value}</span>
          {unit && <span style={{ fontFamily: SF, fontSize: 15, fontWeight: 600, color: "rgba(29,53,87,0.5)" }}>{unit}</span>}
        </div>
        {note && (noteKind === "watch"
          ? <span style={{ display: "inline-flex", alignItems: "center", gap: 5, fontFamily: SF, fontSize: 12.5, fontWeight: 700, color: NAVY, background: "#FFB703", padding: "3px 10px", borderRadius: 999, marginTop: 10 }}>{note}</span>
          : <div style={{ fontFamily: SF, fontSize: 13.5, fontWeight: 600, color: noteColor || "rgba(29,53,87,0.55)", marginTop: 8 }}>{note}</div>)}
      </div>
    </Glass>
  );
}

function TabItem({ icon, label, on }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 3, flex: 1, padding: "2px 0" }}>
      <Sym d={icon} size={25} stroke={on ? NAVY : "rgba(29,53,87,0.5)"} fill={on ? NAVY : undefined} sw={on ? 0 : 1.9} />
      <span style={{ fontFamily: SF, fontSize: 10.5, fontWeight: on ? 700 : 500, color: on ? NAVY : "rgba(29,53,87,0.55)" }}>{label}</span>
    </div>
  );
}

function MobileHome() {
  const [scrolled, setScrolled] = React.useState(false);
  const onScroll = (e) => setScrolled(e.target.scrollTop > 28);

  return (
    <div data-screen-label="Mobile home — Liquid Glass" style={{
      width: 390, height: 844, borderRadius: 52, overflow: "hidden", position: "relative",
      // white / off-white base with faint colour washes so the glass tints read cleanly (no mint ground)
      background: "radial-gradient(120% 60% at 80% -5%, #EAF0F6 0%, rgba(234,240,246,0) 55%), radial-gradient(90% 45% at 0% 8%, #F3ECEC 0%, rgba(243,236,236,0) 50%), #F7F8FA",
      boxShadow: "0 40px 90px rgba(16,28,51,0.22), 0 0 0 1px rgba(16,28,51,0.10)",
      fontFamily: SF, WebkitFontSmoothing: "antialiased",
    }}>
      {/* dynamic island */}
      <div style={{ position: "absolute", top: 11, left: "50%", transform: "translateX(-50%)", width: 124, height: 36, borderRadius: 22, background: "#000", zIndex: 60 }}></div>

      {/* status bar */}
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 54, display: "flex", alignItems: "center", justifyContent: "space-between", padding: "0 30px", zIndex: 55, paddingTop: 14 }}>
        <span style={{ fontFamily: SFD, fontWeight: 600, fontSize: 16, color: NAVY }}>9:41</span>
        <span style={{ fontFamily: SF, fontWeight: 700, fontSize: 12, color: NAVY, letterSpacing: "0.04em" }}>5G ▪ ▪ ▪</span>
      </div>

      {/* scroll-edge glass bar — condenses large title to inline on scroll */}
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: 96, zIndex: 40, pointerEvents: "none",
        opacity: scrolled ? 1 : 0, transition: "opacity 200ms ease" }}>
        <div style={{ position: "absolute", inset: 0, backdropFilter: "blur(18px) saturate(160%)", WebkitBackdropFilter: "blur(18px) saturate(160%)",
          background: "linear-gradient(180deg, rgba(247,248,250,0.86) 60%, rgba(247,248,250,0))", maskImage: "linear-gradient(180deg,#000 60%,transparent)" }}></div>
        <div style={{ position: "absolute", top: 56, left: 0, right: 0, textAlign: "center", fontFamily: SFD, fontWeight: 700, fontSize: 17, color: NAVY }}>Today</div>
      </div>

      {/* content (scrolls under the bars) */}
      <div onScroll={onScroll} style={{ position: "absolute", inset: 0, overflowY: "auto", paddingTop: 54 }}>
        {/* large title */}
        <div style={{ padding: "8px 20px 4px", display: "flex", justifyContent: "space-between", alignItems: "flex-end" }}>
          <div>
            <div style={{ fontFamily: SF, fontSize: 15, fontWeight: 600, color: "rgba(29,53,87,0.5)" }}>Saturday 13 June</div>
            <h1 style={{ fontFamily: SFD, fontSize: 34, fontWeight: 700, color: NAVY, letterSpacing: "-0.02em", margin: "2px 0 0" }}>Today</h1>
          </div>
          <Glass radius={9999} style={{ width: 40, height: 40 }}>
            <div style={{ width: 40, height: 40, display: "grid", placeItems: "center" }}>
              <Sym d={ICON.person} size={22} />
            </div>
          </Glass>
        </div>

        {/* metric grid */}
        <div style={{ padding: "14px 16px 0", display: "flex", flexWrap: "wrap", gap: 12 }}>
          <MetricCard icon={ICON.drop} tint="rgba(168,218,220,0.5)" label="Glucose" value="6.2" unit="mmol/L" note="● within range" noteColor="#457B9D" />
          <MetricCard icon={ICON.heart} tint="rgba(244,146,154,0.45)" label="Resting HR" value="58" unit="bpm" note="steady" />
          <MetricCard icon={ICON.moon} tint="rgba(69,123,157,0.32)" label="Sleep" value="7h 24m" note="▲ 15% below your average" noteKind="watch" big />
        </div>

        {/* consent card */}
        <div style={{ padding: "16px 16px 0" }}>
          <Glass radius={26} tint="rgba(255,255,255,0.5)">
            <div style={{ padding: 18 }}>
              <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 12 }}>
                <div style={{ width: 34, height: 34, borderRadius: 10, background: "rgba(69,123,157,0.16)", display: "grid", placeItems: "center" }}>
                  <Sym d={ICON.shield} size={20} stroke="#457B9D" />
                </div>
                <span style={{ fontFamily: SFD, fontSize: 17, fontWeight: 700, color: NAVY }}>Shared on your terms</span>
              </div>
              <p style={{ fontFamily: SF, fontSize: 15, lineHeight: 1.45, color: "rgba(29,53,87,0.7)", margin: 0 }}>
                Your diabetes nurse can see glucose and sleep patterns — not raw readings. Shared by you, expires in 6 days.
              </p>
              <div style={{ display: "flex", gap: 9, marginTop: 14 }}>
                <div style={{ flex: 1, textAlign: "center", padding: "11px 0", borderRadius: 13, background: NAVY, color: "#fff", fontFamily: SF, fontSize: 15, fontWeight: 600 }}>Manage sharing</div>
                <div style={{ flex: "none", padding: "11px 16px", borderRadius: 13, background: "rgba(29,53,87,0.07)", color: NAVY, fontFamily: SF, fontSize: 15, fontWeight: 600 }}>Extend</div>
              </div>
            </div>
          </Glass>
        </div>

        {/* a little spare list to give the scroll-edge something to pass under */}
        <div style={{ padding: "16px 16px 140px" }}>
          <div style={{ fontFamily: SF, fontSize: 13, fontWeight: 600, color: "rgba(29,53,87,0.5)", textTransform: "uppercase", letterSpacing: "0.04em", padding: "0 6px 8px" }}>Worth a look</div>
          <Glass radius={22} tint="rgba(255,255,255,0.5)">
            {[["pulse", "HRV dips on busy days", "A pattern in your data"], ["drop", "Glucose steadiest after walks", "Last 2 weeks"]].map((r, i) => (
              <div key={r[0]} style={{ display: "flex", alignItems: "center", gap: 13, padding: "14px 16px", borderTop: i ? "0.5px solid rgba(29,53,87,0.1)" : "none" }}>
                <Sym d={ICON[r[0]]} size={22} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: SF, fontSize: 16, fontWeight: 600, color: NAVY }}>{r[1]}</div>
                  <div style={{ fontFamily: SF, fontSize: 13.5, color: "rgba(29,53,87,0.5)" }}>{r[2]}</div>
                </div>
                <Sym d="M10 5l7 7-7 7" size={18} stroke="rgba(29,53,87,0.3)" />
              </div>
            ))}
          </Glass>
        </div>
      </div>

      {/* floating glass tab capsule — detached from the edge */}
      <div style={{ position: "absolute", left: 16, right: 16, bottom: 26, zIndex: 50 }}>
        <Glass radius={9999} tint="rgba(255,255,255,0.62)">
          <div style={{ display: "flex", alignItems: "center", padding: "9px 12px 7px" }}>
            <TabItem icon={ICON.home} label="Today" on />
            <TabItem icon={ICON.pulse} label="Trends" />
            <TabItem icon={ICON.shield} label="Sharing" />
            <TabItem icon={ICON.chat} label="Messages" />
          </div>
        </Glass>
      </div>

      {/* home indicator */}
      <div style={{ position: "absolute", bottom: 8, left: 0, right: 0, display: "flex", justifyContent: "center", zIndex: 60, pointerEvents: "none" }}>
        <div style={{ width: 134, height: 5, borderRadius: 100, background: "rgba(29,53,87,0.28)" }}></div>
      </div>
    </div>
  );
}

window.MobileHome = MobileHome;
