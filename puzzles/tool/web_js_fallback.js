// Actufree's Block Blast engine packs the board into a 64-bit bitboard, and
// JavaScript integers carry 53 bits of precision. The wasm build is the only
// correct one, so rather than ship a game that deals from wrong masks, this
// replaces Flutter's JS fallback — which it always emits and offers no way to
// suppress — with an explanation.
document.body.innerHTML =
  '<div style="font:16px/1.6 -apple-system,BlinkMacSystemFont,Segoe UI,Roboto,sans-serif;' +
  'max-width:34rem;margin:4rem auto;padding:0 1.25rem;color:#1a1c1e">' +
  '<h1 style="font-size:1.6rem;letter-spacing:-.02em">This browser cannot run Actufree</h1>' +
  '<p>The puzzles need WebAssembly with garbage collection, which this browser ' +
  'does not support. Recent versions of Chrome, Edge, Firefox and Safari all do.</p>' +
  '<p><a href="../" style="color:#6d28d9">Back to Actufree</a></p></div>';
