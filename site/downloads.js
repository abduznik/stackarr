const REPO = "abduznik/stackarr";
const RELEASES_LIST_API = `https://api.github.com/repos/${REPO}/releases`;

function assetPlatform(asset) {
  const name = asset.name.toLowerCase();
  if (name.endsWith(".apk")) return { name: "Android", icon: "android" };
  if (name.endsWith("-windows.zip") || name.endsWith(".zip")) return { name: "Windows", icon: "windows" };
  if (name.endsWith(".dmg")) return { name: "macOS", icon: "mac" };
  if (name.endsWith(".appimage")) return { name: "Linux", icon: "linux" };
  return { name: asset.name, icon: "file" };
}

function formatDate(iso) {
  return new Date(iso).toLocaleDateString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
  });
}

function formatSize(bytes) {
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

const ICONS = {
  android: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="5" y="2" width="14" height="20" rx="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>',
  windows: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><rect x="3" y="4" width="18" height="12" rx="1"/><line x1="8" y1="20" x2="16" y2="20"/><line x1="12" y1="16" x2="12" y2="20"/></svg>',
  mac: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M16 4.5c-1.2-1.3-3.1-1.6-4.4-.4-1.1-1.1-3-1.4-4.4-.2C5.6 5.3 5.2 8 6.6 10.3c1.2 2 4 5.3 5.4 6.7 1.4-1.4 4.2-4.7 5.4-6.7C18.8 8 18.2 5.5 16 4.5Z"/></svg>',
  linux: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><circle cx="12" cy="12" r="9"/></svg>',
  file: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6"/></svg>',
};

function releaseCard(release, isLatest) {
  const assets = release.assets || [];
  const assetRows = assets
    .map((asset) => {
      const { name, icon } = assetPlatform(asset);
      return `
        <a class="asset-row" href="${asset.browser_download_url}">
          <span class="asset-icon">${ICONS[icon] || ICONS.file}</span>
          <span class="asset-info">
            <span class="asset-name">${name}</span>
            <span class="asset-file">${asset.name}</span>
          </span>
          <span class="asset-size">${formatSize(asset.size)}</span>
          <span class="asset-dl-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>
          </span>
        </a>`;
    })
    .join("");

  return `
    <article class="release-card ${isLatest ? "latest" : ""}">
      <div class="release-head">
        <div class="release-title">
          <span class="release-tag">${release.tag_name}</span>
          ${isLatest ? '<span class="latest-pill">Latest</span>' : ""}
          ${release.prerelease ? '<span class="pre-pill">Pre-release</span>' : ""}
        </div>
        <span class="release-date">${formatDate(release.published_at)}</span>
      </div>
      ${release.body ? `<div class="release-notes">${renderNotes(release.body)}</div>` : ""}
      <div class="asset-list">
        ${assetRows || '<p class="no-assets">No downloadable builds attached to this release.</p>'}
      </div>
      <a class="release-gh-link" href="${release.html_url}" target="_blank" rel="noopener">View on GitHub &rarr;</a>
    </article>`;
}

function renderNotes(body) {
  // GitHub release bodies are markdown; render a light, safe subset (bold,
  // links, bare URLs) since we control the source but still avoid raw HTML injection.
  const escapeHtml = (s) =>
    s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

  const inline = (line) => {
    let html = escapeHtml(line);
    html = html.replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>");
    html = html.replace(/https?:\/\/[^\s<]+\/compare\/([^\s<]+)/g, (match, range) => {
      return `<a href="${match}" target="_blank" rel="noopener">${range}</a>`;
    });
    html = html.replace(
      /(https?:\/\/[^\s<]+)/g,
      '<a href="$1" target="_blank" rel="noopener">$1</a>'
    );
    return html;
  };

  return body
    .split("\n")
    .filter((line) => line.trim().length > 0)
    .slice(0, 6)
    .map((line) => `<p>${inline(line)}</p>`)
    .join("");
}

async function loadReleases() {
  const container = document.querySelector("[data-releases-list]");
  const statusEl = document.querySelector("[data-releases-status]");
  if (!container) return;

  try {
    const res = await fetch(`${RELEASES_LIST_API}?per_page=30`, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!res.ok) throw new Error(`GitHub API responded ${res.status}`);
    const releases = await res.json();

    if (!Array.isArray(releases) || releases.length === 0) {
      statusEl.textContent = "No releases published yet.";
      return;
    }

    statusEl.remove();
    container.innerHTML = releases
      .map((release, i) => releaseCard(release, i === 0))
      .join("");
  } catch (err) {
    statusEl.classList.add("error");
    statusEl.innerHTML = `Couldn't load release history from GitHub &mdash; <a href="https://github.com/${REPO}/releases" target="_blank" rel="noopener">view releases directly</a>.`;
  }
}

document.addEventListener("DOMContentLoaded", loadReleases);
