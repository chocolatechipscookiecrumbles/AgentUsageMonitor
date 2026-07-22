import { useState } from "react"
import type { ReactElement } from "react"

type State = "confirmed" | "cached" | "refreshing" | "unavailable"

interface Props {
  state: State
  darkMode: boolean
}

// ─── Primitives ───────────────────────────────────────────────────────────────

function ProgressBar({ value, color, dark }: { value: number; color: string; dark: boolean }) {
  return (
    <div className={`h-[4px] rounded-full overflow-hidden ${dark ? "bg-white/[0.09]" : "bg-black/[0.07]"}`}>
      <div
        className="h-full rounded-full transition-all duration-700"
        style={{ width: `${value}%`, backgroundColor: color }}
      />
    </div>
  )
}

function ProgressRing({ value, color, size = 60 }: { value: number; color: string; size?: number }) {
  const r = (size - 9) / 2
  const circ = 2 * Math.PI * r
  const dash = (value / 100) * circ
  return (
    <svg width={size} height={size} style={{ transform: "rotate(-90deg)" }}>
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke="rgba(128,128,128,0.12)" strokeWidth="4.5" />
      <circle
        cx={size / 2}
        cy={size / 2}
        r={r}
        fill="none"
        stroke={color}
        strokeWidth="4.5"
        strokeLinecap="round"
        strokeDasharray={`${dash} ${circ - dash}`}
        style={{ transition: "stroke-dasharray 0.7s ease" }}
      />
    </svg>
  )
}

function SpinnerIcon({ color, size = 10 }: { color: string; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 16 16"
      fill="none"
      style={{ animation: "spin 0.85s linear infinite" }}
    >
      <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
      <circle cx="8" cy="8" r="6" stroke={color} strokeWidth="2" strokeOpacity="0.2" />
      <path d="M8 2a6 6 0 0 1 6 6" stroke={color} strokeWidth="2" strokeLinecap="round" />
    </svg>
  )
}

function Icon({ name, size = 13, color = "currentColor" }: { name: string; size?: number; color?: string }) {
  const d: Record<string, ReactElement> = {
    "refresh": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <path d="M13 8A5 5 0 1 1 10.5 3.5" stroke={color} strokeWidth="1.3" strokeLinecap="round" />
        <path d="M10.5 1v2.5H13" stroke={color} strokeWidth="1.3" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    ),
    "clock": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <circle cx="8" cy="8" r="6" stroke={color} strokeWidth="1.2" />
        <path d="M8 5v3l2 1.5" stroke={color} strokeWidth="1.2" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    ),
    "calendar": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <rect x="2" y="3" width="12" height="11" rx="2" stroke={color} strokeWidth="1.2" />
        <line x1="2" y1="7" x2="14" y2="7" stroke={color} strokeWidth="1.2" />
        <line x1="5" y1="1.5" x2="5" y2="4.5" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
        <line x1="11" y1="1.5" x2="11" y2="4.5" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
      </svg>
    ),
    "bell": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <path d="M8 2a4 4 0 0 0-4 4v3l-1 1.5h10L12 9V6A4 4 0 0 0 8 2Z" stroke={color} strokeWidth="1.2" strokeLinejoin="round" />
        <path d="M6.5 13.5a1.5 1.5 0 0 0 3 0" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
      </svg>
    ),
    "gear": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <circle cx="8" cy="8" r="2.5" stroke={color} strokeWidth="1.2" />
        <path d="M8 1v2M8 13v2M1 8h2M13 8h2M2.93 2.93l1.41 1.41M11.66 11.66l1.41 1.41M2.93 13.07l1.41-1.41M11.66 4.34l1.41-1.41" stroke={color} strokeWidth="1.15" strokeLinecap="round" />
      </svg>
    ),
    "xmark": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <path d="M3 3l10 10M13 3L3 13" stroke={color} strokeWidth="1.4" strokeLinecap="round" />
      </svg>
    ),
    "warning": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <path d="M8 2L14.5 13H1.5L8 2Z" stroke={color} strokeWidth="1.2" strokeLinejoin="round" />
        <line x1="8" y1="6.5" x2="8" y2="9.5" stroke={color} strokeWidth="1.3" strokeLinecap="round" />
        <circle cx="8" cy="11.5" r="0.65" fill={color} />
      </svg>
    ),
    "creditcard": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <rect x="1.5" y="3.5" width="13" height="9" rx="1.5" stroke={color} strokeWidth="1.2" />
        <line x1="1.5" y1="7" x2="14.5" y2="7" stroke={color} strokeWidth="1.2" />
        <rect x="3" y="9" width="3" height="1.5" rx="0.5" fill={color} />
      </svg>
    ),
    "checkmark": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <circle cx="8" cy="8" r="7" fill={color} />
        <path d="M5 8l2.5 2.5L11 6" stroke="white" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    ),
    "gauge": (
      <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
        <circle cx="8" cy="8" r="6" stroke={color} strokeWidth="1.2" />
        <circle cx="8" cy="8" r="1.2" fill={color} />
        <line x1="8" y1="8" x2="5.5" y2="5.5" stroke={color} strokeWidth="1.2" strokeLinecap="round" />
      </svg>
    ),
  }
  return d[name] ?? <span style={{ fontSize: size - 2, color }}>{name[0]}</span>
}

// ─── Confirmation badge ───────────────────────────────────────────────────────

function ConfirmationBadge({ state }: { state: State }) {
  const cfg = {
    confirmed: { label: "Confirmed", dot: "#30d158", bg: "rgba(48,209,88,0.12)", color: "#30d158" },
    cached: { label: "Showing cached snapshot", dot: "#ff9f0a", bg: "rgba(255,159,10,0.12)", color: "#ff9f0a" },
    refreshing: { label: "Refreshing…", dot: "#0a84ff", bg: "rgba(10,132,255,0.12)", color: "#0a84ff" },
    unavailable: { label: "Unavailable", dot: "#8e8e93", bg: "rgba(142,142,147,0.12)", color: "#8e8e93" },
  }[state]

  return (
    <div
      className="inline-flex items-center gap-1.5 px-2 py-[3px] rounded-full"
      style={{ backgroundColor: cfg.bg }}
    >
      {state === "refreshing" ? (
        <SpinnerIcon color={cfg.dot} size={8} />
      ) : (
        <span className="w-[6px] h-[6px] rounded-full flex-shrink-0" style={{ backgroundColor: cfg.dot }} />
      )}
      <span className="text-[11px] font-medium" style={{ color: cfg.color }}>
        {cfg.label}
      </span>
    </div>
  )
}

// ─── Window card ──────────────────────────────────────────────────────────────

function WindowCard({
  title,
  usedPct,
  resetTime,
  timeUntil,
  dark,
  group,
  dimmed,
}: {
  title: string
  usedPct: number
  resetTime: string
  timeUntil: string
  dark: boolean
  group: string
  dimmed: boolean
}) {
  const remaining = 100 - usedPct
  const barColor = remaining <= 10 ? "#ff453a" : remaining <= 25 ? "#ff9f0a" : "#30d158"
  const text = dark ? "text-white" : "text-[#1c1c1e]"
  const sub = dark ? "text-white/40" : "text-black/38"

  return (
    <div className={`px-4 py-3 ${group} ${dimmed ? "opacity-75" : ""}`}>
      <div className="flex items-center justify-between mb-[6px]">
        <span className={`text-[12px] font-medium ${text}`}>{title}</span>
        <span className="text-[12px] font-semibold" style={{ color: barColor }}>
          {remaining}% used
        </span>
      </div>
      <ProgressBar value={usedPct} color={barColor} dark={dark} />
      <div className="flex items-center justify-between mt-1.5">
        <span className={`text-[11px] ${sub}`}>Remaining {remaining}%</span>
        <span className={`text-[11px] ${sub}`}>Resets {resetTime} · {timeUntil}</span>
      </div>
    </div>
  )
}

// ─── Empty state ──────────────────────────────────────────────────────────────

function UnavailableState({ dark }: { dark: boolean }) {
  const text = dark ? "text-white" : "text-[#1c1c1e]"
  const sub = dark ? "text-white/40" : "text-black/38"
  const bg = dark ? "bg-white/[0.04]" : "bg-black/[0.03]"

  return (
    <div className={`mx-3 mb-3 rounded-[10px] px-5 py-6 flex flex-col items-center text-center gap-2.5 ${bg}`}>
      <div className="w-10 h-10 rounded-full bg-[rgba(142,142,147,0.10)] flex items-center justify-center">
        <Icon name="warning" size={20} color="#8e8e93" />
      </div>
      <div>
        <div className={`text-[13px] font-semibold ${text}`}>Unable to Read Usage</div>
        <div className={`text-[11px] mt-1 ${sub} leading-relaxed max-w-[190px] mx-auto`}>
          No confirmed quota could be collected from Codex App Server.
        </div>
      </div>
      <div className="flex gap-2 mt-1">
        <button className="px-3.5 py-1.5 rounded-[7px] text-[12px] font-medium bg-[#0a84ff] text-white cursor-pointer hover:bg-[#0077ed] transition-colors">
          Retry
        </button>
        <button className={`px-3.5 py-1.5 rounded-[7px] text-[12px] font-medium cursor-pointer transition-colors ${dark ? "bg-white/[0.08] text-white hover:bg-white/[0.12]" : "bg-black/[0.06] text-[#1c1c1e] hover:bg-black/[0.09]"}`}>
          Preferences
        </button>
      </div>
    </div>
  )
}

// ─── Main dropdown ────────────────────────────────────────────────────────────

export default function MenuBarDropdown({ state, darkMode: dark }: Props) {
  const [activeTab, setActiveTab] = useState<"codex" | "claude" | "copilot">("codex")

  const fiveHourUsed = state === "unavailable" ? 0 : 61
  const weeklyUsed = state === "unavailable" ? 0 : 72
  const lowestRemaining = state === "unavailable" ? 0 : 39
  const ringColor =
    state === "unavailable"
      ? "#8e8e93"
      : state === "cached"
        ? "#ff9f0a"
        : lowestRemaining <= 10
          ? "#ff453a"
          : lowestRemaining <= 25
            ? "#ff9f0a"
            : "#30d158"

  // Design-system surfaces — cards should "almost blend into the window"
  const windowBg = dark ? "bg-[#242424]" : "bg-[#f5f5f7]"
  const groupBg = dark ? "bg-white/[0.055]" : "bg-white"
  const groupShadow = dark ? "" : "shadow-[0_1px_3px_rgba(0,0,0,0.06)]"
  const text = dark ? "text-white" : "text-[#1c1c1e]"
  const sub = dark ? "text-white/40" : "text-black/38"
  const border = dark ? "border-white/[0.07]" : "border-black/[0.07]"
  const divider = dark ? "border-white/[0.06]" : "border-black/[0.06]"
  const iconColor = dark ? "rgba(255,255,255,0.35)" : "rgba(0,0,0,0.30)"

  const cardClass = `rounded-[10px] overflow-hidden ${groupBg} ${groupShadow}`

  return (
    <div
      className={`w-[340px] rounded-[14px] overflow-hidden border ${border} ${windowBg}`}
      style={{
        boxShadow: dark
          ? "0 16px 48px rgba(0,0,0,0.55), 0 0 0 0.5px rgba(255,255,255,0.07)"
          : "0 16px 48px rgba(0,0,0,0.14), 0 0 0 0.5px rgba(0,0,0,0.08)",
      }}
    >
      {/* Provider tabs */}
      <div className={`flex border-b ${border} ${dark ? "bg-[#1e1e1e]" : "bg-[#ebebeb]"}`}>
        {(["codex", "claude", "copilot"] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            className={`flex-1 py-2 text-[12px] font-medium transition-colors cursor-pointer ${
              activeTab === tab
                ? dark
                  ? "text-white border-b-[1.5px] border-[#0a84ff]"
                  : "text-[#0a84ff] border-b-[1.5px] border-[#0a84ff]"
                : sub
            }`}
            style={{ marginBottom: activeTab === tab ? -1 : 0 }}
          >
            {tab.charAt(0).toUpperCase() + tab.slice(1)}
          </button>
        ))}
      </div>

      {/* Header row */}
      <div className="px-4 pt-3.5 pb-3 flex items-center justify-between">
        <div className="flex items-center gap-2.5">
          <div className="w-7 h-7 rounded-[8px] bg-gradient-to-br from-[#0a84ff] to-[#5e5ce6] flex items-center justify-center flex-shrink-0">
            <Icon name="gauge" size={13} color="white" />
          </div>
          <div>
            <div className={`text-[13px] font-semibold leading-snug ${text}`}>Codex Usage Monitor</div>
            <div className={`text-[11px] leading-snug ${sub}`}>
              {state === "refreshing" ? "Refreshing…" : "Updated 11:42:13 AM"}
            </div>
          </div>
        </div>
        <button
          disabled={state === "refreshing"}
          className={`flex items-center gap-1.5 px-2.5 py-1.5 rounded-[7px] text-[11px] font-medium transition-all cursor-pointer ${
            state === "refreshing"
              ? `${sub} opacity-50`
              : "text-[#0a84ff] bg-[rgba(10,132,255,0.09)] hover:bg-[rgba(10,132,255,0.15)]"
          }`}
        >
          {state === "refreshing" ? (
            <SpinnerIcon color="#0a84ff" size={10} />
          ) : (
            <Icon name="refresh" size={10} color="#0a84ff" />
          )}
          {state === "refreshing" ? "Refreshing" : "Refresh Now"}
        </button>
      </div>

      {/* Content */}
      {state === "unavailable" ? (
        <UnavailableState dark={dark} />
      ) : (
        <div className="px-3 pb-3 flex flex-col gap-2">
          {/* Cached warning strip */}
          {state === "cached" && (
            <div className="flex items-center gap-2 px-3 py-2 rounded-[8px] bg-[rgba(255,159,10,0.10)]">
              <Icon name="clock" size={11} color="#ff9f0a" />
              <span className="text-[11px] font-medium text-[#ff9f0a]">Showing Last Confirmed Snapshot</span>
            </div>
          )}

          {/* Primary quota card */}
          <div className={`${cardClass} px-4 py-3`}>
            <div className="flex items-center justify-between">
              <div>
                <div className={`text-[10px] font-semibold uppercase tracking-[0.05em] ${sub} mb-0.5`}>Current Plan</div>
                <div className={`text-[20px] font-bold leading-tight ${text}`}>Pro</div>
                <div className="mt-2">
                  <div className={`text-[10px] ${sub}`}>Lowest remaining</div>
                  <div className="text-[26px] font-bold leading-none" style={{ color: ringColor }}>
                    {lowestRemaining}%
                  </div>
                </div>
              </div>
              <div className="relative flex items-center justify-center">
                <ProgressRing value={100 - lowestRemaining} color={ringColor} size={64} />
                <div className="absolute inset-0 flex items-center justify-center">
                  <span className={`text-[13px] font-bold ${text}`}>{lowestRemaining}</span>
                </div>
              </div>
            </div>
            <div className="mt-2.5">
              <ConfirmationBadge state={state} />
            </div>
          </div>

          {/* Window cards — grouped */}
          <div className={`${cardClass}`}>
            <WindowCard
              title="Five Hour Window"
              usedPct={fiveHourUsed}
              resetTime="3:42 PM"
              timeUntil="2h 18m"
              dark={dark}
              group=""
              dimmed={state === "cached"}
            />
            <div className={`border-t mx-4 ${divider}`} />
            <WindowCard
              title="Weekly Window"
              usedPct={weeklyUsed}
              resetTime="Sat 8:00 PM"
              timeUntil="5d 13h"
              dark={dark}
              group=""
              dimmed={state === "cached"}
            />
          </div>

          {/* Credits card */}
          <div className={`${cardClass} px-4 py-3`}>
            <div className="flex items-center justify-between mb-2.5">
              <div className="flex items-center gap-2">
                <Icon name="creditcard" size={12} color={iconColor} />
                <span className={`text-[12px] font-medium ${text}`}>Credit Balance</span>
              </div>
              <span className={`text-[18px] font-bold ${text}`}>143</span>
            </div>
            <div className={`border-t ${divider} pt-2.5`}>
              <div className="flex items-center justify-between mb-1.5">
                <span className={`text-[11px] font-medium ${text}`}>Earned Reset Credits</span>
                <span className="text-[11px] font-semibold text-[#0a84ff]">3 Available</span>
              </div>
              {[
                { label: "Tomorrow, 8:00 PM" },
                { label: "Jul 21, 2025, 8:00 PM" },
                { label: "Aug 2, 2025, 8:00 PM" },
              ].map((item, i) => (
                <div key={i} className="flex items-center gap-1.5 mb-[4px] last:mb-0">
                  <Icon name="calendar" size={10} color={dark ? "rgba(255,255,255,0.28)" : "rgba(0,0,0,0.26)"} />
                  <span className={`text-[11px] ${sub}`}>{item.label}</span>
                </div>
              ))}
            </div>
          </div>

          {/* Freshness metadata */}
          <div className={`${cardClass} px-4`}>
            {[
              { label: "Collected", value: "11:42:13 AM" },
              { label: "Source", value: "Live" },
              {
                label: "Confirmation",
                value:
                  state === "cached"
                    ? "Cached · Last Known Good"
                    : state === "refreshing"
                      ? "Refreshing…"
                      : "Confirmed After Retry",
                accent:
                  state === "cached"
                    ? "#ff9f0a"
                    : state === "refreshing"
                      ? "#0a84ff"
                      : "#30d158",
              },
              { label: "Collector", value: "Codex App Server" },
            ].map((row, i, arr) => (
              <div key={i}>
                <div className="flex items-center justify-between py-[8px]">
                  <span className={`text-[11px] ${sub}`}>{row.label}</span>
                  <span
                    className="text-[11px] font-medium"
                    style={{ color: row.accent ?? (dark ? "rgba(255,255,255,0.75)" : "rgba(0,0,0,0.65)") }}
                  >
                    {row.value}
                  </span>
                </div>
                {i < arr.length - 1 && <div className={`border-t ${divider}`} />}
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Bottom action menu */}
      <div className={`border-t ${border}`}>
        {[
          { icon: "refresh", label: "Refresh Now", disabled: state === "refreshing" },
          { icon: "bell", label: "Notification Settings", disabled: false },
          { icon: "gear", label: "Preferences…", disabled: false },
          { icon: "xmark", label: "Quit Codex Usage Monitor", disabled: false },
        ].map((item, i) => (
          <button
            key={i}
            disabled={item.disabled}
            className={`w-full flex items-center gap-2.5 px-4 py-[8px] text-[13px] transition-colors cursor-pointer text-left ${
              item.disabled
                ? `${sub} opacity-40`
                : dark
                  ? `${text} hover:bg-white/[0.05]`
                  : `${text} hover:bg-black/[0.03]`
            }`}
          >
            <Icon name={item.icon} size={13} color={iconColor} />
            {item.label}
          </button>
        ))}
      </div>
    </div>
  )
}
