#!/usr/bin/env node
/**
 * Multi-mode PDF exporter for explainer-html documents.
 * 
 * Supports multiple output display modes:
 *   1. phone / mobile:       390pt × 844pt (9:19.5) - Native smartphone viewport, one screen per page, 6-8 pages
 *   2. a4-portrait / a4:     595pt × 842pt (1:1.414) - Standard A4 portrait for formal print, desk reading
 *   3. a4-landscape / land:  842pt × 595pt (1.414:1) - A4 landscape for wide tables, Gantt charts, wide architecture
 *   4. slide / 16-9:         960pt × 540pt (16:9)    - Widescreen presentation / projector slides
 *   5. auto:                 Preserves the exact @page size declared inside the source HTML
 *
 * Usage:
 *   node export-pdf.mjs <input.html> [output.pdf] [--mode <phone|a4-portrait|a4-landscape|slide|auto>] [--preview]
 *
 * Examples:
 *   node export-pdf.mjs report.html --mode phone --preview
 *   node export-pdf.mjs report.html proposal.pdf --mode a4-portrait
 *   node export-pdf.mjs architecture.html --mode a4-landscape
 *   node export-pdf.mjs slides.html --mode slide
 */

import fs from "node:fs";
import path from "node:path";
import { execSync, spawnSync } from "node:child_process";

const CHROME_PATH = process.env.CHROME_BIN || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

const MODES = {
  phone: {
    aliases: ["phone", "mobile", "ios", "iphone"],
    label: "手机原生竖屏 (9:19.5)",
    pageSize: "390pt 844pt",
    margin: "14pt 12pt",
    expectedWidthPts: 390,
    expectedHeightPts: 844,
    description: "适合领导微信/移动端阅读优先，一页一屏，高信息密度推荐 6–8 屏",
    printCss: `
      @page { size: 390pt 844pt; margin: 14pt 12pt; }
      body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    `,
  },
  "a4-portrait": {
    aliases: ["a4-portrait", "a4", "portrait", "a4-v"],
    label: "A4 纵向打印/标准公文 (1:1.414)",
    pageSize: "595pt 842pt",
    margin: "10mm 8mm",
    expectedWidthPts: 595,
    expectedHeightPts: 842,
    description: "适合正式呈报材料、打印归档、平板与桌面阅读",
    printCss: `
      @page { size: 595pt 842pt; margin: 10mm 8mm; }
      body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    `,
  },
  "a4-landscape": {
    aliases: ["a4-landscape", "landscape", "land", "a4-h"],
    label: "A4 横向展示 (1.414:1)",
    pageSize: "842pt 595pt",
    margin: "8mm 10mm",
    expectedWidthPts: 842,
    expectedHeightPts: 595,
    description: "适合宽幅甘特图、复杂对照大表、横向架构图与技术全景",
    printCss: `
      @page { size: 842pt 595pt; margin: 8mm 10mm; }
      body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    `,
  },
  slide: {
    aliases: ["slide", "16-9", "16:9", "widescreen", "ppt"],
    label: "16:9 宽屏幻灯片 (16:9)",
    pageSize: "960pt 540pt",
    margin: "14pt 16pt",
    expectedWidthPts: 960,
    expectedHeightPts: 540,
    description: "适合会议室投屏演示、大屏演说、幻灯片汇报",
    printCss: `
      @page { size: 960pt 540pt; margin: 14pt 16pt; }
      body { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
    `,
  },
};

function printHelp() {
  console.log(`
Multi-mode PDF Exporter for explainer-html
===========================================

Usage:
  node export-pdf.mjs <input.html> [output.pdf] [options]

Supported Modes (--mode <name>):
  • phone / mobile      : 390pt × 844pt (9:19.5)  - ${MODES.phone.description}
  • a4-portrait / a4    : 595pt × 842pt (1:1.414) - ${MODES["a4-portrait"].description}
  • a4-landscape / land : 842pt × 595pt (1.414:1) - ${MODES["a4-landscape"].description}
  • slide / 16-9        : 960pt × 540pt (16:9)    - ${MODES.slide.description}
  • auto                : 保留 HTML 内部原生的 @page 设定（不强制覆写）

Options:
  --mode <mode>         指定目标版式模式（默认：若 HTML 已声明 @page 则 auto，否则 phone）
  --preview             导出后自动使用 pdftoppm 生成 PNG 缩略图以便快速目检
  --preview-dir <dir>   指定缩略图输出目录（默认 /tmp/explainer-preview-<timestamp>）
  -h, --help            查看帮助说明
`);
}

// Parse args
const args = process.argv.slice(2);
if (args.includes("-h") || args.includes("--help") || args.length === 0) {
  printHelp();
  process.exit(0);
}

let inputHtml = null;
let outputPdf = null;
let requestedMode = null;
let generatePreview = false;
let previewDir = null;

for (let i = 0; i < args.length; i++) {
  const arg = args[i];
  if (arg === "--mode") {
    requestedMode = args[++i]?.toLowerCase();
  } else if (arg === "--preview") {
    generatePreview = true;
  } else if (arg === "--preview-dir") {
    previewDir = args[++i];
  } else if (!arg.startsWith("-")) {
    if (!inputHtml) {
      inputHtml = arg;
    } else if (!outputPdf) {
      outputPdf = arg;
    }
  }
}

if (!inputHtml) {
  console.error("❌ 错误：请提供输入的 HTML 文件路径。");
  printHelp();
  process.exit(1);
}

const resolvedInput = path.resolve(process.cwd(), inputHtml);
if (!fs.existsSync(resolvedInput)) {
  console.error(`❌ 错误：输入文件不存在: ${resolvedInput}`);
  process.exit(1);
}

if (!outputPdf) {
  const parsed = path.parse(resolvedInput);
  outputPdf = path.join(parsed.dir, `${parsed.name}.pdf`);
}
const resolvedOutput = path.resolve(process.cwd(), outputPdf);

if (!fs.existsSync(CHROME_PATH)) {
  console.error(`❌ 错误：未找到 Google Chrome: ${CHROME_PATH}`);
  process.exit(1);
}

const htmlContent = fs.readFileSync(resolvedInput, "utf8");

// Detect existing @page in HTML
const pageMatch = htmlContent.match(/@page\s*\{([^}]+)\}/i);
const hasDeclaredPage = Boolean(pageMatch);

// Resolve mode
let activeModeKey = "auto";
if (requestedMode) {
  for (const [key, config] of Object.entries(MODES)) {
    if (config.aliases.includes(requestedMode)) {
      activeModeKey = key;
      break;
    }
  }
  if (activeModeKey === "auto" && requestedMode !== "auto") {
    console.error(`❌ 未知模式: "${requestedMode}"。可选模式：phone, a4-portrait, a4-landscape, slide, auto`);
    process.exit(1);
  }
} else {
  // If not specified, default to auto if HTML has @page, else phone
  activeModeKey = hasDeclaredPage ? "auto" : "phone";
}

let fileToRender = resolvedInput;
let tempFileToCleanup = null;

if (activeModeKey !== "auto") {
  const modeConfig = MODES[activeModeKey];
  console.log(`📐 应用版式模式: [${activeModeKey}] ${modeConfig.label}`);
  
  // Inject or override @page in a temporary HTML file
  const injection = `
<!-- injected by export-pdf.mjs for mode: ${activeModeKey} -->
<style id="export-pdf-injected-page">
  ${modeConfig.printCss}
</style>
`;
  let modifiedHtml = htmlContent;
  if (modifiedHtml.includes("</head>")) {
    modifiedHtml = modifiedHtml.replace("</head>", `${injection}</head>`);
  } else {
    modifiedHtml = `${injection}\n${modifiedHtml}`;
  }

  const tempFilePath = path.join(
    path.dirname(resolvedInput),
    `.temp-${path.basename(resolvedInput, ".html")}-${activeModeKey}-${Date.now()}.html`
  );
  fs.writeFileSync(tempFilePath, modifiedHtml, "utf8");
  fileToRender = tempFilePath;
  tempFileToCleanup = tempFilePath;
} else {
  console.log(`📐 应用版式模式: [auto] 保留 HTML 内部原生 @page 设定`);
}

const fileUrl = `file://${path.resolve(fileToRender)}`;
console.log(`🚀 正在通过 Chrome Headless 渲染 PDF...`);
console.log(`   输入: ${resolvedInput}`);
console.log(`   输出: ${resolvedOutput}`);

try {
  const chromeArgs = [
    "--headless",
    "--disable-gpu",
    "--no-pdf-header-footer",
    "--virtual-time-budget=5000",
    `--print-to-pdf=${resolvedOutput}`,
    fileUrl,
  ];

  const res = spawnSync(CHROME_PATH, chromeArgs, { stdio: ["ignore", "pipe", "pipe"] });
  if (res.status !== 0) {
    const errText = res.stderr ? res.stderr.toString() : "";
    if (!fs.existsSync(resolvedOutput) || fs.statSync(resolvedOutput).size === 0) {
      console.error(`❌ Chrome 导出失败 (code ${res.status}):\n${errText}`);
      process.exit(1);
    }
  }

  const stat = fs.statSync(resolvedOutput);
  console.log(`✅ PDF 导出成功: ${(stat.size / 1024).toFixed(1)} KB`);

  // Verify with pdfinfo if available
  try {
    const pdfinfoOutput = execSync(`pdfinfo "${resolvedOutput}" 2>/dev/null`, { encoding: "utf8" });
    const pagesMatch = pdfinfoOutput.match(/Pages:\s+(\d+)/);
    const sizeMatch = pdfinfoOutput.match(/Page size:\s+([0-9.]+)\s+x\s+([0-9.]+)\s+pts(?:\s+\(([^)]+)\))?/);

    const pages = pagesMatch ? parseInt(pagesMatch[1], 10) : null;
    const widthPts = sizeMatch ? parseFloat(sizeMatch[1]) : null;
    const heightPts = sizeMatch ? parseFloat(sizeMatch[2]) : null;
    const sizeLabel = sizeMatch && sizeMatch[3] ? sizeMatch[3] : "";

    console.log(`\n📋 PDF 规格校验报告:`);
    console.log(`   • 总页数: ${pages} 页`);
    console.log(`   • 页面尺寸: ${widthPts} × ${heightPts} pts ${sizeLabel ? `(${sizeLabel})` : ""}`);

    if (activeModeKey !== "auto") {
      const modeConfig = MODES[activeModeKey];
      const matchW = Math.abs(widthPts - modeConfig.expectedWidthPts) < 5;
      const matchH = Math.abs(heightPts - modeConfig.expectedHeightPts) < 5;
      if (matchW && matchH) {
        console.log(`   • 尺寸匹配: ✅ 严格契合 ${modeConfig.label}`);
      } else {
        console.warn(`   • 尺寸提醒: ⚠️ 当前页面尺寸 (${widthPts}x${heightPts}) 与模式期望 (${modeConfig.expectedWidthPts}x${modeConfig.expectedHeightPts}) 有偏差。`);
      }

      if (activeModeKey === "phone" && pages > 9) {
        console.warn(`   • 篇幅提示: ⚠️ 手机模式建议精炼至 6–8 页，当前页数 (${pages} 页) 偏长，请检查是否有多余解释性段落或未合并的重复表格。`);
      }
    }
  } catch (e) {
    // pdfinfo not installed or failed, skip
  }

  // Generate previews if requested
  if (generatePreview) {
    try {
      const targetDir = previewDir || path.join("/tmp", `explainer-preview-${Date.now()}`);
      fs.mkdirSync(targetDir, { recursive: true });
      console.log(`\n🖼️ 正在生成页面缩略预览图 (pdftoppm 150 DPI)...`);
      execSync(`pdftoppm -png -r 150 "${resolvedOutput}" "${path.join(targetDir, "page")}"`);
      const generatedImages = fs.readdirSync(targetDir).filter((f) => f.endsWith(".png")).sort();
      console.log(`   预览目录: ${targetDir}`);
      console.log(`   生成图片: ${generatedImages.length} 张`);
      for (const img of generatedImages.slice(0, 8)) {
        console.log(`     - ${path.join(targetDir, img)}`);
      }
      if (generatedImages.length > 8) {
        console.log(`     ... 另有 ${generatedImages.length - 8} 张`);
      }
    } catch (err) {
      console.warn(`⚠️ 预览图生成失败: ${err.message}`);
    }
  }

} finally {
  if (tempFileToCleanup && fs.existsSync(tempFileToCleanup)) {
    try { fs.unlinkSync(tempFileToCleanup); } catch {}
  }
}
