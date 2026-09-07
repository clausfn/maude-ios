// Clinical Ops dashboard — Maude B2B console (light clinical console).
// Hanken Grotesk headings, Public Sans UI/body, IBM Plex Mono numbers.
// Lucide icons (stroke 1.75). White grounds, navy floating chrome, elevation hierarchy.
// Status triplets ● ▲ ✕ in day-form colours. No glass, no gradients — shadows do the lift.

const CO_BRAND = "../../assets/brand/";
const CO_SERIF = "var(--font-serif)";
const CO_HEAD = { fontFamily: "var(--font-serif)", fontWeight: 700, letterSpacing: "-0.01em" }; // headings: Hanken Grotesk (body is Public Sans)
const CO_MONO = "var(--font-mono)";
const CO_KICK = { fontFamily: CO_MONO, textTransform: "uppercase", letterSpacing: "0.1em", fontWeight: 600 };

// ── Lucide wrapper (same contract as components/core/Icon.jsx) ──
function coToPascal(name) {
  return String(name).replace(/(^\w|-\w)/g, (m) => m.replace("-", "").toUpperCase());
}
function coRenderNode(arr) {
  return arr.map((child, i) => {
    if (!Array.isArray(child)) return null;
    if (typeof child[0] === "string") {
      const kids = Array.isArray(child[2]) ? coRenderNode(child[2]) : null;
      return React.createElement(child[0], { key: i, ...(child[1] || {}) }, kids);
    }
    return coRenderNode(child);
  });
}
function CoIcon({ name, size = 18, color = "currentColor", stroke = 1.75, style }) {
  const lib = typeof window !== "undefined" ? window.lucide : undefined;
  const node = lib && lib.icons ? lib.icons[coToPascal(name)] || lib.icons[name] : null;
  if (!node) return <span aria-hidden="true" style={{ display: "inline-block", width: size, height: size, ...style }}></span>;
  return (
    <svg xmlns="http://www.w3.org/2000/svg" width={size} height={size} viewBox="0 0 24 24" fill="none"
      stroke={color} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round"
      style={{ display: "block", flex: "none", ...style }} aria-hidden="true">
      {coRenderNode(node)}
    </svg>
  );
}

function CoMark({ size = 22 }) {
  return <img src={CO_BRAND + "maude_mark_iris.svg"}
    alt="Maude" width={size} height={size} style={{ display: "block" }} />;
}

// ── Status triplets — shape + word + colour, never colour alone ──
const CO_TRIPLET = {
  good: { glyph: "●", word: "WITHIN RANGE" },
  watch: { glyph: "▲", word: "WATCH" },
  act: { glyph: "✕", word: "ACT NOW" },
};
function CoStatusChip({ kind }) {
  const t = CO_TRIPLET[kind];
  const base = { display: "inline-flex", alignItems: "center", gap: 6, fontFamily: CO_MONO, fontSize: 10.5, fontWeight: 600, letterSpacing: "0.06em", padding: "4px 9px", borderRadius: 3, whiteSpace: "nowrap" };
  if (kind === "watch") {
    return <span style={{ ...base, background: "var(--c-watch)", color: "var(--c-text)" }}>{t.glyph} {t.word}</span>;
  }
  const color = kind === "good" ? "var(--c-good)" : "var(--c-act)";
  const line = kind === "good" ? "var(--c-good-line)" : "var(--c-act-line)";
  return <span style={{ ...base, color, border: `1px solid ${line}`, background: "transparent" }}>{t.glyph} {t.word}</span>;
}

// ── Shared surfaces ──
const coTile = { background: "var(--c-tile)", border: "1px solid var(--c-line)", borderRadius: 10, boxShadow: "var(--sh-card)" };
const coKicker = { ...CO_KICK, fontSize: 10, color: "var(--c-text3)", margin: 0 };
const coPrimaryBtn = { all: "unset", display: "inline-flex", alignItems: "center", gap: 8, boxSizing: "border-box", whiteSpace: "nowrap", flex: "none", background: "var(--c-btn-bg)", color: "var(--c-btn-text)", fontWeight: 700, fontSize: 13, padding: "10px 16px", borderRadius: 9, cursor: "pointer" };
const coGhostBtn = { all: "unset", display: "inline-flex", alignItems: "center", gap: 7, boxSizing: "border-box", cursor: "pointer", fontSize: 11.5, fontWeight: 600, color: "var(--c-text2)", border: "1px solid var(--c-line)", borderRadius: 8, padding: "6px 11px", background: "transparent" };

function CoCardHead({ icon, iconColor, title, right }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 12 }}>
      <CoIcon name={icon} size={16} color={iconColor || "var(--c-text3)"} />
      <h2 style={{ ...CO_HEAD, fontSize: 15.5, margin: 0, flex: 1 }}>{title}</h2>
      {right}
    </div>
  );
}

// ── Nav ──
function CoNavItem({ icon, label, on, locked, badge }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 9, padding: "8px 10px", borderRadius: 8, fontSize: 13,
      fontWeight: on ? 700 : 500, cursor: locked ? "default" : "pointer", opacity: locked ? 0.45 : 1,
      background: on ? "var(--c-text)" : "transparent",
      color: on ? "#FFFFFF" : "var(--c-text2)" }}>
      <CoIcon name={icon} size={16} color={on ? "#FFFFFF" : "var(--c-text3)"} />
      <span style={{ flex: 1 }}>{label}</span>
      {badge && <span style={{ fontFamily: CO_MONO, fontSize: 10, fontVariantNumeric: "tabular-nums", color: on ? "rgba(255,255,255,.7)" : "var(--c-text3)" }}>{badge}</span>}
    </div>
  );
}
function CoNavGroup({ children }) {
  return <div style={{ ...CO_KICK, fontSize: 9.5, color: "var(--c-text3)", margin: "15px 8px 6px" }}>{children}</div>;
}

// ── KPI tile ──
function CoKpi({ label, value, unit, delta, deltaKind }) {
  const deltaColor = deltaKind === "act" ? "var(--c-act)" : deltaKind === "watch" ? "var(--c-text)" : deltaKind === "good" ? "var(--c-good)" : "var(--c-text3)";
  return (
    <div style={{ ...coTile, padding: 16 }}>
      <div style={{ ...coKicker, marginBottom: 6 }}>{label}</div>
      <div style={{ fontFamily: CO_MONO, fontSize: 26, fontWeight: 500, fontVariantNumeric: "tabular-nums", color: "var(--c-text)" }}>
        {value}{unit && <span style={{ fontSize: 13, color: "var(--c-text3)", marginLeft: 4 }}>{unit}</span>}
      </div>
      {delta && <div style={{ fontFamily: CO_MONO, fontSize: 11, fontVariantNumeric: "tabular-nums", color: deltaColor, marginTop: 5 }}>{delta}</div>}
    </div>
  );
}

// ── Insight row ──
function CoInsight({ kind, title, meaning, suggested }) {
  return (
    <div style={{ ...coTile, padding: "15px 17px", marginBottom: 10 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 10 }}>
        <span style={{ fontWeight: 700, fontSize: 14.5, color: "var(--c-text)" }}>{title}</span>
        <CoStatusChip kind={kind} />
      </div>
      <div style={{ fontSize: 13, color: "var(--c-text2)", margin: "6px 0 0", lineHeight: 1.5 }}>{meaning}</div>
      {suggested && (
        <div style={{ fontSize: 13, color: "var(--c-text2)", borderTop: "1px dashed var(--c-line)", paddingTop: 8, marginTop: 9, lineHeight: 1.5 }}>
          <span style={{ ...CO_KICK, fontSize: 9.5, color: "var(--c-kick)", marginRight: 8 }}>Suggested</span>{suggested}
        </div>
      )}
      <div style={{ display: "flex", gap: 7, marginTop: 11, flexWrap: "wrap" }}>
        <button style={{ ...coGhostBtn, color: "var(--c-text)", borderColor: "var(--c-text3)" }}><CoIcon name="message-square" size={13} /> Message client</button>
        <button style={coGhostBtn}><CoIcon name="clipboard-list" size={13} /> Add to plan</button>
        <button style={coGhostBtn}><CoIcon name="flag" size={13} /> Flag for review</button>
        <button style={coGhostBtn}><CoIcon name="check" size={13} /> Mark addressed</button>
      </div>
    </div>
  );
}

// ── Spare sparkline — time in range, 14 days, cohort (synthetic, k ≥ 11) ──
function CoSpark() {
  const vals = [71, 72, 70, 73, 74, 72, 75, 74, 76, 74, 73, 75, 77, 76];
  const W = 560, H = 96, lo = 64, hi = 82;
  const x = (i) => (i / (vals.length - 1)) * W;
  const y = (v) => H - ((v - lo) / (hi - lo)) * H;
  const line = vals.map((v, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
  const area = `${line} L${W},${H} L0,${H} Z`;
  const target = y(70);
  return (
    <svg viewBox={`0 0 ${W} ${H}`} style={{ width: "100%", height: "auto", display: "block" }} role="img" aria-label="Cohort time in range, last 14 days, between 70 and 77 percent">
      <path d={area} fill="var(--c-good)" opacity="0.12"></path>
      <line x1="0" y1={target} x2={W} y2={target} stroke="var(--c-line)" strokeDasharray="4 5"></line>
      <path d={line} fill="none" stroke="var(--c-good)" strokeWidth="2"></path>
      <circle cx={x(13)} cy={y(76)} r="3.5" fill="var(--c-good)"></circle>
    </svg>
  );
}

// ── Row primitives ──
function CoTimeRow({ when, label, kind, last }) {
  return (
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", gap: 12, fontSize: 13, padding: "8px 0", borderBottom: last ? "none" : "1px solid var(--c-line)" }}>
      <span style={{ color: "var(--c-text2)" }}>
        <span style={{ fontFamily: CO_MONO, fontSize: 12, color: "var(--c-text)", fontVariantNumeric: "tabular-nums" }}>{when}</span> — {label}
      </span>
      <span style={{ ...CO_KICK, fontSize: 10, color: "var(--c-kick)", whiteSpace: "nowrap" }}>{kind}</span>
    </div>
  );
}

function CoConsentRow({ glyph, color, what, detail, when, last }) {
  return (
    <div style={{ display: "flex", gap: 10, padding: "9px 0", borderBottom: last ? "none" : "1px solid var(--c-line)", alignItems: "baseline" }}>
      <span style={{ fontFamily: CO_MONO, fontSize: 11, color, width: 12, flex: "none" }}>{glyph}</span>
      <span style={{ flex: 1, fontSize: 13, lineHeight: 1.45 }}>
        <b style={{ color: "var(--c-text)", fontWeight: 700 }}>{what}</b>
        <span style={{ color: "var(--c-text2)" }}> — {detail}</span>
      </span>
      <span style={{ fontFamily: CO_MONO, fontSize: 11, color: "var(--c-text3)", fontVariantNumeric: "tabular-nums", flex: "none" }}>{when}</span>
    </div>
  );
}

// ───────────────────────── Dashboard ─────────────────────────
function ClinicalOpsDashboard() {
  return (
    <div className="lqc" data-screen-label="Clinical Ops dashboard" style={{ minHeight: "100vh", background: "var(--c-ground)", color: "var(--c-text)", fontFamily: "var(--font-sans)", padding: "10px 10px 0" }}>

      {/* floating menu bar — inset + radius + elevation so it hovers above the content plane */}
      <div style={{ background: "var(--c-tile)", borderRadius: 14, boxShadow: "var(--sh-bar)", padding: "11px 18px", position: "sticky", top: 10, zIndex: 30 }}>
        <div style={{ maxWidth: 1340, margin: "0 auto", display: "flex", alignItems: "center", justifyContent: "space-between", gap: 10 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 9 }}>
            <CoMark size={22} />
            <span style={{ ...CO_HEAD, fontSize: 18 }}>Maude</span>
            <span style={{ fontFamily: CO_MONO, fontSize: 11.5, color: "var(--c-text3)", marginLeft: 6, whiteSpace: "nowrap" }}>· clinical ops</span>
          </div>
          <div style={{ display: "flex", alignItems: "center", gap: 8, flex: "none" }}>
            <button style={coGhostBtn}><CoIcon name="search" size={14} /> Find client</button>
            <button style={coGhostBtn}><CoIcon name="bell" size={14} /> Alerts</button>
            <button style={coGhostBtn}><CoIcon name="log-out" size={14} /> Sign out</button>
          </div>
        </div>
      </div>

      {/* shell */}
      <div style={{ maxWidth: 1340, margin: "0 auto", display: "grid", gridTemplateColumns: "212px 1fr", gap: 18, alignItems: "start", padding: "18px 8px 40px" }}>
        <nav style={{ background: "var(--c-tile)", borderRadius: 12, boxShadow: "var(--sh-panel)", padding: "16px 12px", position: "sticky", top: 78 }}>
          <div style={{ display: "flex", alignItems: "center", gap: 9, marginBottom: 12, padding: "0 2px" }}>
            <div style={{ width: 34, height: 34, borderRadius: 8, display: "grid", placeItems: "center", fontFamily: CO_MONO, fontWeight: 600, fontSize: 12, background: "var(--c-ground)", border: "1px solid var(--c-line)", color: "var(--c-text)" }}>DN</div>
            <div style={{ minWidth: 0 }}>
              <div style={{ fontWeight: 700, fontSize: 13, lineHeight: 1.2, whiteSpace: "nowrap" }}>Diabetes nurse</div>
              <div style={{ fontSize: 11, color: "var(--c-text3)" }}>Consented clients</div>
            </div>
          </div>
          <span style={{ display: "inline-flex", alignItems: "center", gap: 6, fontFamily: CO_MONO, fontSize: 10, fontWeight: 600, letterSpacing: "0.05em", padding: "4px 9px", borderRadius: 3, marginBottom: 8, color: "var(--c-good)", border: "1px solid var(--c-good-line)" }}>● CONSENTED</span>

          <CoNavGroup>Worklist</CoNavGroup>
          <CoNavItem icon="layout-dashboard" label="Dashboard" on />
          <CoNavItem icon="users" label="Your clients" badge="28" />
          <CoNavItem icon="message-square" label="Messages" badge="3" />
          <CoNavItem icon="calendar-days" label="Appointments" />
          <CoNavGroup>Organisation</CoNavGroup>
          <CoNavItem icon="shield-check" label="Consent ledger" />
          <CoNavItem icon="chart-column" label="Cohort (Mode B)" locked />
          <CoNavItem icon="settings" label="Admin" locked />
        </nav>

        <main style={{ minWidth: 0 }}>
          {/* header */}
          <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 14, flexWrap: "wrap" }}>
            <div>
              <h1 style={{ ...CO_HEAD, fontSize: 25, margin: 0 }}>Clinical ops</h1>
              <p style={{ color: "var(--c-text2)", margin: "6px 0 0", fontSize: 14, lineHeight: 1.5, maxWidth: 620 }}>
                28 citizens have consented to share with your organisation. Everything below is a derived view — raw data never leaves their devices.
              </p>
              <div style={{ fontFamily: CO_MONO, fontSize: 11.5, color: "var(--c-text3)", fontVariantNumeric: "tabular-nums", marginTop: 6 }}>Sat · 13 Jun · updated 08:42</div>
            </div>
            <button style={coPrimaryBtn}><CoIcon name="plus" size={15} stroke={2.25} /> Patient triage</button>
          </div>

          {/* KPI row */}
          <div style={{ display: "grid", gridTemplateColumns: "repeat(4, 1fr)", gap: 12, margin: "18px 0" }}>
            <CoKpi label="Consented clients" value="28" delta="+2 this week" deltaKind="good" />
            <CoKpi label="Act now" value="2" delta="✕ no readings ≥ 5 days" deltaKind="act" />
            <CoKpi label="Watch" value="5" delta="▲ drifting from baseline" deltaKind="watch" />
            <CoKpi label="Consults today" value="4" delta="next 09:15" />
          </div>

          {/* two columns */}
          <div style={{ display: "grid", gridTemplateColumns: "minmax(0, 1.6fr) minmax(0, 1fr)", gap: 12, alignItems: "start" }}>
            <div style={{ minWidth: 0 }}>
              <div style={{ ...coKicker, margin: "0 0 9px" }}>Patterns worth acting on</div>
              <CoInsight kind="act" title="Citizen LV022 — no readings for 6 days"
                meaning="Last sync was Sun 7 Jun. Their share remains active; the gap itself is the pattern."
                suggested="Check in before the share expires on 12 Jul." />
              <CoInsight kind="watch" title="Citizen LV014 — fasting glucose drifting"
                meaning="Third week running above their own 90-day baseline. A pattern in their own data — not a medical finding." />
              <CoInsight kind="watch" title="Citizen LV001 — HRV dips track high-load workdays"
                meaning="Mornings after back-to-back meeting days show ~15% lower HRV in their data." />

              <div style={{ ...coTile, padding: 16, marginTop: 12 }}>
                <CoCardHead icon="activity" title="Cohort time in range — 14 days"
                  right={<span style={{ ...CO_KICK, fontSize: 9.5, color: "var(--c-kick)" }}>synthetic aggregate · k ≥ 11</span>} />
                <CoSpark />
                <div style={{ display: "flex", justifyContent: "space-between", marginTop: 8, fontFamily: CO_MONO, fontSize: 10.5, color: "var(--c-text3)", fontVariantNumeric: "tabular-nums" }}>
                  <span>31 May</span>
                  <span>target 70% (dashed)</span>
                  <span>13 Jun · <b style={{ color: "var(--c-good)", fontWeight: 600 }}>76%</b></span>
                </div>
              </div>
            </div>

            <div style={{ minWidth: 0, display: "grid", gap: 12 }}>
              <div style={{ ...coTile, padding: 16 }}>
                <CoCardHead icon="calendar-days" title="Today & upcoming" />
                <CoTimeRow when="09:15" label="Citizen LV014" kind="review" />
                <CoTimeRow when="14:30" label="Citizen LV001" kind="consult" />
                <CoTimeRow when="15:45" label="Citizen LV022" kind="check-in" />
                <CoTimeRow when="Mon · 10:00" label="Citizen LV031" kind="intake" last />
              </div>

              <div style={{ ...coTile, padding: 16 }}>
                <CoCardHead icon="shield-check" iconColor="var(--c-good)" title="Consent changes" />
                <CoConsentRow glyph="●" color="var(--c-good)" what="Granted" detail="LV031, sleep & recovery, 5 data groups" when="08:12" />
                <CoConsentRow glyph="▲" color="var(--c-watch)" what="Expiring" detail="LV014, renew by Tue 16 Jun" when="Tue" />
                <CoConsentRow glyph="✕" color="var(--c-act)" what="Revoked" detail="LV009 — view closed immediately" when="Thu" last />
                <div style={{ fontSize: 12, color: "var(--c-text3)", lineHeight: 1.5, marginTop: 10 }}>
                  Every change is evidenced on the consent ledger. The citizen can revoke in one tap.
                </div>
              </div>
            </div>
          </div>

          <div style={{ fontFamily: CO_MONO, fontSize: 10.5, color: "var(--c-text3)", marginTop: 26, fontVariantNumeric: "tabular-nums" }}>v09 · 13 Jun 2026</div>
        </main>
      </div>
    </div>
  );
}

window.ClinicalOpsDashboard = ClinicalOpsDashboard;
