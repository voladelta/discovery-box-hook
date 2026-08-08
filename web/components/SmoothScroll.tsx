import Lenis from "lenis";
import { useEffect } from "react";

export function SmoothScroll() {
  useEffect(() => {
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    let lenis: Lenis | null = null;

    const configure = () => {
      lenis?.destroy();
      lenis = null;

      if (reducedMotion.matches) return;

      lenis = new Lenis({
        autoRaf: true,
        anchors: true,
        lerp: 0.09,
        smoothWheel: true,
        syncTouch: false,
        wheelMultiplier: 0.88,
        overscroll: true,
        stopInertiaOnNavigate: true,
      });
    };

    configure();
    reducedMotion.addEventListener("change", configure);

    return () => {
      reducedMotion.removeEventListener("change", configure);
      lenis?.destroy();
    };
  }, []);

  return null;
}
