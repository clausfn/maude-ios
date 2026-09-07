/* @ds-bundle: {"format":3,"namespace":"MaudeDesignSystem_af5aa6","components":[{"name":"Mark","sourcePath":"components/brand/Mark.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"ConsentChip","sourcePath":"components/core/ConsentChip.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"Input","sourcePath":"components/core/Input.jsx"},{"name":"Pill","sourcePath":"components/core/Pill.jsx"},{"name":"SegmentedControl","sourcePath":"components/core/SegmentedControl.jsx"},{"name":"Switch","sourcePath":"components/core/Switch.jsx"},{"name":"Insight","sourcePath":"components/health/Insight.jsx"},{"name":"KpiTile","sourcePath":"components/health/KpiTile.jsx"},{"name":"MetricRing","sourcePath":"components/health/MetricRing.jsx"},{"name":"NudgeCard","sourcePath":"components/health/NudgeCard.jsx"}],"sourceHashes":{"components/brand/Mark.jsx":"52d02e8c2580","components/core/Button.jsx":"98e69d3a6a62","components/core/Card.jsx":"dc8940416521","components/core/ConsentChip.jsx":"fe8c474e3c41","components/core/Icon.jsx":"c70971cb83cf","components/core/Input.jsx":"0ef6b9e65ace","components/core/Pill.jsx":"86018d0160e0","components/core/SegmentedControl.jsx":"b8dc7a8203f1","components/core/Switch.jsx":"d6a53a920d63","components/health/Insight.jsx":"96b3700952e6","components/health/KpiTile.jsx":"0621797f1676","components/health/MetricRing.jsx":"dc9f87b81720","components/health/NudgeCard.jsx":"dceab0522248","explorations/clinical-ops.jsx":"3b767e5cfdec","explorations/ios-frame.jsx":"be3343be4b51","explorations/mobile-home.jsx":"752c5caf98e9","maude-prototype/ios-frame.jsx":"be3343be4b51","maude-prototype/prototype.jsx":"70b0415b13f4","ui_kits/maude-app/app.jsx":"eef480135464","ui_kits/maude-app/ios-frame.jsx":"be3343be4b51","ui_kits/maude-console/browser-window.jsx":"7afe17ad52c6","ui_kits/maude-console/console.jsx":"e486b5efb2b0"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.MaudeDesignSystem_af5aa6 = window.MaudeDesignSystem_af5aa6 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/brand/Mark.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Maude Iris mark (A4 · Navy + Bright Fern) — ALWAYS embeds the brand SVG asset; never redraws the mark in code.
 * Pass `src` to point at where you copied /assets/brand into your project.
 * primary = navy + deep fern arc (light grounds) · reversed = paper + bright fern arc (navy grounds) · mono = all navy.
 */

const ASSET = {
  primary: "assets/brand/maude_mark_iris.svg",
  mono: "assets/brand/maude_mark_iris_mono.svg",
  reversed: "assets/brand/maude_mark_iris_reversed.svg"
};
function Mark({
  variant = "primary",
  size = 28,
  wordmark = false,
  src,
  style,
  ...rest
}) {
  const file = src ?? ASSET[variant] ?? ASSET.primary;
  const onDark = variant === "reversed";
  const img = /*#__PURE__*/React.createElement("img", {
    src: file,
    alt: "Maude",
    width: size,
    height: size,
    style: {
      display: "block",
      width: size,
      height: size
    }
  });
  if (!wordmark) {
    return /*#__PURE__*/React.createElement("span", _extends({
      style: {
        display: "inline-flex",
        ...style
      }
    }, rest), img);
  }
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: Math.round(size * 0.25),
      ...style
    }
  }, rest), img, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-serif)",
      fontWeight: 400,
      fontSize: Math.round(size * 0.98),
      letterSpacing: "-0.01em",
      color: onDark ? "var(--paper)" : "var(--ink)"
    }
  }, "Maude"));
}
Object.assign(__ds_scope, { Mark });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/brand/Mark.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Maude button. Primary = ink fill / paper text. Ghost = bordered. Secondary = paper fill.
 * Press state drops opacity to 0.85. Radius md. Weight 500.
 */
function Button({
  variant = "primary",
  size = "md",
  disabled = false,
  fullWidth = false,
  leadingIcon,
  trailingIcon,
  children,
  style,
  ...rest
}) {
  const sizes = {
    sm: {
      padding: "6px 12px",
      fontSize: 12.5
    },
    md: {
      padding: "8px 14px",
      fontSize: 13.5
    },
    lg: {
      padding: "11px 18px",
      fontSize: 15
    }
  };
  const variants = {
    primary: {
      background: "var(--ink)",
      color: "var(--paper)",
      border: "1px solid var(--ink)"
    },
    secondary: {
      background: "var(--paper)",
      color: "var(--ink-2)",
      border: "1px solid var(--line)"
    },
    ghost: {
      background: "transparent",
      color: "var(--ink)",
      border: "1px solid var(--line)"
    },
    accent: {
      background: "var(--moss)",
      color: "#fff",
      border: "1px solid var(--moss)"
    },
    danger: {
      background: "var(--paper)",
      color: "var(--rust)",
      border: "1px solid var(--rust)"
    }
  };
  return /*#__PURE__*/React.createElement("button", _extends({
    disabled: disabled,
    style: {
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      gap: 7,
      width: fullWidth ? "100%" : undefined,
      fontFamily: "var(--font-sans)",
      fontWeight: 500,
      lineHeight: 1.1,
      borderRadius: "var(--radius-md)",
      cursor: disabled ? "default" : "pointer",
      opacity: disabled ? 0.45 : 1,
      transition: "opacity 0.15s ease, border-color 0.15s ease",
      ...sizes[size],
      ...variants[variant],
      ...style
    },
    onMouseDown: e => {
      if (!disabled) e.currentTarget.style.opacity = "0.85";
    },
    onMouseUp: e => {
      if (!disabled) e.currentTarget.style.opacity = "1";
    },
    onMouseLeave: e => {
      if (!disabled) e.currentTarget.style.opacity = "1";
    }
  }, rest), leadingIcon, children, trailingIcon);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Maude card — paper-2 fill, 0.5px line border, radius lg, the one approved shadow.
 * `accent` adds the meaningful coloured left-rule (moss/amber/rust). `inverse` = ink card.
 */
function Card({
  accent,
  inverse = false,
  interactive = false,
  padding = 14,
  children,
  style,
  ...rest
}) {
  const accentColor = {
    moss: "var(--moss)",
    amber: "var(--amber)",
    rust: "var(--rust)"
  }[accent];
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      position: "relative",
      background: inverse ? "var(--ink)" : "var(--paper-2)",
      color: inverse ? "var(--paper)" : "var(--ink-2)",
      border: inverse ? "1px solid var(--ink)" : "0.5px solid var(--line)",
      borderRadius: "var(--radius-lg)",
      boxShadow: "var(--shadow-card)",
      padding,
      borderLeft: accentColor ? `3px solid ${accentColor}` : undefined,
      cursor: interactive ? "pointer" : undefined,
      transition: "border-color 0.15s ease",
      ...style
    },
    onMouseEnter: e => {
      if (interactive && !accentColor) e.currentTarget.style.borderColor = "var(--moss)";
    },
    onMouseLeave: e => {
      if (interactive && !accentColor) e.currentTarget.style.borderColor = "var(--line)";
    }
  }, rest), children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/ConsentChip.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Consent / boundary chip — the product's signature element. The persistent
 * "Private / consented" indicator: moss-2 fill, moss-3 border, moss text, a 6px moss dot.
 */
function ConsentChip({
  label = "Private · consented",
  state = "consented",
  style,
  ...rest
}) {
  const states = {
    consented: {
      bg: "var(--moss-2)",
      fg: "var(--moss)",
      bd: "var(--moss-3)",
      dot: "var(--moss)"
    },
    private: {
      bg: "var(--moss-2)",
      fg: "var(--moss)",
      bd: "var(--moss-3)",
      dot: "var(--moss)"
    },
    revoked: {
      bg: "var(--rust-2)",
      fg: "var(--rust)",
      bd: "transparent",
      dot: "var(--rust)"
    },
    expired: {
      bg: "var(--line-2)",
      fg: "var(--ink-3)",
      bd: "transparent",
      dot: "var(--ink-4)"
    }
  };
  const s = states[state] ?? states.consented;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 7,
      padding: "5px 11px",
      borderRadius: "var(--radius-pill)",
      fontFamily: "var(--font-sans)",
      fontSize: 11,
      fontWeight: 700,
      lineHeight: 1.2,
      background: s.bg,
      color: s.fg,
      border: `1px solid ${s.bd}`,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: "50%",
      background: s.dot,
      flex: "none"
    }
  }), label);
}
Object.assign(__ds_scope, { ConsentChip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/ConsentChip.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Icon — thin wrapper over Lucide (our flagged substitute for the app's SF Symbols).
 * Requires the Lucide UMD script loaded globally (window.lucide). Accepts kebab or
 * PascalCase names. Defaults: 18px, currentColor, 1.75 stroke (SF-Symbols-like).
 */
function toPascal(name) {
  return String(name).replace(/(^\w|-\w)/g, m => m.replace("-", "").toUpperCase());
}
function renderNode(arr) {
  return arr.map((child, i) => {
    if (!Array.isArray(child)) return null;
    if (typeof child[0] === "string") {
      const kids = Array.isArray(child[2]) ? renderNode(child[2]) : null;
      return React.createElement(child[0], {
        key: i,
        ...(child[1] || {})
      }, kids);
    }
    return renderNode(child);
  });
}
function Icon({
  name,
  size = 18,
  color = "currentColor",
  stroke = 1.75,
  style,
  ...rest
}) {
  const lib = typeof window !== "undefined" ? window.lucide : undefined;
  const node = lib && lib.icons ? lib.icons[toPascal(name)] || lib.icons[name] : null;
  if (!node) {
    // Fallback: a neutral dot so layouts never break if Lucide isn't present.
    return /*#__PURE__*/React.createElement("span", _extends({
      "aria-hidden": "true",
      style: {
        display: "inline-block",
        width: size,
        height: size,
        ...style
      }
    }, rest));
  }
  return /*#__PURE__*/React.createElement("svg", _extends({
    xmlns: "http://www.w3.org/2000/svg",
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: color,
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: {
      display: "block",
      flex: "none",
      ...style
    }
  }, rest), renderNode(node));
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/core/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Text input with optional label and mono kicker. White fill, line border, radius sm.
 * Focus ring uses moss. Supports `invalid` (rust) state.
 */
function Input({
  label,
  hint,
  invalid = false,
  mono = false,
  style,
  id,
  ...rest
}) {
  const inputId = id || (label ? `in-${label.replace(/\s+/g, "-").toLowerCase()}` : undefined);
  const [focused, setFocused] = React.useState(false);
  const borderColor = invalid ? "var(--rust)" : focused ? "var(--moss)" : "var(--line)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 6,
      ...style
    }
  }, label && /*#__PURE__*/React.createElement("label", {
    htmlFor: inputId,
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 10.5,
      fontWeight: 500,
      letterSpacing: "1px",
      textTransform: "uppercase",
      color: "var(--ink-3)"
    }
  }, label), /*#__PURE__*/React.createElement("input", _extends({
    id: inputId,
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    style: {
      fontFamily: mono ? "var(--font-mono)" : "var(--font-sans)",
      fontSize: 14,
      color: "var(--ink)",
      background: "#fff",
      border: `1px solid ${borderColor}`,
      borderRadius: "var(--radius-sm)",
      padding: "11px 12px",
      outline: "none",
      boxShadow: focused && !invalid ? "0 0 0 3px var(--moss-2)" : "none",
      transition: "border-color 0.15s ease, box-shadow 0.15s ease"
    }
  }, rest)), hint && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: invalid ? "var(--rust)" : "var(--ink-3)"
    }
  }, hint));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Input.jsx", error: String((e && e.message) || e) }); }

// components/core/Pill.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Pill / badge. Tones map to brand meaning: moss = consent, amber = engine/watch,
 * rust = boundary/refusal, neutral = informational. Optional leading dot.
 */
function Pill({
  tone = "neutral",
  dot = false,
  children,
  style,
  ...rest
}) {
  const tones = {
    moss: {
      bg: "var(--moss-2)",
      fg: "var(--moss)",
      bd: "var(--moss-3)"
    },
    amber: {
      bg: "var(--amber-2)",
      fg: "var(--amber-text)",
      bd: "transparent"
    },
    rust: {
      bg: "var(--rust-2)",
      fg: "var(--rust)",
      bd: "transparent"
    },
    neutral: {
      bg: "var(--line-2)",
      fg: "var(--ink-2)",
      bd: "transparent"
    },
    ink: {
      bg: "var(--ink)",
      fg: "var(--paper)",
      bd: "transparent"
    }
  };
  const t = tones[tone] ?? tones.neutral;
  return /*#__PURE__*/React.createElement("span", _extends({
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5,
      padding: "4px 9px",
      borderRadius: "var(--radius-pill)",
      fontFamily: "var(--font-sans)",
      fontSize: 11,
      fontWeight: 700,
      lineHeight: 1.2,
      background: t.bg,
      color: t.fg,
      border: `1px solid ${t.bd}`,
      ...style
    }
  }, rest), dot && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: "50%",
      background: "currentColor"
    }
  }), children);
}
Object.assign(__ds_scope, { Pill });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Pill.jsx", error: String((e && e.message) || e) }); }

// components/core/SegmentedControl.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Segmented control — the inline pill segment from v08 (.seg) and the iOS tab picker.
 * Active segment = ink fill / white text. Options: [{value,label,icon?}] or string[].
 */
function SegmentedControl({
  options = [],
  value,
  onChange,
  size = "md",
  style,
  ...rest
}) {
  const opts = options.map(o => typeof o === "string" ? {
    value: o,
    label: o
  } : o);
  const pad = size === "sm" ? "6px 11px" : "8px 14px";
  const fs = size === "sm" ? 11.5 : 12.5;
  return /*#__PURE__*/React.createElement("div", _extends({
    role: "tablist",
    style: {
      display: "inline-flex",
      border: "1px solid var(--line)",
      borderRadius: "var(--radius-md)",
      overflow: "hidden",
      background: "#fff",
      ...style
    }
  }, rest), opts.map((o, i) => {
    const on = o.value === value;
    return /*#__PURE__*/React.createElement("button", {
      key: o.value,
      role: "tab",
      "aria-selected": on,
      onClick: () => onChange && onChange(o.value),
      style: {
        display: "inline-flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 6,
        padding: pad,
        fontFamily: "var(--font-sans)",
        fontSize: fs,
        fontWeight: 700,
        border: "none",
        borderLeft: i === 0 ? "none" : "1px solid var(--line)",
        background: on ? "var(--ink)" : "transparent",
        color: on ? "#fff" : "var(--ink-3)",
        cursor: "pointer",
        transition: "background 0.18s ease, color 0.18s ease"
      }
    }, o.icon, o.label);
  }));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/core/Switch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Switch — moss when on, line when off. The track/knob from the iOS WalletSwitch.
 */
function Switch({
  checked = false,
  onChange,
  disabled = false,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    role: "switch",
    "aria-checked": checked,
    disabled: disabled,
    onClick: () => !disabled && onChange && onChange(!checked),
    style: {
      position: "relative",
      width: 40,
      height: 24,
      borderRadius: "var(--radius-pill)",
      border: "none",
      background: checked ? "var(--moss)" : "var(--line)",
      cursor: disabled ? "default" : "pointer",
      opacity: disabled ? 0.5 : 1,
      transition: "background 0.18s ease",
      padding: 0,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      top: 3,
      left: checked ? 19 : 3,
      width: 18,
      height: 18,
      borderRadius: "50%",
      background: "#fff",
      boxShadow: "0 1px 2px rgba(14,26,43,0.25)",
      transition: "left 0.18s ease"
    }
  }));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Switch.jsx", error: String((e && e.message) || e) }); }

// components/health/Insight.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * Insight — the console's "pattern worth acting on" card. 4px left-rule encodes severity
 * (amber default/watch, rust high, moss info). Severity dot, title, meaning, suggested
 * action chip, optional action buttons. From v08 `.insight`.
 */
const SEV = {
  high: "var(--rust)",
  watch: "var(--amber)",
  info: "var(--moss)",
  low: "var(--amber)"
};
function Insight({
  severity = "watch",
  title,
  meaning,
  suggested,
  actions = [],
  onAction,
  style,
  ...rest
}) {
  const color = SEV[severity] ?? SEV.watch;
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      background: "var(--paper-2)",
      border: "0.5px solid var(--line)",
      borderLeft: `4px solid ${color}`,
      borderRadius: "var(--radius-lg)",
      boxShadow: "var(--shadow-card)",
      padding: "13px 15px",
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      alignItems: "flex-start"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 9,
      height: 9,
      borderRadius: "50%",
      background: color,
      marginTop: 5,
      flex: "none"
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontWeight: 800,
      fontSize: 14,
      color: "var(--ink)",
      lineHeight: 1.3
    }
  }, title)), meaning && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12.5,
      color: "var(--ink-2)",
      margin: "5px 0",
      lineHeight: 1.45
    }
  }, meaning), suggested && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12.5,
      color: "var(--ink)",
      background: "var(--moss-2)",
      border: "1px solid var(--moss-3)",
      borderRadius: "var(--radius-sm)",
      padding: "7px 10px",
      marginTop: 7
    }
  }, /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--moss-text-dark)"
    }
  }, "Suggested:"), " ", suggested), actions.length > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 7,
      marginTop: 9,
      flexWrap: "wrap"
    }
  }, actions.map((a, i) => /*#__PURE__*/React.createElement("button", {
    key: a,
    onClick: () => onAction && onAction(a),
    style: {
      fontSize: 11.5,
      fontWeight: 800,
      border: i === 0 ? "1px solid var(--moss)" : "1px solid var(--line)",
      borderRadius: "var(--radius-sm)",
      padding: "6px 10px",
      background: i === 0 ? "var(--moss)" : "#fff",
      color: i === 0 ? "#fff" : "var(--ink-2)",
      cursor: "pointer"
    }
  }, a))));
}
Object.assign(__ds_scope, { Insight });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/health/Insight.jsx", error: String((e && e.message) || e) }); }

// components/health/KpiTile.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * KpiTile — the console's clickable stat card. Mono uppercase label (h3), big number
 * with a small unit, and a delta/granularity line. From v08 `.kpi`.
 */
function KpiTile({
  label,
  value,
  unit,
  delta,
  trend = "flat",
  onClick,
  style,
  ...rest
}) {
  const trendColor = {
    up: "var(--moss-text-dark)",
    down: "var(--rust)",
    flat: "var(--ink-3)"
  }[trend];
  return /*#__PURE__*/React.createElement("div", _extends({
    onClick: onClick,
    style: {
      background: "var(--paper-2)",
      border: "0.5px solid var(--line)",
      borderRadius: "var(--radius-lg)",
      boxShadow: "var(--shadow-card)",
      padding: 14,
      cursor: onClick ? "pointer" : undefined,
      transition: "border-color 0.15s ease",
      ...style
    },
    onMouseEnter: e => {
      if (onClick) e.currentTarget.style.borderColor = "var(--moss)";
    },
    onMouseLeave: e => {
      if (onClick) e.currentTarget.style.borderColor = "var(--line)";
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 10,
      fontWeight: 600,
      letterSpacing: "0.1em",
      textTransform: "uppercase",
      color: "var(--ink-3)",
      marginBottom: 5
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 22,
      fontWeight: 800,
      letterSpacing: "-0.02em",
      color: "var(--ink)",
      lineHeight: 1.1
    }
  }, value, unit && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11,
      color: "var(--ink-3)",
      fontWeight: 700,
      marginLeft: 2
    }
  }, unit)), delta && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      fontWeight: 800,
      marginTop: 2,
      color: trendColor
    }
  }, delta));
}
Object.assign(__ds_scope, { KpiTile });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/health/KpiTile.jsx", error: String((e && e.message) || e) }); }

// components/health/MetricRing.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * MetricRing — circular progress, moss arc on a line-2 track (amber when `warn`).
 * Centre value in tabular mono, uppercase label below. From the iOS MetricRingCard.
 */
function MetricRing({
  value,
  label,
  progress = 0,
  warn = false,
  size = 80,
  stroke = 7.5,
  style,
  ...rest
}) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const p = Math.max(0, Math.min(1, progress));
  const arcColor = warn ? "var(--amber)" : "var(--moss)";
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 8,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: size,
      height: size
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    style: {
      transform: "rotate(-90deg)"
    }
  }, /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r,
    fill: "none",
    stroke: "var(--line-2)",
    strokeWidth: stroke
  }), /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r,
    fill: "none",
    stroke: arcColor,
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeDasharray: c,
    strokeDashoffset: c * (1 - p),
    style: {
      transition: "stroke-dashoffset 0.5s ease"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontFamily: "var(--font-mono)",
      fontVariantNumeric: "tabular-nums",
      fontWeight: 600,
      fontSize: size * 0.2,
      color: "var(--ink)"
    }
  }, value)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 9.5,
      letterSpacing: "1px",
      textTransform: "uppercase",
      color: "var(--ink-3)",
      textAlign: "center",
      maxWidth: size + 24
    }
  }, label));
}
Object.assign(__ds_scope, { MetricRing });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/health/MetricRing.jsx", error: String((e && e.message) || e) }); }

// components/health/NudgeCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
/**
 * NudgeCard — the citizen app's signature feed item. Paper-2 fill, 3px moss left-rule
 * (recoloured by accent), mono "time · TAG" kicker, describe-don't-prescribe body,
 * optional actions. Accent maps to topic, not severity.
 */
const ACCENTS = {
  sleep: "var(--moss)",
  glucose: "var(--amber)",
  cardiac: "var(--ink-3)",
  travel: "var(--rust)",
  general: "var(--ink-4)"
};
function NudgeCard({
  time,
  tag,
  accent = "general",
  body,
  primaryAction,
  secondaryActions = [],
  onPrimary,
  onSecondary,
  style,
  ...rest
}) {
  const accentColor = ACCENTS[accent] ?? ACCENTS.general;
  return /*#__PURE__*/React.createElement("div", _extends({
    style: {
      position: "relative",
      background: "var(--paper-2)",
      border: "0.5px solid var(--line)",
      borderLeft: `3px solid ${accentColor}`,
      borderRadius: "var(--radius-md)",
      boxShadow: "var(--shadow-card)",
      padding: 14,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 10,
      letterSpacing: "1.2px",
      textTransform: "uppercase",
      marginBottom: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--ink-3)"
    }
  }, time), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--ink-3)"
    }
  }, " \xB7 "), /*#__PURE__*/React.createElement("span", {
    style: {
      color: accentColor
    }
  }, tag)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 14.5,
      lineHeight: 1.45,
      color: "var(--ink-2)"
    }
  }, body), (primaryAction || secondaryActions.length > 0) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      marginTop: 12,
      flexWrap: "wrap"
    }
  }, primaryAction && /*#__PURE__*/React.createElement("button", {
    onClick: onPrimary,
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 12.5,
      fontWeight: 500,
      padding: "8px 14px",
      background: "var(--ink)",
      color: "#fff",
      border: "none",
      borderRadius: "var(--radius-md)",
      cursor: "pointer"
    }
  }, primaryAction), secondaryActions.map(label => /*#__PURE__*/React.createElement("button", {
    key: label,
    onClick: () => onSecondary && onSecondary(label),
    style: {
      fontFamily: "var(--font-sans)",
      fontSize: 12.5,
      fontWeight: 500,
      padding: "8px 14px",
      background: "var(--paper)",
      color: "var(--ink-2)",
      border: "1px solid var(--line)",
      borderRadius: "var(--radius-md)",
      cursor: "pointer"
    }
  }, label))));
}
Object.assign(__ds_scope, { NudgeCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/health/NudgeCard.jsx", error: String((e && e.message) || e) }); }

// explorations/clinical-ops.jsx
try { (() => {
// Clinical Ops dashboard — Maude B2B console (light clinical console).
// Hanken Grotesk headings, Public Sans UI/body, IBM Plex Mono numbers.
// Lucide icons (stroke 1.75). White grounds, navy floating chrome, elevation hierarchy.
// Status triplets ● ▲ ✕ in day-form colours. No glass, no gradients — shadows do the lift.

const CO_BRAND = "../assets/brand/";
const CO_SERIF = "var(--font-serif)";
const CO_HEAD = {
  fontFamily: "var(--font-serif)",
  fontWeight: 700,
  letterSpacing: "-0.01em"
}; // headings: Hanken Grotesk (body is Public Sans)
const CO_MONO = "var(--font-mono)";
const CO_KICK = {
  fontFamily: CO_MONO,
  textTransform: "uppercase",
  letterSpacing: "0.1em",
  fontWeight: 600
};

// ── Lucide wrapper (same contract as components/core/Icon.jsx) ──
function coToPascal(name) {
  return String(name).replace(/(^\w|-\w)/g, m => m.replace("-", "").toUpperCase());
}
function coRenderNode(arr) {
  return arr.map((child, i) => {
    if (!Array.isArray(child)) return null;
    if (typeof child[0] === "string") {
      const kids = Array.isArray(child[2]) ? coRenderNode(child[2]) : null;
      return React.createElement(child[0], {
        key: i,
        ...(child[1] || {})
      }, kids);
    }
    return coRenderNode(child);
  });
}
function CoIcon({
  name,
  size = 18,
  color = "currentColor",
  stroke = 1.75,
  style
}) {
  const lib = typeof window !== "undefined" ? window.lucide : undefined;
  const node = lib && lib.icons ? lib.icons[coToPascal(name)] || lib.icons[name] : null;
  if (!node) return /*#__PURE__*/React.createElement("span", {
    "aria-hidden": "true",
    style: {
      display: "inline-block",
      width: size,
      height: size,
      ...style
    }
  });
  return /*#__PURE__*/React.createElement("svg", {
    xmlns: "http://www.w3.org/2000/svg",
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: color,
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: {
      display: "block",
      flex: "none",
      ...style
    },
    "aria-hidden": "true"
  }, coRenderNode(node));
}
function CoMark({
  size = 22
}) {
  return /*#__PURE__*/React.createElement("img", {
    src: CO_BRAND + "maude_mark_iris.svg",
    alt: "Maude",
    width: size,
    height: size,
    style: {
      display: "block"
    }
  });
}

// ── Status triplets — shape + word + colour, never colour alone ──
const CO_TRIPLET = {
  good: {
    glyph: "●",
    word: "WITHIN RANGE"
  },
  watch: {
    glyph: "▲",
    word: "WATCH"
  },
  act: {
    glyph: "✕",
    word: "ACT NOW"
  }
};
function CoStatusChip({
  kind
}) {
  const t = CO_TRIPLET[kind];
  const base = {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    fontFamily: CO_MONO,
    fontSize: 10.5,
    fontWeight: 600,
    letterSpacing: "0.06em",
    padding: "4px 9px",
    borderRadius: 3,
    whiteSpace: "nowrap"
  };
  if (kind === "watch") {
    return /*#__PURE__*/React.createElement("span", {
      style: {
        ...base,
        background: "var(--c-watch)",
        color: "var(--c-text)"
      }
    }, t.glyph, " ", t.word);
  }
  const color = kind === "good" ? "var(--c-good)" : "var(--c-act)";
  const line = kind === "good" ? "var(--c-good-line)" : "var(--c-act-line)";
  return /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      color,
      border: `1px solid ${line}`,
      background: "transparent"
    }
  }, t.glyph, " ", t.word);
}

// ── Shared surfaces ──
const coTile = {
  background: "var(--c-tile)",
  border: "1px solid var(--c-line)",
  borderRadius: 10,
  boxShadow: "var(--sh-card)"
};
const coKicker = {
  ...CO_KICK,
  fontSize: 10,
  color: "var(--c-text3)",
  margin: 0
};
const coPrimaryBtn = {
  all: "unset",
  display: "inline-flex",
  alignItems: "center",
  gap: 8,
  boxSizing: "border-box",
  whiteSpace: "nowrap",
  flex: "none",
  background: "var(--c-btn-bg)",
  color: "var(--c-btn-text)",
  fontWeight: 700,
  fontSize: 13,
  padding: "10px 16px",
  borderRadius: 9,
  cursor: "pointer"
};
const coGhostBtn = {
  all: "unset",
  display: "inline-flex",
  alignItems: "center",
  gap: 7,
  boxSizing: "border-box",
  cursor: "pointer",
  fontSize: 11.5,
  fontWeight: 600,
  color: "var(--c-text2)",
  border: "1px solid var(--c-line)",
  borderRadius: 8,
  padding: "6px 11px",
  background: "transparent"
};
function CoCardHead({
  icon,
  iconColor,
  title,
  right
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: icon,
    size: 16,
    color: iconColor || "var(--c-text3)"
  }), /*#__PURE__*/React.createElement("h2", {
    style: {
      ...CO_HEAD,
      fontSize: 15.5,
      margin: 0,
      flex: 1
    }
  }, title), right);
}

// ── Nav ──
function CoNavItem({
  icon,
  label,
  on,
  locked,
  badge
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 9,
      padding: "8px 10px",
      borderRadius: 8,
      fontSize: 13,
      fontWeight: on ? 700 : 500,
      cursor: locked ? "default" : "pointer",
      opacity: locked ? 0.45 : 1,
      background: on ? "var(--c-text)" : "transparent",
      color: on ? "#FFFFFF" : "var(--c-text2)"
    }
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: icon,
    size: 16,
    color: on ? "#FFFFFF" : "var(--c-text3)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }, label), badge && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 10,
      fontVariantNumeric: "tabular-nums",
      color: on ? "rgba(255,255,255,.7)" : "var(--c-text3)"
    }
  }, badge));
}
function CoNavGroup({
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...CO_KICK,
      fontSize: 9.5,
      color: "var(--c-text3)",
      margin: "15px 8px 6px"
    }
  }, children);
}

// ── KPI tile ──
function CoKpi({
  label,
  value,
  unit,
  delta,
  deltaKind
}) {
  const deltaColor = deltaKind === "act" ? "var(--c-act)" : deltaKind === "watch" ? "var(--c-text)" : deltaKind === "good" ? "var(--c-good)" : "var(--c-text3)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...coTile,
      padding: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...coKicker,
      marginBottom: 6
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 26,
      fontWeight: 500,
      fontVariantNumeric: "tabular-nums",
      color: "var(--c-text)"
    }
  }, value, unit && /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      color: "var(--c-text3)",
      marginLeft: 4
    }
  }, unit)), delta && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 11,
      fontVariantNumeric: "tabular-nums",
      color: deltaColor,
      marginTop: 5
    }
  }, delta));
}

// ── Insight row ──
function CoInsight({
  kind,
  title,
  meaning,
  suggested
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...coTile,
      padding: "15px 17px",
      marginBottom: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "flex-start",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontWeight: 700,
      fontSize: 14.5,
      color: "var(--c-text)"
    }
  }, title), /*#__PURE__*/React.createElement(CoStatusChip, {
    kind: kind
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--c-text2)",
      margin: "6px 0 0",
      lineHeight: 1.5
    }
  }, meaning), suggested && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--c-text2)",
      borderTop: "1px dashed var(--c-line)",
      paddingTop: 8,
      marginTop: 9,
      lineHeight: 1.5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      ...CO_KICK,
      fontSize: 9.5,
      color: "var(--c-kick)",
      marginRight: 8
    }
  }, "Suggested"), suggested), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 7,
      marginTop: 11,
      flexWrap: "wrap"
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: {
      ...coGhostBtn,
      color: "var(--c-text)",
      borderColor: "var(--c-text3)"
    }
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: "message-square",
    size: 13
  }), " Message client"), /*#__PURE__*/React.createElement("button", {
    style: coGhostBtn
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: "clipboard-list",
    size: 13
  }), " Add to plan"), /*#__PURE__*/React.createElement("button", {
    style: coGhostBtn
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: "flag",
    size: 13
  }), " Flag for review"), /*#__PURE__*/React.createElement("button", {
    style: coGhostBtn
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: "check",
    size: 13
  }), " Mark addressed")));
}

// ── Spare sparkline — time in range, 14 days, cohort (synthetic, k ≥ 11) ──
function CoSpark() {
  const vals = [71, 72, 70, 73, 74, 72, 75, 74, 76, 74, 73, 75, 77, 76];
  const W = 560,
    H = 96,
    lo = 64,
    hi = 82;
  const x = i => i / (vals.length - 1) * W;
  const y = v => H - (v - lo) / (hi - lo) * H;
  const line = vals.map((v, i) => `${i ? "L" : "M"}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(" ");
  const area = `${line} L${W},${H} L0,${H} Z`;
  const target = y(70);
  return /*#__PURE__*/React.createElement("svg", {
    viewBox: `0 0 ${W} ${H}`,
    style: {
      width: "100%",
      height: "auto",
      display: "block"
    },
    role: "img",
    "aria-label": "Cohort time in range, last 14 days, between 70 and 77 percent"
  }, /*#__PURE__*/React.createElement("path", {
    d: area,
    fill: "var(--c-good)",
    opacity: "0.12"
  }), /*#__PURE__*/React.createElement("line", {
    x1: "0",
    y1: target,
    x2: W,
    y2: target,
    stroke: "var(--c-line)",
    strokeDasharray: "4 5"
  }), /*#__PURE__*/React.createElement("path", {
    d: line,
    fill: "none",
    stroke: "var(--c-good)",
    strokeWidth: "2"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: x(13),
    cy: y(76),
    r: "3.5",
    fill: "var(--c-good)"
  }));
}

// ── Row primitives ──
function CoTimeRow({
  when,
  label,
  kind,
  last
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "baseline",
      gap: 12,
      fontSize: 13,
      padding: "8px 0",
      borderBottom: last ? "none" : "1px solid var(--c-line)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--c-text2)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 12,
      color: "var(--c-text)",
      fontVariantNumeric: "tabular-nums"
    }
  }, when), " \u2014 ", label), /*#__PURE__*/React.createElement("span", {
    style: {
      ...CO_KICK,
      fontSize: 10,
      color: "var(--c-kick)",
      whiteSpace: "nowrap"
    }
  }, kind));
}
function CoConsentRow({
  glyph,
  color,
  what,
  detail,
  when,
  last
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 10,
      padding: "9px 0",
      borderBottom: last ? "none" : "1px solid var(--c-line)",
      alignItems: "baseline"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 11,
      color,
      width: 12,
      flex: "none"
    }
  }, glyph), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      fontSize: 13,
      lineHeight: 1.45
    }
  }, /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--c-text)",
      fontWeight: 700
    }
  }, what), /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--c-text2)"
    }
  }, " \u2014 ", detail)), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 11,
      color: "var(--c-text3)",
      fontVariantNumeric: "tabular-nums",
      flex: "none"
    }
  }, when));
}

// ───────────────────────── Dashboard ─────────────────────────
function ClinicalOpsDashboard() {
  return /*#__PURE__*/React.createElement("div", {
    className: "lqc",
    "data-screen-label": "Clinical Ops dashboard",
    style: {
      minHeight: "100vh",
      background: "var(--c-ground)",
      color: "var(--c-text)",
      fontFamily: "var(--font-sans)",
      padding: "10px 10px 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--c-tile)",
      borderRadius: 14,
      boxShadow: "var(--sh-bar)",
      padding: "11px 18px",
      position: "sticky",
      top: 10,
      zIndex: 30
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 1340,
      margin: "0 auto",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 9
    }
  }, /*#__PURE__*/React.createElement(CoMark, {
    size: 22
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...CO_HEAD,
      fontSize: 18
    }
  }, "Maude"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 11.5,
      color: "var(--c-text3)",
      marginLeft: 6,
      whiteSpace: "nowrap"
    }
  }, "\xB7 clinical ops")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      flex: "none"
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: coGhostBtn
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: "search",
    size: 14
  }), " Find client"), /*#__PURE__*/React.createElement("button", {
    style: coGhostBtn
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: "bell",
    size: 14
  }), " Alerts"), /*#__PURE__*/React.createElement("button", {
    style: coGhostBtn
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: "log-out",
    size: 14
  }), " Sign out")))), /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 1340,
      margin: "0 auto",
      display: "grid",
      gridTemplateColumns: "212px 1fr",
      gap: 18,
      alignItems: "start",
      padding: "18px 8px 40px"
    }
  }, /*#__PURE__*/React.createElement("nav", {
    style: {
      background: "var(--c-tile)",
      borderRadius: 12,
      boxShadow: "var(--sh-panel)",
      padding: "16px 12px",
      position: "sticky",
      top: 78
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 9,
      marginBottom: 12,
      padding: "0 2px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 34,
      height: 34,
      borderRadius: 8,
      display: "grid",
      placeItems: "center",
      fontFamily: CO_MONO,
      fontWeight: 600,
      fontSize: 12,
      background: "var(--c-ground)",
      border: "1px solid var(--c-line)",
      color: "var(--c-text)"
    }
  }, "DN"), /*#__PURE__*/React.createElement("div", {
    style: {
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 700,
      fontSize: 13,
      lineHeight: 1.2,
      whiteSpace: "nowrap"
    }
  }, "Diabetes nurse"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: "var(--c-text3)"
    }
  }, "Consented clients"))), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      fontFamily: CO_MONO,
      fontSize: 10,
      fontWeight: 600,
      letterSpacing: "0.05em",
      padding: "4px 9px",
      borderRadius: 3,
      marginBottom: 8,
      color: "var(--c-good)",
      border: "1px solid var(--c-good-line)"
    }
  }, "\u25CF CONSENTED"), /*#__PURE__*/React.createElement(CoNavGroup, null, "Worklist"), /*#__PURE__*/React.createElement(CoNavItem, {
    icon: "layout-dashboard",
    label: "Dashboard",
    on: true
  }), /*#__PURE__*/React.createElement(CoNavItem, {
    icon: "users",
    label: "Your clients",
    badge: "28"
  }), /*#__PURE__*/React.createElement(CoNavItem, {
    icon: "message-square",
    label: "Messages",
    badge: "3"
  }), /*#__PURE__*/React.createElement(CoNavItem, {
    icon: "calendar-days",
    label: "Appointments"
  }), /*#__PURE__*/React.createElement(CoNavGroup, null, "Organisation"), /*#__PURE__*/React.createElement(CoNavItem, {
    icon: "shield-check",
    label: "Consent ledger"
  }), /*#__PURE__*/React.createElement(CoNavItem, {
    icon: "chart-column",
    label: "Cohort (Mode B)",
    locked: true
  }), /*#__PURE__*/React.createElement(CoNavItem, {
    icon: "settings",
    label: "Admin",
    locked: true
  })), /*#__PURE__*/React.createElement("main", {
    style: {
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-start",
      justifyContent: "space-between",
      gap: 14,
      flexWrap: "wrap"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("h1", {
    style: {
      ...CO_HEAD,
      fontSize: 25,
      margin: 0
    }
  }, "Clinical ops"), /*#__PURE__*/React.createElement("p", {
    style: {
      color: "var(--c-text2)",
      margin: "6px 0 0",
      fontSize: 14,
      lineHeight: 1.5,
      maxWidth: 620
    }
  }, "28 citizens have consented to share with your organisation. Everything below is a derived view \u2014 raw data never leaves their devices."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 11.5,
      color: "var(--c-text3)",
      fontVariantNumeric: "tabular-nums",
      marginTop: 6
    }
  }, "Sat \xB7 13 Jun \xB7 updated 08:42")), /*#__PURE__*/React.createElement("button", {
    style: coPrimaryBtn
  }, /*#__PURE__*/React.createElement(CoIcon, {
    name: "plus",
    size: 15,
    stroke: 2.25
  }), " Patient triage")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "repeat(4, 1fr)",
      gap: 12,
      margin: "18px 0"
    }
  }, /*#__PURE__*/React.createElement(CoKpi, {
    label: "Consented clients",
    value: "28",
    delta: "+2 this week",
    deltaKind: "good"
  }), /*#__PURE__*/React.createElement(CoKpi, {
    label: "Act now",
    value: "2",
    delta: "\u2715 no readings \u2265 5 days",
    deltaKind: "act"
  }), /*#__PURE__*/React.createElement(CoKpi, {
    label: "Watch",
    value: "5",
    delta: "\u25B2 drifting from baseline",
    deltaKind: "watch"
  }), /*#__PURE__*/React.createElement(CoKpi, {
    label: "Consults today",
    value: "4",
    delta: "next 09:15"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "minmax(0, 1.6fr) minmax(0, 1fr)",
      gap: 12,
      alignItems: "start"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...coKicker,
      margin: "0 0 9px"
    }
  }, "Patterns worth acting on"), /*#__PURE__*/React.createElement(CoInsight, {
    kind: "act",
    title: "Citizen LV022 \u2014 no readings for 6 days",
    meaning: "Last sync was Sun 7 Jun. Their share remains active; the gap itself is the pattern.",
    suggested: "Check in before the share expires on 12 Jul."
  }), /*#__PURE__*/React.createElement(CoInsight, {
    kind: "watch",
    title: "Citizen LV014 \u2014 fasting glucose drifting",
    meaning: "Third week running above their own 90-day baseline. A pattern in their own data \u2014 not a medical finding."
  }), /*#__PURE__*/React.createElement(CoInsight, {
    kind: "watch",
    title: "Citizen LV001 \u2014 HRV dips track high-load workdays",
    meaning: "Mornings after back-to-back meeting days show ~15% lower HRV in their data."
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      ...coTile,
      padding: 16,
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(CoCardHead, {
    icon: "activity",
    title: "Cohort time in range \u2014 14 days",
    right: /*#__PURE__*/React.createElement("span", {
      style: {
        ...CO_KICK,
        fontSize: 9.5,
        color: "var(--c-kick)"
      }
    }, "synthetic aggregate \xB7 k \u2265 11")
  }), /*#__PURE__*/React.createElement(CoSpark, null), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      marginTop: 8,
      fontFamily: CO_MONO,
      fontSize: 10.5,
      color: "var(--c-text3)",
      fontVariantNumeric: "tabular-nums"
    }
  }, /*#__PURE__*/React.createElement("span", null, "31 May"), /*#__PURE__*/React.createElement("span", null, "target 70% (dashed)"), /*#__PURE__*/React.createElement("span", null, "13 Jun \xB7 ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--c-good)",
      fontWeight: 600
    }
  }, "76%"))))), /*#__PURE__*/React.createElement("div", {
    style: {
      minWidth: 0,
      display: "grid",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...coTile,
      padding: 16
    }
  }, /*#__PURE__*/React.createElement(CoCardHead, {
    icon: "calendar-days",
    title: "Today & upcoming"
  }), /*#__PURE__*/React.createElement(CoTimeRow, {
    when: "09:15",
    label: "Citizen LV014",
    kind: "review"
  }), /*#__PURE__*/React.createElement(CoTimeRow, {
    when: "14:30",
    label: "Citizen LV001",
    kind: "consult"
  }), /*#__PURE__*/React.createElement(CoTimeRow, {
    when: "15:45",
    label: "Citizen LV022",
    kind: "check-in"
  }), /*#__PURE__*/React.createElement(CoTimeRow, {
    when: "Mon \xB7 10:00",
    label: "Citizen LV031",
    kind: "intake",
    last: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      ...coTile,
      padding: 16
    }
  }, /*#__PURE__*/React.createElement(CoCardHead, {
    icon: "shield-check",
    iconColor: "var(--c-good)",
    title: "Consent changes"
  }), /*#__PURE__*/React.createElement(CoConsentRow, {
    glyph: "\u25CF",
    color: "var(--c-good)",
    what: "Granted",
    detail: "LV031, sleep & recovery, 5 data groups",
    when: "08:12"
  }), /*#__PURE__*/React.createElement(CoConsentRow, {
    glyph: "\u25B2",
    color: "var(--c-watch)",
    what: "Expiring",
    detail: "LV014, renew by Tue 16 Jun",
    when: "Tue"
  }), /*#__PURE__*/React.createElement(CoConsentRow, {
    glyph: "\u2715",
    color: "var(--c-act)",
    what: "Revoked",
    detail: "LV009 \u2014 view closed immediately",
    when: "Thu",
    last: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: "var(--c-text3)",
      lineHeight: 1.5,
      marginTop: 10
    }
  }, "Every change is evidenced on the consent ledger. The citizen can revoke in one tap.")))), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: CO_MONO,
      fontSize: 10.5,
      color: "var(--c-text3)",
      marginTop: 26,
      fontVariantNumeric: "tabular-nums"
    }
  }, "v09 \xB7 13 Jun 2026"))));
}
window.ClinicalOpsDashboard = ClinicalOpsDashboard;
})(); } catch (e) { __ds_ns.__errors.push({ path: "explorations/clinical-ops.jsx", error: String((e && e.message) || e) }); }

// explorations/ios-frame.jsx
try { (() => {
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)

/* BEGIN USAGE */
// iOS.jsx — Simplified iOS 26 (Liquid Glass) device frame
// Based on the iOS 26 UI Kit + Figma status bar spec. No assets, no deps.
// Exports (to window): IOSDevice, IOSStatusBar, IOSNavBar, IOSGlassPill, IOSList, IOSListRow, IOSKeyboard
//
// Usage — wrap your screen content in <IOSDevice> to get the bezel, status bar
// and home indicator (props: title, dark, keyboard):
//
//   <IOSDevice title="Settings">
//     ...your screen content...
//   </IOSDevice>
//   <IOSDevice dark title="Search" keyboard>…</IOSDevice>
/* END USAGE */

// ─────────────────────────────────────────────────────────────
// Status bar
// ─────────────────────────────────────────────────────────────
function IOSStatusBar({
  dark = false,
  time = '9:41'
}) {
  const c = dark ? '#fff' : '#000';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 154,
      alignItems: 'center',
      justifyContent: 'center',
      padding: '21px 24px 19px',
      boxSizing: 'border-box',
      position: 'relative',
      zIndex: 20,
      width: '100%'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 22,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      paddingTop: 1.5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: '-apple-system, "SF Pro", system-ui',
      fontWeight: 590,
      fontSize: 17,
      lineHeight: '22px',
      color: c
    }
  }, time)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 22,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 7,
      paddingTop: 1,
      paddingRight: 1
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "19",
    height: "12",
    viewBox: "0 0 19 12"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0",
    y: "7.5",
    width: "3.2",
    height: "4.5",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "4.8",
    y: "5",
    width: "3.2",
    height: "7",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "9.6",
    y: "2.5",
    width: "3.2",
    height: "9.5",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "14.4",
    y: "0",
    width: "3.2",
    height: "12",
    rx: "0.7",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "17",
    height: "12",
    viewBox: "0 0 17 12"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z",
    fill: c
  }), /*#__PURE__*/React.createElement("path", {
    d: "M8.5 6.8C9.9 6.8 11.1 7.3 12 8.2L13.1 7.1C11.8 5.9 10.2 5.1 8.5 5.1C6.8 5.1 5.2 5.9 3.9 7.1L5 8.2C5.9 7.3 7.1 6.8 8.5 6.8Z",
    fill: c
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "8.5",
    cy: "10.5",
    r: "1.5",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "27",
    height: "13",
    viewBox: "0 0 27 13"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0.5",
    y: "0.5",
    width: "23",
    height: "12",
    rx: "3.5",
    stroke: c,
    strokeOpacity: "0.35",
    fill: "none"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "2",
    y: "2",
    width: "20",
    height: "9",
    rx: "2",
    fill: c
  }), /*#__PURE__*/React.createElement("path", {
    d: "M25 4.5V8.5C25.8 8.2 26.5 7.2 26.5 6.5C26.5 5.8 25.8 4.8 25 4.5Z",
    fill: c,
    fillOpacity: "0.4"
  }))));
}

// ─────────────────────────────────────────────────────────────
// Liquid glass pill — blur + tint + shine
// ─────────────────────────────────────────────────────────────
function IOSGlassPill({
  children,
  dark = false,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 44,
      minWidth: 44,
      borderRadius: 9999,
      position: 'relative',
      overflow: 'hidden',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      boxShadow: dark ? '0 2px 6px rgba(0,0,0,0.35), 0 6px 16px rgba(0,0,0,0.2)' : '0 1px 3px rgba(0,0,0,0.07), 0 3px 10px rgba(0,0,0,0.06)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 9999,
      backdropFilter: 'blur(12px) saturate(180%)',
      WebkitBackdropFilter: 'blur(12px) saturate(180%)',
      background: dark ? 'rgba(120,120,128,0.28)' : 'rgba(255,255,255,0.5)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 9999,
      boxShadow: dark ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15), inset -1px -1px 1px rgba(255,255,255,0.08)' : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
      border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 1,
      display: 'flex',
      alignItems: 'center',
      padding: '0 4px'
    }
  }, children));
}

// ─────────────────────────────────────────────────────────────
// Navigation bar — glass pills + large title
// ─────────────────────────────────────────────────────────────
function IOSNavBar({
  title = 'Title',
  dark = false,
  trailingIcon = true
}) {
  const muted = dark ? 'rgba(255,255,255,0.6)' : '#404040';
  const text = dark ? '#fff' : '#000';
  const pillIcon = content => /*#__PURE__*/React.createElement(IOSGlassPill, {
    dark: dark
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 36,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, content));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      paddingTop: 62,
      paddingBottom: 10,
      position: 'relative',
      zIndex: 5
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 16px'
    }
  }, pillIcon(/*#__PURE__*/React.createElement("svg", {
    width: "12",
    height: "20",
    viewBox: "0 0 12 20",
    fill: "none",
    style: {
      marginLeft: -1
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M10 2L2 10l8 8",
    stroke: muted,
    strokeWidth: "2.5",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }))), trailingIcon && pillIcon(/*#__PURE__*/React.createElement("svg", {
    width: "22",
    height: "6",
    viewBox: "0 0 22 6"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "3",
    cy: "3",
    r: "2.5",
    fill: muted
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "3",
    r: "2.5",
    fill: muted
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "19",
    cy: "3",
    r: "2.5",
    fill: muted
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      fontFamily: '-apple-system, system-ui',
      fontSize: 34,
      fontWeight: 700,
      lineHeight: '41px',
      color: text,
      letterSpacing: 0.4
    }
  }, title));
}

// ─────────────────────────────────────────────────────────────
// Grouped list (inset card, r:26) + row (52px)
// ─────────────────────────────────────────────────────────────
function IOSListRow({
  title,
  detail,
  icon,
  chevron = true,
  isLast = false,
  dark = false
}) {
  const text = dark ? '#fff' : '#000';
  const sec = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const ter = dark ? 'rgba(235,235,245,0.3)' : 'rgba(60,60,67,0.3)';
  const sep = dark ? 'rgba(84,84,88,0.65)' : 'rgba(60,60,67,0.12)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      minHeight: 52,
      padding: '0 16px',
      position: 'relative',
      fontFamily: '-apple-system, system-ui',
      fontSize: 17,
      letterSpacing: -0.43
    }
  }, icon && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 30,
      height: 30,
      borderRadius: 7,
      background: icon,
      marginRight: 12,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      color: text
    }
  }, title), detail && /*#__PURE__*/React.createElement("span", {
    style: {
      color: sec,
      marginRight: 6
    }
  }, detail), chevron && /*#__PURE__*/React.createElement("svg", {
    width: "8",
    height: "14",
    viewBox: "0 0 8 14",
    style: {
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 1l6 6-6 6",
    stroke: ter,
    strokeWidth: "2",
    fill: "none",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  })), !isLast && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      right: 0,
      left: icon ? 58 : 16,
      height: 0.5,
      background: sep
    }
  }));
}
function IOSList({
  header,
  children,
  dark = false
}) {
  const hc = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const bg = dark ? '#1C1C1E' : '#fff';
  return /*#__PURE__*/React.createElement("div", null, header && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: '-apple-system, system-ui',
      fontSize: 13,
      color: hc,
      textTransform: 'uppercase',
      padding: '8px 36px 6px',
      letterSpacing: -0.08
    }
  }, header), /*#__PURE__*/React.createElement("div", {
    style: {
      background: bg,
      borderRadius: 26,
      margin: '0 16px',
      overflow: 'hidden'
    }
  }, children));
}

// ─────────────────────────────────────────────────────────────
// Device frame
// ─────────────────────────────────────────────────────────────
function IOSDevice({
  children,
  width = 402,
  height = 874,
  dark = false,
  title,
  keyboard = false
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      height,
      borderRadius: 48,
      overflow: 'hidden',
      position: 'relative',
      background: dark ? '#000' : '#F2F2F7',
      boxShadow: '0 40px 80px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.12)',
      fontFamily: '-apple-system, system-ui, sans-serif',
      WebkitFontSmoothing: 'antialiased'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 11,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 126,
      height: 37,
      borderRadius: 24,
      background: '#000',
      zIndex: 50
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      zIndex: 10
    }
  }, /*#__PURE__*/React.createElement(IOSStatusBar, {
    dark: dark
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column'
    }
  }, title !== undefined && /*#__PURE__*/React.createElement(IOSNavBar, {
    title: title,
    dark: dark
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'auto'
    }
  }, children), keyboard && /*#__PURE__*/React.createElement(IOSKeyboard, {
    dark: dark
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      left: 0,
      right: 0,
      zIndex: 60,
      height: 34,
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'flex-end',
      paddingBottom: 8,
      pointerEvents: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 139,
      height: 5,
      borderRadius: 100,
      background: dark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.25)'
    }
  })));
}

// ─────────────────────────────────────────────────────────────
// Keyboard — iOS 26 liquid glass
// ─────────────────────────────────────────────────────────────
function IOSKeyboard({
  dark = false
}) {
  const glyph = dark ? 'rgba(255,255,255,0.7)' : '#595959';
  const sugg = dark ? 'rgba(255,255,255,0.6)' : '#333';
  const keyBg = dark ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.85)';

  // special-key icons
  const icons = {
    shift: /*#__PURE__*/React.createElement("svg", {
      width: "19",
      height: "17",
      viewBox: "0 0 19 17"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M9.5 1L1 9.5h4.5V16h8V9.5H18L9.5 1z",
      fill: glyph
    })),
    del: /*#__PURE__*/React.createElement("svg", {
      width: "23",
      height: "17",
      viewBox: "0 0 23 17"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M7 1h13a2 2 0 012 2v11a2 2 0 01-2 2H7l-6-7.5L7 1z",
      fill: "none",
      stroke: glyph,
      strokeWidth: "1.6",
      strokeLinejoin: "round"
    }), /*#__PURE__*/React.createElement("path", {
      d: "M10 5l7 7M17 5l-7 7",
      stroke: glyph,
      strokeWidth: "1.6",
      strokeLinecap: "round"
    })),
    ret: /*#__PURE__*/React.createElement("svg", {
      width: "20",
      height: "14",
      viewBox: "0 0 20 14"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M18 1v6H4m0 0l4-4M4 7l4 4",
      fill: "none",
      stroke: "#fff",
      strokeWidth: "1.8",
      strokeLinecap: "round",
      strokeLinejoin: "round"
    }))
  };
  const key = (content, {
    w,
    flex,
    ret,
    fs = 25,
    k
  } = {}) => /*#__PURE__*/React.createElement("div", {
    key: k,
    style: {
      height: 42,
      borderRadius: 8.5,
      flex: flex ? 1 : undefined,
      width: w,
      minWidth: 0,
      background: ret ? '#08f' : keyBg,
      boxShadow: '0 1px 0 rgba(0,0,0,0.075)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: '-apple-system, "SF Compact", system-ui',
      fontSize: fs,
      fontWeight: 458,
      color: ret ? '#fff' : glyph
    }
  }, content);
  const row = (keys, pad = 0) => /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6.5,
      justifyContent: 'center',
      padding: `0 ${pad}px`
    }
  }, keys.map(l => key(l, {
    flex: true,
    k: l
  })));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 15,
      borderRadius: 27,
      overflow: 'hidden',
      padding: '11px 0 2px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      boxShadow: dark ? '0 -2px 20px rgba(0,0,0,0.09)' : '0 -1px 6px rgba(0,0,0,0.018), 0 -3px 20px rgba(0,0,0,0.012)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 27,
      backdropFilter: 'blur(12px) saturate(180%)',
      WebkitBackdropFilter: 'blur(12px) saturate(180%)',
      background: dark ? 'rgba(120,120,128,0.14)' : 'rgba(255,255,255,0.25)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 27,
      boxShadow: dark ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15)' : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
      border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 20,
      alignItems: 'center',
      padding: '8px 22px 13px',
      width: '100%',
      boxSizing: 'border-box',
      position: 'relative'
    }
  }, ['"The"', 'the', 'to'].map((w, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: i
  }, i > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 1,
      height: 25,
      background: '#ccc',
      opacity: 0.3
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      textAlign: 'center',
      fontFamily: '-apple-system, system-ui',
      fontSize: 17,
      color: sugg,
      letterSpacing: -0.43,
      lineHeight: '22px'
    }
  }, w)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 13,
      padding: '0 6.5px',
      width: '100%',
      boxSizing: 'border-box',
      position: 'relative'
    }
  }, row(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']), row(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'], 20), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14.25,
      alignItems: 'center'
    }
  }, key(icons.shift, {
    w: 45,
    k: 'shift'
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6.5,
      flex: 1
    }
  }, ['z', 'x', 'c', 'v', 'b', 'n', 'm'].map(l => key(l, {
    flex: true,
    k: l
  }))), key(icons.del, {
    w: 45,
    k: 'del'
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6,
      alignItems: 'center'
    }
  }, key('ABC', {
    w: 92.25,
    fs: 18,
    k: 'abc'
  }), key('', {
    flex: true,
    k: 'space'
  }), key(icons.ret, {
    w: 92.25,
    ret: true,
    k: 'ret'
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 56,
      width: '100%',
      position: 'relative'
    }
  }));
}
Object.assign(window, {
  IOSDevice,
  IOSStatusBar,
  IOSNavBar,
  IOSGlassPill,
  IOSList,
  IOSListRow,
  IOSKeyboard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "explorations/ios-frame.jsx", error: String((e && e.message) || e) }); }

// explorations/mobile-home.jsx
try { (() => {
// Maude mobile home — Apple Liquid Glass (iOS 26), the CITIZEN consumer surface.
// Opposite of the matte console: translucent glass layers (blur+saturate), specular
// top-edge highlight + hairline inner stroke, large-title nav condensing on scroll,
// scroll-edge fade under the bar, floating glass tab capsule. White/off-white base — no mint.
// SF Pro + SF-Symbol-style glyphs. This is a reference mock for the prompt's §6.

const SF = '-apple-system, "SF Pro Text", "SF Pro", system-ui, sans-serif';
const SFD = '-apple-system, "SF Pro Display", "SF Pro", system-ui, sans-serif';
const NAVY = "#1D3557";

// ── Glass surface: tint + blur, specular highlight, hairline stroke (concentric radii) ──
function Glass({
  radius = 28,
  tint = "rgba(255,255,255,0.6)",
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      borderRadius: radius,
      overflow: "hidden",
      boxShadow: "0 1px 3px rgba(16,28,51,0.06), 0 10px 30px -12px rgba(16,28,51,0.18)",
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      borderRadius: radius,
      backdropFilter: "blur(20px) saturate(180%)",
      WebkitBackdropFilter: "blur(20px) saturate(180%)",
      background: tint
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      borderRadius: radius,
      pointerEvents: "none",
      boxShadow: "inset 1.5px 1.5px 1px rgba(255,255,255,0.85), inset -1px -1px 1px rgba(255,255,255,0.45)",
      border: "0.5px solid rgba(16,28,51,0.07)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      zIndex: 1
    }
  }, children));
}

// minimal SF-Symbol-style glyphs (stroked, rounded)
function Sym({
  d,
  size = 26,
  fill,
  stroke = NAVY,
  sw = 1.9,
  op = 1
}) {
  return /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: "0 0 28 28",
    fill: fill || "none",
    style: {
      opacity: op,
      display: "block"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: d,
    stroke: fill ? "none" : stroke,
    strokeWidth: sw,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    fill: fill || "none"
  }));
}
const ICON = {
  drop: "M14 4C14 4 7 12 7 17a7 7 0 0 0 14 0C21 12 14 4 14 4Z",
  heart: "M14 23S5 17.5 5 11.5A4.5 4.5 0 0 1 14 9 4.5 4.5 0 0 1 23 11.5C23 17.5 14 23 14 23Z",
  moon: "M22 16.5A9 9 0 0 1 11.5 6 7 7 0 1 0 22 16.5Z",
  shield: "M14 4 5 7v6c0 5 4 9 9 11 5-2 9-6 9-11V7l-9-3Z",
  home: "M5 13 14 5l9 8M8 11v10h12V11",
  pulse: "M3 14h5l3-7 4 14 3-7h6",
  chat: "M5 6h18v13H14l-5 4v-4H5Z",
  person: "M14 14a4.5 4.5 0 1 0 0-9 4.5 4.5 0 0 0 0 9ZM6 24c0-4.5 3.6-7 8-7s8 2.5 8 7"
};
function MetricCard({
  icon,
  tint,
  label,
  value,
  unit,
  note,
  noteColor,
  noteKind,
  big
}) {
  return /*#__PURE__*/React.createElement(Glass, {
    radius: 26,
    tint: "rgba(255,255,255,0.55)",
    style: {
      flex: big ? "1 1 100%" : "1 1 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 9,
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 34,
      height: 34,
      borderRadius: 10,
      background: tint,
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Sym, {
    d: icon,
    size: 20
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SF,
      fontSize: 14,
      fontWeight: 600,
      color: "rgba(29,53,87,0.62)"
    }
  }, label)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: 5,
      whiteSpace: "nowrap"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SFD,
      fontSize: big ? 40 : 34,
      fontWeight: 700,
      color: NAVY,
      letterSpacing: "-0.02em",
      lineHeight: 1
    }
  }, value), unit && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SF,
      fontSize: 15,
      fontWeight: 600,
      color: "rgba(29,53,87,0.5)"
    }
  }, unit)), note && (noteKind === "watch" ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5,
      fontFamily: SF,
      fontSize: 12.5,
      fontWeight: 700,
      color: NAVY,
      background: "#FFB703",
      padding: "3px 10px",
      borderRadius: 999,
      marginTop: 10
    }
  }, note) : /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: SF,
      fontSize: 13.5,
      fontWeight: 600,
      color: noteColor || "rgba(29,53,87,0.55)",
      marginTop: 8
    }
  }, note))));
}
function TabItem({
  icon,
  label,
  on
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 3,
      flex: 1,
      padding: "2px 0"
    }
  }, /*#__PURE__*/React.createElement(Sym, {
    d: icon,
    size: 25,
    stroke: on ? NAVY : "rgba(29,53,87,0.5)",
    fill: on ? NAVY : undefined,
    sw: on ? 0 : 1.9
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SF,
      fontSize: 10.5,
      fontWeight: on ? 700 : 500,
      color: on ? NAVY : "rgba(29,53,87,0.55)"
    }
  }, label));
}
function MobileHome() {
  const [scrolled, setScrolled] = React.useState(false);
  const onScroll = e => setScrolled(e.target.scrollTop > 28);
  return /*#__PURE__*/React.createElement("div", {
    "data-screen-label": "Mobile home \u2014 Liquid Glass",
    style: {
      width: 390,
      height: 844,
      borderRadius: 52,
      overflow: "hidden",
      position: "relative",
      // white / off-white base with faint colour washes so the glass tints read cleanly (no mint ground)
      background: "radial-gradient(120% 60% at 80% -5%, #EAF0F6 0%, rgba(234,240,246,0) 55%), radial-gradient(90% 45% at 0% 8%, #F3ECEC 0%, rgba(243,236,236,0) 50%), #F7F8FA",
      boxShadow: "0 40px 90px rgba(16,28,51,0.22), 0 0 0 1px rgba(16,28,51,0.10)",
      fontFamily: SF,
      WebkitFontSmoothing: "antialiased"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 11,
      left: "50%",
      transform: "translateX(-50%)",
      width: 124,
      height: 36,
      borderRadius: 22,
      background: "#000",
      zIndex: 60
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 0,
      left: 0,
      right: 0,
      height: 54,
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "0 30px",
      zIndex: 55,
      paddingTop: 14
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SFD,
      fontWeight: 600,
      fontSize: 16,
      color: NAVY
    }
  }, "9:41"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SF,
      fontWeight: 700,
      fontSize: 12,
      color: NAVY,
      letterSpacing: "0.04em"
    }
  }, "5G \u25AA \u25AA \u25AA")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 0,
      left: 0,
      right: 0,
      height: 96,
      zIndex: 40,
      pointerEvents: "none",
      opacity: scrolled ? 1 : 0,
      transition: "opacity 200ms ease"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      backdropFilter: "blur(18px) saturate(160%)",
      WebkitBackdropFilter: "blur(18px) saturate(160%)",
      background: "linear-gradient(180deg, rgba(247,248,250,0.86) 60%, rgba(247,248,250,0))",
      maskImage: "linear-gradient(180deg,#000 60%,transparent)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      top: 56,
      left: 0,
      right: 0,
      textAlign: "center",
      fontFamily: SFD,
      fontWeight: 700,
      fontSize: 17,
      color: NAVY
    }
  }, "Today")), /*#__PURE__*/React.createElement("div", {
    onScroll: onScroll,
    style: {
      position: "absolute",
      inset: 0,
      overflowY: "auto",
      paddingTop: 54
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "8px 20px 4px",
      display: "flex",
      justifyContent: "space-between",
      alignItems: "flex-end"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: SF,
      fontSize: 15,
      fontWeight: 600,
      color: "rgba(29,53,87,0.5)"
    }
  }, "Saturday 13 June"), /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: SFD,
      fontSize: 34,
      fontWeight: 700,
      color: NAVY,
      letterSpacing: "-0.02em",
      margin: "2px 0 0"
    }
  }, "Today")), /*#__PURE__*/React.createElement(Glass, {
    radius: 9999,
    style: {
      width: 40,
      height: 40
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 40,
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Sym, {
    d: ICON.person,
    size: 22
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "14px 16px 0",
      display: "flex",
      flexWrap: "wrap",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(MetricCard, {
    icon: ICON.drop,
    tint: "rgba(168,218,220,0.5)",
    label: "Glucose",
    value: "6.2",
    unit: "mmol/L",
    note: "\u25CF within range",
    noteColor: "#457B9D"
  }), /*#__PURE__*/React.createElement(MetricCard, {
    icon: ICON.heart,
    tint: "rgba(244,146,154,0.45)",
    label: "Resting HR",
    value: "58",
    unit: "bpm",
    note: "steady"
  }), /*#__PURE__*/React.createElement(MetricCard, {
    icon: ICON.moon,
    tint: "rgba(69,123,157,0.32)",
    label: "Sleep",
    value: "7h 24m",
    note: "\u25B2 15% below your average",
    noteKind: "watch",
    big: true
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "16px 16px 0"
    }
  }, /*#__PURE__*/React.createElement(Glass, {
    radius: 26,
    tint: "rgba(255,255,255,0.5)"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 18
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10,
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 34,
      height: 34,
      borderRadius: 10,
      background: "rgba(69,123,157,0.16)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Sym, {
    d: ICON.shield,
    size: 20,
    stroke: "#457B9D"
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SFD,
      fontSize: 17,
      fontWeight: 700,
      color: NAVY
    }
  }, "Shared on your terms")), /*#__PURE__*/React.createElement("p", {
    style: {
      fontFamily: SF,
      fontSize: 15,
      lineHeight: 1.45,
      color: "rgba(29,53,87,0.7)",
      margin: 0
    }
  }, "Your diabetes nurse can see glucose and sleep patterns \u2014 not raw readings. Shared by you, expires in 6 days."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 9,
      marginTop: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      textAlign: "center",
      padding: "11px 0",
      borderRadius: 13,
      background: NAVY,
      color: "#fff",
      fontFamily: SF,
      fontSize: 15,
      fontWeight: 600
    }
  }, "Manage sharing"), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: "none",
      padding: "11px 16px",
      borderRadius: 13,
      background: "rgba(29,53,87,0.07)",
      color: NAVY,
      fontFamily: SF,
      fontSize: 15,
      fontWeight: 600
    }
  }, "Extend"))))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "16px 16px 140px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: SF,
      fontSize: 13,
      fontWeight: 600,
      color: "rgba(29,53,87,0.5)",
      textTransform: "uppercase",
      letterSpacing: "0.04em",
      padding: "0 6px 8px"
    }
  }, "Worth a look"), /*#__PURE__*/React.createElement(Glass, {
    radius: 22,
    tint: "rgba(255,255,255,0.5)"
  }, [["pulse", "HRV dips on busy days", "A pattern in your data"], ["drop", "Glucose steadiest after walks", "Last 2 weeks"]].map((r, i) => /*#__PURE__*/React.createElement("div", {
    key: r[0],
    style: {
      display: "flex",
      alignItems: "center",
      gap: 13,
      padding: "14px 16px",
      borderTop: i ? "0.5px solid rgba(29,53,87,0.1)" : "none"
    }
  }, /*#__PURE__*/React.createElement(Sym, {
    d: ICON[r[0]],
    size: 22
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: SF,
      fontSize: 16,
      fontWeight: 600,
      color: NAVY
    }
  }, r[1]), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: SF,
      fontSize: 13.5,
      color: "rgba(29,53,87,0.5)"
    }
  }, r[2])), /*#__PURE__*/React.createElement(Sym, {
    d: "M10 5l7 7-7 7",
    size: 18,
    stroke: "rgba(29,53,87,0.3)"
  })))))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 16,
      right: 16,
      bottom: 26,
      zIndex: 50
    }
  }, /*#__PURE__*/React.createElement(Glass, {
    radius: 9999,
    tint: "rgba(255,255,255,0.62)"
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      padding: "9px 12px 7px"
    }
  }, /*#__PURE__*/React.createElement(TabItem, {
    icon: ICON.home,
    label: "Today",
    on: true
  }), /*#__PURE__*/React.createElement(TabItem, {
    icon: ICON.pulse,
    label: "Trends"
  }), /*#__PURE__*/React.createElement(TabItem, {
    icon: ICON.shield,
    label: "Sharing"
  }), /*#__PURE__*/React.createElement(TabItem, {
    icon: ICON.chat,
    label: "Messages"
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      bottom: 8,
      left: 0,
      right: 0,
      display: "flex",
      justifyContent: "center",
      zIndex: 60,
      pointerEvents: "none"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 134,
      height: 5,
      borderRadius: 100,
      background: "rgba(29,53,87,0.28)"
    }
  })));
}
window.MobileHome = MobileHome;
})(); } catch (e) { __ds_ns.__errors.push({ path: "explorations/mobile-home.jsx", error: String((e && e.message) || e) }); }

// maude-prototype/ios-frame.jsx
try { (() => {
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)

/* BEGIN USAGE */
// iOS.jsx — Simplified iOS 26 (Liquid Glass) device frame
// Based on the iOS 26 UI Kit + Figma status bar spec. No assets, no deps.
// Exports (to window): IOSDevice, IOSStatusBar, IOSNavBar, IOSGlassPill, IOSList, IOSListRow, IOSKeyboard
//
// Usage — wrap your screen content in <IOSDevice> to get the bezel, status bar
// and home indicator (props: title, dark, keyboard):
//
//   <IOSDevice title="Settings">
//     ...your screen content...
//   </IOSDevice>
//   <IOSDevice dark title="Search" keyboard>…</IOSDevice>
/* END USAGE */

// ─────────────────────────────────────────────────────────────
// Status bar
// ─────────────────────────────────────────────────────────────
function IOSStatusBar({
  dark = false,
  time = '9:41'
}) {
  const c = dark ? '#fff' : '#000';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 154,
      alignItems: 'center',
      justifyContent: 'center',
      padding: '21px 24px 19px',
      boxSizing: 'border-box',
      position: 'relative',
      zIndex: 20,
      width: '100%'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 22,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      paddingTop: 1.5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: '-apple-system, "SF Pro", system-ui',
      fontWeight: 590,
      fontSize: 17,
      lineHeight: '22px',
      color: c
    }
  }, time)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 22,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 7,
      paddingTop: 1,
      paddingRight: 1
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "19",
    height: "12",
    viewBox: "0 0 19 12"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0",
    y: "7.5",
    width: "3.2",
    height: "4.5",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "4.8",
    y: "5",
    width: "3.2",
    height: "7",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "9.6",
    y: "2.5",
    width: "3.2",
    height: "9.5",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "14.4",
    y: "0",
    width: "3.2",
    height: "12",
    rx: "0.7",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "17",
    height: "12",
    viewBox: "0 0 17 12"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z",
    fill: c
  }), /*#__PURE__*/React.createElement("path", {
    d: "M8.5 6.8C9.9 6.8 11.1 7.3 12 8.2L13.1 7.1C11.8 5.9 10.2 5.1 8.5 5.1C6.8 5.1 5.2 5.9 3.9 7.1L5 8.2C5.9 7.3 7.1 6.8 8.5 6.8Z",
    fill: c
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "8.5",
    cy: "10.5",
    r: "1.5",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "27",
    height: "13",
    viewBox: "0 0 27 13"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0.5",
    y: "0.5",
    width: "23",
    height: "12",
    rx: "3.5",
    stroke: c,
    strokeOpacity: "0.35",
    fill: "none"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "2",
    y: "2",
    width: "20",
    height: "9",
    rx: "2",
    fill: c
  }), /*#__PURE__*/React.createElement("path", {
    d: "M25 4.5V8.5C25.8 8.2 26.5 7.2 26.5 6.5C26.5 5.8 25.8 4.8 25 4.5Z",
    fill: c,
    fillOpacity: "0.4"
  }))));
}

// ─────────────────────────────────────────────────────────────
// Liquid glass pill — blur + tint + shine
// ─────────────────────────────────────────────────────────────
function IOSGlassPill({
  children,
  dark = false,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 44,
      minWidth: 44,
      borderRadius: 9999,
      position: 'relative',
      overflow: 'hidden',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      boxShadow: dark ? '0 2px 6px rgba(0,0,0,0.35), 0 6px 16px rgba(0,0,0,0.2)' : '0 1px 3px rgba(0,0,0,0.07), 0 3px 10px rgba(0,0,0,0.06)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 9999,
      backdropFilter: 'blur(12px) saturate(180%)',
      WebkitBackdropFilter: 'blur(12px) saturate(180%)',
      background: dark ? 'rgba(120,120,128,0.28)' : 'rgba(255,255,255,0.5)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 9999,
      boxShadow: dark ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15), inset -1px -1px 1px rgba(255,255,255,0.08)' : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
      border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 1,
      display: 'flex',
      alignItems: 'center',
      padding: '0 4px'
    }
  }, children));
}

// ─────────────────────────────────────────────────────────────
// Navigation bar — glass pills + large title
// ─────────────────────────────────────────────────────────────
function IOSNavBar({
  title = 'Title',
  dark = false,
  trailingIcon = true
}) {
  const muted = dark ? 'rgba(255,255,255,0.6)' : '#404040';
  const text = dark ? '#fff' : '#000';
  const pillIcon = content => /*#__PURE__*/React.createElement(IOSGlassPill, {
    dark: dark
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 36,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, content));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      paddingTop: 62,
      paddingBottom: 10,
      position: 'relative',
      zIndex: 5
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 16px'
    }
  }, pillIcon(/*#__PURE__*/React.createElement("svg", {
    width: "12",
    height: "20",
    viewBox: "0 0 12 20",
    fill: "none",
    style: {
      marginLeft: -1
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M10 2L2 10l8 8",
    stroke: muted,
    strokeWidth: "2.5",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }))), trailingIcon && pillIcon(/*#__PURE__*/React.createElement("svg", {
    width: "22",
    height: "6",
    viewBox: "0 0 22 6"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "3",
    cy: "3",
    r: "2.5",
    fill: muted
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "3",
    r: "2.5",
    fill: muted
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "19",
    cy: "3",
    r: "2.5",
    fill: muted
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      fontFamily: '-apple-system, system-ui',
      fontSize: 34,
      fontWeight: 700,
      lineHeight: '41px',
      color: text,
      letterSpacing: 0.4
    }
  }, title));
}

// ─────────────────────────────────────────────────────────────
// Grouped list (inset card, r:26) + row (52px)
// ─────────────────────────────────────────────────────────────
function IOSListRow({
  title,
  detail,
  icon,
  chevron = true,
  isLast = false,
  dark = false
}) {
  const text = dark ? '#fff' : '#000';
  const sec = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const ter = dark ? 'rgba(235,235,245,0.3)' : 'rgba(60,60,67,0.3)';
  const sep = dark ? 'rgba(84,84,88,0.65)' : 'rgba(60,60,67,0.12)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      minHeight: 52,
      padding: '0 16px',
      position: 'relative',
      fontFamily: '-apple-system, system-ui',
      fontSize: 17,
      letterSpacing: -0.43
    }
  }, icon && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 30,
      height: 30,
      borderRadius: 7,
      background: icon,
      marginRight: 12,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      color: text
    }
  }, title), detail && /*#__PURE__*/React.createElement("span", {
    style: {
      color: sec,
      marginRight: 6
    }
  }, detail), chevron && /*#__PURE__*/React.createElement("svg", {
    width: "8",
    height: "14",
    viewBox: "0 0 8 14",
    style: {
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 1l6 6-6 6",
    stroke: ter,
    strokeWidth: "2",
    fill: "none",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  })), !isLast && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      right: 0,
      left: icon ? 58 : 16,
      height: 0.5,
      background: sep
    }
  }));
}
function IOSList({
  header,
  children,
  dark = false
}) {
  const hc = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const bg = dark ? '#1C1C1E' : '#fff';
  return /*#__PURE__*/React.createElement("div", null, header && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: '-apple-system, system-ui',
      fontSize: 13,
      color: hc,
      textTransform: 'uppercase',
      padding: '8px 36px 6px',
      letterSpacing: -0.08
    }
  }, header), /*#__PURE__*/React.createElement("div", {
    style: {
      background: bg,
      borderRadius: 26,
      margin: '0 16px',
      overflow: 'hidden'
    }
  }, children));
}

// ─────────────────────────────────────────────────────────────
// Device frame
// ─────────────────────────────────────────────────────────────
function IOSDevice({
  children,
  width = 402,
  height = 874,
  dark = false,
  title,
  keyboard = false
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      height,
      borderRadius: 48,
      overflow: 'hidden',
      position: 'relative',
      background: dark ? '#000' : '#F2F2F7',
      boxShadow: '0 40px 80px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.12)',
      fontFamily: '-apple-system, system-ui, sans-serif',
      WebkitFontSmoothing: 'antialiased'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 11,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 126,
      height: 37,
      borderRadius: 24,
      background: '#000',
      zIndex: 50
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      zIndex: 10
    }
  }, /*#__PURE__*/React.createElement(IOSStatusBar, {
    dark: dark
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column'
    }
  }, title !== undefined && /*#__PURE__*/React.createElement(IOSNavBar, {
    title: title,
    dark: dark
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'auto'
    }
  }, children), keyboard && /*#__PURE__*/React.createElement(IOSKeyboard, {
    dark: dark
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      left: 0,
      right: 0,
      zIndex: 60,
      height: 34,
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'flex-end',
      paddingBottom: 8,
      pointerEvents: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 139,
      height: 5,
      borderRadius: 100,
      background: dark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.25)'
    }
  })));
}

// ─────────────────────────────────────────────────────────────
// Keyboard — iOS 26 liquid glass
// ─────────────────────────────────────────────────────────────
function IOSKeyboard({
  dark = false
}) {
  const glyph = dark ? 'rgba(255,255,255,0.7)' : '#595959';
  const sugg = dark ? 'rgba(255,255,255,0.6)' : '#333';
  const keyBg = dark ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.85)';

  // special-key icons
  const icons = {
    shift: /*#__PURE__*/React.createElement("svg", {
      width: "19",
      height: "17",
      viewBox: "0 0 19 17"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M9.5 1L1 9.5h4.5V16h8V9.5H18L9.5 1z",
      fill: glyph
    })),
    del: /*#__PURE__*/React.createElement("svg", {
      width: "23",
      height: "17",
      viewBox: "0 0 23 17"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M7 1h13a2 2 0 012 2v11a2 2 0 01-2 2H7l-6-7.5L7 1z",
      fill: "none",
      stroke: glyph,
      strokeWidth: "1.6",
      strokeLinejoin: "round"
    }), /*#__PURE__*/React.createElement("path", {
      d: "M10 5l7 7M17 5l-7 7",
      stroke: glyph,
      strokeWidth: "1.6",
      strokeLinecap: "round"
    })),
    ret: /*#__PURE__*/React.createElement("svg", {
      width: "20",
      height: "14",
      viewBox: "0 0 20 14"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M18 1v6H4m0 0l4-4M4 7l4 4",
      fill: "none",
      stroke: "#fff",
      strokeWidth: "1.8",
      strokeLinecap: "round",
      strokeLinejoin: "round"
    }))
  };
  const key = (content, {
    w,
    flex,
    ret,
    fs = 25,
    k
  } = {}) => /*#__PURE__*/React.createElement("div", {
    key: k,
    style: {
      height: 42,
      borderRadius: 8.5,
      flex: flex ? 1 : undefined,
      width: w,
      minWidth: 0,
      background: ret ? '#08f' : keyBg,
      boxShadow: '0 1px 0 rgba(0,0,0,0.075)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: '-apple-system, "SF Compact", system-ui',
      fontSize: fs,
      fontWeight: 458,
      color: ret ? '#fff' : glyph
    }
  }, content);
  const row = (keys, pad = 0) => /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6.5,
      justifyContent: 'center',
      padding: `0 ${pad}px`
    }
  }, keys.map(l => key(l, {
    flex: true,
    k: l
  })));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 15,
      borderRadius: 27,
      overflow: 'hidden',
      padding: '11px 0 2px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      boxShadow: dark ? '0 -2px 20px rgba(0,0,0,0.09)' : '0 -1px 6px rgba(0,0,0,0.018), 0 -3px 20px rgba(0,0,0,0.012)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 27,
      backdropFilter: 'blur(12px) saturate(180%)',
      WebkitBackdropFilter: 'blur(12px) saturate(180%)',
      background: dark ? 'rgba(120,120,128,0.14)' : 'rgba(255,255,255,0.25)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 27,
      boxShadow: dark ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15)' : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
      border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 20,
      alignItems: 'center',
      padding: '8px 22px 13px',
      width: '100%',
      boxSizing: 'border-box',
      position: 'relative'
    }
  }, ['"The"', 'the', 'to'].map((w, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: i
  }, i > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 1,
      height: 25,
      background: '#ccc',
      opacity: 0.3
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      textAlign: 'center',
      fontFamily: '-apple-system, system-ui',
      fontSize: 17,
      color: sugg,
      letterSpacing: -0.43,
      lineHeight: '22px'
    }
  }, w)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 13,
      padding: '0 6.5px',
      width: '100%',
      boxSizing: 'border-box',
      position: 'relative'
    }
  }, row(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']), row(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'], 20), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14.25,
      alignItems: 'center'
    }
  }, key(icons.shift, {
    w: 45,
    k: 'shift'
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6.5,
      flex: 1
    }
  }, ['z', 'x', 'c', 'v', 'b', 'n', 'm'].map(l => key(l, {
    flex: true,
    k: l
  }))), key(icons.del, {
    w: 45,
    k: 'del'
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6,
      alignItems: 'center'
    }
  }, key('ABC', {
    w: 92.25,
    fs: 18,
    k: 'abc'
  }), key('', {
    flex: true,
    k: 'space'
  }), key(icons.ret, {
    w: 92.25,
    ret: true,
    k: 'ret'
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 56,
      width: '100%',
      position: 'relative'
    }
  }));
}
Object.assign(window, {
  IOSDevice,
  IOSStatusBar,
  IOSNavBar,
  IOSGlassPill,
  IOSList,
  IOSListRow,
  IOSKeyboard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "maude-prototype/ios-frame.jsx", error: String((e && e.message) || e) }); }

// maude-prototype/prototype.jsx
try { (() => {
// Maude v2 — clickable prototype. Assembles the user's chosen directions:
// Home (C hybrid) · Correlation (C plain-sentence, depth on tap) · Baseline (B Aperture arc)
// · Week (heatmap) · Privacy (consent control) → Consent history (A). Real navigation.
// Styled with the Maude tokens (../styles.css). Attaches MaudePrototype to window.

const {
  useState
} = React;
const ASSET = "../assets/brand/";

/* ---------- helpers ---------- */
function renderLucide(arr) {
  return arr.map((c, i) => {
    if (!Array.isArray(c)) return null;
    if (typeof c[0] === "string") {
      const kids = Array.isArray(c[2]) ? renderLucide(c[2]) : null;
      return React.createElement(c[0], {
        key: i,
        ...(c[1] || {})
      }, kids);
    }
    return renderLucide(c);
  });
}
function Ico({
  name,
  size = 20,
  color = "currentColor",
  stroke = 1.9,
  style
}) {
  const lib = typeof window !== "undefined" ? window.lucide : null;
  const toP = n => String(n).replace(/(^\w|-\w)/g, m => m.replace("-", "").toUpperCase());
  const node = lib && lib.icons ? lib.icons[toP(name)] : null;
  if (!node) return /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-block",
      width: size,
      height: size,
      ...style
    }
  });
  return /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: color,
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: {
      display: "block",
      ...style
    }
  }, renderLucide(node));
}
function Mark({
  size = 24,
  reversed
}) {
  return /*#__PURE__*/React.createElement("img", {
    src: ASSET + (reversed ? "maude_mark_iris_reversed.svg" : "maude_mark_iris.svg"),
    alt: "Maude",
    width: size,
    height: size,
    style: {
      display: "block"
    }
  });
}
const KICK = {
  fontFamily: "var(--font-mono)",
  textTransform: "uppercase",
  letterSpacing: "1px"
};
const CARD = {
  background: "var(--white)",
  border: "0.5px solid var(--line)",
  borderRadius: "var(--radius-lg)",
  boxShadow: "var(--shadow-card)",
  padding: 14
};
const META = {
  fontFamily: "var(--font-mono)",
  fontSize: 10,
  color: "var(--ink-3)",
  background: "var(--paper)",
  border: "1px solid var(--line-2)",
  borderRadius: "var(--radius-sm)",
  padding: "3px 7px"
};
const PRIMARY = {
  marginTop: 14,
  background: "var(--ink)",
  color: "var(--paper)",
  border: "none",
  borderRadius: "var(--radius-md)",
  padding: 14,
  width: "100%",
  fontSize: 15,
  fontWeight: 700,
  fontFamily: "var(--font-sans)",
  cursor: "pointer"
};
const SECONDARY = {
  marginTop: 10,
  background: "var(--white)",
  color: "var(--ink)",
  border: "1px solid var(--line)",
  borderRadius: "var(--radius-md)",
  padding: 13,
  width: "100%",
  fontSize: 14.5,
  fontWeight: 700,
  fontFamily: "var(--font-sans)",
  cursor: "pointer"
};
const TERTIARY = {
  marginTop: 4,
  background: "none",
  border: "none",
  color: "var(--ink-2)",
  fontSize: 14,
  fontWeight: 700,
  width: "100%",
  padding: 11,
  cursor: "pointer"
};
function AppBar({
  avatar = "CN"
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 9,
      padding: "4px 20px 2px"
    }
  }, /*#__PURE__*/React.createElement(Mark, {
    size: 24
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 16,
      fontWeight: 900,
      letterSpacing: "-0.3px",
      color: "var(--ink)"
    }
  }, "Maude"), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 30,
      height: 30,
      borderRadius: "50%",
      background: "var(--ink)",
      color: "#fff",
      display: "grid",
      placeItems: "center",
      fontSize: 11,
      fontWeight: 600
    }
  }, avatar));
}
function BackBar({
  title,
  onBack,
  right
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "4px 20px 2px"
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onBack,
    style: {
      width: 32,
      height: 32,
      borderRadius: "50%",
      border: "1px solid var(--line)",
      background: "var(--white)",
      color: "var(--ink-2)",
      fontSize: 17,
      cursor: "pointer",
      lineHeight: 1
    }
  }, "\u2039"), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 16,
      fontWeight: 900,
      letterSpacing: "-0.3px"
    }
  }, title), /*#__PURE__*/React.createElement("span", {
    style: {
      minWidth: 32,
      display: "flex",
      justifyContent: "flex-end"
    }
  }, right));
}
const GATED = /*#__PURE__*/React.createElement("span", {
  style: {
    ...KICK,
    display: "inline-flex",
    alignItems: "center",
    gap: 5,
    fontSize: 9.5,
    fontWeight: 600,
    padding: "5px 9px",
    borderRadius: 999,
    background: "var(--moss-2)",
    color: "var(--moss-text-dark)",
    letterSpacing: "0.5px"
  }
}, /*#__PURE__*/React.createElement("span", {
  style: {
    width: 6,
    height: 6,
    borderRadius: "50%",
    background: "var(--moss)"
  }
}), "GATED");
const EVID = /*#__PURE__*/React.createElement("div", {
  style: {
    display: "flex",
    gap: 6,
    marginTop: 13,
    flexWrap: "wrap"
  }
}, /*#__PURE__*/React.createElement("span", {
  style: META
}, /*#__PURE__*/React.createElement("b", {
  style: {
    color: "var(--ink)"
  }
}, "N"), " 42 nights"), /*#__PURE__*/React.createElement("span", {
  style: META
}, "baseline ", /*#__PURE__*/React.createElement("b", {
  style: {
    color: "var(--ink)"
  }
}, "90d")), /*#__PURE__*/React.createElement("span", {
  style: META
}, "r ", /*#__PURE__*/React.createElement("b", {
  style: {
    color: "var(--ink)"
  }
}, "0.62")), /*#__PURE__*/React.createElement("span", {
  style: META
}, "p<", /*#__PURE__*/React.createElement("b", {
  style: {
    color: "var(--ink)"
  }
}, ".01")));

/* ---------- HOME (C hybrid) ---------- */
function Home({
  push
}) {
  const chip = (l, v, clay, to) => /*#__PURE__*/React.createElement("button", {
    onClick: () => push(to),
    style: {
      flex: 1,
      textAlign: "left",
      border: "1px solid var(--line-2)",
      borderRadius: "var(--radius-md)",
      padding: "9px 10px",
      background: "var(--white)",
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 8,
      color: "var(--ink-3)"
    }
  }, l), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      fontWeight: 800,
      marginTop: 3,
      display: "flex",
      alignItems: "center",
      gap: 5,
      color: clay ? "var(--clay-text)" : "var(--ink)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: "50%",
      background: clay ? "var(--clay)" : "var(--moss)"
    }
  }), v));
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(AppBar, null), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 20px 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10.5,
      letterSpacing: "1.4px",
      color: "var(--ink-3)"
    }
  }, "Thu \xB7 22 May"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 26,
      fontWeight: 900,
      letterSpacing: "-0.6px",
      color: "var(--ink)",
      marginTop: 4
    }
  }, "Morning, Clara"), /*#__PURE__*/React.createElement("button", {
    onClick: () => push("correlation"),
    style: {
      ...CARD,
      border: "1px solid var(--clay-3)",
      textAlign: "left",
      width: "100%",
      marginTop: 14,
      cursor: "pointer",
      display: "block"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      color: "var(--clay-text)",
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      letterSpacing: "1.2px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 7,
      height: 7,
      borderRadius: "50%",
      background: "var(--clay)"
    }
  }), "We noticed something"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 19,
      fontWeight: 900,
      letterSpacing: "-0.4px",
      lineHeight: 1.15,
      color: "var(--ink)",
      marginTop: 10
    }
  }, "Late dinners are costing you sleep."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--clay-text)",
      marginTop: 7,
      lineHeight: 1.4
    }
  }, "Calmest when dinner's before 20:30."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 700,
      color: "var(--ink)",
      marginTop: 11,
      display: "flex",
      alignItems: "center",
      gap: 6
    }
  }, "See the evidence \u2192")), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9.5,
      color: "var(--ink-3)",
      margin: "16px 0 8px",
      letterSpacing: "1px"
    }
  }, "Your signals \xB7 vs your normal"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8
    }
  }, chip("Sleep", "6h52", false, "baseline"), chip("In range", "61%", true, "correlation"), chip("HRV", "48", false, "baseline"), chip("RHR", "58", false, "baseline")), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      marginTop: 16,
      ...KICK,
      fontSize: 11,
      color: "var(--ink-3)",
      letterSpacing: "0.5px"
    }
  }, "Not averages. Yours.")));
}

/* ---------- CORRELATION (C plain sentence, depth on tap) ---------- */
function Correlation({
  back
}) {
  const [showData, setShowData] = useState(false);
  const [reminded, setReminded] = useState(false);
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(BackBar, {
    title: "Insight",
    onBack: back,
    right: GATED
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "14px 22px 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 27,
      fontWeight: 900,
      letterSpacing: "-0.7px",
      lineHeight: 1.16,
      color: "var(--ink)"
    }
  }, "78% of your restless nights followed a meal after ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--clay-text)"
    }
  }, "20:30"), "."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      lineHeight: 1.45,
      color: "var(--clay-text)",
      background: "var(--clay-2)",
      border: "1px solid var(--clay-3)",
      borderRadius: "var(--radius-md)",
      padding: "10px 12px",
      marginTop: 14,
      display: "flex",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", null, "\u25C6"), /*#__PURE__*/React.createElement("span", null, "Eat earlier and, in your data, the pattern eases. ", /*#__PURE__*/React.createElement("b", null, "Dinner before 20:30"), " is the lever.")), /*#__PURE__*/React.createElement("div", {
    style: {
      ...CARD,
      marginTop: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9.5,
      color: "var(--ink-3)"
    }
  }, "Of your restless nights"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      marginTop: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 26,
      borderRadius: 6,
      background: "var(--line-2)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: "78%",
      height: "100%",
      background: "var(--clay)"
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 18,
      fontWeight: 700,
      color: "var(--clay-text)"
    }
  }, "78%")), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: "var(--ink-3)",
      marginTop: 10,
      lineHeight: 1.45
    }
  }, "\u2026came after a late meal. Only 22% followed an early one.")), EVID, !showData && /*#__PURE__*/React.createElement("button", {
    onClick: () => setShowData(true),
    style: SECONDARY
  }, "See the data behind this \u203A"), showData && /*#__PURE__*/React.createElement("div", {
    style: {
      ...CARD,
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9.5,
      color: "var(--ink-3)"
    }
  }, "Before vs after 20:30"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 14,
      alignItems: "flex-end",
      height: 110,
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "flex-end",
      height: "100%"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 24,
      fontWeight: 900,
      color: "var(--moss-text-dark)",
      letterSpacing: "-0.5px"
    }
  }, "18%"), /*#__PURE__*/React.createElement("div", {
    style: {
      width: "100%",
      background: "var(--moss)",
      height: 22,
      borderRadius: "6px 6px 0 0",
      marginTop: 6
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10.5,
      fontWeight: 700,
      marginTop: 6
    }
  }, "Before")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "flex-end",
      height: "100%"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 24,
      fontWeight: 900,
      color: "var(--clay-text)",
      letterSpacing: "-0.5px"
    }
  }, "78%"), /*#__PURE__*/React.createElement("div", {
    style: {
      width: "100%",
      background: "var(--clay)",
      height: 92,
      borderRadius: "6px 6px 0 0",
      marginTop: 6
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10.5,
      fontWeight: 700,
      marginTop: 6
    }
  }, "After 20:30"))), /*#__PURE__*/React.createElement("svg", {
    viewBox: "0 0 300 70",
    style: {
      width: "100%",
      height: 60,
      marginTop: 14,
      display: "block"
    },
    preserveAspectRatio: "none"
  }, /*#__PURE__*/React.createElement("polyline", {
    fill: "none",
    stroke: "var(--clay)",
    strokeWidth: "2.2",
    strokeLinecap: "round",
    points: "6,20 40,30 74,24 108,52 142,58 176,32 210,28 244,56 278,60 296,40"
  }), /*#__PURE__*/React.createElement("polyline", {
    fill: "none",
    stroke: "var(--moss)",
    strokeWidth: "2.2",
    strokeLinecap: "round",
    points: "6,46 40,36 74,42 108,18 142,14 176,40 210,44 244,16 278,12 296,34"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 12,
      marginTop: 8,
      fontFamily: "var(--font-mono)",
      fontSize: 9.5,
      color: "var(--ink-3)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5
    }
  }, /*#__PURE__*/React.createElement("i", {
    style: {
      width: 14,
      height: 3,
      background: "var(--clay)",
      display: "block",
      borderRadius: 2
    }
  }), "Meal lateness"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5
    }
  }, /*#__PURE__*/React.createElement("i", {
    style: {
      width: 14,
      height: 3,
      background: "var(--moss)",
      display: "block",
      borderRadius: 2
    }
  }), "Sleep disruption"))), reminded ? /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14,
      background: "var(--moss-2)",
      border: "1px solid var(--moss-3)",
      borderRadius: "var(--radius-md)",
      padding: 14,
      color: "var(--moss-text-dark)",
      fontWeight: 700,
      fontSize: 14,
      display: "flex",
      alignItems: "center",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    name: "check",
    size: 16,
    color: "var(--moss)"
  }), " Reminder set for 20:30. Nice.") : /*#__PURE__*/React.createElement("button", {
    onClick: () => setReminded(true),
    style: PRIMARY
  }, "Remind me to wind down at 20:30"), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 18
    }
  })));
}

/* ---------- BASELINE (B Aperture arc) ---------- */
function Baseline({
  back
}) {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(BackBar, {
    title: "HRV",
    onBack: back
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "14px 22px 0",
      textAlign: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10.5,
      color: "var(--ink-3)",
      textAlign: "left",
      letterSpacing: "1.2px"
    }
  }, "Heart-rate variability"), /*#__PURE__*/React.createElement("svg", {
    viewBox: "0 0 220 200",
    style: {
      width: 240,
      height: 218,
      margin: "8px auto 0",
      display: "block"
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M 178.9 41.5 A 80 80 0 1 1 41.1 41.5",
    fill: "none",
    stroke: "var(--line)",
    strokeWidth: "13",
    strokeLinecap: "round"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M 168.4 152.6 A 80 80 0 0 1 51.6 152.6",
    fill: "none",
    stroke: "var(--moss-3)",
    strokeWidth: "13",
    strokeLinecap: "round"
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "98",
    cy: "189.6",
    r: "9",
    fill: "var(--moss)",
    stroke: "var(--paper)",
    strokeWidth: "3.5"
  }), /*#__PURE__*/React.createElement("text", {
    x: "100",
    y: "104",
    textAnchor: "middle",
    fontFamily: "var(--font-sans)",
    fontSize: "50",
    fontWeight: "900",
    fill: "var(--ink)",
    letterSpacing: "-2"
  }, "48"), /*#__PURE__*/React.createElement("text", {
    x: "100",
    y: "126",
    textAnchor: "middle",
    fontFamily: "var(--font-mono)",
    fontSize: "12",
    fill: "var(--moss-text-dark)",
    letterSpacing: "1"
  }, "IN YOUR RANGE")), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 11,
      color: "var(--ink-3)",
      marginTop: -6,
      letterSpacing: "0.5px"
    }
  }, "your normal 42\u201354 ms"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      lineHeight: 1.5,
      color: "var(--ink-2)",
      marginTop: 14,
      textAlign: "left"
    }
  }, "A calm day for you \u2014 ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--moss-text-dark)"
    }
  }, "recovery's trending up"), " across the week."), /*#__PURE__*/React.createElement("button", {
    style: PRIMARY
  }, "Log what's working"), /*#__PURE__*/React.createElement("button", {
    style: TERTIARY
  }, "See your 90-day baseline \u203A")));
}

/* ---------- WEEK (heatmap) ---------- */
const HM_BG = {
  good: "var(--moss-2)",
  good2: "var(--moss-3)",
  mild: "var(--clay-2)",
  flag: "var(--clay)",
  na: "var(--paper)"
};
const HM_ROWS = [["Sleep", ["good", "good2", "mild", "good", "good2", "good", "good2"]], ["Gluc", ["good", "good", "flag", "mild", "good", "good", "good"]], ["HRV", ["good2", "good", "flag", "mild", "good", "good2", "good"]], ["Energy", ["good", "good", "flag", "mild", "good", "good", "good2"]]];
function Week({
  push
}) {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "6px 20px 2px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 20,
      fontWeight: 900,
      letterSpacing: "-0.4px"
    }
  }, "This week"), /*#__PURE__*/React.createElement(Mark, {
    size: 22
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "10px 20px 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      color: "var(--ink-3)"
    }
  }, "19\u201325 May \xB7 vs your normal"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "46px repeat(7,1fr)",
      gap: 4,
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement("div", null), ["M", "T", "W", "T", "F", "S", "S"].map((d, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      ...KICK,
      fontSize: 9,
      textAlign: "center",
      color: i === 2 ? "var(--clay-text)" : "var(--ink-3)",
      fontWeight: i === 2 ? 700 : 400
    }
  }, d)), HM_ROWS.map(([label, cells]) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: label
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 8.5,
      color: "var(--ink-3)",
      display: "flex",
      alignItems: "center"
    }
  }, label), cells.map((c, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      aspectRatio: "1",
      borderRadius: i === 2 ? 6 : 5,
      background: HM_BG[c],
      border: c === "na" ? "1px solid var(--line-2)" : "none",
      boxShadow: i === 2 ? "0 0 0 2px var(--clay)" : "none"
    }
  }))))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 12,
      marginTop: 12,
      ...KICK,
      fontSize: 9,
      color: "var(--ink-3)",
      letterSpacing: "0.5px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5
    }
  }, /*#__PURE__*/React.createElement("i", {
    style: {
      width: 11,
      height: 11,
      borderRadius: 3,
      background: "var(--moss-2)",
      display: "block"
    }
  }), "In range"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5
    }
  }, /*#__PURE__*/React.createElement("i", {
    style: {
      width: 11,
      height: 11,
      borderRadius: 3,
      background: "var(--clay-2)",
      display: "block"
    }
  }), "Mild"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 5
    }
  }, /*#__PURE__*/React.createElement("i", {
    style: {
      width: 11,
      height: 11,
      borderRadius: 3,
      background: "var(--clay)",
      display: "block"
    }
  }), "Notice")), /*#__PURE__*/React.createElement("button", {
    onClick: () => push("correlation"),
    style: {
      ...CARD,
      border: "1px solid var(--clay-3)",
      borderLeft: "3px solid var(--clay)",
      textAlign: "left",
      width: "100%",
      marginTop: 16,
      cursor: "pointer",
      display: "block"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9.5,
      color: "var(--clay-text)"
    }
  }, "Wednesday \xB7 a cluster"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      fontWeight: 800,
      color: "var(--ink)",
      marginTop: 5,
      lineHeight: 1.25
    }
  }, "Meetings + a late dinner, and three signals dipped together."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 6,
      marginTop: 9,
      flexWrap: "wrap"
    }
  }, ["Glucose", "HRV", "Energy"].map(c => /*#__PURE__*/React.createElement("span", {
    key: c,
    style: {
      ...KICK,
      fontSize: 9,
      padding: "3px 7px",
      borderRadius: 999,
      background: "var(--clay-2)",
      color: "var(--clay-text)",
      letterSpacing: "0.4px"
    }
  }, c))), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12.5,
      fontWeight: 700,
      color: "var(--ink)",
      marginTop: 11
    }
  }, "See what connects them \u2192"))));
}

/* ---------- PRIVACY (consent control) ---------- */
function Grant({
  ini,
  color,
  name,
  org,
  chips,
  meta,
  onPause
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...CARD,
      marginBottom: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 34,
      height: 34,
      borderRadius: 9,
      flex: "none",
      display: "grid",
      placeItems: "center",
      color: "#fff",
      fontWeight: 800,
      fontSize: 12,
      background: color
    }
  }, ini), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15,
      fontWeight: 800,
      color: "var(--ink)"
    }
  }, name), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11.5,
      color: "var(--ink-3)"
    }
  }, org)), /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 9,
      padding: "4px 8px",
      borderRadius: 999,
      background: "var(--moss)",
      color: "#fff",
      letterSpacing: "0.4px"
    }
  }, "Active")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 6,
      flexWrap: "wrap",
      marginTop: 11
    }
  }, chips.map(c => /*#__PURE__*/React.createElement("span", {
    key: c,
    style: {
      ...KICK,
      fontSize: 9,
      padding: "4px 8px",
      borderRadius: 999,
      background: "var(--moss-2)",
      color: "var(--moss-text-dark)",
      letterSpacing: "0.4px"
    }
  }, c))), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11.5,
      color: "var(--ink-3)",
      marginTop: 10
    }
  }, meta), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onPause,
    style: {
      flex: 1,
      background: "var(--white)",
      border: "1px solid var(--clay-3)",
      color: "var(--clay-text)",
      borderRadius: "var(--radius-md)",
      padding: 10,
      fontSize: 13,
      fontWeight: 800,
      cursor: "pointer"
    }
  }, "Pause sharing"), /*#__PURE__*/React.createElement("button", {
    style: {
      flex: 1,
      background: "var(--white)",
      border: "1px solid var(--line)",
      color: "var(--ink-2)",
      borderRadius: "var(--radius-md)",
      padding: 10,
      fontSize: 13,
      fontWeight: 700,
      cursor: "pointer"
    }
  }, "Manage scope")));
}
function Privacy({
  push
}) {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "6px 20px 2px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 20,
      fontWeight: 900,
      letterSpacing: "-0.4px"
    }
  }, "Privacy"), /*#__PURE__*/React.createElement("button", {
    onClick: () => push("consentHistory"),
    style: {
      background: "none",
      border: "none",
      fontSize: 12.5,
      fontWeight: 700,
      color: "var(--ink-2)",
      cursor: "pointer"
    }
  }, "History \u203A")), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "10px 20px 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--moss-2)",
      border: "1px solid var(--moss-3)",
      borderRadius: "var(--radius-lg)",
      padding: "14px 15px",
      display: "flex",
      gap: 11,
      alignItems: "flex-start"
    }
  }, /*#__PURE__*/React.createElement(Mark, {
    size: 30
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 15.5,
      fontWeight: 800,
      color: "var(--ink)",
      letterSpacing: "-0.2px"
    }
  }, "Nothing is shared by default."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12.5,
      color: "var(--moss-text-dark)",
      marginTop: 2,
      lineHeight: 1.4
    }
  }, "Your data stays on this phone. You decide every exception."))), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      color: "var(--ink-3)",
      margin: "18px 0 9px"
    }
  }, "Who can see your data \xB7 2 active"), /*#__PURE__*/React.createElement(Grant, {
    ini: "DN",
    color: "#457B9D",
    name: "Dr. Lund \xB7 nurse",
    org: "Sygehus S\xF8nderjylland",
    chips: ["Glucose", "Time in range", "Meds"],
    meta: "Derived view only \xB7 expires in 6 days",
    onPause: () => push("pauseReceipt")
  }), /*#__PURE__*/React.createElement(Grant, {
    ini: "HC",
    color: "var(--clay)",
    name: "Mara \xB7 health coach",
    org: "Maude partner",
    chips: ["Sleep", "HRV", "Activity"],
    meta: "Pattern-only \xB7 expires in 20 days",
    onPause: () => push("pauseReceipt")
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      color: "var(--ink-3)",
      margin: "4px 0 9px"
    }
  }, "Research contributions"), /*#__PURE__*/React.createElement("div", {
    style: {
      border: "1px dashed var(--line)",
      borderRadius: "var(--radius-md)",
      padding: 14,
      fontSize: 12.5,
      color: "var(--ink-3)",
      lineHeight: 1.45
    }
  }, "Anonymous compute only \u2014 your device answers queries, your data never moves. ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--ink-2)"
    }
  }, "On \xB7 earns DfG tokens"))));
}

/* ---------- PAUSE RECEIPT ---------- */
function PauseReceipt({
  back,
  push
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      display: "flex",
      flexDirection: "column",
      justifyContent: "center",
      alignItems: "center",
      textAlign: "center",
      padding: "0 22px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 72,
      height: 72,
      borderRadius: "50%",
      background: "var(--clay-2)",
      border: "1px solid var(--clay-3)",
      display: "grid",
      placeItems: "center"
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    name: "pause",
    size: 28,
    color: "var(--clay)",
    stroke: 2.2
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 25,
      fontWeight: 900,
      letterSpacing: "-0.6px",
      color: "var(--ink)",
      marginTop: 18
    }
  }, "Paused. Nothing is shared."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14.5,
      lineHeight: 1.5,
      color: "var(--ink-2)",
      marginTop: 12,
      maxWidth: 280
    }
  }, "Dr. Lund can no longer see anything. It happened the instant you tapped \u2014 and it's on your record."), /*#__PURE__*/React.createElement("div", {
    style: {
      ...CARD,
      marginTop: 22,
      width: "100%",
      textAlign: "left"
    }
  }, [["EVENT", "SHARE_PAUSED", "var(--clay-text)"], ["RECIPIENT", "Dr. Lund", "var(--ink)"], ["AT", "22 May · 09:41:06", "var(--ink)"], ["RAW DATA", "← never stored", "var(--ink)"]].map(([k, v, c]) => /*#__PURE__*/React.createElement("div", {
    key: k,
    style: {
      display: "flex",
      justifyContent: "space-between",
      fontFamily: "var(--font-mono)",
      fontSize: 11,
      padding: "5px 0"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--ink-3)"
    }
  }, k), /*#__PURE__*/React.createElement("span", {
    style: {
      color: c,
      fontWeight: 600
    }
  }, v)))), /*#__PURE__*/React.createElement("div", {
    style: {
      width: "100%"
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: back,
    style: PRIMARY
  }, "Done"), /*#__PURE__*/React.createElement("button", {
    onClick: () => push("consentHistory"),
    style: TERTIARY
  }, "View consent history \u203A")));
}

/* ---------- CONSENT HISTORY (A) ---------- */
function ConsentHistory({
  back
}) {
  const ev = (color, t, m) => /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      marginBottom: 18
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      position: "absolute",
      left: -22,
      top: 2,
      width: 12,
      height: 12,
      borderRadius: "50%",
      background: color,
      border: "2px solid var(--paper)"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14.5,
      fontWeight: 700,
      color: "var(--ink)",
      lineHeight: 1.3
    }
  }, t), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 10.5,
      color: "var(--ink-3)",
      marginTop: 4
    }
  }, m, " \xB7 ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--moss-text-dark)"
    }
  }, "\u2713 verified")));
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(BackBar, {
    title: "Consent history",
    onBack: back
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "14px 22px 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--moss-2)",
      border: "1px solid var(--moss-3)",
      borderRadius: "var(--radius-md)",
      padding: "12px 14px",
      fontSize: 13.5,
      lineHeight: 1.45,
      color: "var(--ink-2)"
    }
  }, "Every access to your data is recorded here. ", /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--moss-text-dark)"
    }
  }, "Nobody can edit this \u2014 not even us.")), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      paddingLeft: 22,
      marginTop: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      left: 5,
      top: 8,
      bottom: 8,
      width: 2,
      background: "var(--line)"
    }
  }), ev("var(--clay)", "You paused Dr. Lund's access.", "Today · 09:41"), ev("var(--ink-4)", "Dr. Lund viewed your glucose summary.", "Yesterday · 14:32"), ev("var(--moss)", "You shared sleep & HRV with Mara.", "19 May · 08:10"), ev("var(--moss)", "Maude answered a research query — anonymously.", "18 May · 02:00")), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      fontWeight: 700,
      color: "var(--ink-2)"
    }
  }, "Technical details \u203A")));
}

/* ---------- JOURNAL ---------- */
function Journal() {
  const cap = (icon, label, clay) => /*#__PURE__*/React.createElement("div", {
    style: {
      ...CARD,
      display: "flex",
      alignItems: "center",
      gap: 11,
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 36,
      height: 36,
      borderRadius: 10,
      flex: "none",
      display: "grid",
      placeItems: "center",
      background: clay ? "var(--clay-2)" : "var(--moss-2)"
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    name: icon,
    size: 18,
    color: clay ? "var(--clay)" : "var(--moss)"
  })), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 14,
      fontWeight: 800,
      color: "var(--ink)"
    }
  }, label));
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "6px 20px 2px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 20,
      fontWeight: 900,
      letterSpacing: "-0.4px"
    }
  }, "Journal")), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "10px 20px 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      color: "var(--ink-3)",
      marginBottom: 9
    }
  }, "Capture"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 10
    }
  }, cap("smile", "Log mood"), cap("utensils", "Add meal"), cap("activity", "Add symptom", true), cap("mic", "Voice note")), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      color: "var(--ink-3)",
      margin: "16px 0 8px"
    }
  }, "Suggested now"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      flexWrap: "wrap"
    }
  }, ["It's 21:30 — log dinner?", "Note how you slept?"].map(s => /*#__PURE__*/React.createElement("span", {
    key: s,
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 7,
      background: "var(--clay-2)",
      border: "1px solid var(--clay-3)",
      color: "var(--clay-text)",
      fontSize: 12.5,
      fontWeight: 700,
      padding: "8px 12px",
      borderRadius: 999
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 6,
      height: 6,
      borderRadius: "50%",
      background: "var(--clay)"
    }
  }), s))), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      color: "var(--ink-3)",
      margin: "18px 0 4px"
    }
  }, "Recent \xB7 private by default"), [["var(--moss)", "Felt good · light run", "Today 08:10"], ["var(--clay)", "Headache after late dinner", "Yesterday 22:40"]].map(([c, t, m]) => /*#__PURE__*/React.createElement("div", {
    key: t,
    style: {
      display: "flex",
      gap: 11,
      padding: "11px 0",
      borderBottom: "1px solid var(--line-2)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 9,
      height: 9,
      borderRadius: "50%",
      marginTop: 5,
      flex: "none",
      background: c
    }
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 700,
      color: "var(--ink)"
    }
  }, t), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 10.5,
      color: "var(--ink-3)",
      marginTop: 3
    }
  }, m, " \xB7 \uD83D\uDD12 on device"))))));
}

/* ---------- SETTINGS (stub) ---------- */
function Settings() {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "6px 20px 2px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 20,
      fontWeight: 900,
      letterSpacing: "-0.4px"
    }
  }, "Settings")), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "12px 20px 0"
    }
  }, ["Account", "Data sources", "Notifications", "Technical details", "About Maude"].map(s => /*#__PURE__*/React.createElement("div", {
    key: s,
    style: {
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      padding: "15px 0",
      borderBottom: "1px solid var(--line-2)",
      fontSize: 15,
      color: "var(--ink)"
    }
  }, s, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--ink-4)"
    }
  }, "\u203A"))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 22,
      display: "flex",
      alignItems: "center",
      gap: 8,
      justifyContent: "center",
      opacity: 0.8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 9,
      color: "var(--ink-4)"
    }
  }, "Powered by"), /*#__PURE__*/React.createElement("span", {
    style: {
      background: "var(--ink)",
      borderRadius: 6,
      padding: "5px 8px",
      display: "flex"
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: ASSET + "dfg_logo_negative.svg",
    alt: "Data for Good",
    style: {
      height: 16,
      filter: "brightness(0) invert(1)"
    }
  })))));
}

/* ---------- TAB BAR ---------- */
const TABS = [{
  id: "home",
  label: "Home",
  icon: "circle"
}, {
  id: "insights",
  label: "Insights",
  icon: "trending-up"
}, {
  id: "journal",
  label: "Journal",
  icon: "book-open"
}, {
  id: "privacy",
  label: "Privacy",
  icon: "shield"
}, {
  id: "settings",
  label: "Settings",
  icon: "settings"
}];
function TabBar({
  tab,
  setTab
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      borderTop: "1px solid var(--line)",
      background: "var(--paper)",
      padding: "9px 0 26px"
    }
  }, TABS.map(t => {
    const on = t.id === tab;
    return /*#__PURE__*/React.createElement("button", {
      key: t.id,
      onClick: () => setTab(t.id),
      style: {
        flex: 1,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 4,
        background: "none",
        border: "none",
        cursor: "pointer",
        color: on ? "var(--ink)" : "var(--ink-3)"
      }
    }, t.id === "home" ? /*#__PURE__*/React.createElement("svg", {
      width: "20",
      height: "20",
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: on ? "var(--ink)" : "var(--ink-3)",
      strokeWidth: on ? 2.2 : 1.9
    }, /*#__PURE__*/React.createElement("circle", {
      cx: "12",
      cy: "12",
      r: "9"
    }), /*#__PURE__*/React.createElement("circle", {
      cx: "12",
      cy: "12",
      r: "2.4",
      fill: on ? "var(--ink)" : "var(--ink-3)"
    })) : /*#__PURE__*/React.createElement(Ico, {
      name: t.icon,
      size: 20,
      color: on ? "var(--ink)" : "var(--ink-3)",
      stroke: on ? 2.2 : 1.8
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 9.5,
        fontWeight: on ? 700 : 400
      }
    }, t.label), /*#__PURE__*/React.createElement("span", {
      style: {
        width: 4,
        height: 4,
        borderRadius: "50%",
        background: on ? "var(--moss)" : "transparent"
      }
    }));
  }));
}

/* ---------- APP ---------- */
const ROOTS = {
  home: "home",
  insights: "week",
  journal: "journal",
  privacy: "privacy",
  settings: "settings"
};
function MaudePrototype() {
  const [tab, setTab] = useState("home");
  const [stack, setStack] = useState([]);
  const cur = stack.length ? stack[stack.length - 1] : ROOTS[tab];
  const push = id => setStack(s => [...s, id]);
  const back = () => setStack(s => s.slice(0, -1));
  const switchTab = t => {
    setTab(t);
    setStack([]);
  };
  const screens = {
    home: /*#__PURE__*/React.createElement(Home, {
      push: push
    }),
    correlation: /*#__PURE__*/React.createElement(Correlation, {
      back: back
    }),
    baseline: /*#__PURE__*/React.createElement(Baseline, {
      back: back
    }),
    week: /*#__PURE__*/React.createElement(Week, {
      push: push
    }),
    privacy: /*#__PURE__*/React.createElement(Privacy, {
      push: push
    }),
    pauseReceipt: /*#__PURE__*/React.createElement(PauseReceipt, {
      back: back,
      push: push
    }),
    consentHistory: /*#__PURE__*/React.createElement(ConsentHistory, {
      back: back
    }),
    journal: /*#__PURE__*/React.createElement(Journal, null),
    settings: /*#__PURE__*/React.createElement(Settings, null)
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      display: "flex",
      flexDirection: "column",
      background: "var(--paper)",
      fontFamily: "var(--font-sans)",
      paddingTop: 46
    }
  }, /*#__PURE__*/React.createElement("div", {
    key: cur,
    style: {
      flex: 1,
      overflow: "auto"
    }
  }, screens[cur]), /*#__PURE__*/React.createElement(TabBar, {
    tab: tab,
    setTab: switchTab
  }));
}
window.MaudePrototype = MaudePrototype;
})(); } catch (e) { __ds_ns.__errors.push({ path: "maude-prototype/prototype.jsx", error: String((e && e.message) || e) }); }

// ui_kits/maude-app/app.jsx
try { (() => {
// Maude citizen app — UI kit recreation (Today + Wallet + tab chrome).
// Self-contained: styled with the Maude design tokens (styles.css). Mirrors the DS
// primitives (NudgeCard, MetricRing, Card, ConsentChip) from the SwiftUI source.
// Attaches MaudeApp to window for index.html to mount inside <IOSDevice>.

const ASSET = "../../assets/brand/";

// ── tiny Lucide icon helper (flagged SF Symbols substitute) ──
function renderLucide(arr) {
  return arr.map((child, i) => {
    if (!Array.isArray(child)) return null;
    if (typeof child[0] === "string") {
      const kids = Array.isArray(child[2]) ? renderLucide(child[2]) : null;
      return React.createElement(child[0], {
        key: i,
        ...(child[1] || {})
      }, kids);
    }
    return renderLucide(child);
  });
}
function Ico({
  name,
  size = 20,
  color = "currentColor",
  stroke = 1.9,
  style
}) {
  const lib = typeof window !== "undefined" ? window.lucide : null;
  const toP = n => String(n).replace(/(^\w|-\w)/g, m => m.replace("-", "").toUpperCase());
  const node = lib && lib.icons ? lib.icons[toP(name)] : null;
  if (!node) return /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-block",
      width: size,
      height: size,
      ...style
    }
  });
  return /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: color,
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeLinejoin: "round",
    style: {
      display: "block",
      ...style
    }
  }, renderLucide(node));
}

// ── Iris mark (embed, never redraw) ──
function Mark({
  size = 26,
  reversed = false
}) {
  return /*#__PURE__*/React.createElement("img", {
    src: ASSET + (reversed ? "maude_mark_iris_reversed.svg" : "maude_mark_iris.svg"),
    alt: "Maude",
    width: size,
    height: size,
    style: {
      display: "block"
    }
  });
}

// ── App bar ──
function AppBar({
  showMark,
  title,
  initials = "CN"
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10,
      padding: "8px 20px 4px"
    }
  }, showMark ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Mark, {
    size: 26
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 17,
      fontWeight: 900,
      letterSpacing: "-0.3px",
      color: "var(--ink)"
    }
  }, "Maude")) : /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 17,
      fontWeight: 900,
      letterSpacing: "-0.3px",
      color: "var(--ink)"
    }
  }, title), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 32,
      height: 32,
      borderRadius: "50%",
      background: "var(--ink)",
      color: "#fff",
      display: "grid",
      placeItems: "center",
      fontSize: 12,
      fontWeight: 600
    }
  }, initials));
}
const KICK = {
  fontFamily: "var(--font-mono)",
  textTransform: "uppercase"
};
function SectionHeader({
  label,
  trailing,
  trailingColor = "var(--moss)"
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      padding: "22px 20px 8px"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 11,
      letterSpacing: "1.6px",
      color: "var(--ink-3)"
    }
  }, label), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), trailing && /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 10.5,
      letterSpacing: "1px",
      color: trailingColor
    }
  }, trailing));
}

// ── Metric ring ──
function MetricRing({
  value,
  label,
  progress,
  warn
}) {
  const size = 78,
    stroke = 7.5,
    r = (size - stroke) / 2,
    c = 2 * Math.PI * r;
  const arc = warn ? "var(--amber)" : "var(--moss)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      gap: 8,
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      width: size,
      height: size
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: size,
    height: size,
    style: {
      transform: "rotate(-90deg)"
    }
  }, /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r,
    fill: "none",
    stroke: "var(--line-2)",
    strokeWidth: stroke
  }), /*#__PURE__*/React.createElement("circle", {
    cx: size / 2,
    cy: size / 2,
    r: r,
    fill: "none",
    stroke: arc,
    strokeWidth: stroke,
    strokeLinecap: "round",
    strokeDasharray: c,
    strokeDashoffset: c * (1 - progress)
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      display: "grid",
      placeItems: "center",
      fontFamily: "var(--font-mono)",
      fontVariantNumeric: "tabular-nums",
      fontWeight: 600,
      fontSize: 16,
      color: "var(--ink)"
    }
  }, value)), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9.5,
      letterSpacing: "1px",
      color: "var(--ink-3)",
      textAlign: "center"
    }
  }, label));
}
function RingsCard() {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      margin: "18px 20px 0",
      display: "flex",
      gap: 10,
      padding: "18px 12px",
      background: "var(--paper-2)",
      border: "0.5px solid var(--line)",
      borderRadius: "var(--radius-lg)",
      boxShadow: "var(--shadow-card)"
    }
  }, /*#__PURE__*/React.createElement(MetricRing, {
    value: "7.2",
    label: "Glucose",
    progress: 0.62
  }), /*#__PURE__*/React.createElement(MetricRing, {
    value: "74%",
    label: "In range",
    progress: 0.74
  }), /*#__PURE__*/React.createElement(MetricRing, {
    value: "48",
    label: "HRV ms",
    progress: 0.4,
    warn: true
  }));
}

// ── Lifestyle / week-in-context card (amber) ──
function LifestyleCard() {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      margin: "18px 20px 0",
      padding: 14,
      background: "var(--paper-2)",
      border: "0.5px solid var(--line)",
      borderRadius: 12,
      boxShadow: "var(--shadow-card)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 9,
      letterSpacing: "1px",
      color: "var(--amber)"
    }
  }, "WEEK IN CONTEXT"), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 9,
      letterSpacing: "0.6px",
      color: "var(--amber)",
      background: "var(--amber-2)",
      padding: "3px 8px",
      borderRadius: 999
    }
  }, "STRONG")), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14,
      fontWeight: 700,
      letterSpacing: "-0.2px",
      color: "var(--ink)",
      marginTop: 10
    }
  }, "High meeting load + late dinner \u2192 HRV dip"), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 5,
      borderRadius: 999,
      background: "var(--line-2)",
      marginTop: 10,
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: "74%",
      height: "100%",
      background: "var(--amber)",
      borderRadius: 999
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      lineHeight: 1.5,
      color: "var(--ink-2)",
      marginTop: 10
    }
  }, "Wednesday's back-to-back meetings and a meal after 21:00 track with a 15% lower HRV the following morning in your data. This pattern showed up on 3 of the last 4 high-load days."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 6,
      marginTop: 10
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    name: "info",
    size: 13,
    color: "var(--ink-4)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 11.5,
      color: "var(--ink-4)"
    }
  }, "A pattern in your own data \u2014 not a medical finding.")), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 6,
      marginTop: 12
    }
  }, ["Calendar", "Spending", "HRV"].map(s => /*#__PURE__*/React.createElement("span", {
    key: s,
    style: {
      ...KICK,
      fontSize: 8,
      letterSpacing: "0.5px",
      color: "var(--ink-3)",
      background: "var(--line-2)",
      padding: "3px 7px",
      borderRadius: 999
    }
  }, s)), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: "var(--moss)",
      fontWeight: 600
    }
  }, "View full week \u2192")));
}

// ── Nudge card ──
const NUDGE_ACCENT = {
  sleep: "var(--moss)",
  glucose: "var(--amber)",
  cardiac: "var(--ink-3)"
};
function NudgeCard({
  time,
  tag,
  accent,
  body,
  primary,
  secondary
}) {
  const ac = NUDGE_ACCENT[accent] || "var(--ink-4)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--paper-2)",
      border: "0.5px solid var(--line)",
      borderLeft: `3px solid ${ac}`,
      borderRadius: "var(--radius-md)",
      boxShadow: "var(--shadow-card)",
      padding: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      letterSpacing: "1.2px",
      marginBottom: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--ink-3)"
    }
  }, time, " \xB7 "), /*#__PURE__*/React.createElement("span", {
    style: {
      color: ac
    }
  }, tag)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 14.5,
      lineHeight: 1.45,
      color: "var(--ink-2)"
    }
  }, body), (primary || secondary) && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 8,
      marginTop: 12
    }
  }, primary && /*#__PURE__*/React.createElement("button", {
    style: {
      fontSize: 12.5,
      fontWeight: 500,
      padding: "8px 14px",
      background: "var(--ink)",
      color: "#fff",
      border: "none",
      borderRadius: "var(--radius-md)",
      cursor: "pointer"
    }
  }, primary), secondary && /*#__PURE__*/React.createElement("button", {
    style: {
      fontSize: 12.5,
      fontWeight: 500,
      padding: "8px 14px",
      background: "var(--paper)",
      color: "var(--ink-2)",
      border: "1px solid var(--line)",
      borderRadius: "var(--radius-md)",
      cursor: "pointer"
    }
  }, secondary)));
}

// ── TODAY screen ──
function TodayScreen() {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(AppBar, {
    showMark: true
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "14px 20px 4px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 11,
      letterSpacing: "1.6px",
      color: "var(--ink-3)"
    }
  }, "THU \xB7 22 MAY"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 30,
      fontWeight: 900,
      letterSpacing: "-0.7px",
      lineHeight: 1.08,
      color: "var(--ink)",
      marginTop: 6
    }
  }, "Good morning,", /*#__PURE__*/React.createElement("br", null), "Clara")), /*#__PURE__*/React.createElement(RingsCard, null), /*#__PURE__*/React.createElement(LifestyleCard, null), /*#__PURE__*/React.createElement(SectionHeader, {
    label: "Today's nudges",
    trailing: "3 NEW"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 10,
      padding: "0 20px 24px"
    }
  }, /*#__PURE__*/React.createElement(NudgeCard, {
    time: "08:14",
    tag: "SLEEP",
    accent: "sleep",
    body: "You woke twice between 02:00\u201304:00 last night. On nights after a late workout this month, your deep sleep ran ~20 min shorter \u2014 a pattern in your own data.",
    primary: "See the pattern",
    secondary: "Not now"
  }), /*#__PURE__*/React.createElement(NudgeCard, {
    time: "12:30",
    tag: "GLUCOSE",
    accent: "glucose",
    body: "Lunches with bread pushed your glucose above 9 mmol/L on 4 of 6 days this week. Adding a walk afterwards tracked with a gentler curve last week."
  }), /*#__PURE__*/React.createElement(NudgeCard, {
    time: "07:50",
    tag: "CARDIAC",
    accent: "cardiac",
    body: "Resting heart rate has held steady at 58 bpm across the last 10 mornings. Nothing to act on \u2014 just confirming a stable baseline."
  })));
}

// ── WALLET screen ──
function IrisMini() {
  return /*#__PURE__*/React.createElement("img", {
    src: ASSET + "maude_mark_iris_reversed.svg",
    alt: "",
    width: 34,
    height: 34,
    style: {
      opacity: 0.92
    }
  });
}
function StatCell({
  label,
  value,
  sub
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      textAlign: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9,
      letterSpacing: "1px",
      color: "var(--ink-4)"
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontVariantNumeric: "tabular-nums",
      fontSize: 20,
      color: "#fff",
      margin: "2px 0"
    }
  }, value), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9,
      color: "var(--ink-3)"
    }
  }, sub));
}
function SpendCard({
  icon,
  title,
  desc,
  cost,
  charity
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 14,
      padding: 14,
      background: "var(--paper-2)",
      border: "1px solid var(--line-2)",
      borderRadius: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 40,
      height: 40,
      borderRadius: "50%",
      flex: "none",
      display: "grid",
      placeItems: "center",
      background: charity ? "var(--rust-2)" : "var(--moss-2)"
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    name: icon,
    size: 16,
    color: charity ? "var(--rust)" : "var(--moss)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13.5,
      fontWeight: 600,
      color: "var(--ink)"
    }
  }, title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: "var(--ink-3)",
      lineHeight: 1.35
    }
  }, desc)), /*#__PURE__*/React.createElement("button", {
    style: {
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      padding: "6px 10px",
      background: "var(--ink)",
      color: "#fff",
      border: "none",
      borderRadius: 8,
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 13
    }
  }, cost), /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 8
    }
  }, "tokens")));
}
function WalletScreen() {
  const [tab, setTab] = React.useState("inApp");
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(AppBar, {
    title: "DfG Tokens"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: "12px 20px 0",
      background: "var(--ink)",
      borderRadius: "var(--radius-lg)",
      padding: "20px 20px 16px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "flex-start"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10,
      letterSpacing: "1px",
      color: "var(--ink-4)"
    }
  }, "TOKEN BALANCE"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      gap: 6,
      marginTop: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 48,
      fontWeight: 700,
      color: "#fff",
      lineHeight: 1
    }
  }, "12"), /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 13,
      color: "var(--moss-rev)"
    }
  }, "DfG"))), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement(IrisMini, null)), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 1,
      background: "rgba(255,255,255,0.1)",
      margin: "14px 0"
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex"
    }
  }, /*#__PURE__*/React.createElement(StatCell, {
    label: "EARNED",
    value: "14",
    sub: "last 30 days"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 1,
      background: "rgba(255,255,255,0.1)"
    }
  }), /*#__PURE__*/React.createElement(StatCell, {
    label: "DONATED",
    value: "2",
    sub: "all time"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 1,
      background: "rgba(255,255,255,0.1)"
    }
  }), /*#__PURE__*/React.createElement(StatCell, {
    label: "REDEEMED",
    value: "0",
    sub: "in-app"
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: "12px 20px 0",
      display: "flex",
      gap: 10,
      padding: 12,
      background: "var(--moss-2)",
      border: "1px solid var(--moss-3)",
      borderRadius: 10
    }
  }, /*#__PURE__*/React.createElement(Ico, {
    name: "shield-check",
    size: 15,
    color: "var(--moss)",
    style: {
      flex: "none",
      marginTop: 1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 12,
      color: "var(--ink-3)",
      lineHeight: 1.4
    }
  }, "You earn tokens when your device contributes to anonymised research queries. Your health data never leaves this phone.")), /*#__PURE__*/React.createElement(SectionHeader, {
    label: "Recent earnings"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      margin: "0 20px",
      background: "var(--paper-2)",
      border: "1px solid var(--line-2)",
      borderRadius: 12,
      overflow: "hidden"
    }
  }, [["CGM variability cohort query answered", "Diabetes research", "+4", "1h ago"], ["Sleep fragmentation pattern contributed", "Sleep science", "+2", "1d ago"], ["HRV + activity correlation computed", "Cardiovascular research", "+3", "2d ago"]].map((e, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12,
      padding: "11px 16px",
      borderTop: i ? "1px solid var(--line-2)" : "none"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--ink)"
    }
  }, e[0]), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9,
      letterSpacing: "0.5px",
      color: "var(--ink-3)"
    }
  }, e[1])), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "right"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-mono)",
      fontSize: 14,
      color: "var(--moss)"
    }
  }, e[2]), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 10.5,
      color: "var(--ink-4)"
    }
  }, e[3]))))), /*#__PURE__*/React.createElement(SectionHeader, {
    label: "Spend"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "0 20px 24px"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "inline-flex",
      width: "100%",
      border: "1px solid var(--line)",
      borderRadius: 10,
      overflow: "hidden",
      background: "var(--paper-2)",
      marginBottom: 12
    }
  }, [["inApp", "In-app features"], ["charity", "Charity donation"]].map(([v, l]) => /*#__PURE__*/React.createElement("button", {
    key: v,
    onClick: () => setTab(v),
    style: {
      flex: 1,
      padding: "9px 0",
      fontSize: 12.5,
      fontWeight: 500,
      border: "none",
      background: tab === v ? "var(--ink)" : "transparent",
      color: tab === v ? "#fff" : "var(--ink-3)",
      cursor: "pointer"
    }
  }, l))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 8
    }
  }, tab === "inApp" ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(SpendCard, {
    icon: "history",
    title: "Extended history",
    desc: "Nudge patterns across 12 months instead of 3",
    cost: 8
  }), /*#__PURE__*/React.createElement(SpendCard, {
    icon: "cloud-sun",
    title: "Weather correlation layer",
    desc: "Correlate your metrics with local air quality and pollen",
    cost: 5
  })) : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(SpendCard, {
    icon: "heart",
    title: "Diabetes Research Centre",
    desc: "Donate to type 1 diabetes research in Denmark",
    cost: 10,
    charity: true
  }), /*#__PURE__*/React.createElement(SpendCard, {
    icon: "globe",
    title: "Open Health Data Initiative",
    desc: "Support public-domain health data infrastructure",
    cost: 5,
    charity: true
  })))));
}

// ── Tab bar ──
const TABS = [{
  id: "today",
  label: "Today",
  icon: "circle"
}, {
  id: "trends",
  label: "Trends",
  icon: "trending-up"
}, {
  id: "wallet",
  label: "Wallet",
  icon: "wallet"
}, {
  id: "journal",
  label: "Journal",
  icon: "book-open"
}];
function TabBar({
  tab,
  setTab
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      background: "var(--paper)",
      borderTop: "0.5px solid var(--line)",
      padding: "10px 0 26px"
    }
  }, TABS.map(t => {
    const on = t.id === tab;
    return /*#__PURE__*/React.createElement("button", {
      key: t.id,
      onClick: () => setTab(t.id),
      style: {
        flex: 1,
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        gap: 5,
        background: "none",
        border: "none",
        cursor: "pointer",
        color: on ? "var(--ink)" : "var(--ink-3)"
      }
    }, /*#__PURE__*/React.createElement(Ico, {
      name: t.icon,
      size: 20,
      color: on ? "var(--ink)" : "var(--ink-3)",
      stroke: on ? 2.2 : 1.8
    }), /*#__PURE__*/React.createElement("span", {
      style: {
        fontSize: 10,
        fontWeight: on ? 700 : 400,
        letterSpacing: "0.2px"
      }
    }, t.label), /*#__PURE__*/React.createElement("span", {
      style: {
        width: 4,
        height: 4,
        borderRadius: "50%",
        background: on ? "var(--moss)" : "transparent"
      }
    }));
  }));
}
function Placeholder({
  title
}) {
  return /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(AppBar, {
    title: title
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      placeItems: "center",
      height: 360,
      color: "var(--ink-4)",
      fontSize: 13,
      textAlign: "center",
      padding: "0 40px"
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement(Mark, {
    size: 40
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14
    }
  }, title, " \u2014 recreation not included in this kit."))));
}
function MaudeApp() {
  const [tab, setTab] = React.useState("today");
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: "100%",
      display: "flex",
      flexDirection: "column",
      background: "var(--paper)",
      fontFamily: "var(--font-sans)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: "auto",
      paddingTop: 50
    }
  }, tab === "today" && /*#__PURE__*/React.createElement(TodayScreen, null), tab === "wallet" && /*#__PURE__*/React.createElement(WalletScreen, null), tab === "trends" && /*#__PURE__*/React.createElement(Placeholder, {
    title: "Trends"
  }), tab === "journal" && /*#__PURE__*/React.createElement(Placeholder, {
    title: "Journal"
  })), /*#__PURE__*/React.createElement(TabBar, {
    tab: tab,
    setTab: setTab
  }));
}
window.MaudeApp = MaudeApp;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/maude-app/app.jsx", error: String((e && e.message) || e) }); }

// ui_kits/maude-app/ios-frame.jsx
try { (() => {
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)

/* BEGIN USAGE */
// iOS.jsx — Simplified iOS 26 (Liquid Glass) device frame
// Based on the iOS 26 UI Kit + Figma status bar spec. No assets, no deps.
// Exports (to window): IOSDevice, IOSStatusBar, IOSNavBar, IOSGlassPill, IOSList, IOSListRow, IOSKeyboard
//
// Usage — wrap your screen content in <IOSDevice> to get the bezel, status bar
// and home indicator (props: title, dark, keyboard):
//
//   <IOSDevice title="Settings">
//     ...your screen content...
//   </IOSDevice>
//   <IOSDevice dark title="Search" keyboard>…</IOSDevice>
/* END USAGE */

// ─────────────────────────────────────────────────────────────
// Status bar
// ─────────────────────────────────────────────────────────────
function IOSStatusBar({
  dark = false,
  time = '9:41'
}) {
  const c = dark ? '#fff' : '#000';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 154,
      alignItems: 'center',
      justifyContent: 'center',
      padding: '21px 24px 19px',
      boxSizing: 'border-box',
      position: 'relative',
      zIndex: 20,
      width: '100%'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 22,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      paddingTop: 1.5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: '-apple-system, "SF Pro", system-ui',
      fontWeight: 590,
      fontSize: 17,
      lineHeight: '22px',
      color: c
    }
  }, time)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 22,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 7,
      paddingTop: 1,
      paddingRight: 1
    }
  }, /*#__PURE__*/React.createElement("svg", {
    width: "19",
    height: "12",
    viewBox: "0 0 19 12"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0",
    y: "7.5",
    width: "3.2",
    height: "4.5",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "4.8",
    y: "5",
    width: "3.2",
    height: "7",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "9.6",
    y: "2.5",
    width: "3.2",
    height: "9.5",
    rx: "0.7",
    fill: c
  }), /*#__PURE__*/React.createElement("rect", {
    x: "14.4",
    y: "0",
    width: "3.2",
    height: "12",
    rx: "0.7",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "17",
    height: "12",
    viewBox: "0 0 17 12"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z",
    fill: c
  }), /*#__PURE__*/React.createElement("path", {
    d: "M8.5 6.8C9.9 6.8 11.1 7.3 12 8.2L13.1 7.1C11.8 5.9 10.2 5.1 8.5 5.1C6.8 5.1 5.2 5.9 3.9 7.1L5 8.2C5.9 7.3 7.1 6.8 8.5 6.8Z",
    fill: c
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "8.5",
    cy: "10.5",
    r: "1.5",
    fill: c
  })), /*#__PURE__*/React.createElement("svg", {
    width: "27",
    height: "13",
    viewBox: "0 0 27 13"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "0.5",
    y: "0.5",
    width: "23",
    height: "12",
    rx: "3.5",
    stroke: c,
    strokeOpacity: "0.35",
    fill: "none"
  }), /*#__PURE__*/React.createElement("rect", {
    x: "2",
    y: "2",
    width: "20",
    height: "9",
    rx: "2",
    fill: c
  }), /*#__PURE__*/React.createElement("path", {
    d: "M25 4.5V8.5C25.8 8.2 26.5 7.2 26.5 6.5C26.5 5.8 25.8 4.8 25 4.5Z",
    fill: c,
    fillOpacity: "0.4"
  }))));
}

// ─────────────────────────────────────────────────────────────
// Liquid glass pill — blur + tint + shine
// ─────────────────────────────────────────────────────────────
function IOSGlassPill({
  children,
  dark = false,
  style = {}
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 44,
      minWidth: 44,
      borderRadius: 9999,
      position: 'relative',
      overflow: 'hidden',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      boxShadow: dark ? '0 2px 6px rgba(0,0,0,0.35), 0 6px 16px rgba(0,0,0,0.2)' : '0 1px 3px rgba(0,0,0,0.07), 0 3px 10px rgba(0,0,0,0.06)',
      ...style
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 9999,
      backdropFilter: 'blur(12px) saturate(180%)',
      WebkitBackdropFilter: 'blur(12px) saturate(180%)',
      background: dark ? 'rgba(120,120,128,0.28)' : 'rgba(255,255,255,0.5)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 9999,
      boxShadow: dark ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15), inset -1px -1px 1px rgba(255,255,255,0.08)' : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
      border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 1,
      display: 'flex',
      alignItems: 'center',
      padding: '0 4px'
    }
  }, children));
}

// ─────────────────────────────────────────────────────────────
// Navigation bar — glass pills + large title
// ─────────────────────────────────────────────────────────────
function IOSNavBar({
  title = 'Title',
  dark = false,
  trailingIcon = true
}) {
  const muted = dark ? 'rgba(255,255,255,0.6)' : '#404040';
  const text = dark ? '#fff' : '#000';
  const pillIcon = content => /*#__PURE__*/React.createElement(IOSGlassPill, {
    dark: dark
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 36,
      height: 36,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, content));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10,
      paddingTop: 62,
      paddingBottom: 10,
      position: 'relative',
      zIndex: 5
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 16px'
    }
  }, pillIcon(/*#__PURE__*/React.createElement("svg", {
    width: "12",
    height: "20",
    viewBox: "0 0 12 20",
    fill: "none",
    style: {
      marginLeft: -1
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M10 2L2 10l8 8",
    stroke: muted,
    strokeWidth: "2.5",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  }))), trailingIcon && pillIcon(/*#__PURE__*/React.createElement("svg", {
    width: "22",
    height: "6",
    viewBox: "0 0 22 6"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "3",
    cy: "3",
    r: "2.5",
    fill: muted
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "3",
    r: "2.5",
    fill: muted
  }), /*#__PURE__*/React.createElement("circle", {
    cx: "19",
    cy: "3",
    r: "2.5",
    fill: muted
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px',
      fontFamily: '-apple-system, system-ui',
      fontSize: 34,
      fontWeight: 700,
      lineHeight: '41px',
      color: text,
      letterSpacing: 0.4
    }
  }, title));
}

// ─────────────────────────────────────────────────────────────
// Grouped list (inset card, r:26) + row (52px)
// ─────────────────────────────────────────────────────────────
function IOSListRow({
  title,
  detail,
  icon,
  chevron = true,
  isLast = false,
  dark = false
}) {
  const text = dark ? '#fff' : '#000';
  const sec = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const ter = dark ? 'rgba(235,235,245,0.3)' : 'rgba(60,60,67,0.3)';
  const sep = dark ? 'rgba(84,84,88,0.65)' : 'rgba(60,60,67,0.12)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      minHeight: 52,
      padding: '0 16px',
      position: 'relative',
      fontFamily: '-apple-system, system-ui',
      fontSize: 17,
      letterSpacing: -0.43
    }
  }, icon && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 30,
      height: 30,
      borderRadius: 7,
      background: icon,
      marginRight: 12,
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      color: text
    }
  }, title), detail && /*#__PURE__*/React.createElement("span", {
    style: {
      color: sec,
      marginRight: 6
    }
  }, detail), chevron && /*#__PURE__*/React.createElement("svg", {
    width: "8",
    height: "14",
    viewBox: "0 0 8 14",
    style: {
      flexShrink: 0
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 1l6 6-6 6",
    stroke: ter,
    strokeWidth: "2",
    fill: "none",
    strokeLinecap: "round",
    strokeLinejoin: "round"
  })), !isLast && /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      right: 0,
      left: icon ? 58 : 16,
      height: 0.5,
      background: sep
    }
  }));
}
function IOSList({
  header,
  children,
  dark = false
}) {
  const hc = dark ? 'rgba(235,235,245,0.6)' : 'rgba(60,60,67,0.6)';
  const bg = dark ? '#1C1C1E' : '#fff';
  return /*#__PURE__*/React.createElement("div", null, header && /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: '-apple-system, system-ui',
      fontSize: 13,
      color: hc,
      textTransform: 'uppercase',
      padding: '8px 36px 6px',
      letterSpacing: -0.08
    }
  }, header), /*#__PURE__*/React.createElement("div", {
    style: {
      background: bg,
      borderRadius: 26,
      margin: '0 16px',
      overflow: 'hidden'
    }
  }, children));
}

// ─────────────────────────────────────────────────────────────
// Device frame
// ─────────────────────────────────────────────────────────────
function IOSDevice({
  children,
  width = 402,
  height = 874,
  dark = false,
  title,
  keyboard = false
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      height,
      borderRadius: 48,
      overflow: 'hidden',
      position: 'relative',
      background: dark ? '#000' : '#F2F2F7',
      boxShadow: '0 40px 80px rgba(0,0,0,0.18), 0 0 0 1px rgba(0,0,0,0.12)',
      fontFamily: '-apple-system, system-ui, sans-serif',
      WebkitFontSmoothing: 'antialiased'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 11,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 126,
      height: 37,
      borderRadius: 24,
      background: '#000',
      zIndex: 50
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      zIndex: 10
    }
  }, /*#__PURE__*/React.createElement(IOSStatusBar, {
    dark: dark
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      height: '100%',
      display: 'flex',
      flexDirection: 'column'
    }
  }, title !== undefined && /*#__PURE__*/React.createElement(IOSNavBar, {
    title: title,
    dark: dark
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflow: 'auto'
    }
  }, children), keyboard && /*#__PURE__*/React.createElement(IOSKeyboard, {
    dark: dark
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      bottom: 0,
      left: 0,
      right: 0,
      zIndex: 60,
      height: 34,
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'flex-end',
      paddingBottom: 8,
      pointerEvents: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 139,
      height: 5,
      borderRadius: 100,
      background: dark ? 'rgba(255,255,255,0.7)' : 'rgba(0,0,0,0.25)'
    }
  })));
}

// ─────────────────────────────────────────────────────────────
// Keyboard — iOS 26 liquid glass
// ─────────────────────────────────────────────────────────────
function IOSKeyboard({
  dark = false
}) {
  const glyph = dark ? 'rgba(255,255,255,0.7)' : '#595959';
  const sugg = dark ? 'rgba(255,255,255,0.6)' : '#333';
  const keyBg = dark ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.85)';

  // special-key icons
  const icons = {
    shift: /*#__PURE__*/React.createElement("svg", {
      width: "19",
      height: "17",
      viewBox: "0 0 19 17"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M9.5 1L1 9.5h4.5V16h8V9.5H18L9.5 1z",
      fill: glyph
    })),
    del: /*#__PURE__*/React.createElement("svg", {
      width: "23",
      height: "17",
      viewBox: "0 0 23 17"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M7 1h13a2 2 0 012 2v11a2 2 0 01-2 2H7l-6-7.5L7 1z",
      fill: "none",
      stroke: glyph,
      strokeWidth: "1.6",
      strokeLinejoin: "round"
    }), /*#__PURE__*/React.createElement("path", {
      d: "M10 5l7 7M17 5l-7 7",
      stroke: glyph,
      strokeWidth: "1.6",
      strokeLinecap: "round"
    })),
    ret: /*#__PURE__*/React.createElement("svg", {
      width: "20",
      height: "14",
      viewBox: "0 0 20 14"
    }, /*#__PURE__*/React.createElement("path", {
      d: "M18 1v6H4m0 0l4-4M4 7l4 4",
      fill: "none",
      stroke: "#fff",
      strokeWidth: "1.8",
      strokeLinecap: "round",
      strokeLinejoin: "round"
    }))
  };
  const key = (content, {
    w,
    flex,
    ret,
    fs = 25,
    k
  } = {}) => /*#__PURE__*/React.createElement("div", {
    key: k,
    style: {
      height: 42,
      borderRadius: 8.5,
      flex: flex ? 1 : undefined,
      width: w,
      minWidth: 0,
      background: ret ? '#08f' : keyBg,
      boxShadow: '0 1px 0 rgba(0,0,0,0.075)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      fontFamily: '-apple-system, "SF Compact", system-ui',
      fontSize: fs,
      fontWeight: 458,
      color: ret ? '#fff' : glyph
    }
  }, content);
  const row = (keys, pad = 0) => /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6.5,
      justifyContent: 'center',
      padding: `0 ${pad}px`
    }
  }, keys.map(l => key(l, {
    flex: true,
    k: l
  })));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      zIndex: 15,
      borderRadius: 27,
      overflow: 'hidden',
      padding: '11px 0 2px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      boxShadow: dark ? '0 -2px 20px rgba(0,0,0,0.09)' : '0 -1px 6px rgba(0,0,0,0.018), 0 -3px 20px rgba(0,0,0,0.012)'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 27,
      backdropFilter: 'blur(12px) saturate(180%)',
      WebkitBackdropFilter: 'blur(12px) saturate(180%)',
      background: dark ? 'rgba(120,120,128,0.14)' : 'rgba(255,255,255,0.25)'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      borderRadius: 27,
      boxShadow: dark ? 'inset 1.5px 1.5px 1px rgba(255,255,255,0.15)' : 'inset 1.5px 1.5px 1px rgba(255,255,255,0.7), inset -1px -1px 1px rgba(255,255,255,0.4)',
      border: dark ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(0,0,0,0.06)',
      pointerEvents: 'none'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 20,
      alignItems: 'center',
      padding: '8px 22px 13px',
      width: '100%',
      boxSizing: 'border-box',
      position: 'relative'
    }
  }, ['"The"', 'the', 'to'].map((w, i) => /*#__PURE__*/React.createElement(React.Fragment, {
    key: i
  }, i > 0 && /*#__PURE__*/React.createElement("div", {
    style: {
      width: 1,
      height: 25,
      background: '#ccc',
      opacity: 0.3
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      textAlign: 'center',
      fontFamily: '-apple-system, system-ui',
      fontSize: 17,
      color: sugg,
      letterSpacing: -0.43,
      lineHeight: '22px'
    }
  }, w)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 13,
      padding: '0 6.5px',
      width: '100%',
      boxSizing: 'border-box',
      position: 'relative'
    }
  }, row(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']), row(['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'], 20), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14.25,
      alignItems: 'center'
    }
  }, key(icons.shift, {
    w: 45,
    k: 'shift'
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6.5,
      flex: 1
    }
  }, ['z', 'x', 'c', 'v', 'b', 'n', 'm'].map(l => key(l, {
    flex: true,
    k: l
  }))), key(icons.del, {
    w: 45,
    k: 'del'
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 6,
      alignItems: 'center'
    }
  }, key('ABC', {
    w: 92.25,
    fs: 18,
    k: 'abc'
  }), key('', {
    flex: true,
    k: 'space'
  }), key(icons.ret, {
    w: 92.25,
    ret: true,
    k: 'ret'
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 56,
      width: '100%',
      position: 'relative'
    }
  }));
}
Object.assign(window, {
  IOSDevice,
  IOSStatusBar,
  IOSNavBar,
  IOSGlassPill,
  IOSList,
  IOSListRow,
  IOSKeyboard
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/maude-app/ios-frame.jsx", error: String((e && e.message) || e) }); }

// ui_kits/maude-console/browser-window.jsx
try { (() => {
// @ds-adherence-ignore -- omelette starter scaffold (raw elements/hex/px by design)

/* BEGIN USAGE */
// Chrome.jsx — Simplified Chrome browser window (dark theme, macOS)
// No dependencies, no image assets. All inline styles + inline SVG.
// Exports (to window): ChromeWindow, ChromeTabBar, ChromeToolbar, ChromeTab, ChromeTrafficLights
//
// Usage — wrap your page content in <ChromeWindow> to get the tab bar + URL bar:
//
//   <ChromeWindow width={1100} height={680} url="acme.design/pricing">
//     ...your page content...
//   </ChromeWindow>
/* END USAGE */

const CHROME_C = {
  barBg: '#202124',
  tabBg: '#35363a',
  text: '#e8eaed',
  dim: '#9aa0a6',
  urlBg: '#282a2d'
};
function ChromeTrafficLights() {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      padding: '0 14px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 12,
      height: 12,
      borderRadius: '50%',
      background: '#ff5f57'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 12,
      height: 12,
      borderRadius: '50%',
      background: '#febc2e'
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 12,
      height: 12,
      borderRadius: '50%',
      background: '#28c840'
    }
  }));
}

// Single tab (active has curved scoops)
function ChromeTab({
  title = 'New Tab',
  active = false
}) {
  const curve = flip => /*#__PURE__*/React.createElement("svg", {
    width: "8",
    height: "10",
    viewBox: "0 0 8 10",
    style: {
      position: 'absolute',
      bottom: 0,
      [flip ? 'right' : 'left']: -8,
      transform: flip ? 'scaleX(-1)' : 'none'
    }
  }, /*#__PURE__*/React.createElement("path", {
    d: "M0 10C2 9 6 8 8 0V10H0Z",
    fill: CHROME_C.tabBg
  }));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      height: 34,
      alignSelf: 'flex-end',
      padding: '0 12px',
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      background: active ? CHROME_C.tabBg : 'transparent',
      borderRadius: '8px 8px 0 0',
      minWidth: 120,
      maxWidth: 220,
      fontFamily: 'system-ui, sans-serif',
      fontSize: 12,
      color: active ? CHROME_C.text : CHROME_C.dim
    }
  }, active && curve(false), active && curve(true), /*#__PURE__*/React.createElement("div", {
    style: {
      width: 14,
      height: 14,
      borderRadius: '50%',
      background: '#5f6368',
      flexShrink: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, title));
}
function ChromeTabBar({
  tabs = [{
    title: 'New Tab'
  }],
  activeIndex = 0
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      height: 44,
      background: CHROME_C.barBg,
      paddingRight: 8
    }
  }, /*#__PURE__*/React.createElement(ChromeTrafficLights, null), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-end',
      height: '100%',
      paddingLeft: 4,
      flex: 1
    }
  }, tabs.map((t, i) => /*#__PURE__*/React.createElement(ChromeTab, {
    key: i,
    title: t.title,
    active: i === activeIndex
  }))));
}
function ChromeToolbar({
  url = 'example.com'
}) {
  const iconDot = /*#__PURE__*/React.createElement("div", {
    style: {
      width: 28,
      height: 28,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 16,
      height: 16,
      borderRadius: '50%',
      background: CHROME_C.dim,
      opacity: 0.4
    }
  }));
  return /*#__PURE__*/React.createElement("div", {
    style: {
      height: 40,
      background: CHROME_C.tabBg,
      display: 'flex',
      alignItems: 'center',
      gap: 4,
      padding: '0 8px'
    }
  }, iconDot, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      height: 30,
      borderRadius: 15,
      background: CHROME_C.urlBg,
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      padding: '0 14px',
      margin: '0 6px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 12,
      height: 12,
      borderRadius: '50%',
      background: CHROME_C.dim,
      opacity: 0.4
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      color: CHROME_C.text,
      fontSize: 13,
      fontFamily: 'system-ui, sans-serif'
    }
  }, url)), iconDot);
}
function ChromeWindow({
  tabs = [{
    title: 'New Tab'
  }],
  activeIndex = 0,
  url = 'example.com',
  width = 900,
  height = 600,
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width,
      height,
      borderRadius: 10,
      overflow: 'hidden',
      boxShadow: '0 24px 80px rgba(0,0,0,0.35), 0 0 0 1px rgba(0,0,0,0.1)',
      display: 'flex',
      flexDirection: 'column',
      background: CHROME_C.tabBg
    }
  }, /*#__PURE__*/React.createElement(ChromeTabBar, {
    tabs: tabs,
    activeIndex: activeIndex
  }), /*#__PURE__*/React.createElement(ChromeToolbar, {
    url: url
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      background: '#fff',
      overflow: 'auto'
    }
  }, children));
}
Object.assign(window, {
  ChromeWindow,
  ChromeTabBar,
  ChromeToolbar,
  ChromeTab,
  ChromeTrafficLights
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/maude-console/browser-window.jsx", error: String((e && e.message) || e) }); }

// ui_kits/maude-console/console.jsx
try { (() => {
// Maude B2B console — Harbor A5 restyle (Login → Roster → Citizen view).
// Night (navy) ground by default with a Day/Night toggle. All colours are
// ground-resolved Harbor tokens via the .lqc[data-mode] CSS vars in index.html.
// Status always ships as a triplet: shape + word + colour (● ▲ ✕).
// No glass, no glow, no left-border accents, no decorative waveforms.

const BRAND = "../../assets/brand/";
const SERIF = "var(--font-serif)";
const MONO = "var(--font-mono)";
const KICK = {
  fontFamily: MONO,
  textTransform: "uppercase",
  letterSpacing: "0.1em",
  fontWeight: 600
};
function MarkImg({
  size = 22,
  mode = "night"
}) {
  return /*#__PURE__*/React.createElement("img", {
    src: BRAND + (mode === "night" ? "maude_mark_iris_reversed.svg" : "maude_mark_iris.svg"),
    alt: "Maude",
    width: size,
    height: size,
    style: {
      display: "block"
    }
  });
}

// ── Status triplets — shape + word + colour, never colour alone ──
const TRIPLET = {
  good: {
    glyph: "●",
    word: "WITHIN RANGE"
  },
  watch: {
    glyph: "▲",
    word: "WATCH"
  },
  act: {
    glyph: "✕",
    word: "ACT NOW"
  }
};
function StatusChip({
  kind
}) {
  const t = TRIPLET[kind];
  const base = {
    display: "inline-flex",
    alignItems: "center",
    gap: 6,
    fontFamily: MONO,
    fontSize: 10.5,
    fontWeight: 600,
    letterSpacing: "0.06em",
    padding: "4px 9px",
    borderRadius: 3,
    whiteSpace: "nowrap"
  };
  if (kind === "act") {
    // the only state allowed a fill — act-fill pairs with page-ink text, never white-on-red
    return /*#__PURE__*/React.createElement("span", {
      style: {
        ...base,
        background: "var(--c-act-fill)",
        color: "var(--c-act-fill-text)"
      }
    }, t.glyph, " ", t.word);
  }
  const color = kind === "good" ? "var(--c-good)" : "var(--c-watch)";
  const line = kind === "good" ? "var(--c-good-line)" : "var(--c-watch-line)";
  return /*#__PURE__*/React.createElement("span", {
    style: {
      ...base,
      color,
      border: `1px solid ${line}`,
      background: "transparent"
    }
  }, t.glyph, " ", t.word);
}

// ── Shared surfaces ──
const tile = {
  background: "var(--c-tile)",
  border: "1px solid var(--c-line)",
  borderRadius: 12
};
const kicker = {
  ...KICK,
  fontSize: 10,
  color: "var(--c-text3)",
  margin: 0
};
const primaryBtn = {
  all: "unset",
  display: "block",
  boxSizing: "border-box",
  textAlign: "center",
  width: "100%",
  background: "var(--c-btn-bg)",
  color: "var(--c-btn-text)",
  fontWeight: 700,
  fontSize: 14,
  padding: "12px 0",
  borderRadius: 9,
  cursor: "pointer"
};
const ghostBtn = {
  all: "unset",
  display: "inline-block",
  boxSizing: "border-box",
  textAlign: "center",
  cursor: "pointer",
  fontSize: 12.5,
  fontWeight: 600,
  color: "var(--c-text2)",
  border: "1px solid var(--c-line)",
  borderRadius: 8,
  padding: "8px 13px",
  background: "transparent"
};

// ───────────────────────── Login ─────────────────────────
function Login({
  onEnter,
  mode
}) {
  const inStyle = {
    width: "100%",
    boxSizing: "border-box",
    font: "inherit",
    fontSize: 14,
    padding: "11px 12px",
    border: "1px solid var(--c-line)",
    borderRadius: 8,
    marginBottom: 10,
    background: "var(--c-page)",
    color: "var(--c-text)"
  };
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      background: "var(--c-page)",
      display: "flex",
      flexDirection: "column",
      alignItems: "center",
      justifyContent: "center",
      overflow: "auto",
      color: "var(--c-text)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(MarkImg, {
    size: 38,
    mode: mode
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SERIF,
      fontSize: 34,
      fontWeight: 400,
      letterSpacing: "-0.01em"
    }
  }, "Maude")), /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 10.5,
      color: "var(--c-text3)",
      margin: "8px 0 22px"
    }
  }, "console.maude.app \xB7 for organisations"), /*#__PURE__*/React.createElement("div", {
    style: {
      ...tile,
      padding: 24,
      width: 340
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: SERIF,
      fontSize: 21,
      fontWeight: 400,
      margin: "0 0 14px",
      color: "var(--c-text)"
    }
  }, "Sign in to your workspace"), /*#__PURE__*/React.createElement("input", {
    defaultValue: "dfgworks",
    "aria-label": "Workspace",
    style: inStyle
  }), /*#__PURE__*/React.createElement("input", {
    type: "password",
    defaultValue: "maude",
    "aria-label": "Password",
    style: inStyle
  }), /*#__PURE__*/React.createElement("button", {
    onClick: () => onEnter("Diabetes nurse", "DN"),
    style: {
      ...primaryBtn,
      marginTop: 4
    }
  }, "Sign in"), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      color: "var(--c-text3)",
      fontSize: 12,
      margin: "11px 0"
    }
  }, "or"), /*#__PURE__*/React.createElement("button", {
    onClick: () => onEnter("Diabetes nurse", "DN"),
    style: {
      ...ghostBtn,
      display: "block",
      width: "100%"
    }
  }, "Continue with MitID Erhverv")), /*#__PURE__*/React.createElement("div", {
    style: {
      ...tile,
      padding: 20,
      width: 340,
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...kicker,
      marginBottom: 10
    }
  }, "Preview a role"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 8
    }
  }, [["Diabetes nurse", "DN"], ["Health coach", "HC"], ["Research analyst", "RA"], ["Super admin", "SA"]].map(([r, ini]) => /*#__PURE__*/React.createElement("button", {
    key: r,
    onClick: () => onEnter(r, ini),
    style: ghostBtn
  }, r)))), /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--c-text3)",
      fontSize: 12,
      marginTop: 18,
      maxWidth: 340,
      textAlign: "center",
      lineHeight: 1.5
    }
  }, "You see only what citizens have consented to share with your organisation."));
}

// ───────────────────────── Chrome ─────────────────────────
function ConsoleChrome({
  who,
  tier,
  crumb,
  nav,
  children,
  onSignOut,
  mode,
  setMode
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--c-text)",
      background: "var(--c-page)",
      minHeight: "100%"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--c-page)",
      borderBottom: "1px solid var(--c-line)",
      padding: "10px 0",
      position: "sticky",
      top: 0,
      zIndex: 30
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 1340,
      margin: "0 auto",
      padding: "0 18px",
      display: "flex",
      alignItems: "center",
      justifyContent: "space-between",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 9
    }
  }, /*#__PURE__*/React.createElement(MarkImg, {
    size: 22,
    mode: mode
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: SERIF,
      fontSize: 19,
      fontWeight: 400
    }
  }, "Maude"), crumb && /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: MONO,
      fontSize: 11.5,
      color: "var(--c-text3)",
      marginLeft: 6
    }
  }, crumb)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    role: "group",
    "aria-label": "Display mode",
    style: {
      display: "inline-flex",
      border: "1px solid var(--c-line)",
      borderRadius: 7,
      overflow: "hidden"
    }
  }, [["day", "Day"], ["night", "Night"]].map(([v, l]) => /*#__PURE__*/React.createElement("button", {
    key: v,
    onClick: () => setMode(v),
    style: {
      all: "unset",
      cursor: "pointer",
      padding: "6px 11px",
      fontFamily: MONO,
      fontSize: 10.5,
      fontWeight: 600,
      letterSpacing: "0.06em",
      textTransform: "uppercase",
      background: mode === v ? "var(--c-btn-bg)" : "transparent",
      color: mode === v ? "var(--c-btn-text)" : "var(--c-text3)"
    }
  }, l))), /*#__PURE__*/React.createElement("button", {
    onClick: onSignOut,
    style: ghostBtn
  }, "Sign out")))), /*#__PURE__*/React.createElement("div", {
    style: {
      maxWidth: 1340,
      margin: "0 auto",
      display: "grid",
      gridTemplateColumns: "216px 1fr",
      minHeight: "calc(100% - 45px)"
    }
  }, /*#__PURE__*/React.createElement("nav", {
    style: {
      borderRight: "1px solid var(--c-line)",
      padding: "18px 14px"
    }
  }, who && /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 9,
      marginBottom: 14
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 34,
      height: 34,
      borderRadius: 8,
      display: "grid",
      placeItems: "center",
      fontFamily: MONO,
      fontWeight: 600,
      fontSize: 12,
      background: "var(--c-tile)",
      border: "1px solid var(--c-line)",
      color: "var(--c-text)"
    }
  }, who.initials), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 700,
      fontSize: 13,
      lineHeight: 1.15
    }
  }, who.name), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 11,
      color: "var(--c-text3)"
    }
  }, who.role))), tier && /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      fontFamily: MONO,
      fontSize: 10,
      fontWeight: 600,
      letterSpacing: "0.05em",
      padding: "4px 9px",
      borderRadius: 3,
      marginBottom: 12,
      color: "var(--c-good)",
      border: "1px solid var(--c-good-line)"
    }
  }, "\u25CF ", tier), nav), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "22px 26px 60px",
      minWidth: 0
    }
  }, children)));
}
function NavItem({
  label,
  on,
  locked,
  onClick
}) {
  return /*#__PURE__*/React.createElement("div", {
    onClick: locked ? undefined : onClick,
    style: {
      padding: "8px 10px",
      borderRadius: 7,
      fontSize: 13,
      fontWeight: on ? 700 : 500,
      cursor: locked ? "default" : "pointer",
      opacity: locked ? 0.45 : 1,
      background: on ? "var(--c-tile)" : "transparent",
      border: on ? "1px solid var(--c-line)" : "1px solid transparent",
      color: on ? "var(--c-text)" : "var(--c-text2)"
    }
  }, label);
}
function NavGroup({
  children
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...KICK,
      fontSize: 9.5,
      color: "var(--c-text3)",
      margin: "15px 8px 6px"
    }
  }, children);
}

// ───────────────────────── Roster ─────────────────────────
const CITIZENS = [{
  id: "LV001",
  alias: "Citizen LV001",
  status: "good",
  purpose: "Type 2 diabetes follow-up",
  note: "HRV trending up · within personal baseline",
  asOf: "22 May",
  expiry: "28 May",
  next: "Today 14:30",
  readings: "21/21"
}, {
  id: "LV014",
  alias: "Citizen LV014",
  status: "watch",
  purpose: "Post-discharge glucose review",
  note: "Fasting glucose drifting — 3rd week running",
  asOf: "21 May",
  expiry: "04 Jun",
  next: "Fri 09:15",
  readings: "19/21"
}, {
  id: "LV022",
  alias: "Citizen LV022",
  status: "act",
  purpose: "Sleep & recovery coaching",
  note: "No readings for 6 days — check in",
  asOf: "20 May",
  expiry: "12 Jun",
  next: null,
  readings: "14/21"
}];
function Roster({
  who,
  onOpen,
  onSignOut,
  mode,
  setMode
}) {
  const nav = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(NavGroup, null, "Worklist"), /*#__PURE__*/React.createElement(NavItem, {
    label: "Your clients",
    on: true
  }), /*#__PURE__*/React.createElement(NavItem, {
    label: "Messages"
  }), /*#__PURE__*/React.createElement(NavItem, {
    label: "Appointments"
  }), /*#__PURE__*/React.createElement(NavGroup, null, "Organisation"), /*#__PURE__*/React.createElement(NavItem, {
    label: "Cohort (Mode B)",
    locked: true
  }), /*#__PURE__*/React.createElement(NavItem, {
    label: "Admin",
    locked: true
  }));
  return /*#__PURE__*/React.createElement(ConsoleChrome, {
    who: who,
    tier: "CONSENTED",
    crumb: "\xB7 your clients",
    nav: nav,
    onSignOut: onSignOut,
    mode: mode,
    setMode: setMode
  }, /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: SERIF,
      fontSize: 30,
      fontWeight: 400,
      letterSpacing: "-0.01em",
      margin: 0
    }
  }, "Your clients"), /*#__PURE__*/React.createElement("p", {
    style: {
      color: "var(--c-text2)",
      marginTop: 6,
      fontSize: 14,
      maxWidth: 560
    }
  }, "Only citizens who have consented to share with your organisation appear here."), /*#__PURE__*/React.createElement("div", {
    style: {
      ...tile,
      padding: "14px 16px",
      margin: "16px 0"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...kicker,
      marginBottom: 8
    }
  }, "Today & upcoming"), [["Today · 14:30", "Citizen LV001", "consult"], ["Fri · 09:15", "Citizen LV014", "review"]].map(([when, alias, kind], i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "baseline",
      gap: 12,
      fontSize: 13.5,
      padding: "8px 0",
      borderBottom: i === 0 ? "1px solid var(--c-line)" : "none"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--c-text2)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontFamily: MONO,
      fontSize: 12,
      color: "var(--c-text)",
      fontVariantNumeric: "tabular-nums"
    }
  }, when), " \u2014 ", alias), /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 10,
      color: "var(--c-kick)"
    }
  }, kind)))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "repeat(3, 1fr)",
      gap: 12
    }
  }, CITIZENS.map(c => /*#__PURE__*/React.createElement("div", {
    key: c.id,
    onClick: () => onOpen(c),
    role: "button",
    tabIndex: 0,
    onKeyDown: e => {
      if (e.key === "Enter") onOpen(c);
    },
    style: {
      ...tile,
      padding: 16,
      cursor: "pointer",
      display: "flex",
      flexDirection: "column",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "flex-start",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 700,
      fontSize: 15
    }
  }, c.alias), /*#__PURE__*/React.createElement(StatusChip, {
    kind: c.status
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--c-text2)",
      lineHeight: 1.45
    }
  }, c.note), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 12,
      color: "var(--c-text3)"
    }
  }, c.purpose), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: MONO,
      fontSize: 11,
      color: "var(--c-text3)",
      fontVariantNumeric: "tabular-nums",
      marginTop: "auto"
    }
  }, c.readings, " readings \xB7 expires ", c.expiry, c.next ? " · next " + c.next : "")))));
}

// ───────────────────────── Citizen view ─────────────────────────
function Kpi({
  label,
  value,
  unit
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...tile,
      padding: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...kicker,
      marginBottom: 6
    }
  }, label), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: MONO,
      fontSize: 26,
      fontWeight: 500,
      fontVariantNumeric: "tabular-nums",
      color: "var(--c-text)"
    }
  }, value, /*#__PURE__*/React.createElement("span", {
    style: {
      fontSize: 13,
      color: "var(--c-text3)",
      marginLeft: 4
    }
  }, unit)));
}
function Insight({
  kind,
  title,
  meaning,
  suggested
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...tile,
      padding: "15px 17px",
      marginBottom: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "flex-start",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      fontWeight: 700,
      fontSize: 14.5,
      color: "var(--c-text)"
    }
  }, title), /*#__PURE__*/React.createElement(StatusChip, {
    kind: kind
  })), meaning && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--c-text2)",
      margin: "6px 0 0",
      lineHeight: 1.5
    }
  }, meaning), suggested && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--c-text2)",
      borderTop: "1px dashed var(--c-line)",
      paddingTop: 8,
      marginTop: 9,
      lineHeight: 1.5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 9.5,
      color: "var(--c-kick)",
      marginRight: 8
    }
  }, "Suggested"), suggested), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 7,
      marginTop: 11,
      flexWrap: "wrap"
    }
  }, ["Message client", "Add to plan", "Flag for review", "Mark addressed"].map((a, i) => /*#__PURE__*/React.createElement("button", {
    key: a,
    style: i === 0 ? {
      ...ghostBtn,
      color: "var(--c-text)",
      borderColor: "var(--c-text3)",
      fontSize: 11.5,
      padding: "6px 11px"
    } : {
      ...ghostBtn,
      fontSize: 11.5,
      padding: "6px 11px"
    }
  }, a))));
}
function MetricCard({
  title,
  rows,
  badge
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      ...tile,
      padding: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      justifyContent: "space-between",
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: SERIF,
      fontSize: 18,
      fontWeight: 400,
      margin: 0
    }
  }, title), badge && /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 9.5,
      color: "var(--c-kick)"
    }
  }, badge)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 22,
      flexWrap: "wrap"
    }
  }, rows.map(([k, v]) => /*#__PURE__*/React.createElement("div", {
    key: k
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...kicker,
      fontSize: 9.5,
      marginBottom: 3
    }
  }, k), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: MONO,
      fontSize: 17,
      fontWeight: 500,
      fontVariantNumeric: "tabular-nums"
    }
  }, v)))));
}
function CitizenViewScreen({
  who,
  citizen,
  onBack,
  onSignOut,
  mode,
  setMode
}) {
  const nav = /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(NavItem, {
    label: "Overview",
    on: true
  }), /*#__PURE__*/React.createElement(NavGroup, null, "Consented data"), /*#__PURE__*/React.createElement(NavItem, {
    label: "Glucose (GMI)"
  }), /*#__PURE__*/React.createElement(NavItem, {
    label: "Time in range"
  }), /*#__PURE__*/React.createElement(NavItem, {
    label: "Heart rate"
  }), /*#__PURE__*/React.createElement(NavItem, {
    label: "Sleep"
  }), /*#__PURE__*/React.createElement(NavItem, {
    label: "Medications"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 14
    }
  }, /*#__PURE__*/React.createElement("button", {
    onClick: onBack,
    style: {
      ...ghostBtn,
      display: "block",
      width: "100%",
      color: "var(--c-act)",
      borderColor: "var(--c-act-line)"
    }
  }, "\u2715 Citizen can revoke")));
  return /*#__PURE__*/React.createElement(ConsoleChrome, {
    who: who,
    tier: "CONSENTED",
    nav: nav,
    onSignOut: onSignOut,
    mode: mode,
    setMode: setMode,
    crumb: /*#__PURE__*/React.createElement("span", null, "\xB7 ", /*#__PURE__*/React.createElement("a", {
      onClick: onBack,
      style: {
        color: "var(--c-text2)",
        cursor: "pointer"
      }
    }, "your clients"), " / ", citizen.alias.toLowerCase())
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      justifyContent: "space-between",
      gap: 14,
      flexWrap: "wrap"
    }
  }, /*#__PURE__*/React.createElement("h1", {
    style: {
      fontFamily: SERIF,
      fontSize: 30,
      fontWeight: 400,
      letterSpacing: "-0.01em",
      margin: 0
    }
  }, citizen.alias), /*#__PURE__*/React.createElement(StatusChip, {
    kind: citizen.status
  })), /*#__PURE__*/React.createElement("p", {
    style: {
      color: "var(--c-text2)",
      margin: "8px 0 0",
      fontSize: 14,
      maxWidth: 680,
      lineHeight: 1.5
    }
  }, "Their own baseline, shared on their terms \u2014 not a population average. You see 5 consented data groups as a derived view; raw data never leaves their device."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: MONO,
      fontSize: 11.5,
      color: "var(--c-text3)",
      fontVariantNumeric: "tabular-nums",
      margin: "6px 0 18px"
    }
  }, "as of ", citizen.asOf, " \xB7 expires ", citizen.expiry, " \xB7 ", citizen.readings, " readings"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "repeat(4, 1fr)",
      gap: 12,
      marginBottom: 18
    }
  }, /*#__PURE__*/React.createElement(Kpi, {
    label: "GMI",
    value: "6.4",
    unit: "%"
  }), /*#__PURE__*/React.createElement(Kpi, {
    label: "Time in range",
    value: "74",
    unit: "%"
  }), /*#__PURE__*/React.createElement(Kpi, {
    label: "Resting HR",
    value: "58",
    unit: "bpm"
  }), /*#__PURE__*/React.createElement(Kpi, {
    label: "Sleep",
    value: "6:52",
    unit: "h"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      ...kicker,
      margin: "0 0 9px"
    }
  }, "Patterns worth acting on"), /*#__PURE__*/React.createElement(Insight, {
    kind: "act",
    title: "Post-dinner glucose excursions rising",
    meaning: "Three of the last five evenings show a spike above 10 mmol/L after 20:00.",
    suggested: "Review evening carbohydrate timing at the next consult."
  }), /*#__PURE__*/React.createElement(Insight, {
    kind: "watch",
    title: "HRV dips track high-load workdays",
    meaning: "Mornings after back-to-back meeting days show ~15% lower HRV."
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 10,
      alignItems: "center",
      flexWrap: "wrap",
      margin: "4px 0 18px"
    }
  }, /*#__PURE__*/React.createElement("button", {
    style: {
      ...primaryBtn,
      display: "inline-block",
      width: "auto",
      padding: "10px 16px",
      fontSize: 13
    }
  }, "Start secure consultation"), /*#__PURE__*/React.createElement("button", {
    style: ghostBtn
  }, "Message ", citizen.alias)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 12,
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement(MetricCard, {
    title: "Glucose (GMI)",
    rows: [["latest", "6.4%"], ["mean", "7.1"], ["min", "4.2"], ["max", "11.8"]]
  }), /*#__PURE__*/React.createElement(MetricCard, {
    title: "Time in range",
    rows: [["latest", "74%"], ["target", "70%"], ["low", "4%"]],
    badge: "pattern only"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      ...tile,
      padding: 16
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "baseline",
      justifyContent: "space-between",
      marginBottom: 9
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: SERIF,
      fontSize: 18,
      fontWeight: 400,
      margin: 0
    }
  }, "What this share lets you see"), /*#__PURE__*/React.createElement("span", {
    style: {
      ...KICK,
      fontSize: 9.5,
      color: "var(--c-good)"
    }
  }, "\u25CF consent-scoped")), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--c-text2)",
      lineHeight: 1.5
    }
  }, /*#__PURE__*/React.createElement("b", {
    style: {
      color: "var(--c-text)"
    }
  }, "5 data groups"), ", derived view: Glucose \xB7 Time in range \xB7 Heart rate \xB7 Sleep \xB7 Medications."), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: 13,
      color: "var(--c-text3)",
      marginTop: 7,
      lineHeight: 1.5
    }
  }, "Everything outside this list stays private. Expires ", citizen.expiry, ". The citizen can revoke in one tap \u2014 this view disappears immediately, evidenced on the consent ledger.")), /*#__PURE__*/React.createElement("div", {
    style: {
      ...tile,
      padding: 16
    }
  }, /*#__PURE__*/React.createElement("h2", {
    style: {
      fontFamily: SERIF,
      fontSize: 18,
      fontWeight: 400,
      margin: "0 0 9px"
    }
  }, "Activity log"), /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--c-text3)",
      fontSize: 13,
      lineHeight: 1.5
    }
  }, "No actions yet. Your messages, plan items and flags appear here \u2014 each one is audited."))));
}

// ───────────────────────── Root ─────────────────────────
function MaudeConsole() {
  const [stage, setStage] = React.useState("login");
  const [who, setWho] = React.useState(null);
  const [citizen, setCitizen] = React.useState(null);
  const [mode, setMode] = React.useState("night");
  const enter = (name, ini) => {
    setWho({
      name,
      initials: ini,
      role: "Consented clients"
    });
    setStage("roster");
  };
  const signOut = () => {
    setWho(null);
    setStage("login");
  };
  let screen;
  if (stage === "login") screen = /*#__PURE__*/React.createElement(Login, {
    onEnter: enter,
    mode: mode
  });else if (stage === "citizen") screen = /*#__PURE__*/React.createElement(CitizenViewScreen, {
    who: who,
    citizen: citizen,
    onBack: () => setStage("roster"),
    onSignOut: signOut,
    mode: mode,
    setMode: setMode
  });else screen = /*#__PURE__*/React.createElement(Roster, {
    who: who,
    onOpen: c => {
      setCitizen(c);
      setStage("citizen");
    },
    onSignOut: signOut,
    mode: mode,
    setMode: setMode
  });
  return /*#__PURE__*/React.createElement("div", {
    className: "lqc",
    "data-mode": mode,
    style: {
      position: "absolute",
      inset: 0,
      overflow: "auto",
      background: "var(--c-page)",
      fontFamily: "var(--font-sans)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      position: "relative",
      minHeight: "100%"
    }
  }, screen));
}
window.MaudeConsole = MaudeConsole;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/maude-console/console.jsx", error: String((e && e.message) || e) }); }

__ds_ns.Mark = __ds_scope.Mark;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.ConsentChip = __ds_scope.ConsentChip;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Pill = __ds_scope.Pill;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.Insight = __ds_scope.Insight;

__ds_ns.KpiTile = __ds_scope.KpiTile;

__ds_ns.MetricRing = __ds_scope.MetricRing;

__ds_ns.NudgeCard = __ds_scope.NudgeCard;

})();
