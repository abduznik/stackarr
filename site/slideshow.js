function wireSlideshow() {
  const slides = document.querySelectorAll("[data-slide]");
  const dots = document.querySelectorAll("[data-slideshow-dots] .dot-btn");
  if (slides.length === 0) return;

  const prefersReducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let current = 0;

  function show(index) {
    current = index;
    slides.forEach((img, i) => img.classList.toggle("active", i === index));
    dots.forEach((dot, i) => dot.classList.toggle("active", i === index));
  }

  dots.forEach((dot, i) => {
    dot.addEventListener("click", () => show(i));
  });

  if (prefersReducedMotion) return;

  setInterval(() => {
    show((current + 1) % slides.length);
  }, 3800);
}

document.addEventListener("DOMContentLoaded", wireSlideshow);
