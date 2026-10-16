const flat = (a, b) => Math.hypot(a[0] - b[0], a[2] - b[2]);

// Same diagonal as shared/drive/terrain.js and CraterPhysics.lua, in source X/Z.
function heightAt(terrain, x, z) {
 const {size, n, heights} = terrain || {};
 if (!Number.isInteger(n) || n < 1 || !(size > 0) || heights?.length !== (n + 1) ** 2) return null;
 const gx = (x + size / 2) * n / size, gz = (z + size / 2) * n / size;
 if (gx < 0 || gz < 0 || gx > n || gz > n) return null;
 const ix = Math.min(n - 1, Math.floor(gx)), iz = Math.min(n - 1, Math.floor(gz));
 const u = gx - ix, v = gz - iz, at = (i, j) => heights[i * (n + 1) + j];
 const h = u >= v
  ? at(ix, iz) * (1 - u) + at(ix + 1, iz) * (u - v) + at(ix + 1, iz + 1) * v
  : at(ix, iz) * (1 - v) + at(ix, iz + 1) * (v - u) + at(ix + 1, iz + 1) * u;
 return Number.isFinite(h) ? h : null;
}

// Split exactly at cell boundaries AND triangle diagonals. Regular coarse
// samples can miss a short steep triangle between two equally high samples.
function profileParameters(from, to, terrain) {
 const step = terrain.size / terrain.n, parameters = [0, 1];
 const cuts = (a, b, offset, spacing) => {
  if (Math.abs(b - a) < 1e-12) return;
  const lo = Math.min(a, b), hi = Math.max(a, b);
  for (let k = Math.ceil((lo - offset) / spacing); k <= Math.floor((hi - offset) / spacing); k++) {
   const t = (offset + k * spacing - a) / (b - a);
   if (t > 0 && t < 1) parameters.push(t);
  }
 };
 cuts(from[0], to[0], -terrain.size / 2, step);
 cuts(from[2], to[2], -terrain.size / 2, step);
 cuts(from[0] - from[2], to[0] - to[2], 0, step);
 return parameters.sort((a, b) => a - b).filter((t, i, all) => !i || t - all[i - 1] > 1e-10);
}

function evaluateTerrainConnector(from, to, terrain, {maxSlopeDeg = 15, maxNodeHeightError = 1e-4} = {}) {
 if (![from, to].every(p => Array.isArray(p) && p.length >= 3 && p.every(Number.isFinite))) throw Error('Finite source-coordinate positions required');
 if (!(maxSlopeDeg > 0 && maxSlopeDeg < 90) || !(maxNodeHeightError >= 0)) throw Error('Invalid connector limits');
 const startHeight = heightAt(terrain, from[0], from[2]), endHeight = heightAt(terrain, to[0], to[2]);
 if (startHeight === null || endHeight === null) return {reachable: false, reason: 'missing-heightfield', distance: flat(from, to)};
 const distance = flat(from, to), profile = profileParameters(from, to, terrain).map(t => {
  const x = from[0] + (to[0] - from[0]) * t, z = from[2] + (to[2] - from[2]) * t;
  return {t, x, z, height: heightAt(terrain, x, z)};
 });
 let maxSlope = 0;
 for (let i = 1; i < profile.length; i++) {
  const previous = profile[i - 1], current = profile[i];
  if (current.height === null) return {reachable: false, reason: 'outside-heightfield', distance};
  const run = (current.t - previous.t) * distance;
  if (run > 1e-10) maxSlope = Math.max(maxSlope, Math.atan2(Math.abs(current.height - previous.height), run) * 180 / Math.PI);
 }
 const nodeHeightError = Math.abs(endHeight - to[1]);
 const reason = nodeHeightError > maxNodeHeightError ? 'node-not-on-terrain' : maxSlope > maxSlopeDeg + 1e-8 ? 'steep-terrain' : 'terrain-profile-pass';
 return {reachable: reason === 'terrain-profile-pass', reason, distance, maxSlopeDeg: maxSlope, nodeHeightError, startHeight, endHeight, profile};
}

function findRoadConnector(from, layout, options = {}) {
 const candidates = Object.entries(layout.nav.nodes).map(([id, pos]) => ({id, pos, distance: flat(from, pos)}))
  .sort((a, b) => a.distance - b.distance || a.id.localeCompare(b.id));
 const rejected = [];
 for (const candidate of candidates) {
  if (candidate.distance > (options.maxDistance ?? Infinity)) break;
  const profile = evaluateTerrainConnector(from, candidate.pos, layout.terrain, options);
  if (profile.reachable) return {...candidate, profile, rejected};
  rejected.push({id: candidate.id, reason: profile.reason, maxSlopeDeg: profile.maxSlopeDeg});
 }
 return null;
}

module.exports = {heightAt, evaluateTerrainConnector, findRoadConnector};
