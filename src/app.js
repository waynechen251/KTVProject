const S = {
  songs: [],
  queue: [],
  currentIndex: -1,
  mode: "instrumental",
  masterVolume: 1,
};

const mv = document.getElementById("mv");
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
const btnSkip = document.getElementById("btnSkip");
let hls = null;
let isInteracted = false;

const fmt = (s) => {
  s = Math.max(0, Math.floor(s || 0));
  const m = String(Math.floor(s / 60)).padStart(2, "0");
  const ss = String(s % 60).padStart(2, "0");
  return `${m}:${ss}`;
};

function applyVolume() {
  const v = typeof S.masterVolume === "number" ? S.masterVolume : 1;
  mv.volume = v;
  if (volLabel) volLabel.textContent = `${String(Math.round(v * 100)).padStart(3, "0")}%`;
}

function applyMode() {
  const isInstrumental = S.mode === 'instrumental';
  const targetTrackName = isInstrumental ? 'audio_1' : 'audio_2';

  if (hls && hls.audioTracks.length > 0) {
    let targetTrackIndex = -1;
    hls.audioTracks.forEach((track, index) => {
      if (track.name === targetTrackName) {
        targetTrackIndex = index;
      }
    });

    if (targetTrackIndex !== -1) {
      console.log(`Switching audio track to: ${targetTrackName} (index: ${targetTrackIndex})`);
      hls.audioTrack = targetTrackIndex;
    } else {
      console.warn(`Audio track named "${targetTrackName}" not found.`);
    }
  } else if (mv.audioTracks && mv.audioTracks.length > 0) {
    for (let i = 0; i < mv.audioTracks.length; i++) {
      mv.audioTracks[i].enabled = mv.audioTracks[i].label === targetTrackName;
    }
  }

  updateModeButtons();
}

function updateModeButtons() {
  for (const id of ["mode伴奏", "mode原唱"]) {
    document.getElementById(id).classList.remove("muted");
  }
  const map = { instrumental: "mode伴奏", vocal: "mode原唱" };
  document.getElementById(map[S.mode]).classList.add("muted");
}

function loadSong(song) {
  const hlsUrl = song.rootUrl + song.hlsUrl;

  if (hls) {
    hls.destroy();
    hls = null;
  }

  if (Hls.isSupported()) {
    hls = new Hls();
    hls.loadSource(hlsUrl);
    hls.attachMedia(mv);
    hls.on(Hls.Events.MANIFEST_PARSED, () => {
      mv.play();
    });
    hls.on(Hls.Events.AUDIO_TRACKS_UPDATED, () => {
      applyMode();
    });
  } else if (mv.canPlayType('application/vnd.apple.mpegurl')) {
    mv.src = hlsUrl;
    mv.addEventListener('loadedmetadata', () => {
      applyMode();
      mv.play();
    }, { once: true });
  }
  applyVolume();
}

function playSync() {
  mv.play();
  updatePlayPauseButton();
}

function pauseBoth() {
  mv.pause();
  updatePlayPauseButton();
}

function restartBoth() {
  mv.currentTime = 0;
  mv.play();
  updatePlayPauseButton();
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

function handleSeek() {
  mv.currentTime = parseFloat(seek.value) || 0;
}

function handleEnded() {
  const idx = S.currentIndex;
  if (idx === -1) return;
  S.queue.splice(idx, 1);
  if (S.queue.length === 0) {
    S.currentIndex = -1;
    pauseBoth();
    mv.src = "";
  } else {
    S.currentIndex = idx >= S.queue.length ? S.queue.length - 1 : idx;
    playCurrent();
  }
  renderQueue();
}

function playCurrent() {
  const id = S.queue[S.currentIndex];
  const song = S.songs.find((s) => s.id === id);
  if (!song) return;
  loadSong(song);
  renderQueue();
}

function enqueue(id) {
  if (!isInteracted) {
    mv.play().catch(() => { });
    mv.pause();
    isInteracted = true;
  }

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
    mv.src = "";
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
    const label = `<span>${i + 1}. ${isCurrent ? "正在播放▶︎ " : ""}${s?.title || id} - ${s?.artist || ""}</span>`;
    const controls = document.createElement("span");
    if (!isCurrent) {
      const ins = document.createElement("button");
      ins.textContent = "插播";
      ins.dataset.i = String(i);
      ins.className = "insert";
      ins.onclick = (e) => insertAfterCurrent(parseInt(e.target.dataset.i, 10));
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
  const res = await fetch("config/songs.json");
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
  thead.innerHTML = `<tr><th style="text-align:left;padding:6px;border-bottom:1px solid #333">編號</th><th style="text-align:left;padding:6px;border-bottom:1px solid #333">歌手</th><th style="text-align:left;padding:6px;border-bottom:1px solid #333">歌名</th><th style="text-align:center;padding:6px;border-bottom:1px solid #333">點歌</th></tr>`;
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
      tr.innerHTML = `<td style="padding:6px;border-bottom:1px dashed #333">${s.id}</td><td style="padding:6px;border-bottom:1px dashed #333">${s.artist || ""}</td><td style="padding:6px;border-bottom:1px dashed #333">${s.title || ""}</td><td style="padding:6px;border-bottom:1px dashed #333;text-align:center"><button data-id="${s.id}">點歌</button></td>`;
      tbody.appendChild(tr);
    });
    tbody.querySelectorAll("button").forEach((b) => {
      b.onclick = () => enqueue(b.dataset.id);
    });
  }
  table.appendChild(tbody);
  panel.appendChild(table);
}

function detectMobileLayout() {
  const isMobile = window.matchMedia("(max-width: 700px)").matches;
  document.body.classList.toggle("mobile", isMobile);
}

function initEventListeners() {
  seek.addEventListener('input', handleSeek);

  const btnPlayPause = document.getElementById("btnPlayPause");
  if (btnPlayPause) {
    btnPlayPause.onclick = () => {
      if (mv.paused) {
        playSync();
      } else {
        pauseBoth();
      }
    };
  }

  btnRestart.onclick = restartBoth;
  btnSkip.onclick = () => {
    try { mv.pause(); } catch (e) { }
    handleEnded();
  };
  btnClear.onclick = () => {
    S.queue.length = 0;
    S.currentIndex = -1;
    renderQueue();
    pauseBoth();
    mv.src = "";
  };
  btnSearch.onclick = () => {
    const k = kw.value.trim().toLowerCase();
    const list = S.songs.filter((s) => (s.title + s.artist).toLowerCase().includes(k));
    renderResults(list);
  };
  document.getElementById("mode伴奏").addEventListener('click', () => {
    if (S.mode === "instrumental") return;
    S.mode = "instrumental";
    applyMode();
  });
  document.getElementById("mode原唱").addEventListener('click', () => {
    if (S.mode === "vocal") return;
    S.mode = "vocal";
    applyMode();
  });
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
  mv.addEventListener("ended", handleEnded);
  window.addEventListener("resize", detectMobileLayout);
}

function updatePlayPauseButton() {
  const btnPlayPause = document.getElementById("btnPlayPause");
  if (btnPlayPause) {
    btnPlayPause.textContent = mv.paused ? '播放' : '暫停';
  }
}

mv.addEventListener('play', updatePlayPauseButton);
mv.addEventListener('pause', updatePlayPauseButton);

requestAnimationFrame(updateUI);
detectMobileLayout();
loadDB();
initEventListeners();
updateModeButtons();