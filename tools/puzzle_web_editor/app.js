// Puzzle Web Editor — app.js

const PIECE_GLYPH = {
  p:"♟",r:"♜",n:"♞",b:"♝",q:"♛",k:"♚",
  P:"♙",R:"♖",N:"♘",B:"♗",Q:"♕",K:"♔",
};
const FILES = ["a","b","c","d","e","f","g","h"];

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
const state = {
  pools: { easy:[], medium:[], hard:[] },
  opponents: [],
  pool: "easy",
  selectedIndex: -1,
  search: "",
  dirty: false,         // unsaved to disk
  previewStep: 0,
  lastMove: null,       // {from, to}
  boardFlipped: false,
  recordMode: false,
  selectedSquare: null, // square name currently selected in record mode
  legalSquares: [],     // legal destination squares for selectedSquare
};

// ---------------------------------------------------------------------------
// DOM refs
// ---------------------------------------------------------------------------
const el = {};
function initEl() {
  [
    "fightFilter","poolSelect","searchInput","reloadBtn","savePoolBtn",
    "newBtn","duplicateBtn","deleteBtn","puzzleList","listHeader","status",
    "idInput","fenInput","solutionInput","themesInput","descriptionInput",
    "difficultyInput","sourceInput","validateBtn","copyFenBtn",
    "board","boardMeta","rankLabels","fileLabels","moveList","puzzleTitle",
    "resetPreviewBtn","prevMoveBtn","nextMoveBtn","flipBtn","recordBtn","boardPanel",
  ].forEach(id => { el[id] = document.getElementById(id); });
}

// ---------------------------------------------------------------------------
// Status helpers
// ---------------------------------------------------------------------------
function setStatus(text, cls="") {
  el.status.textContent = text;
  el.status.className = `status ${cls}`.trim();
}
function markDirty() {
  state.dirty = true;
  setStatus("Unsaved changes", "dirty");
}
function clearDirty(msg="Saved") {
  state.dirty = false;
  setStatus(msg, "ok");
}

// ---------------------------------------------------------------------------
// Pool helpers
// ---------------------------------------------------------------------------
function poolFromDifficulty(d) {
  const n = Number(d||1);
  if (n <= 2) return "easy";
  if (n <= 4) return "medium";
  return "hard";
}
function currentPool() { return state.pools[state.pool]; }
function getSelected() {
  const arr = currentPool();
  if (state.selectedIndex < 0 || state.selectedIndex >= arr.length) return null;
  return arr[state.selectedIndex];
}

// ---------------------------------------------------------------------------
// Form <-> Puzzle
// ---------------------------------------------------------------------------
function parseSolution(text) {
  return text.trim().split(/\s+/).filter(Boolean);
}
function parseThemes(text) {
  return text.split(",").map(t=>t.trim()).filter(Boolean);
}

function formToPuzzle() {
  return {
    id: el.idInput.value.trim(),
    fen: el.fenInput.value.trim(),
    solution: parseSolution(el.solutionInput.value),
    themes: parseThemes(el.themesInput.value),
    difficulty: Number(el.difficultyInput.value || 1),
    description: el.descriptionInput.value.trim(),
    source: el.sourceInput.value.trim() || "local",
  };
}

function puzzleToForm(p) {
  el.idInput.value = p.id || "";
  el.fenInput.value = p.fen || "";
  el.solutionInput.value = (p.solution || []).join(" ");
  el.themesInput.value = (p.themes || []).join(", ");
  el.descriptionInput.value = p.description || "";
  el.difficultyInput.value = String(p.difficulty || 1);
  el.sourceInput.value = p.source || "local";
  el.puzzleTitle.textContent = p.id || "No puzzle selected";
}

// Auto-apply current form values to the in-memory array (no disk write).
function autoApplyForm() {
  if (state.selectedIndex < 0) return;
  const p = formToPuzzle();
  if (!p.id && !p.fen) return; // empty form, don't overwrite
  currentPool()[state.selectedIndex] = p;
}

// ---------------------------------------------------------------------------
// Validation
// ---------------------------------------------------------------------------
function validatePuzzle(p) {
  if (!p.id) return "id is empty";
  if (!p.fen) return "fen is empty";
  if (!Array.isArray(p.solution) || p.solution.length === 0) return "solution is empty";
  let chess;
  try { chess = new Chess(p.fen); }
  catch (_) { return "invalid FEN"; }
  for (const move of p.solution) {
    if (move.length < 4 || move.length > 5) return `invalid UCI: ${move}`;
    const played = chess.move({ from:move.slice(0,2), to:move.slice(2,4), promotion:move[4]||undefined });
    if (!played) return `illegal move: ${move}`;
  }
  return "";
}

// ---------------------------------------------------------------------------
// Chess helpers
// ---------------------------------------------------------------------------
function buildChess(fen, moves, upToStep) {
  let chess;
  try { chess = new Chess(fen || undefined); }
  catch (_) { return null; }
  const cap = Math.min(upToStep, (moves||[]).length);
  for (let i = 0; i < cap; i++) {
    const uci = moves[i];
    const ok = chess.move({ from:uci.slice(0,2), to:uci.slice(2,4), promotion:uci[4]||undefined });
    if (!ok) break;
  }
  return chess;
}

// ---------------------------------------------------------------------------
// Board rendering
// ---------------------------------------------------------------------------
let boardRenderTimer = null;
function scheduleBoardRender() {
  clearTimeout(boardRenderTimer);
  boardRenderTimer = setTimeout(renderBoard, 120);
}

function renderBoard() {
  const p = formToPuzzle();
  const moves = p.solution || [];

  // Build chess instance up to previewStep
  const chess = buildChess(p.fen, moves, state.previewStep);

  if (!chess) {
    el.board.innerHTML = "<div class='board-error'>Invalid FEN</div>";
    el.boardMeta.textContent = "Invalid FEN";
    el.moveList.innerHTML = "";
    el.rankLabels.innerHTML = "";
    el.fileLabels.innerHTML = "";
    return;
  }

  // Last-move highlight
  if (state.previewStep > 0 && moves[state.previewStep - 1]) {
    const uci = moves[state.previewStep - 1];
    state.lastMove = { from:uci.slice(0,2), to:uci.slice(2,4) };
  } else {
    state.lastMove = null;
  }

  const ranks = state.boardFlipped ? [1,2,3,4,5,6,7,8] : [8,7,6,5,4,3,2,1];
  const files = state.boardFlipped ? ["h","g","f","e","d","c","b","a"] : FILES;

  // Rank labels
  el.rankLabels.innerHTML = "";
  for (const r of ranks) {
    const d = document.createElement("div");
    d.className = "coord-label";
    d.textContent = r;
    el.rankLabels.appendChild(d);
  }

  // File labels
  el.fileLabels.innerHTML = "";
  for (const f of files) {
    const d = document.createElement("div");
    d.className = "coord-label";
    d.textContent = f;
    el.fileLabels.appendChild(d);
  }

  // Squares
  el.board.innerHTML = "";
  for (const rank of ranks) {
    for (const file of files) {
      const sqName = `${file}${rank}`;
      const pieceObj = chess.get(sqName);
      const piece = pieceObj
        ? (pieceObj.color === "w" ? pieceObj.type.toUpperCase() : pieceObj.type)
        : "";

      const fi = sqName.charCodeAt(0) - 97;
      const ri = Number(sqName[1]);
      const isLight = (fi + ri) % 2 === 0;

      const sq = document.createElement("div");
      sq.className = `square ${isLight ? "light" : "dark"}`;
      sq.dataset.square = sqName;

      if (state.selectedSquare === sqName) sq.classList.add("selected");
      if (state.lastMove?.from === sqName) sq.classList.add("from");
      if (state.lastMove?.to === sqName) sq.classList.add("to");

      if (state.legalSquares.includes(sqName)) {
        if (pieceObj && pieceObj.color !== chess.turn()) {
          sq.classList.add("legal-capture");
        } else {
          sq.classList.add("legal-move");
          const dot = document.createElement("div");
          dot.className = "legal-dot";
          sq.appendChild(dot);
        }
      }

      if (piece) {
        const span = document.createElement("span");
        span.className = "piece";
        span.textContent = PIECE_GLYPH[piece] || "";
        sq.appendChild(span);
      }

      el.board.appendChild(sq);
    }
  }

  // Board meta
  const turnStr = chess.turn() === "w" ? "White" : "Black";
  const checkStr = chess.in_check() ? " · CHECK" : "";
  el.boardMeta.textContent =
    `Step ${state.previewStep}/${moves.length} · ${turnStr} to move${checkStr}${state.recordMode ? " · REC ●" : ""}`;

  // Record mode indicator
  el.boardPanel.classList.toggle("recording", state.recordMode);
  el.recordBtn.classList.toggle("active", state.recordMode);

  // Move badges
  renderMoveBadges(moves);
}

function renderMoveBadges(moves) {
  el.moveList.innerHTML = "";
  if (moves.length === 0) return;

  moves.forEach((uci, i) => {
    const badge = document.createElement("button");
    badge.className = "move-badge" +
      (i < state.previewStep ? " played" : "") +
      (i === state.previewStep - 1 ? " current" : "");
    badge.textContent = uci;
    badge.title = `Jump to after move ${i + 1}`;
    badge.addEventListener("click", () => {
      state.previewStep = i + 1;
      state.selectedSquare = null;
      state.legalSquares = [];
      renderBoard();
    });
    el.moveList.appendChild(badge);
  });
}

// ---------------------------------------------------------------------------
// Interactive board — record mode
// ---------------------------------------------------------------------------
function handleBoardClick(sqName) {
  if (!state.recordMode) return;

  const p = formToPuzzle();
  const moves = p.solution || [];
  const chess = buildChess(p.fen, moves, state.previewStep);
  if (!chess) return;

  const pieceObj = chess.get(sqName);

  // If we already have a selected square...
  if (state.selectedSquare) {
    // Click on a legal target → make the move
    if (state.legalSquares.includes(sqName)) {
      let uci = `${state.selectedSquare}${sqName}`;

      // Auto-promote to queen
      const movingPiece = chess.get(state.selectedSquare);
      if (movingPiece?.type === "p") {
        const toRank = Number(sqName[1]);
        if ((movingPiece.color === "w" && toRank === 8) ||
            (movingPiece.color === "b" && toRank === 1)) {
          uci += "q";
        }
      }

      // Truncate solution at previewStep, append new move
      const newMoves = [...moves.slice(0, state.previewStep), uci];
      el.solutionInput.value = newMoves.join(" ");

      state.previewStep++;
      state.lastMove = { from:state.selectedSquare, to:sqName };
      state.selectedSquare = null;
      state.legalSquares = [];

      autoApplyForm();
      markDirty();
      renderBoard();
      return;
    }

    // Click on another friendly piece → re-select
    if (pieceObj && pieceObj.color === chess.turn()) {
      state.selectedSquare = sqName;
      state.legalSquares = chess.moves({ square:sqName, verbose:true }).map(m => m.to);
      renderBoard();
      return;
    }

    // Click elsewhere → deselect
    state.selectedSquare = null;
    state.legalSquares = [];
    renderBoard();
    return;
  }

  // No selection: select a friendly piece
  if (pieceObj && pieceObj.color === chess.turn()) {
    state.selectedSquare = sqName;
    state.legalSquares = chess.moves({ square:sqName, verbose:true }).map(m => m.to);
    renderBoard();
  }
}

function toggleRecordMode() {
  state.recordMode = !state.recordMode;
  state.selectedSquare = null;
  state.legalSquares = [];
  renderBoard();
}

// ---------------------------------------------------------------------------
// Puzzle list
// ---------------------------------------------------------------------------
function nextId() {
  let max = 0;
  ["easy","medium","hard"].forEach(pool => {
    for (const p of state.pools[pool]) {
      if (typeof p.id !== "string" || !p.id.startsWith("puzzle_")) continue;
      const n = Number(p.id.slice(7));
      if (Number.isInteger(n)) max = Math.max(max, n);
    }
  });
  return `puzzle_${String(max + 1).padStart(3, "0")}`;
}

function renderList() {
  const arr = currentPool();
  const q = state.search.toLowerCase();
  el.puzzleList.innerHTML = "";
  let count = 0;

  arr.forEach((p, idx) => {
    const searchText = `${p.id||""} ${p.description||""} ${(p.themes||[]).join(" ")}`.toLowerCase();
    if (q && !searchText.includes(q)) return;
    count++;

    const node = document.createElement("div");
    node.className = "puzzle-item" + (idx === state.selectedIndex ? " active" : "");

    const diff = p.difficulty || 1;
    const themesHtml = (p.themes||[]).slice(0,3)
      .map(t => `<span class="theme-badge">${t}</span>`).join("");

    node.innerHTML = `
      <div class="item-header">
        <span class="item-id">${p.id || "(no id)"}</span>
        <span class="diff-badge diff-${Math.min(diff,10)}">${diff}</span>
      </div>
      ${p.description ? `<div class="item-desc">${p.description}</div>` : ""}
      ${themesHtml ? `<div class="item-themes">${themesHtml}</div>` : ""}
    `;
    node.addEventListener("click", () => selectPuzzle(idx));
    el.puzzleList.appendChild(node);
  });

  const total = arr.length;
  el.listHeader.textContent =
    `${count}${count !== total ? ` of ${total}` : ""} puzzle${total !== 1 ? "s" : ""} · ${state.pool}`;
}

function selectPuzzle(idx) {
  // Auto-apply current form to memory before switching (no blocking!)
  autoApplyForm();

  state.selectedIndex = idx;
  state.previewStep = 0;
  state.selectedSquare = null;
  state.legalSquares = [];
  state.lastMove = null;

  const arr = currentPool();
  if (idx >= 0 && idx < arr.length) {
    puzzleToForm(arr[idx]);
  }
  renderList();
  renderBoard();
}

// ---------------------------------------------------------------------------
// API calls
// ---------------------------------------------------------------------------
async function loadState() {
  const res = await fetch("/api/state");
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  const data = await res.json();
  state.pools = data.pools;
  state.opponents = Array.isArray(data.opponents) ? data.opponents : [];
  state.opponents.sort((a,b) => Number(a.fight_position||0) - Number(b.fight_position||0));

  // Populate fight filter
  el.fightFilter.innerHTML = "";
  const any = document.createElement("option");
  any.value = ""; any.textContent = "All fights";
  el.fightFilter.appendChild(any);
  state.opponents.forEach((opp, idx) => {
    const pool = poolFromDifficulty(opp.chess_difficulty);
    const opt = document.createElement("option");
    opt.value = String(idx);
    opt.textContent = `${opp.fight_position}. ${opp.name} → ${pool}`;
    el.fightFilter.appendChild(opt);
  });

  state.selectedIndex = currentPool().length ? 0 : -1;
  if (state.selectedIndex >= 0) puzzleToForm(currentPool()[state.selectedIndex]);
  renderList();
  renderBoard();
  clearDirty("Loaded");
}

async function savePool() {
  const res = await fetch(`/api/pool/${state.pool}/save`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ puzzles: currentPool() }),
  });
  if (!res.ok) {
    const err = await res.json().catch(() => ({}));
    throw new Error(err.error || `HTTP ${res.status}`);
  }
  clearDirty(`Saved ${state.pool} (${currentPool().length} puzzles)`);
}

// ---------------------------------------------------------------------------
// Event binding
// ---------------------------------------------------------------------------
function bindEvents() {

  // --- Pool & fight filter ---
  el.poolSelect.addEventListener("change", () => {
    autoApplyForm();
    state.pool = el.poolSelect.value;
    state.selectedIndex = currentPool().length ? 0 : -1;
    state.previewStep = 0;
    state.selectedSquare = null;
    state.legalSquares = [];
    if (state.selectedIndex >= 0) puzzleToForm(currentPool()[state.selectedIndex]);
    renderList();
    renderBoard();
    clearDirty(`Switched to ${state.pool}`);
  });

  el.fightFilter.addEventListener("change", () => {
    const idx = el.fightFilter.value;
    if (idx === "") return;
    const opp = state.opponents[Number(idx)];
    if (!opp) return;
    const pool = poolFromDifficulty(opp.chess_difficulty);
    autoApplyForm();
    state.pool = pool;
    el.poolSelect.value = pool;
    state.selectedIndex = currentPool().length ? 0 : -1;
    state.previewStep = 0;
    state.selectedSquare = null;
    state.legalSquares = [];
    if (state.selectedIndex >= 0) puzzleToForm(currentPool()[state.selectedIndex]);
    renderList();
    renderBoard();
    clearDirty(`${opp.name} → ${pool}`);
  });

  // --- Search ---
  el.searchInput.addEventListener("input", () => {
    state.search = el.searchInput.value.trim();
    renderList();
  });

  // --- Form fields: auto-apply + live board update ---
  const formFields = [
    el.idInput, el.fenInput, el.solutionInput, el.themesInput,
    el.descriptionInput, el.difficultyInput, el.sourceInput,
  ];
  formFields.forEach(node => {
    node.addEventListener("input", () => {
      autoApplyForm();
      markDirty();
      scheduleBoardRender();
    });
  });

  // --- Board clicks ---
  el.board.addEventListener("click", e => {
    const sq = e.target.closest("[data-square]");
    if (!sq) return;
    handleBoardClick(sq.dataset.square);
  });

  // --- Board controls ---
  el.flipBtn.addEventListener("click", () => {
    state.boardFlipped = !state.boardFlipped;
    renderBoard();
  });

  el.recordBtn.addEventListener("click", toggleRecordMode);

  el.resetPreviewBtn.addEventListener("click", () => {
    state.previewStep = 0;
    state.selectedSquare = null;
    state.legalSquares = [];
    renderBoard();
  });

  el.prevMoveBtn.addEventListener("click", () => {
    state.previewStep = Math.max(0, state.previewStep - 1);
    state.selectedSquare = null;
    state.legalSquares = [];
    renderBoard();
  });

  el.nextMoveBtn.addEventListener("click", () => {
    const moves = parseSolution(el.solutionInput.value);
    state.previewStep = Math.min(moves.length, state.previewStep + 1);
    state.selectedSquare = null;
    state.legalSquares = [];
    renderBoard();
  });

  // --- Validate ---
  el.validateBtn.addEventListener("click", () => {
    autoApplyForm();
    const err = validatePuzzle(formToPuzzle());
    if (err) setStatus(`Validation failed: ${err}`, "err");
    else setStatus("Puzzle is valid", "ok");
  });

  // --- Copy FEN ---
  el.copyFenBtn.addEventListener("click", () => {
    const fen = el.fenInput.value.trim();
    if (!fen) return;
    navigator.clipboard.writeText(fen).then(() => {
      setStatus("FEN copied", "ok");
    });
  });

  // --- CRUD ---
  el.newBtn.addEventListener("click", () => {
    autoApplyForm();
    const diff = state.pool === "easy" ? 1 : state.pool === "medium" ? 3 : 5;
    const p = {
      id: nextId(),
      fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1",
      solution: ["e7e5"],
      themes: ["opening"],
      difficulty: diff,
      description: "New puzzle",
      source: "local",
    };
    currentPool().push(p);
    state.selectedIndex = currentPool().length - 1;
    state.previewStep = 0;
    state.selectedSquare = null;
    state.legalSquares = [];
    puzzleToForm(p);
    renderList();
    renderBoard();
    markDirty();
    setStatus("Created (unsaved)", "dirty");
  });

  el.duplicateBtn.addEventListener("click", () => {
    autoApplyForm();
    const src = getSelected();
    if (!src) { setStatus("Nothing selected", "err"); return; }
    const copy = { ...src, id:nextId() };
    currentPool().push(copy);
    state.selectedIndex = currentPool().length - 1;
    state.previewStep = 0;
    state.selectedSquare = null;
    state.legalSquares = [];
    puzzleToForm(copy);
    renderList();
    renderBoard();
    markDirty();
    setStatus("Duplicated (unsaved)", "dirty");
  });

  el.deleteBtn.addEventListener("click", () => {
    const target = getSelected();
    if (!target) return;
    if (!confirm(`Delete "${target.id}"?`)) return;
    currentPool().splice(state.selectedIndex, 1);
    state.selectedIndex = Math.max(0, Math.min(state.selectedIndex, currentPool().length - 1));
    state.previewStep = 0;
    state.selectedSquare = null;
    state.legalSquares = [];
    if (currentPool().length > 0) puzzleToForm(currentPool()[state.selectedIndex]);
    else {
      state.selectedIndex = -1;
      el.puzzleTitle.textContent = "No puzzle selected";
      el.boardMeta.textContent = "No puzzle selected.";
    }
    renderList();
    renderBoard();
    markDirty();
  });

  // --- Save / Reload ---
  el.savePoolBtn.addEventListener("click", async () => {
    autoApplyForm();
    try { await savePool(); }
    catch (err) { setStatus(`Save failed: ${err.message}`, "err"); }
  });

  el.reloadBtn.addEventListener("click", async () => {
    if (state.dirty && !confirm("Discard unsaved changes and reload from disk?")) return;
    try {
      const res = await fetch(`/api/pool/${state.pool}`);
      const data = await res.json();
      state.pools[state.pool] = data.puzzles || [];
      state.selectedIndex = currentPool().length ? 0 : -1;
      state.previewStep = 0;
      state.selectedSquare = null;
      state.legalSquares = [];
      if (state.selectedIndex >= 0) puzzleToForm(currentPool()[state.selectedIndex]);
      renderList();
      renderBoard();
      clearDirty(`Reloaded ${state.pool}`);
    } catch (err) {
      setStatus(`Reload failed: ${err.message}`, "err");
    }
  });

  // --- Keyboard shortcuts ---
  document.addEventListener("keydown", e => {
    const tag = document.activeElement?.tagName;
    const inInput = tag === "INPUT" || tag === "TEXTAREA";

    // Ctrl+S — save (always)
    if (e.ctrlKey && e.key === "s") {
      e.preventDefault();
      autoApplyForm();
      savePool().catch(err => setStatus(`Save failed: ${err.message}`, "err"));
      return;
    }

    if (inInput) return; // don't steal arrow keys etc. while typing

    switch (e.key) {
      case "ArrowLeft":
        state.previewStep = Math.max(0, state.previewStep - 1);
        state.selectedSquare = null; state.legalSquares = [];
        renderBoard(); break;

      case "ArrowRight": {
        const moves = parseSolution(el.solutionInput.value);
        state.previewStep = Math.min(moves.length, state.previewStep + 1);
        state.selectedSquare = null; state.legalSquares = [];
        renderBoard(); break;
      }

      case "f": case "F":
        state.boardFlipped = !state.boardFlipped;
        renderBoard(); break;

      case "r": case "R":
        toggleRecordMode(); break;

      case "Escape":
        if (state.selectedSquare) {
          state.selectedSquare = null; state.legalSquares = [];
          renderBoard();
        } else if (state.recordMode) {
          toggleRecordMode();
        }
        break;
    }
  });
}

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------
(async function init() {
  initEl();
  bindEvents();
  try {
    await loadState();
  } catch (err) {
    setStatus(`Load failed: ${err.message}`, "err");
    el.boardMeta.textContent = "Could not connect to server.";
  }
})();
