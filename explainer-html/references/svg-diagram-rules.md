# SVG 图表防崩与排版铁律（explainer-html 必读参考）

## 1. 头号致命陷阱：HTML5 `<svg>` 外来内容跳出（Foreign Content Breakout）

在 HTML5 标准（Section 13.2.6.5 *Parsing main inForeignContent*）中，当浏览器解析器处于 `<svg>` 内部时，一旦遇到以下任意一个 HTML 标签：

```text
<code>  <strong>  <b>  <span>  <br>  <div>  <p>  <i>  <em>  <ul>  <ol>  <li>  <table>  <h1>..<h6>
```

**浏览器会立即强行闭合 `<svg>` 标签**，并把该标签之后的所有 `<rect>`、`<path>`、`<text>` 全部当成普通 HTML 正文吐到图表框外面！这也是为什么此前多次出现「图只画了第一个框，后面的字全掉到图外底下一坨」的根本原因。

### 正确写法对照表

| 想要的效果 | ❌ 错误写法（直接炸穿 `<svg>`） | ✅ 正确写法（纯原生 SVG 属性） |
| :--- | :--- | :--- |
| 等宽代码字体 | `<text><code>ha trace</code></text>` | `<text font-family="ui-monospace,SFMono-Regular,Menlo,monospace">ha trace</text>` |
| 文字加粗 | `<text><strong>重点</strong></text>` | `<text font-weight="700">重点</text>` |
| 局部变色/加粗 | `<text>前缀 <span>高亮</span></text>` | `<text>前缀 <tspan fill="#a05252" font-weight="700">高亮</tspan></text>` |
| 换行 | `<text>第一行<br>第二行</text>` | 拆成两个 `<text y="140">` 与 `<text y="166">`（行距建议 `font-size * 1.65`） |
| 尖括号转义 | `<text>ha trace <path></text>` | `<text>ha trace &lt;path&gt;</text>`（必须转义 `&lt;` `&gt;` `&amp;`） |

---

## 2. 二号高频缺陷：`<text>` 视觉宽度溢出 `<rect>` 框外

SVG 的 `<text>` **不会自动换行**。手写坐标时，必须遵守宽度预算公式：

$$\text{视觉像素宽度} \approx (\text{中文字符数} \times \text{fontSize} \times 1.04) + (\text{英文字符数} \times \text{fontSize} \times 0.58)$$

- **安全法则**：`text_x + 视觉像素宽度` 必须 $\le \text{rect\_x} + \text{rect\_width} - 14$。
- **常用框宽安全字数表（以 `font-size="13"`、左侧内边距 `18px` 为例）**：
  - `width="220"` 的框：单行最多 **14 个汉字**（或 28 个英文字符）。
  - `width="330"` 的框：单行最多 **22 个汉字**（或 44 个英文字符）。
  - `width="700"` 的半屏框：单行最多 **48 个汉字**。
- **校验门禁**：写完 HTML 后必须执行 `node ~/.claude/skills/explainer-html/scripts/validate-explainer.mjs <file.html>`，脚本会自动计算每一条 `<text>` 与其最小包围 `<rect>` 的右边界，任何溢出都会精确报出文件名、行号与像素差！

---

## 3. 配色与全宽画布规范

- **画布尺寸**：全宽 `svg { width: 100%; height: auto; }`，`viewBox` 统一建议 `0 0 1600 <height>`。
- **节点语义配色（暖纸浅色系）**：
  - **已有/正常/通过（绿调）**：`fill="#e8f0e9" stroke="#4a7c59"`，标题色 `fill="#365d42"`
  - **待建/改造/警示（橙调）**：`fill="#f6ece2" stroke="#b0713c"`，标题色 `fill="#8a542c"`
  - **核心接口/契约（蓝调）**：`fill="#e6edf3" stroke="#4a6b8a"`，标题色 `fill="#4a6b8a"`
  - **故障/待删/禁令（红调）**：`fill="#f4e6e6" stroke="#a05252"`，标题色 `fill="#a05252"`
- **箭头标准画法**（从 `x1=360` 指向 `x2=420`，`y=135`）：
  ```xml
  <path d="M360 135 H420" stroke="#4a6b8a" stroke-width="3"/>
  <polygon points="420,135 408,128 408,142" fill="#4a6b8a"/>
  ```
