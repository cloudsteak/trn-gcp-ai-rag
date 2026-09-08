/**
 * Kis Markdown → HTML konverter a forrásdokumentum-ablakhoz.
 * Nem külső library: a képzésen végigolvasható. Nyers HTML-t nem enged át.
 */
(function (global) {
  function escapeHtml(text) {
    return String(text)
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function safeUrl(url) {
    const value = String(url || "").trim();
    if (/^(https?:|mailto:|#)/i.test(value)) return value;
    return "";
  }

  function renderInline(text) {
    const stash = [];
    const hold = (html) => {
      stash.push(html);
      return `\0${stash.length - 1}\0`;
    };

    let out = String(text);
    out = out.replace(/`([^`]+)`/g, (_, code) => hold(`<code>${escapeHtml(code)}</code>`));
    out = out.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (_, alt, url) => {
      const href = safeUrl(url);
      if (!href) return hold(escapeHtml(alt || "kép"));
      return hold(`<img alt="${escapeHtml(alt)}" src="${escapeHtml(href)}" />`);
    });
    out = out.replace(/\[([^\]]+)\]\(([^)]+)\)/g, (_, label, url) => {
      const href = safeUrl(url);
      if (!href) return hold(escapeHtml(label));
      return hold(
        `<a href="${escapeHtml(href)}" target="_blank" rel="noopener noreferrer">${escapeHtml(label)}</a>`
      );
    });
    out = escapeHtml(out);
    out = out.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
    out = out.replace(/__(.+?)__/g, "<strong>$1</strong>");
    out = out.replace(/\*(.+?)\*/g, "<em>$1</em>");
    out = out.replace(/\0(\d+)\0/g, (_, index) => stash[Number(index)]);
    return out;
  }

  function isFence(line) {
    return /^```/.test(line);
  }

  function isHeading(line) {
    return /^#{1,6} /.test(line);
  }

  function isHr(line) {
    return /^(---|\*\*\*|___)\s*$/.test(line.trim());
  }

  function isQuote(line) {
    return /^>\s?/.test(line);
  }

  function isUl(line) {
    return /^\s*[-*+] /.test(line);
  }

  function isOl(line) {
    return /^\s*\d+\. /.test(line);
  }

  function isTableSep(line) {
    return /^\s*\|?(\s*:?-{3,}:?\s*\|)+\s*:?-{3,}:?\s*\|?\s*$/.test(line);
  }

  function splitRow(line) {
    return line
      .trim()
      .replace(/^\|/, "")
      .replace(/\|$/, "")
      .split("|")
      .map((cell) => cell.trim());
  }

  function renderTable(lines, start) {
    const header = splitRow(lines[start]);
    let i = start + 2;
    const rows = [];
    while (i < lines.length && lines[i].includes("|") && !isFence(lines[i])) {
      if (!lines[i].trim()) break;
      rows.push(splitRow(lines[i]));
      i += 1;
    }
    const head = header.map((cell) => `<th>${renderInline(cell)}</th>`).join("");
    const body = rows
      .map((row) => `<tr>${row.map((cell) => `<td>${renderInline(cell)}</td>`).join("")}</tr>`)
      .join("");
    return {
      html: `<table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>`,
      next: i,
    };
  }

  function renderList(lines, start) {
    const ordered = isOl(lines[start]);
    const itemRe = ordered ? /^\s*\d+\. / : /^\s*[-*+] /;
    const items = [];
    let i = start;
    while (i < lines.length) {
      if (itemRe.test(lines[i])) {
        let item = lines[i].replace(itemRe, "");
        i += 1;
        while (
          i < lines.length &&
          lines[i].trim() &&
          !itemRe.test(lines[i]) &&
          !isHeading(lines[i]) &&
          !isFence(lines[i]) &&
          !isHr(lines[i])
        ) {
          item += " " + lines[i].trim();
          i += 1;
        }
        items.push(item);
        continue;
      }
      if (lines[i].trim() === "" && i + 1 < lines.length && itemRe.test(lines[i + 1])) {
        i += 1;
        continue;
      }
      break;
    }
    const tag = ordered ? "ol" : "ul";
    return {
      html: `<${tag}>${items.map((item) => `<li>${renderInline(item)}</li>`).join("")}</${tag}>`,
      next: i,
    };
  }

  function renderMarkdown(source) {
    const lines = String(source || "").replace(/\r\n/g, "\n").split("\n");
    const html = [];
    let i = 0;

    while (i < lines.length) {
      const line = lines[i];

      if (!line.trim()) {
        i += 1;
        continue;
      }

      if (isFence(line)) {
        const chunks = [];
        i += 1;
        while (i < lines.length && !isFence(lines[i])) {
          chunks.push(lines[i]);
          i += 1;
        }
        if (i < lines.length) i += 1;
        html.push(`<pre><code>${escapeHtml(chunks.join("\n"))}</code></pre>`);
        continue;
      }

      if (isHeading(line)) {
        const level = line.match(/^#{1,6}/)[0].length;
        html.push(`<h${level}>${renderInline(line.slice(level + 1).trim())}</h${level}>`);
        i += 1;
        continue;
      }

      if (isHr(line)) {
        html.push("<hr />");
        i += 1;
        continue;
      }

      if (isQuote(line)) {
        const quotes = [];
        while (i < lines.length && isQuote(lines[i])) {
          quotes.push(lines[i].replace(/^>\s?/, ""));
          i += 1;
        }
        html.push(`<blockquote>${renderInline(quotes.join(" "))}</blockquote>`);
        continue;
      }

      if (line.includes("|") && i + 1 < lines.length && isTableSep(lines[i + 1])) {
        const table = renderTable(lines, i);
        html.push(table.html);
        i = table.next;
        continue;
      }

      if (isUl(line) || isOl(line)) {
        const list = renderList(lines, i);
        html.push(list.html);
        i = list.next;
        continue;
      }

      const para = [line];
      i += 1;
      while (
        i < lines.length &&
        lines[i].trim() &&
        !isHeading(lines[i]) &&
        !isFence(lines[i]) &&
        !isHr(lines[i]) &&
        !isQuote(lines[i]) &&
        !isUl(lines[i]) &&
        !isOl(lines[i])
      ) {
        if (lines[i].includes("|") && i + 1 < lines.length && isTableSep(lines[i + 1])) break;
        para.push(lines[i]);
        i += 1;
      }
      html.push(`<p>${renderInline(para.join(" "))}</p>`);
    }

    return html.join("\n") || "<p></p>";
  }

  global.renderMarkdown = renderMarkdown;
})(window);
