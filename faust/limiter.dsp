declare name "limiter";
import("stdfaust.lib");

lookaheadDelay = .01;
ceiling = hslider("ceiling", 1, 0, 10, .001);
attack = hslider("attack", .01, 0, 1, .001);
hold = hslider("hold", .1, 0, 1, .001);
release = hslider("release", 1, 0, 10, .001);

process = _ : co.limiter_lad_mono(lookaheadDelay, ceiling, attack, hold, release) : _;
