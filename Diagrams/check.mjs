// Diagram checks — run verbatim, from this directory:
//     npm install mermaid@11 jsdom && node check.mjs
//
// Four checks, in order of what they can catch:
//   1. PARSE      — grammar. Says nothing about content or layout.
//   2. STRUCTURE  — every node classed, one shared style block, nothing dangling.
//   3. PLACEMENT  — the hazard a parse cannot see: a node first REFERENCED
//                   outside a subgraph but DECLARED inside it renders outside
//                   the box it belongs to. Parses fine either way.
//   4. RENDER     — layout completes. Text metrics are stubbed (jsdom ships no
//                   SVG layout engine), so this proves the graph resolves, not
//                   that it looks right. Open the SVGs to check that.
//
// Every check prints a corroborating count. A run that examined nothing must
// not be able to report success.
import { JSDOM } from "jsdom";
import fs from "fs";
import path from "path";

const dir = path.dirname(new URL(import.meta.url).pathname);
const files = fs.readdirSync(dir).filter(f => f.endsWith(".mermaid")).sort();
const SHARED = ["act", "dec", "bad", "note", "drill", "term"];
if (files.length === 0) { console.error("No .mermaid files found — wrong directory?"); process.exit(1); }

const dom = new JSDOM("<!doctype html><html><body></body></html>", { pretendToBeVisual: true });
globalThis.window = dom.window; globalThis.document = dom.window.document;
for (const k of ["Element","SVGElement","CSSStyleSheet","Node","DOMParser",
                 "XMLSerializer","HTMLElement","getComputedStyle","MutationObserver"]) {
  if (dom.window[k]) globalThis[k] = dom.window[k];
}
const proto = dom.window.SVGElement.prototype;
proto.getBBox = function () {
  const t = this.textContent || "";
  const lines = Math.max(1, (this.querySelectorAll ? this.querySelectorAll("tspan").length : 1) || 1);
  return { x: 0, y: 0, width: Math.max(20, (t.length * 6) / lines), height: Math.max(16, lines * 18) };
};
proto.getComputedTextLength = function () { return (this.textContent || "").length * 6; };
globalThis.DOMPurify = { sanitize: s => s, addHook() {}, setConfig() {} };
const mermaid = (await import("mermaid/dist/mermaid.esm.mjs")).default;
mermaid.initialize({ startOnLoad: false, securityLevel: "loose" });

const strip = line => {
  let s = line, prev;
  do { prev = s;
    s = s.replace(/([A-Za-z][\w]*)\(\("(?:[^"]*)"\)\)/g, "$1")
         .replace(/([A-Za-z][\w]*)\["(?:[^"]*)"\]/g, "$1")
         .replace(/([A-Za-z][\w]*)\{"(?:[^"]*)"\}/g, "$1");
  } while (s !== prev);
  return s;
};

let parseOK = 0, renderOK = 0, structIssues = 0, placeIssues = 0;

for (const f of files) {
  const raw = fs.readFileSync(path.join(dir, f), "utf8");
  const lines = raw.split("\n");
  const body = lines.filter(l => !l.trim().startsWith("%%"));

  try { await mermaid.parse(raw); parseOK++; }
  catch (e) { console.log(`PARSE FAIL ${f} -> ${String(e.message || e).split("\n")[0]}`); continue; }

  // --- structure ---
  const declared = new Set(), subgraphs = new Set();
  for (const l of body) {
    const sg = l.match(/subgraph\s+([A-Za-z][\w]*)/); if (sg) subgraphs.add(sg[1]);
    for (const m of l.matchAll(/([A-Za-z][\w]*)(?:\(\("|\["|\{")/g)) declared.add(m[1]);
  }
  const out = new Map(), inn = new Map(), all = new Set(declared);
  for (const l0 of body) {
    const l = strip(l0).replace(/\|[^|]*\|/g, " ");
    const re = /([A-Za-z][\w]*)\s*(-->|-\.->|==>)\s*([A-Za-z][\w]*)/g; let m;
    while ((m = re.exec(l)) !== null) {
      const [, a, kind, b] = m; all.add(a); all.add(b);
      if (kind === "-->") { out.set(a, 1); inn.set(b, 1); }
      re.lastIndex = m.index + m[1].length + m[2].length;
    }
  }
  const real = [...all].filter(n => !subgraphs.has(n));
  const classed = new Map();
  for (const l of body) {
    const m = l.match(/^\s*class\s+([\w,]+)\s+(\w+)\s*$/);
    if (m) for (const n of m[1].split(",")) classed.set(n, m[2]);
  }
  const defs = [...raw.matchAll(/class[D]ef\s+(\w+)/g)].map(m => m[1]);
  const kind = c => [...classed].filter(([, v]) => v === c).map(([n]) => n);
  const notes = new Set(kind("note")), terms = new Set(kind("term")), drills = new Set(kind("drill"));
  const problems = [];
  if (JSON.stringify(defs) !== JSON.stringify(SHARED)) problems.push(`style block DIVERGES: ${defs}`);
  for (const n of real) if (!classed.has(n)) problems.push(`unclassed node ${n}`);
  for (const n of classed.keys()) if (!real.includes(n)) problems.push(`classed non-node ${n}`);
  for (const n of real) if (!inn.has(n) && !notes.has(n) && !terms.has(n)) problems.push(`dangling root ${n}`);
  for (const n of real) if (!out.has(n) && !notes.has(n) && !terms.has(n) && !drills.has(n)) problems.push(`dangling leaf ${n}`);
  structIssues += problems.length;

  // --- placement ---
  const ctx = []; const lineCtx = lines.map(l => {
    const t = l.trim();
    if (/^subgraph\s/.test(t)) { const id = t.match(/subgraph\s+([A-Za-z][\w]*)/); ctx.push(id ? id[1] : "?"); return ctx.at(-1); }
    if (t === "end") { const c = ctx.at(-1); ctx.pop(); return c; }
    return ctx.length ? ctx.at(-1) : null;
  });
  const firstRef = new Map(), declAt = new Map();
  lines.forEach((l, i) => {
    if (l.trim().startsWith("%%") || /^\s*class(Def)?\s/.test(l)) return;
    const bare = l.replace(/"[^"]*"/g, '""');
    for (const m of bare.matchAll(/\b([A-Z][A-Z0-9]*)\b/g)) {
      if (["TD","LR","BT","RL"].includes(m[1])) continue;
      if (!firstRef.has(m[1])) firstRef.set(m[1], i);
    }
    for (const m of bare.matchAll(/([A-Z][A-Z0-9]*)(?:\(\(""\)\)|\[""\]|\{""\})/g))
      if (!declAt.has(m[1])) declAt.set(m[1], i);
  });
  for (const [id, d] of declAt) {
    const r = firstRef.get(id);
    if (r !== undefined && r !== d && lineCtx[r] !== lineCtx[d]) {
      problems.push(`MISPLACED ${id}: first referenced in ${lineCtx[r] ?? "top level"} (line ${r + 1}) but declared in ${lineCtx[d] ?? "top level"} (line ${d + 1})`);
      placeIssues++;
    }
  }

  // --- render ---
  let rendered = "n/a";
  try {
    const { svg } = await mermaid.render("g" + f.replace(/\W/g, ""), raw);
    rendered = `${(svg.match(/class="node /g) || []).length} nodes, ${(svg.match(/class="cluster /g) || []).length} subgraphs`;
    renderOK++;
  } catch (e) { problems.push(`RENDER FAIL -> ${String(e.message || e).split("\n")[0]}`); }

  console.log(`${problems.length ? "ISSUES" : "clean "}  ${f}  [${rendered}]`);
  for (const p of problems) console.log(`         - ${p}`);
}

console.log(`\n--- ${files.length} files examined | parse ${parseOK}/${files.length} | render ${renderOK}/${files.length} | structural issues ${structIssues} | placement issues ${placeIssues} ---`);
console.log(files.length === 5 ? "(five files is the expected denominator)" : `WARNING: expected 5 files, examined ${files.length}`);
process.exit(parseOK === files.length && renderOK === files.length && structIssues === 0 && placeIssues === 0 ? 0 : 1);
