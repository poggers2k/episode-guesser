/* איזה פרק? — the series list and episodes load from data/ on the server at every launch,
   so a series added there shows up without a new app version. */
"use strict";

// Where the data lives. In a store wrapper (Capacitor) set window.WE_DATA_BASE to the full hosted URL before this script.
const DATA_BASE = window.WE_DATA_BASE || "data/";
const ROUNDS = 10;
const GENRE_LABEL = { sitcom: "סיטקומים", drama: "דרמות" };

const app = document.getElementById("app");
const esc = s => String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
const pad = n => String(n).padStart(2, "0");

let catalog = null;          // {updated, series:[{id,he,en,tint,genre,seasons,episodes,playable,v}]}
const seriesCache = {};      // id -> full series {id,he,en,tint,seasons:[counts],eps:[[s,e,title,desc]]}
let state = { screen: "home" };

function store(k, v) {
  try {
    if (v === undefined) return JSON.parse(localStorage.getItem(k));
    localStorage.setItem(k, JSON.stringify(v));
  } catch (e) { return null; }
}
function shuffle(a) { a = a.slice(); for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; } return a; }

/* Scoring: right season = 50 (0 if the hint revealed it). The episode counts only when the season is right:
   exact 50, one off 30, two off 15, further 0. */
function scoreOf(gs, ge, s, e, hint) {
  const okS = gs === s, d = Math.abs(ge - e);
  const sp = okS && !hint ? 50 : 0;
  const ep = okS ? (d === 0 ? 50 : d === 1 ? 30 : d === 2 ? 15 : 0) : 0;
  return { sp, ep, d, exact: okS && d === 0, p: sp + ep };
}
const grade = r => r.exact ? "g" : r.p > 0 ? "n" : "b";

/* ---------- data ---------- */
async function loadCatalog() {
  try {
    const res = await fetch(DATA_BASE + "catalog.json", { cache: "no-cache" });
    if (!res.ok) throw new Error(res.status);
    catalog = await res.json();
    render();
  } catch (e) {
    app.innerHTML = `${brandHtml()}<p class="status err">לא הצלחנו לטעון את רשימת הסדרות. בדקו את החיבור לאינטרנט ונסו שוב.</p>
      <div><button class="btn" id="retryBtn">לנסות שוב</button></div>`;
  }
}
async function loadSeries(meta) {
  if (seriesCache[meta.id]?.v === meta.v) return seriesCache[meta.id];
  const res = await fetch(`${DATA_BASE}series/${encodeURIComponent(meta.id)}.json?v=${encodeURIComponent(meta.v || "")}`);
  if (!res.ok) throw new Error(res.status);
  const s = await res.json();
  s.v = meta.v;
  seriesCache[meta.id] = s;
  return s;
}

/* ---------- game flow ---------- */
function pickRounds(S) {
  const playable = S.eps.map((ep, i) => ep[3] ? i : -1).filter(i => i >= 0);
  const key = "seen:" + S.id;
  let seen = new Set(store(key) || []);
  let fresh = playable.filter(i => !seen.has(S.eps[i][0] + "-" + S.eps[i][1]));
  if (fresh.length < Math.min(ROUNDS, playable.length)) { seen = new Set(); fresh = playable; }
  const chosen = shuffle(fresh).slice(0, Math.min(ROUNDS, fresh.length));
  chosen.forEach(i => seen.add(S.eps[i][0] + "-" + S.eps[i][1]));
  store(key, [...seen]);
  return chosen;
}
async function startGame(id) {
  const meta = catalog.series.find(s => s.id === id);
  if (!meta) return;
  state = { screen: "loading", sid: id };
  render();
  try {
    const S = await loadSeries(meta);
    state = { screen: "play", sid: id, queue: pickRounds(S), round: 0, results: [], gs: null, ge: null, hint: false, revealed: false };
  } catch (e) {
    state = { screen: "home", error: "לא הצלחנו לטעון את הפרקים של הסדרה. נסו שוב." };
  }
  render(); window.scrollTo({ top: 0 });
}
const cur = () => seriesCache[state.sid];

/* ---------- views ---------- */
function brandHtml(intro) {
  return `<header class="brand"><h1>איזה <span>פרק?</span></h1>${intro ? `<p>${intro}</p>` : ""}</header>`;
}
function homeView() {
  const groups = {};
  for (const s of catalog.series) (groups[s.genre || "other"] ||= []).push(s);
  const order = ["sitcom", "drama", ...Object.keys(groups).filter(g => !GENRE_LABEL[g])];
  const sections = order.filter(g => groups[g]).map(g => `
    <section class="group">
      <p class="label">${esc(GENRE_LABEL[g] || "עוד סדרות")}</p>
      <div class="grid">${groups[g].map(card).join("")}</div>
    </section>`).join("");
  return `
  ${brandHtml(`קוראים תקציר של פרק ומנחשים מאיזו עונה ומאיזה פרק הוא. ${ROUNDS} סיבובים, עד 100 נקודות לסיבוב.`)}
  <section class="rules" aria-label="ניקוד">
    <div><b class="mono">50</b><span>עונה נכונה</span></div>
    <div><b class="mono">+50</b><span>פרק מדויק</span></div>
    <div><b class="mono">+30</b><span>פרק אחד ליד</span></div>
    <div><b class="mono">+15</b><span>שני פרקים ליד</span></div>
    <p>הפרק נספר רק כשהעונה נכונה. רמז חושף את העונה, ואז מקבלים רק את נקודות הפרק.</p>
  </section>
  ${state.error ? `<p class="status err">${esc(state.error)}</p>` : ""}
  ${sections}
  <footer class="credits">
    <span>התקצירים נכתבו במיוחד למשחק. רשימות הפרקים והמספור לפי <a href="https://www.tvmaze.com" target="_blank" rel="noopener">TVmaze</a>, ולכן בשירותי סטרימינג המספור יכול להיות שונה בפרקים כפולים.</span>
    <span>המשחק אינו קשור לאף אולפן, רשת או שירות סטרימינג. שמות הסדרות שייכים לבעליהן.</span>
    ${catalog.updated ? `<span>רשימת הסדרות עודכנה ב-<span class="mono">${esc(catalog.updated)}</span></span>` : ""}
  </footer>`;
}
function card(s) {
  const best = store("best:" + s.id);
  return `<button class="show" style="--tint:${esc(s.tint || "#777")}" data-start="${esc(s.id)}">
    <span class="nm">${esc(s.he)}</span><span class="en">${esc(s.en)}</span>
    <span class="meta"><span>${s.seasons} עונות</span><span>${s.episodes} פרקים</span>${best != null ? `<span class="best">שיא: ${best}</span>` : ""}</span>
  </button>`;
}
function playView() {
  const S = cur(), [s, e, title, desc] = S.eps[state.queue[state.round]];
  const total = state.results.reduce((a, r) => a + r.p, 0);
  const prog = state.queue.map((_, i) => { const r = state.results[i]; return `<i class="${r ? grade(r) : i === state.round ? "c" : ""}"></i>`; }).join("");
  const showS = state.revealed || state.hint, showE = state.revealed;
  const slug = `<div class="slug"><span class="kicker">תיאור הפרק</span>
      <span class="cell ${showS ? "on" : ""}">S${showS ? pad(s) : "??"}</span><span class="dot">·</span><span class="cell ${showE ? "on" : ""}">E${showE ? pad(e) : "??"}</span></div>`;
  let lower;
  if (!state.revealed) {
    const seasonChips = S.seasons.map((_, i) => `<button class="chip" data-s="${i + 1}" aria-pressed="${state.gs === i + 1}" ${state.hint && i + 1 !== s ? "disabled" : ""}>${i + 1}</button>`).join("");
    const epCount = state.gs ? S.seasons[state.gs - 1] : 0;
    const epChips = state.gs ? Array.from({ length: epCount }, (_, i) => `<button class="chip" data-e="${i + 1}" aria-pressed="${state.ge === i + 1}">${i + 1}</button>`).join("") : "";
    lower = `<section class="pick">
        <h3>עונה <small>${S.seasons.length} עונות</small></h3><div class="chips">${seasonChips}</div>
        <h3>פרק ${state.gs ? `<small>${epCount} פרקים בעונה ${state.gs}</small>` : ""}</h3>
        ${state.gs ? `<div class="chips">${epChips}</div>` : `<p class="hint">בחרו עונה כדי לראות את הפרקים שלה.</p>`}
      </section>
      <div class="actions">
        <button class="btn ghost small" id="hintBtn" ${state.hint ? "disabled" : ""}>${state.hint ? "העונה נחשפה" : "רמז: חשפו את העונה (מוותרים על 50 נק׳ העונה)"}</button>
        <button class="btn" id="guessBtn" ${state.gs && state.ge ? "" : "disabled"}>ניחוש</button>
      </div>`;
  } else {
    const r = state.results[state.round], g = grade(r);
    const word = r.exact ? (r.hint ? "בול, עם רמז" : "בול!") : g === "b" ? "לא הפעם" : "קרוב";
    const last = state.round === state.queue.length - 1;
    const sLine = r.gs !== s ? `עונה: לא נכונה (ניחשתם ${r.gs})` : r.hint ? "עונה: נחשפה ברמז" : "עונה: נכונה";
    const eLine = r.gs !== s ? "פרק: לא נספר כשהעונה לא נכונה" : r.d === 0 ? "פרק: מדויק" : `פרק: טעות של ${r.d === 1 ? "פרק אחד" : r.d + " פרקים"} (ניחשתם ${r.ge})`;
    lower = `<section class="verdict v-${{ g: "good", n: "near", b: "bad" }[g]}" aria-live="polite">
        <div class="big"><b>${word}</b><span class="pts mono">+${r.p}</span></div>
        <p>התשובה: <strong>עונה ${s}, פרק ${e}</strong></p>
        <div class="brk"><span>${sLine}</span><span class="mono">+${r.sp}</span><span>${eLine}</span><span class="mono">+${r.ep}</span></div>
      </section>
      <div class="actions"><span></span><button class="btn" id="nextBtn">${last ? "לתוצאות" : "לסיבוב הבא"}</button></div>`;
  }
  return `
  <div class="bar">
    <div class="who"><button class="btn ghost small" id="homeBtn">→ סדרות</button><b>${esc(S.he)}</b></div>
    <div class="stats"><span>סיבוב <b class="mono">${state.round + 1}/${state.queue.length}</b></span><span>ניקוד <b class="mono">${total}</b></span></div>
  </div>
  <div class="progress" aria-hidden="true">${prog}</div>
  <article class="screen">${slug}<p class="desc">${esc(desc)}</p>${state.revealed ? `<p class="ttl"><bdi dir="ltr">${esc(title)}</bdi></p>` : ""}</article>
  ${lower}`;
}
function endView() {
  const S = cur(), total = state.results.reduce((a, r) => a + r.p, 0), max = state.queue.length * 100;
  const pct = total / max;
  const line = pct >= .8 ? "מומחים אמיתיים. ראיתם כל פרק לפחות פעמיים." : pct >= .5 ? "צפייה רצינית. עוד סבב בינג׳ ואתם שם." : pct >= .25 ? "זוכרים את הקווים הכלליים, פחות את המספרים." : "אולי הגיע הזמן לצפייה חוזרת.";
  const rows = state.results.map((r, i) => {
    const [s, e, t] = S.eps[state.queue[i]];
    return `<tr><td class="mono">S${pad(s)}E${pad(e)}</td><td><bdi dir="ltr">${esc(t)}</bdi></td><td class="mono">S${pad(r.gs)}E${pad(r.ge)}${r.hint ? " ·רמז" : ""}</td><td class="p ${grade(r)}">${r.p}</td></tr>`;
  }).join("");
  return `
  <div class="bar"><div class="who"><b>${esc(S.he)}</b></div><button class="btn ghost small" id="homeBtn">→ סדרות</button></div>
  <section class="final">
    <p class="label">ניקוד סופי</p>
    <div class="score mono">${total}<small>/${max}</small></div>
    <p>${line}</p>
    ${state.newBest ? `<p class="note">שיא חדש לסדרה הזו.</p>` : ""}
  </section>
  <div class="tbl"><table>
    <thead><tr><th>הפרק</th><th>שם</th><th>הניחוש</th><th>נק׳</th></tr></thead>
    <tbody>${rows}</tbody></table></div>
  <div class="actions"><button class="btn ghost" id="homeBtn2">בחירת סדרה</button><button class="btn" id="againBtn">עוד סבב</button></div>`;
}
function render() {
  if (!catalog) return;
  if (state.screen === "loading") { app.innerHTML = `${brandHtml()}<p class="status">טוען פרקים…</p>`; return; }
  app.innerHTML = state.screen === "play" ? playView() : state.screen === "end" ? endView() : homeView();
}

/* ---------- events ---------- */
app.addEventListener("click", ev => {
  const t = ev.target.closest("button"); if (!t) return;
  if (t.dataset.start) { startGame(t.dataset.start); return; }
  if (t.dataset.s) { const v = +t.dataset.s; if (state.gs !== v) { state.gs = v; state.ge = null; } render(); return; }
  if (t.dataset.e) { state.ge = +t.dataset.e; render(); return; }
  switch (t.id) {
    case "retryBtn": loadCatalog(); break;
    case "hintBtn": {
      const [s] = cur().eps[state.queue[state.round]];
      state.hint = true; if (state.gs !== s) { state.gs = s; state.ge = null; } render(); break;
    }
    case "guessBtn": {
      const [s, e] = cur().eps[state.queue[state.round]];
      state.results[state.round] = { gs: state.gs, ge: state.ge, hint: state.hint, ...scoreOf(state.gs, state.ge, s, e, state.hint) };
      state.revealed = true; render(); break;
    }
    case "nextBtn":
      if (state.round === state.queue.length - 1) {
        const total = state.results.reduce((a, r) => a + r.p, 0), b = store("best:" + state.sid);
        state.newBest = b != null && total > b;
        if (b == null || total > b) store("best:" + state.sid, total);
        state.screen = "end";
      } else { state.round++; state.gs = null; state.ge = null; state.hint = false; state.revealed = false; }
      render(); window.scrollTo({ top: 0 }); break;
    case "againBtn": startGame(state.sid); break;
    case "homeBtn": case "homeBtn2": state = { screen: "home" }; render(); window.scrollTo({ top: 0 }); break;
  }
});

/* ---------- boot ---------- */
loadCatalog();
if ("serviceWorker" in navigator && location.protocol !== "file:") {
  window.addEventListener("load", () => navigator.serviceWorker.register("sw.js").catch(() => {}));
}
