#!/usr/bin/env node
/**
 * Deterministic validator for explainer-html single-file HTML outputs.
 *
 * Catches the 5 recurring defect classes before opening in browser:
 *   1. HTML5 SVG breakout tags (<code>, <strong>, <b>, <span>, <br>, <div>, <p>, <i>, <em>, <ul>, <li>)
 *      used inside <svg> without <foreignObject>, which causes the HTML5 parser to prematurely close <svg>
 *      and dump all remaining diagram text into normal <body> flow.
 *   2. SVG <text> visual width overflowing its enclosing <rect> right boundary (text spilling out of boxes).
 *   3. Narrow layout anti-patterns (max-width: 960px / 1200px / 1440px on body/main).
 *   4. Dark-theme backgrounds or missing warm-paper light palette (#faf7f0 / #f7f3ea).
 *   5. Sensitive local path / credential leaks (/Users/, emails, tokens).
 *   6. (always) Banned phrases (AI-flavored meta-narration, kickers, 定性, 不是A而是B),
 *      plus heading register: no question/colloquial/counting headings, no English eyebrow labels.
 *      See references/report-writing.md §5. A .md file (e.g. IM message draft) only runs this check.
 *
 * Usage:
 *   node ~/.claude/skills/explainer-html/scripts/validate-explainer.mjs <path-to-file.html> [--report]
 *   node ~/.claude/skills/explainer-html/scripts/validate-explainer.mjs <message.md> --report
 */

import fs from "node:fs";

const args = process.argv.slice(2);
const reportMode = args.includes("--report");
const filePath = args.find((a) => !a.startsWith("--"));
if (!filePath || !fs.existsSync(filePath)) {
  console.error("Usage: node validate-explainer.mjs <path-to-file.html|message.md> [--report]");
  process.exit(2);
}

// Banned report phrases (references/report-writing.md §5)
const bannedPhrases = [
  [/先给出|下面我们来看|下面来看|本节介绍|本文将|一页能看完/g, "元叙事"],
  [/我们的打法|之所以|我的判断是|基于这个判断|为什么要/g, "解释打法/动机"],
  [/这意味着|一句话[：:]|总之|归根结底|总而言之/g, "总结收尾句"],
  [/意义重大|关键的一步|真正的瓶颈|本质上|核心在于/g, "定性"],
  [/需要说明的是|值得注意的是|并非/g, "防御性"],
  [/赋能|抓手|全面提升/g, "空泛形容"],
  [/不是[^。，；！？\n]{1,24}[，,]\s*而是/g, "不是A而是B"],
];
function lintReportPhrases(text, out) {
  for (const [re, label] of bannedPhrases) {
    for (const m of text.matchAll(re)) {
      const at = Math.max(0, m.index - 12);
      out.push(`[REPORT] ${label}：「${m[0]}」…${text.slice(at, m.index + m[0].length + 12).replace(/\s+/g, " ")}…`);
    }
  }
}

if (filePath.endsWith(".md")) {
  const out = [];
  lintReportPhrases(fs.readFileSync(filePath, "utf8"), out);
  if (out.length) {
    console.error(`\n❌ report lint FAILED with ${out.length} hit(s):\n`);
    for (const o of out) console.error(`  • ${o}`);
    process.exit(1);
  }
  console.log("✅ report lint PASSED (0 banned phrases).");
  process.exit(0);
}

const html = fs.readFileSync(filePath, "utf8");
const errors = [];
const warnings = [];

function lineNumberAt(index) {
  let line = 1;
  for (let i = 0; i < index && i < html.length; i++) {
    if (html.charCodeAt(i) === 10) line++;
  }
  return line;
}

function decodeEntities(str) {
  return str
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'");
}

function estimateTextWidthPx(rawText, fontSize) {
  const text = decodeEntities(rawText.replace(/<[^>]+>/g, ""));
  let width = 0;
  for (const ch of text) {
    const cp = ch.codePointAt(0) ?? 0;
    if (cp > 0x2e80) {
      // CJK / full-width punctuation / emoji
      width += fontSize * 1.04;
    } else if ("MW@#%&".includes(ch)) {
      width += fontSize * 0.76;
    } else {
      width += fontSize * 0.57;
    }
  }
  return Math.ceil(width);
}

// Strip HTML comments while preserving line numbers (replace non-newline chars with spaces)
const htmlNoComments = html.replace(/<!--[\s\S]*?-->/g, (m) => m.replace(/[^\n]/g, " "));

// 1 & 2. Inspect every <svg>...</svg> block
const svgRegex = /<svg\b[^>]*>([\s\S]*?)<\/svg>/gi;
let svgMatch;
let svgIndex = 0;
while ((svgMatch = svgRegex.exec(htmlNoComments)) !== null) {
  svgIndex++;
  const svgStartOffset = svgMatch.index;
  const svgFull = svgMatch[0];
  const svgInner = svgMatch[1];

  // Strip <foreignObject>...</foreignObject> before checking for HTML5 breakout tags
  const withoutForeign = svgInner.replace(/<foreignObject\b[^>]*>[\s\S]*?<\/foreignObject>/gi, (m) =>
    " ".repeat(m.length),
  );

  const breakoutTagRegex = /<\/?(code|strong|b|span|br|div|p|i|em|ul|ol|li|table|h[1-6])\b[^>]*>/gi;
  let bMatch;
  while ((bMatch = breakoutTagRegex.exec(withoutForeign)) !== null) {
    const line = lineNumberAt(svgStartOffset + svgFull.indexOf(svgInner) + bMatch.index);
    errors.push(
      `[SVG #${svgIndex} Line ${line}] FATAL HTML5 SVG BREAKOUT: Found HTML tag ${bMatch[0]} directly inside <svg>. ` +
        `The HTML5 parser immediately auto-closes <svg> when it sees <${bMatch[1]}> outside <foreignObject>, dumping all subsequent text outside the diagram! ` +
        `Fix: remove <${bMatch[1]}> and use SVG attributes (font-family="monospace" / font-weight="700") or <tspan>.`,
    );
  }

  // Parse all <rect> in this SVG
  const rects = [];
  const rectRegex = /<rect\b([^>]*?)\/?>/gi;
  let rMatch;
  while ((rMatch = rectRegex.exec(withoutForeign)) !== null) {
    const attrs = rMatch[1];
    const x = parseFloat((/\bx=["']([0-9.]+)["']/i.exec(attrs) ?? [])[1]);
    const y = parseFloat((/\by=["']([0-9.]+)["']/i.exec(attrs) ?? [])[1]);
    const width = parseFloat((/\bwidth=["']([0-9.]+)["']/i.exec(attrs) ?? [])[1]);
    const height = parseFloat((/\bheight=["']([0-9.]+)["']/i.exec(attrs) ?? [])[1]);
    if ([x, y, width, height].every(Number.isFinite)) {
      rects.push({ x, y, width, height, area: width * height });
    }
  }

  // Parse all <text> in this SVG and check against smallest enclosing <rect>
  const textRegex = /<text\b([^>]*?)>([\s\S]*?)<\/text>/gi;
  let tMatch;
  while ((tMatch = textRegex.exec(withoutForeign)) !== null) {
    const attrs = tMatch[1];
    const content = tMatch[2];
    const tx = parseFloat((/\bx=["']([0-9.]+)["']/i.exec(attrs) ?? [])[1]);
    const ty = parseFloat((/\by=["']([0-9.]+)["']/i.exec(attrs) ?? [])[1]);
    const fontSize = parseFloat((/\bfont-size=["']([0-9.]+)["']/i.exec(attrs) ?? [])[1] ?? "15");
    const textAnchor = (/\btext-anchor=["']([a-z]+)["']/i.exec(attrs) ?? [])[1] ?? "start";
    if (!Number.isFinite(tx) || !Number.isFinite(ty)) continue;

    const estWidth = estimateTextWidthPx(content, fontSize);
    const leftEdge = textAnchor === "middle" ? tx - estWidth / 2 : textAnchor === "end" ? tx - estWidth : tx;
    const rightEdge = leftEdge + estWidth;

    // Find smallest enclosing rect containing the text anchor point (tx, ty - fontSize * 0.4)
    const cy = ty - fontSize * 0.35;
    const enclosing = rects
      .filter((r) => tx >= r.x && tx <= r.x + r.width && cy >= r.y && cy <= r.y + r.height)
      .sort((a, b) => a.area - b.area)[0];

    if (enclosing) {
      const rectRight = enclosing.x + enclosing.width;
      const line = lineNumberAt(svgStartOffset + svgFull.indexOf(svgInner) + tMatch.index);
      if (rightEdge > rectRight - 6) {
        const cleanText = decodeEntities(content.replace(/<[^>]+>/g, "")).trim();
        errors.push(
          `[SVG #${svgIndex} Line ${line}] SVG_TEXT_OVERFLOW: Text "${cleanText.slice(0, 42)}${cleanText.length > 42 ? "…" : ""}" ` +
            `(x=${tx}, font-size=${fontSize}, estRight=${rightEdge}px) overflows its enclosing <rect x=${enclosing.x} width=${enclosing.width}> (rectRight=${rectRight}px). ` +
            `Fix: widen the <rect>, reduce font-size, or split into two <text> lines.`,
        );
      }
    }
  }
}

// 3. Check full-width layout rule (skipped for --report mode which allows phone/compact containers)
const styleBlocks = [...html.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/gi)].map((m) => m[1]).join("\n");
if (!reportMode && /(?:body|main|\.container)\s*\{[^}]*max-width\s*:\s*(?:960|1024|1100|1200|1280|1440)px/i.test(styleBlocks)) {
  errors.push(
    `[LAYOUT] Narrow container detected in <style>. Rule requires full-width layout (max-width: none on main/body with clamp padding).`,
  );
}

// 4. Check light warm-paper theme
if (!/#faf7f0|#f7f3ea/i.test(styleBlocks)) {
  warnings.push(`[THEME] Expected warm-paper background (#faf7f0 or #f7f3ea) in <style>.`);
}

// 5. Check sensitive leaks
const htmlWithoutComments = html.replace(/<!--[\s\S]*?-->/g, "");
const leakPatterns = [
  { regex: /\/Users\/[A-Za-z0-9._-]+/g, label: "macOS absolute user path" },
  { regex: /\/home\/[A-Za-z0-9._-]+/g, label: "Linux absolute user path" },
  { regex: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g, label: "Email address" },
  { regex: /\b(?:ghp_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,})\b/g, label: "API token/secret" },
];
for (const { regex, label } of leakPatterns) {
  const m = htmlWithoutComments.match(regex);
  if (m) {
    errors.push(`[LEAK] Found ${label} in visible HTML: ${m[0]}`);
  }
}

// 6. 文案与标题语域检查（所有 HTML 默认执行，不依赖 --report）
{
  const visible = html
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/<(style|script|svg)[\s\S]*?<\/\1>/gi, " ")
    .replace(/<[^>]+>/g, "");
  lintReportPhrases(decodeEntities(visible), errors);
  // 6b. 标题语域（references/report-writing.md §6）：h1–h4、summary、徽章标题、表头
  const headingRe = /<(h[1-4]|summary|th)\b[^>]*>([\s\S]*?)<\/\1>|<div class="badge[^"]*"><b>([\s\S]*?)<\/b>/gi;
  const colloquial = [
    [/[？?]|怎么|怎样|如何|什么|哪(?!怕)|吗|呢|到底/, "设问/疑问式标题"],
    [/站在哪|做到哪|长什么样|搞定|跑通|交齐|干啥|咋/, "口语化标题"],
    [/\d+\s*(样|件|个)\s*(东西|事情?)|几样|几件/, "凑数式标题（X 样东西 / X 件事）"],
  ];
  for (const m of html.matchAll(headingRe)) {
    const text = decodeEntities((m[2] ?? m[3] ?? "").replace(/<[^>]+>/g, "")).trim();
    if (!text) continue;
    for (const [re, label] of colloquial) {
      if (re.test(text)) errors.push(`[REPORT] ${label}：「${text.slice(0, 40)}」`);
    }
  }
  // 6c. 英文眉标（SECTION 01 · …、TECHNICAL EXPLAINER）
  for (const m of html.matchAll(/<div class="act">([^<]*)<\/div>/g)) {
    if (/SECTION\s*\d|EXPLAINER|CASE STUDY|PIPELINE/i.test(m[1])) errors.push(`[REPORT] 英文眉标：「${m[1].trim()}」`);
  }
}

if (warnings.length > 0) {
  for (const w of warnings) console.warn(`WARN: ${w}`);
}

if (errors.length > 0) {
  console.error(`\n❌ validate-explainer FAILED with ${errors.length} error(s):\n`);
  for (const err of errors) {
    console.error(`  • ${err}`);
  }
  process.exit(1);
}

console.log(`✅ validate-explainer PASSED (${svgIndex} SVG diagram(s) verified, 0 breakout tags, 0 text overflows, 0 leaks).`);
