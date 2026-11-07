import { useEffect, useLayoutEffect, useRef } from "react";

const reducedMotion = () =>
  window.matchMedia("(prefers-reduced-motion: reduce)").matches;

const SHUFFLE_DURATION = 860;
const SOFT_EASE = "cubic-bezier(.22,.68,.2,1)";
const NO_SHADOW = "0 0 0 0 rgb(24 54 42 / 0)";
const LIFT_SHADOW = "0 24px 34px -18px rgb(24 54 42 / .32)";

const readPose = (node) => {
  const style = getComputedStyle(node);
  return {
    transform: style.transform,
    height: style.height,
    opacity: style.opacity,
    zIndex: style.zIndex,
    boxShadow: style.boxShadow === "none" ? NO_SHADOW : style.boxShadow,
  };
};

const offsetPose = (pose, x, y, rotation, scale = 1) => ({
  ...pose,
  transform: `translate(${x}px, ${y}px) ${pose.transform === "none" ? "" : pose.transform} rotate(${rotation}deg) scale(${scale})`,
});

function cardFrames(start, end, depth, direction, poses, width) {
  const height = parseFloat(poses[0].height);
  const frame = (pose, offset, extra = {}) => ({
    ...pose,
    offset,
    easing: SOFT_EASE,
    ...extra,
  });

  // Peel the front card up, cross behind the stack, then settle at the back.
  // Arc anchors use resting poses so repeated clicks cannot accumulate drift.
  if (direction > 0 && depth === 2) {
    const lifted = offsetPose(poses[0], width * 0.07, -height * 0.12, 7, 1.025);
    const crossing = offsetPose(
      poses[0],
      width * 0.025,
      -height * 0.17,
      3,
      0.99,
    );
    return [
      frame(start, 0),
      frame(lifted, 0.29, { zIndex: 4, boxShadow: LIFT_SHADOW }),
      frame(crossing, 0.46, {
        zIndex: 4,
        opacity: 0.84,
        boxShadow: LIFT_SHADOW,
      }),
      frame(crossing, 0.47, {
        zIndex: 1,
        opacity: 0.84,
        boxShadow: LIFT_SHADOW,
      }),
      frame(offsetPose(end, -width * 0.025, -height * 0.025, -1.5, 0.985), 0.8),
      frame(end, 1),
    ];
  }

  // Backwards: lift the rear card along the other side before bringing it forward.
  if (direction < 0 && depth === 0) {
    const lifted = offsetPose(
      poses[2],
      -width * 0.09,
      -height * 0.12,
      -8,
      1.025,
    );
    return [
      frame(start, 0),
      frame(lifted, 0.27, { zIndex: 1, opacity: 0.72, boxShadow: LIFT_SHADOW }),
      frame(lifted, 0.28, { zIndex: 4, opacity: 0.72, boxShadow: LIFT_SHADOW }),
      frame(offsetPose(end, width * 0.015, -height * 0.014, 1, 1.008), 0.79, {
        zIndex: 4,
        boxShadow: LIFT_SHADOW,
      }),
      frame(end, 1),
    ];
  }

  const incoming = depth === 0;
  return [
    frame(start, 0),
    frame(
      offsetPose(start, -direction * width * 0.018, height * 0.006, -direction),
      0.2,
    ),
    frame(
      offsetPose(
        end,
        direction * width * 0.012,
        -height * 0.012,
        direction * 0.8,
        1.006,
      ),
      0.78,
      {
        boxShadow: incoming ? LIFT_SHADOW : NO_SHADOW,
      },
    ),
    frame(end, 1),
  ];
}

// Snapshot the currently painted positions, including interrupted animations.
// This lets rapid clicks reverse the shuffle without jumping back to an old pose.
export function useCardShuffle(step, root) {
  const snapshot = useRef(null);
  const animations = useRef([]);
  const stop = () => {
    animations.current.forEach((animation) => animation.cancel());
    animations.current = [];
    root.current?.querySelector(".process-copy-ghost")?.replaceChildren();
    root.current
      ?.querySelector(".process-counter-outgoing")
      ?.removeAttribute("data-number");
  };
  const capture = (direction) => {
    const copy = root.current?.querySelector(".process-copy");
    const counter = root.current?.querySelector(".process-counter-current");
    const counterStyle = counter && getComputedStyle(counter);
    const outgoing = copy?.cloneNode(true);
    if (outgoing) {
      outgoing.classList.remove("process-copy-current");
      // Keep a visual-only outgoing copy; the live region contains the new step.
      Array.from(copy.children).forEach((child, index) => {
        const style = getComputedStyle(child);
        outgoing.children[index].style.transform = style.transform;
        outgoing.children[index].style.opacity = style.opacity;
      });
    }
    snapshot.current = reducedMotion()
      ? null
      : {
          direction,
          outgoing,
          counter: counter && {
            value: counter.textContent,
            transform: counterStyle.transform,
            opacity: counterStyle.opacity,
          },
          cards: Array.from(
            root.current?.querySelectorAll(".home-process-photo") || [],
            (node) => ({ node, start: readPose(node) }),
          ),
        };
    stop();
  };
  useLayoutEffect(() => {
    const previous = snapshot.current;
    snapshot.current = null;
    if (!previous || reducedMotion()) return;
    const cards = previous.cards.map((card) => ({
      ...card,
      end: readPose(card.node),
      depth: Number(card.node.dataset.depth),
      width: card.node.offsetWidth,
    }));
    const poses = Object.fromEntries(
      cards.map(({ depth, end }) => [depth, end]),
    );
    const play = (node, frames, options) => {
      if (!node?.animate) return;
      const animation = node.animate(frames, options);
      animations.current.push(animation);
      return animation;
    };
    cards.forEach(({ node, start, end, depth, width }) => {
      play(
        node,
        cardFrames(start, end, depth, previous.direction, poses, width),
        {
          duration: SHUFFLE_DURATION,
          easing: "linear",
        },
      );
    });

    const ghost = root.current.querySelector(".process-copy-ghost");
    if (ghost && previous.outgoing) {
      ghost.replaceChildren(previous.outgoing);
      const animation = play(
        previous.outgoing,
        [
          { opacity: 1, transform: "translateY(0)" },
          {
            opacity: 0,
            transform: `translateY(${-previous.direction * 14}px)`,
          },
        ],
        { duration: 170, easing: "ease-out", fill: "forwards" },
      );
      if (animation) animation.onfinish = () => previous.outgoing.remove();
      else previous.outgoing.remove();
    }
    root.current
      .querySelectorAll(".process-copy-current > *")
      .forEach((node, index) => {
        play(
          node,
          [
            {
              opacity: 0,
              transform: `translateY(${previous.direction * 22}px)`,
            },
            { opacity: 1, transform: "translateY(0)" },
          ],
          {
            duration: 440,
            delay: 140 + index * 55,
            easing: SOFT_EASE,
            fill: "backwards",
          },
        );
      });
    const counterExit = root.current.querySelector(".process-counter-outgoing");
    if (counterExit && previous.counter) {
      counterExit.dataset.number = previous.counter.value;
      const animation = play(
        counterExit,
        [
          {
            opacity: previous.counter.opacity,
            transform: previous.counter.transform,
          },
          {
            opacity: 0,
            transform: `translateY(${-previous.direction * 100}%)`,
          },
        ],
        { duration: 360, easing: SOFT_EASE, fill: "forwards" },
      );
      if (animation)
        animation.onfinish = () => {
          if (animations.current.includes(animation))
            counterExit.removeAttribute("data-number");
        };
      else counterExit.removeAttribute("data-number");
    }
    play(
      root.current.querySelector(".process-counter-current"),
      [
        { opacity: 0, transform: `translateY(${previous.direction * 100}%)` },
        { opacity: 1, transform: "translateY(0)" },
      ],
      { duration: 480, delay: 140, easing: SOFT_EASE, fill: "backwards" },
    );
  }, [step, root]);
  useEffect(() => {
    const preference = window.matchMedia("(prefers-reduced-motion: reduce)");
    const cancel = () => {
      snapshot.current = null;
      stop();
    };
    preference.addEventListener("change", cancel);
    window.addEventListener("resize", cancel);
    return () => {
      cancel();
      preference.removeEventListener("change", cancel);
      window.removeEventListener("resize", cancel);
    };
  }, []);
  return capture;
}

export function useSectionReveal(root) {
  useEffect(() => {
    const element = root.current;
    if (!element || !window.IntersectionObserver || reducedMotion()) return;
    const targets = Array.from(
      element.querySelectorAll(
        ".home-heading, .home-story, .home-benefit-column, .home-material-row, .home-material-feature, .home-audience-card, .home-plan, .home-guide, .home-faq-grid",
      ),
    );
    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.dataset.reveal = "visible";
          observer.unobserve(entry.target);
        });
      },
      { threshold: 0.08, rootMargin: "0px 0px -24px 0px" },
    );
    targets.forEach((target) => {
      if (target.getBoundingClientRect().top < window.innerHeight - 24) return;
      target.dataset.reveal = "pending";
      observer.observe(target);
    });
    const revealFocused = (event) => {
      const target = event.target.closest('[data-reveal="pending"]');
      if (target) {
        target.dataset.reveal = "visible";
        observer.unobserve(target);
      }
    };
    const revealAll = () =>
      targets.forEach((target) => {
        delete target.dataset.reveal;
      });
    const preference = window.matchMedia("(prefers-reduced-motion: reduce)");
    const onPreference = () => {
      if (preference.matches) {
        observer.disconnect();
        revealAll();
      }
    };
    element.addEventListener("focusin", revealFocused);
    preference.addEventListener("change", onPreference);
    return () => {
      observer.disconnect();
      revealAll();
      element.removeEventListener("focusin", revealFocused);
      preference.removeEventListener("change", onPreference);
    };
  }, [root]);
}
