// ====== 基本狀態 ======
const S = {
  songs: [], // 歌曲資料庫
  queue: [], // 佇列: [songId, ...]
  currentIndex: -1, // 目前佇列索引
  mode: "instrumental", // instrumental|vocal
  offset: 0, // 固定為 0，不允許使用者調整
  syncing: false,
  masterVolume: 1, // 總音量（0..1）
};

const mv = document.getElementById("mv");
const vocals = document.getElementById("vocals");
const backing = document.getElementById("backing");
const seek = document.getElementById("seek");
const time = document.getElementById("time");
const masterVol = document.getElementById("masterVol");
const volLabel = document.getElementById("volLabel");

const btnPlay = document.getElementById("btnPlay");
const btnPause = document.getElementById("btnPause");
const btnRestart = document.getElementById("btnRestart");
const btnClear = document.getElementById("btnClear");
const btnSearch = document.getElementById("btnSearch");
const kw = document.getElementById("kw");
const offsetMs = document.getElementById("offsetMs");
const btnSkip = document.getElementById("btnSkip");

// ====== 工具 ======
const fmt = (s) => {
  s = Math.max(0, Math.floor(s || 0));
  const m = String(Math.floor(s / 60)).padStart(2, "0");
  const ss = String(s % 60).padStart(2, "0");
  return `${m}:${ss}`;
};
function applyVolume() {
  const v = typeof S.masterVolume === "number" ? S.masterVolume : 1;
  try {
    backing.volume = v;
    vocals.volume = v;
    mv.volume = v;
  } catch (e) {
    console.error(e);
  }
  if (volLabel)
    volLabel.textContent = `${String(Math.round(v * 100)).padStart(3, "0")}%`;
}

function applyMode() {
  mv.muted = true;
  if (S.mode === "instrumental") {
    backing.muted = false;
    vocals.muted = true;
  } else if (S.mode === "vocal") {
    backing.muted = true;
    vocals.muted = false;
  } else {
    console.warn("未知的模式", S.mode);
  }

  if (!mv.paused) {
    try {
      if (Math.abs((vocals.currentTime || 0) - (mv.currentTime || 0)) > 0.05) {
        backing.currentTime = mv.currentTime;
        vocals.currentTime = mv.currentTime;
      }
      backing.play().catch(() => {});
      vocals.play().catch(() => {});
    } catch (e) {
      console.error(e);
    }
  }

  for (const id of ["mode伴奏", "mode原唱"])
    document.getElementById(id).classList.remove("muted");
  const map = {
    instrumental: "mode伴奏",
    vocal: "mode原唱",
  };
  document.getElementById(map[S.mode]).classList.add("muted");

  applyVolume();
}

function loadSong(song) {
  mv.src = song.videoUrl;
  backing.src = song.backingUrl;
  vocals.src = song.vocalUrl;
  S.offset = 0;
  mv.currentTime = 0;
  backing.currentTime = 0;
  vocals.currentTime = 0;
  applyMode();
}

async function playSync() {
  try {
    await mv.play();
    const startVocals = () => vocals.play().catch(() => {});
    const startBacking = () => backing.play().catch(() => {});
    if (mv.readyState >= 2) {
      startVocals();
      startBacking();
    } else {
      mv.addEventListener("playing", startVocals, { once: true });
      mv.addEventListener("playing", startBacking, { once: true });
    }
  } catch (e) {
    console.error(e);
  }
}

function pauseBoth() {
  mv.pause();
  backing.pause();
  vocals.pause();
}

function restartBoth() {
  mv.currentTime = 0;
  backing.currentTime = mv.currentTime;
  vocals.currentTime = mv.currentTime;
  playSync();
}

function tickSync() {
  if (S.syncing) return;
  S.syncing = true;
  const drift = vocals.currentTime - mv.currentTime;
  if (Math.abs(drift) > 0.05) {
    backing.currentTime = mv.currentTime;
    vocals.currentTime = mv.currentTime;
  }
  S.syncing = false;
}

function updateUI() {
  if (mv.duration && isFinite(mv.duration)) {
    seek.max = mv.duration;
    seek.value = mv.currentTime || 0;
    time.textContent = `${fmt(mv.currentTime)} / ${fmt(mv.duration)}`;
  } else {
    time.textContent = `00:00 / 00:00`;
  }
  requestAnimationFrame(updateUI);
}
requestAnimationFrame(updateUI);

mv.addEventListener("timeupdate", tickSync);
mv.addEventListener("seeking", () => {
  backing.currentTime = mv.currentTime;
  vocals.currentTime = mv.currentTime;
});

seek.addEventListener("input", () => {
  mv.currentTime = parseFloat(seek.value) || 0;
  backing.currentTime = mv.currentTime;
  vocals.currentTime = mv.currentTime;
});

btnPlay.onclick = playSync;
btnPause.onclick = pauseBoth;
btnRestart.onclick = restartBoth;
document.getElementById("mode伴奏").onclick = () => {
  S.mode = "instrumental";
  applyMode();
};
document.getElementById("mode原唱").onclick = () => {
  S.mode = "vocal";
  applyMode();
};

btnSkip.onclick = () => {
  try {
    mv.pause();
  } catch (e) {}
  handleEnded();
};

function handleEnded() {
  const idx = S.currentIndex;
  if (idx === -1) return;

  S.queue.splice(idx, 1);

  if (S.queue.length === 0) {
    S.currentIndex = -1;
    pauseBoth();

    try {
      mv.src = "";
      mv.load();
      backing.src = "";
      backing.load();
      vocals.src = "";
      vocals.load();
    } catch (e) {
      console.error("清除媒體來源失敗", e);
    }
  } else {
    if (idx >= S.queue.length) S.currentIndex = S.queue.length - 1;
    else S.currentIndex = idx;
    playCurrent();
  }
  renderQueue();
}

mv.addEventListener("ended", handleEnded);

btnClear.onclick = () => {
  S.queue.length = 0;
  S.currentIndex = -1;
  renderQueue();
  pauseBoth();
};

function playCurrent() {
  const id = S.queue[S.currentIndex];
  const song = S.songs.find((s) => s.id === id);
  if (!song) return;
  loadSong(song);
  playSync();
  renderQueue();
}

function enqueue(id) {
  S.queue.push(id);
  if (S.currentIndex === -1) {
    S.currentIndex = 0;
    playCurrent();
  }
  renderQueue();
}

function removeAt(idx) {
  S.queue.splice(idx, 1);
  if (idx < S.currentIndex) S.currentIndex--;
  if (S.queue.length === 0) {
    S.currentIndex = -1;
    pauseBoth();
  }
  renderQueue();
}

function moveTo(oldIdx, targetPos) {
  if (oldIdx < 0 || oldIdx >= S.queue.length) return;
  const id = S.queue[oldIdx];
  const currentSongId = S.currentIndex !== -1 ? S.queue[S.currentIndex] : null;
  S.queue.splice(oldIdx, 1);
  const pos = Math.max(0, Math.min(targetPos, S.queue.length));
  S.queue.splice(pos, 0, id);
  if (currentSongId) {
    S.currentIndex = S.queue.findIndex((x) => x === currentSongId);
    if (S.currentIndex === -1) S.currentIndex = 0;
  }
  renderQueue();
}

function insertAfterCurrent(oldIdx) {
  const target = S.currentIndex === -1 ? 0 : S.currentIndex + 1;
  moveTo(oldIdx, target);
}

function renderQueue() {
  const box = document.getElementById("queue");
  box.innerHTML = "";
  const queueCountEl = document.getElementById("queueCount");
  const waiting = Math.max(0, S.queue.length - (S.currentIndex === -1 ? 0 : 1));
  if (queueCountEl) queueCountEl.textContent = String(waiting);

  S.queue.forEach((id, i) => {
    const s = S.songs.find((x) => x.id === id);
    const li = document.createElement("li");
    const isCurrent = i === S.currentIndex;
    const label = `<span>${i + 1}. ${isCurrent ? "正在撥放▶︎ " : ""}${
      s?.title || id
    } - ${s?.artist || ""}</span>`;

    const controls = document.createElement("span");
    if (!isCurrent) {
      const ins = document.createElement("button");
      ins.textContent = "插播";
      ins.dataset.i = String(i);
      ins.className = "insert";
      ins.onclick = (e) => {
        insertAfterCurrent(parseInt(e.target.dataset.i, 10));
      };
      controls.appendChild(ins);
    }
    const del = document.createElement("button");
    del.textContent = "刪除";
    del.dataset.i = String(i);
    del.className = "del";
    del.onclick = (e) => removeAt(parseInt(e.target.dataset.i, 10));
    controls.appendChild(del);

    li.innerHTML = label;
    li.appendChild(controls);
    box.appendChild(li);
  });
}

async function loadDB() {
  const res = await fetch("songs.json");
  S.songs = await res.json();
  renderResults(S.songs);
}
function renderResults(list) {
  const panel = document.getElementById("results");
  panel.innerHTML = "";

  const table = document.createElement("table");
  table.style.width = "100%";
  table.style.borderCollapse = "collapse";

  const thead = document.createElement("thead");
  thead.innerHTML = `<tr>
    <th style="text-align:left;padding:6px;border-bottom:1px solid #333">編號</th>
    <th style="text-align:left;padding:6px;border-bottom:1px solid #333">歌手</th>
    <th style="text-align:left;padding:6px;border-bottom:1px solid #333">歌名</th>
    <th style="text-align:center;padding:6px;border-bottom:1px solid #333">點歌</th>
  </tr>`;
  table.appendChild(thead);

  const tbody = document.createElement("tbody");

  if (!list || list.length === 0) {
    const tr = document.createElement("tr");
    const td = document.createElement("td");
    td.colSpan = 4;
    td.textContent = "沒有符合的歌曲";
    td.style.padding = "8px";
    tr.appendChild(td);
    tbody.appendChild(tr);
  } else {
    list.forEach((s) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `<td style="padding:6px;border-bottom:1px dashed #333">${
        s.id
      }</td>
        <td style="padding:6px;border-bottom:1px dashed #333">${
          s.artist || ""
        }</td>
        <td style="padding:6px;border-bottom:1px dashed #333">${
          s.title || ""
        }</td>
        <td style="padding:6px;border-bottom:1px dashed #333;text-align:center">
          <button data-id="${s.id}">點歌</button>
        </td>`;
      tbody.appendChild(tr);
    });
    tbody.querySelectorAll("button").forEach((b) => {
      b.onclick = () => enqueue(b.dataset.id);
    });
  }

  table.appendChild(tbody);
  panel.appendChild(table);
}
btnSearch.onclick = () => {
  const k = kw.value.trim().toLowerCase();
  const list = S.songs.filter((s) =>
    (s.title + s.artist).toLowerCase().includes(k)
  );
  renderResults(list);
};

if (masterVol) {
  masterVol.addEventListener("input", (e) => {
    const v = parseFloat(e.target.value);
    if (Number.isFinite(v)) {
      S.masterVolume = v;
      applyVolume();
    }
  });
  masterVol.value = String(S.masterVolume);
  applyVolume();
}

function detectMobileLayout() {
  const ua = navigator.userAgent || "";
  const isMobileUA = /Mobi|Android|iPhone|iPad|iPod|Windows Phone/i.test(ua);
  const isTouch =
    "ontouchstart" in window ||
    (navigator.maxTouchPoints && navigator.maxTouchPoints > 0) ||
    (window.matchMedia && window.matchMedia("(pointer:coarse)").matches);
  const isMobile = isMobileUA || isTouch;
  document.body.classList.toggle("mobile", !!isMobile);
}
detectMobileLayout();
window.addEventListener("resize", detectMobileLayout);

loadDB();
