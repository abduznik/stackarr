function wireShowcase() {
  const tabs = document.querySelectorAll("[data-showcase-tab]");
  const images = document.querySelectorAll("[data-showcase-img]");
  const caption = document.querySelector("[data-showcase-caption]");
  if (tabs.length === 0) return;

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      const target = tab.getAttribute("data-showcase-tab");

      tabs.forEach((t) => t.classList.toggle("active", t === tab));
      images.forEach((img) =>
        img.classList.toggle("active", img.getAttribute("data-showcase-img") === target)
      );
      if (caption) caption.textContent = tab.getAttribute("data-caption") || "";
    });
  });
}

document.addEventListener("DOMContentLoaded", wireShowcase);
