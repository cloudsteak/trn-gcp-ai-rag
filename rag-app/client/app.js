const apiUrl = (window.APP_CONFIG && window.APP_CONFIG.apiUrl) || "http://localhost:8080";

const messagesEl = document.getElementById("messages");
const inputEl = document.getElementById("input");
const formEl = document.getElementById("composer");
const sendBtn = document.getElementById("send");
const newChatBtn = document.getElementById("newChat");
const ragToggle = document.getElementById("ragToggle");
const debugToggle = document.getElementById("debugToggle");
const debugPanel = document.getElementById("debugPanel");
const debugLog = document.getElementById("debugLog");
const clearDebug = document.getElementById("clearDebug");
const workspace = document.querySelector(".workspace");

const history = [];
const welcomeHtml = document.querySelector(".welcome").innerHTML;
let chatSeq = 0;
let activeAbort = null;

function resetChat() {
  chatSeq += 1;
  if (activeAbort) {
    activeAbort.abort();
    activeAbort = null;
  }
  history.length = 0;
  messagesEl.innerHTML = "";
  const welcome = document.createElement("div");
  welcome.className = "bubble assistant welcome";
  welcome.innerHTML = welcomeHtml;
  messagesEl.appendChild(welcome);
  inputEl.value = "";
  inputEl.style.height = "auto";
  sendBtn.disabled = false;
  inputEl.focus();
}

function appendBubble(role, text) {
  const el = document.createElement("div");
  el.className = `bubble ${role}`;
  el.textContent = text;
  messagesEl.appendChild(el);
  messagesEl.scrollTop = messagesEl.scrollHeight;
  return el;
}

function appendAssistantTurn() {
  const turn = document.createElement("div");
  turn.className = "turn";
  const bubble = document.createElement("div");
  bubble.className = "bubble assistant";
  const cites = document.createElement("div");
  cites.className = "cites";
  turn.append(bubble, cites);
  messagesEl.appendChild(turn);
  messagesEl.scrollTop = messagesEl.scrollHeight;
  return { bubble, cites };
}

function fileName(uri) {
  try {
    return decodeURIComponent(uri.split("/").pop() || uri);
  } catch {
    return uri;
  }
}

function renderCites(citesEl, items) {
  citesEl.innerHTML = "";
  for (const item of items) {
    const btn = document.createElement("button");
    btn.type = "button";
    btn.className = "cite";
    btn.textContent = item.name || fileName(item.uri);
    btn.title = item.uri;
    btn.addEventListener("click", () => openSource(item.uri, btn.textContent));
    citesEl.appendChild(btn);
  }
}

const sourceDialog = document.getElementById("sourceDialog");
const sourceTitle = document.getElementById("sourceTitle");
const sourceUri = document.getElementById("sourceUri");
const sourceBody = document.getElementById("sourceBody");

function isMarkdownFile(name, uri) {
  return /\.md(\b|$)/i.test(`${name || ""} ${uri || ""}`);
}

function showSourceText(name, uri, text) {
  sourceBody.classList.remove("plain", "markdown");
  if (isMarkdownFile(name, uri) && typeof renderMarkdown === "function") {
    sourceBody.classList.add("markdown");
    sourceBody.innerHTML = renderMarkdown(text);
    return;
  }
  sourceBody.classList.add("plain");
  sourceBody.textContent = text;
}

async function openSource(uri, name) {
  sourceTitle.textContent = name;
  sourceUri.textContent = uri;
  sourceBody.classList.remove("markdown");
  sourceBody.classList.add("plain");
  sourceBody.textContent = "Betöltés…";
  sourceDialog.showModal();
  try {
    const response = await fetch(
      `${apiUrl.replace(/\/$/, "")}/source?uri=${encodeURIComponent(uri)}`
    );
    const data = await response.json();
    const text = data.text || data.detail || "Nem sikerült betölteni a fájlt.";
    if (!response.ok) {
      sourceBody.classList.add("plain");
      sourceBody.textContent = typeof text === "string" ? text : JSON.stringify(text);
      return;
    }
    showSourceText(data.name || name, data.uri || uri, text);
  } catch (error) {
    sourceBody.classList.add("plain");
    sourceBody.textContent = `Nem sikerült betölteni a fájlt. ${error}`;
  }
}

document.getElementById("sourceClose").addEventListener("click", () => sourceDialog.close());

function appendDebug(event) {
  if (debugLog.dataset.empty !== "false") {
    debugLog.textContent = "";
    debugLog.dataset.empty = "false";
  }
  const wrap = document.createElement("div");
  wrap.className = "debug-entry";
  const kind = (event.kind || "backend").replace(/[^\w-]/g, "");
  const badge = document.createElement("span");
  badge.className = `kind ${kind}`;
  badge.textContent = kind;
  const title = document.createElement("strong");
  title.textContent = " " + (event.title || kind);
  const detail = document.createElement("div");
  detail.textContent = JSON.stringify(event.detail || event, null, 2);
  wrap.append(badge, title, detail);
  debugLog.appendChild(wrap);
  debugLog.scrollTop = debugLog.scrollHeight;
}

function setDebugVisible(on) {
  debugPanel.classList.toggle("hidden", !on);
  workspace.classList.toggle("debug-on", on);
}

debugToggle.addEventListener("change", () => setDebugVisible(debugToggle.checked));
newChatBtn.addEventListener("click", resetChat);
ragToggle.addEventListener("change", () => {
  resetChat();
  const on = ragToggle.checked;
  appendBubble(
    "assistant",
    on
      ? "RAG bekapcsolva. A válasz a céges dokumentumokból jön."
      : "RAG kikapcsolva. Most a modell általános tudása válaszol."
  );
});
clearDebug.addEventListener("click", () => {
  debugLog.textContent = "A napló üres.";
  debugLog.dataset.empty = "true";
});

inputEl.addEventListener("input", () => {
  inputEl.style.height = "auto";
  inputEl.style.height = Math.min(inputEl.scrollHeight, 160) + "px";
});

inputEl.addEventListener("keydown", (event) => {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault();
    formEl.requestSubmit();
  }
});

formEl.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = inputEl.value.trim();
  if (!message || sendBtn.disabled) return;

  const seq = chatSeq;
  appendBubble("user", message);
  history.push({ role: "user", content: message });
  inputEl.value = "";
  inputEl.style.height = "auto";
  sendBtn.disabled = true;

  const assistantTurn = appendAssistantTurn();
  const assistantEl = assistantTurn.bubble;
  let assistantText = "";
  activeAbort = new AbortController();

  try {
    const response = await fetch(`${apiUrl.replace(/\/$/, "")}/chat`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      signal: activeAbort.signal,
      body: JSON.stringify({
        message,
        history: history.slice(0, -1),
        use_rag: ragToggle.checked,
      }),
    });

    if (!response.ok || !response.body) {
      assistantText = `A server nem válaszolt rendesen (${response.status}).`;
      assistantEl.textContent = assistantText;
      return;
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";

    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const parts = buffer.split("\n\n");
      buffer = parts.pop() || "";
      for (const part of parts) {
        handleSseBlock(part, (chunk) => {
          assistantText += chunk;
          assistantEl.textContent = assistantText;
          messagesEl.scrollTop = messagesEl.scrollHeight;
        }, (items) => {
          renderCites(assistantTurn.cites, items);
          messagesEl.scrollTop = messagesEl.scrollHeight;
        });
      }
    }
  } catch (error) {
    if (error.name === "AbortError") return;
    assistantText = `Nem sikerült elérni a servert (${apiUrl}). ${error}`;
    assistantEl.textContent = assistantText;
    appendDebug({ kind: "error", title: "Hálózati hiba", detail: { error: String(error), apiUrl } });
  } finally {
    if (seq !== chatSeq) return;
    if (assistantText) {
      history.push({ role: "model", content: assistantText });
    }
    sendBtn.disabled = false;
    inputEl.focus();
  }
});

function handleSseBlock(block, onToken, onSources) {
  let eventName = "message";
  const dataLines = [];
  for (const line of block.split("\n")) {
    if (line.startsWith("event:")) eventName = line.slice(6).trim();
    if (line.startsWith("data:")) dataLines.push(line.slice(5).trim());
  }
  if (!dataLines.length) return;
  const payload = JSON.parse(dataLines.join("\n"));
  if (eventName === "debug") appendDebug(payload);
  if (eventName === "token" && payload.text) onToken(payload.text);
  if (eventName === "sources" && onSources) onSources(payload.items || []);
}

setDebugVisible(false);
inputEl.focus();
