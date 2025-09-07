// ====== 基本狀態 ======
const S = {
  songs: [], // 歌曲資料庫
  queue: [], // 佇列: [songId, ...]
  currentIndex: -1, // 目前佇列索引
  mode: "instrumental", // instrumental|guide|vocal
  guideVol: 0.5, // 導唱音量
  offset: 0, // 固定為 0，不允許使用者調整
  syncing: false,
};

const mv = document.getElementById("mv");
const vocals = document.getElementById("vocals");
const backing = document.getElementById("backing");
const seek = document.getElementById("seek");
const time = document.getElementById("time");

const btnPlay = document.getElementById("btnPlay");
const btnPause = document.getElementById("btnPause");
const btnRestart = document.getElementById("btnRestart");
const btnPrev = document.getElementById("btnPrev");
const btnNext = document.getElementById("btnNext");
const btnClear = document.getElementById("btnClear");
const btnSearch = document.getElementById("btnSearch");
const kw = document.getElementById("kw");
const vocalVol = document.getElementById("vocalVol");
const offsetMs = document.getElementById("offsetMs");

// ====== 工具 ======
const fmt = (s) => {
  s = Math.max(0, Math.floor(s || 0));
  const m = String(Math.floor(s / 60)).padStart(2, "0");
  const ss = String(s % 60).padStart(2, "0");
  return `${m}:${ss}`;
};

function applyMode() {
  mv.muted = true;
  if (S.mode === "instrumental") {
    backing.muted = false;
    vocals.muted = true;
  } else if (S.mode === "guide") {
    backing.muted = true;
    vocals.muted = false;
    vocals.volume = parseFloat(vocalVol.value) * S.guideVol;
  } else if (S.mode === "vocal") {
    backing.muted = true;
    vocals.muted = false;
    vocals.volume = parseFloat(vocalVol.value);
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

  for (const id of ["mode伴奏", "mode導唱", "mode原唱"])
    document.getElementById(id).classList.remove("muted");
  const map = {
    instrumental: "mode伴奏",
    guide: "mode導唱",
    vocal: "mode原唱",
  };
  document.getElementById(map[S.mode]).classList.add("muted");
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
    // 等影片開始跑再啟人聲，避免自動播放策略被擋
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
  vocals.pause();
}

function restartBoth() {
  mv.currentTime = 0;
  backing.currentTime = mv.currentTime;
  vocals.currentTime = mv.currentTime;
  playSync();
}

// 時基同步：定期校正人聲到影片
function tickSync() {
  if (S.syncing) return;
  S.syncing = true;
  // 改用絕對同播時間（offset 固定 0）
  const drift = vocals.currentTime - mv.currentTime;
  // 閾值從 80ms 調小為 50ms，減少大幅跳動造成的聽感不連續
  if (Math.abs(drift) > 0.05) {
    // 超過50ms就糾正
    backing.currentTime = mv.currentTime;
    vocals.currentTime = mv.currentTime;
  }
  S.syncing = false;
}

// 進度條與時間
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

// 綁事件
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

// 控制鍵
btnPlay.onclick = playSync;
btnPause.onclick = pauseBoth;
btnRestart.onclick = restartBoth;
document.getElementById("mode伴奏").onclick = () => {
  S.mode = "instrumental";
  applyMode();
};
document.getElementById("mode導唱").onclick = () => {
  S.mode = "guide";
  applyMode();
};
document.getElementById("mode原唱").onclick = () => {
  S.mode = "vocal";
  applyMode();
};

// 佇列控制
btnPrev.onclick = () => {
  if (S.currentIndex > 0) {
    S.currentIndex--;
    playCurrent();
  }
};
btnNext.onclick = () => {
  if (S.currentIndex < S.queue.length - 1) {
    S.currentIndex++;
    playCurrent();
  }
};
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

function renderQueue() {
  const box = document.getElementById("queue");
  box.innerHTML = "";
  S.queue.forEach((id, i) => {
    const s = S.songs.find((x) => x.id === id);
    const li = document.createElement("li");
    li.innerHTML = `<span>${i === S.currentIndex ? "▶︎ " : ""}${
      s?.title || id
    } - ${s?.artist || ""}</span>
      <span>
        <button data-i="${i}" class="go">播放</button>
        <button data-i="${i}" class="del">刪除</button>
      </span>`;
    box.appendChild(li);
  });
  box.querySelectorAll(".go").forEach(
    (b) =>
      (b.onclick = (e) => {
        S.currentIndex = parseInt(e.target.dataset.i, 10);
        playCurrent();
      })
  );
  box.querySelectorAll(".del").forEach(
    (b) =>
      (b.onclick = (e) => {
        removeAt(parseInt(e.target.dataset.i, 10));
      })
  );
}

// 搜尋與點歌
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
    // 綁定按鈕事件
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

// 自動播下一首
mv.addEventListener("ended", () => {
  const idx = S.currentIndex;
  if (idx === -1) return;

  // 從佇列移除當前曲目
  S.queue.splice(idx, 1);

  if (S.queue.length === 0) {
    // 沒有剩餘曲目：重設狀態、暫停、並隱藏舞台
    S.currentIndex = -1;
    pauseBoth();
  } else {
    // 若移除後仍有曲目，確保 currentIndex 在範圍內，並播放該曲（splice 後下一首會位於原 idx）
    if (idx >= S.queue.length) S.currentIndex = S.queue.length - 1;
    else S.currentIndex = idx;
    playCurrent();
  }
  renderQueue();
});

// 啟動
loadDB();
