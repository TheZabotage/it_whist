// ============================================================
// Card Canvas Hook
// Spawns bouncing, spinning, fading playing cards on click.
// Attach to a canvas element with phx-hook="CardCanvas"
// ============================================================

// --- Types ---

interface Frame {
  x: number;
  y: number;
  w: number;
  h: number;
}

// --- Particle Class ---

class Particle {
  private x: number;
  private y: number;
  private sx: number;
  private sy: number;
  private frame: Frame;

  // Rotation
  private rotation: number;  // spin speed per frame
  private angle: number;     // current angle in radians

  // Fade
  private opacity: number;

  // Bounce counter
  private bounces: number;

  constructor(x: number, y: number, sx: number, sy: number, frame: Frame) {
    this.x = x;
    this.y = y;
    this.sx = sx;
    this.sy = sy;
    this.frame = frame;

    // Random spin direction and speed — try 0.05 for slow, 0.3 for fast
    this.rotation = (Math.random() - 0.5) * 0.2;
    this.angle = 0;

    this.opacity = 1.0;
    this.bounces = 0;
  }

  update(
    ctx: CanvasRenderingContext2D,
    canvas: HTMLCanvasElement,
    image: HTMLImageElement,
    dpr: number
  ): boolean {
    // ---- Size ----
    // Scale relative to original card size. 1.0 = full size, 0.3 = 30%
    const scale = 0.35;

    const hw = (this.frame.w * dpr * scale) / 2;
    const hh = (this.frame.h * dpr * scale) / 2;

    // ---- Movement ----
    this.x += this.sx;
    this.y += this.sy;

    // Remove particle if it flies off the left or right edge
    if (this.x < -hw || this.x > canvas.width + hw) return false;

    // ---- Bounce ----
    if (this.y > canvas.height - hh) {
      this.y = canvas.height - hh;

      // Energy retained on bounce — 0.95 = super bouncy, 0.5 = dead drop
      this.sy = -this.sy * 0.85;

      // Slow horizontal movement slightly on bounce for realism
      this.sx *= 0.9;

      this.bounces++;

      // Remove after this many bounces — increase for longer life
      if (this.bounces > 3) return false;
    }

    // ---- Gravity ----
    // Higher = heavier. Try 0.4 for floaty, 2.0 for heavy
    this.sy += 0.98;

    // ---- Fade ----
    // Decreases opacity each frame. Lower = slower fade
    this.opacity -= 0.005;
    if (this.opacity <= 0) return false;

    // ---- Draw ----
    ctx.save();

    // Move origin to card center so rotation works correctly
    ctx.translate(this.x, this.y);
    ctx.rotate(this.angle);
    ctx.globalAlpha = this.opacity;

    // DO NOT CAHNGE THIS
    ctx.drawImage(
      image,
      this.frame.x,                     // source x on spritesheet
      this.frame.y,                     // source y on spritesheet
      this.frame.w,                     // source width
      this.frame.h,                     // source height
      -hw,                              // dest x (offset from center)
      -hh,                              // dest y (offset from center)
      this.frame.w * dpr * scale,       // dest width
      this.frame.h * dpr * scale        // dest height
    );

    ctx.restore();

    // ---- Spin ----
    // Advance angle for next frame
    this.angle += this.rotation;

    return true;
  }
}

// --- Helper: load image ---

function loadImage(src: string): Promise<HTMLImageElement> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.src = src;
  });
}

// --- Helper: load and parse XML texture atlas ---

async function loadAtlas(src: string): Promise<Record<string, Frame>> {
  const res = await fetch(src);
  const text = await res.text();
  const xml = new DOMParser().parseFromString(text, "text/xml");

  const atlas: Record<string, Frame> = {};

  xml.querySelectorAll("SubTexture").forEach((node) => {
    atlas[node.getAttribute("name")!] = {
      x: Number(node.getAttribute("x")),
      y: Number(node.getAttribute("y")),
      w: Number(node.getAttribute("width")),
      h: Number(node.getAttribute("height")),
    };
  });

  return atlas;
}

// --- Hook ---

export const CardCanvas = {
  async mounted() {
    const canvas = this.el as HTMLCanvasElement;
    const dpr = window.devicePixelRatio;

    // Fill the full viewport
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    canvas.style.width = "100%";
    canvas.style.height = "100%";

    const ctx = canvas.getContext("2d")!;
    const particles: Particle[] = [];

    // Load spritesheet and atlas in parallel
    const [image, atlas] = await Promise.all([
      loadImage("/images/playingCards.png"),
      loadAtlas("/images/playingCards.xml"),
    ]);

    const cardKeys = Object.keys(atlas);

    // ---- Click handler ----
    window.addEventListener("click", (e) => {
      const x = e.clientX * dpr;
      const y = e.clientY * dpr;

      // Cap total particles to avoid performance issues
      if (particles.length > 150) return;

      // Spawn between 3 and 6 cards per click
      const count = Math.floor(Math.random() * 8) + 4;

      for (let i = 0; i < count; i++) {
        // Pick a random card from the atlas
        const key = cardKeys[Math.floor(Math.random() * cardKeys.length)];
        const frame = atlas[key];

        // Horizontal spread — try 40 for wide fan, 5 for tight burst
        const sx = (Math.random() - 0.5) * 20;

        // Upward force — more negative = shoots higher
        // Try -3.0 for very high arc, -0.8 for low lob
        const sy = (Math.random() - 1.5) * 15;

        particles.push(new Particle(x, y, sx, sy, frame));
      }
    },{ capture: true });

    // ---- Animation loop ----
    const animate = () => {
      ctx.clearRect(0, 0, canvas.width, canvas.height);

      // Iterate backwards so splicing doesn't skip elements
      for (let i = particles.length - 1; i >= 0; i--) {
        const alive = particles[i].update(ctx, canvas, image, dpr);
        if (!alive) particles.splice(i, 1);
      }

      requestAnimationFrame(animate);
    };

    animate();
  },
};