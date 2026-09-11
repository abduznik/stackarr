const REPO = "abduznik/stackarr";
const RELEASES_API = `https://api.github.com/repos/${REPO}/releases/latest`;
const RELEASES_PAGE = `https://github.com/${REPO}/releases/latest`;

function detectPlatform() {
  const ua = navigator.userAgent;
  if (/Android/i.test(ua)) return "android";
  if (/Windows/i.test(ua)) return "windows";
  if (/Macintosh|Mac OS X/i.test(ua)) return "mac";
  if (/Linux/i.test(ua)) return "linux";
  if (/iPhone|iPad|iPod/i.test(ua)) return "ios";
  return "unknown";
}

function pickAsset(assets, platform) {
  const byExt = (ext) => assets.find((a) => a.name.toLowerCase().endsWith(ext));
  if (platform === "android") return byExt(".apk");
  if (platform === "windows") return byExt("-windows.zip") || byExt(".zip");
  return null;
}

function platformLabel(platform) {
  return {
    android: "Android",
    windows: "Windows",
    mac: "macOS",
    linux: "Linux",
    ios: "iOS",
    unknown: "your platform",
  }[platform];
}

async function wireDownloadButtons() {
  const buttons = document.querySelectorAll("[data-download-button]");
  const metas = document.querySelectorAll("[data-download-meta]");
  if (buttons.length === 0) return;

  const platform = detectPlatform();
  const label = platformLabel(platform);

  buttons.forEach((btn) => {
    const span = btn.querySelector("[data-btn-label]");
    if (span) span.textContent = `Download for ${label}`;
  });

  try {
    const res = await fetch(RELEASES_API, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!res.ok) throw new Error(`GitHub API responded ${res.status}`);
    const release = await res.json();
    const tag = release.tag_name || "latest";
    const asset = pickAsset(release.assets || [], platform);

    if (asset) {
      buttons.forEach((btn) => {
        btn.href = asset.browser_download_url;
        btn.removeAttribute("aria-disabled");
      });
      const sizeMb = (asset.size / (1024 * 1024)).toFixed(1);
      metas.forEach((el) => {
        el.classList.remove("error");
        el.innerHTML = `${tag} &middot; ${sizeMb} MB &middot; <a href="${RELEASES_PAGE}" target="_blank" rel="noopener">all downloads</a>`;
      });
    } else {
      // Platform has no direct build yet (macOS/Linux/iOS) — send to the releases page.
      buttons.forEach((btn) => {
        btn.href = RELEASES_PAGE;
        btn.target = "_blank";
        btn.rel = "noopener";
      });
      metas.forEach((el) => {
        el.classList.remove("error");
        el.innerHTML = `${label} build not published yet &middot; <a href="${RELEASES_PAGE}" target="_blank" rel="noopener">see ${tag} on GitHub</a>`;
      });
    }
  } catch (err) {
    buttons.forEach((btn) => {
      btn.href = RELEASES_PAGE;
      btn.target = "_blank";
      btn.rel = "noopener";
    });
    metas.forEach((el) => {
      el.classList.add("error");
      el.textContent = "Couldn't reach GitHub to find the latest build — opening the releases page instead.";
    });
  }
}

document.addEventListener("DOMContentLoaded", wireDownloadButtons);
