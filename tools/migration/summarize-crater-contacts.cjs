const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const source = path.resolve(process.argv[2]);
const result = JSON.parse(fs.readFileSync(source, 'utf8'));
const paths = result.paths.map(row => {
    const contacts = row.snapshots.flatMap(snapshot => Object.values(snapshot.contacts));
    const histogram = {};
    for (const contact of contacts) histogram[contact.name] = (histogram[contact.name] || 0) + 1;
    const firstHull = row.snapshots.flatMap(snapshot => Object.values(snapshot.contacts).filter(contact => contact.name.startsWith('Hull')).map(contact => ({step: snapshot.step, pose: snapshot.after, contact})))[0];
    return {name: row.name, mode: row.mode, route: row.route, forwardProgress: row.forwardProgress,
        start: row.start, finish: row.finish, histogram, firstHull,
        minDistance: contacts.length ? Math.min(...contacts.map(contact => contact.distance)) : null,
        maxImpulse: contacts.length ? Math.max(...contacts.map(contact => contact.impulse)) : null,
        contactCount: row.contactCount, droppedContacts: row.droppedContacts, stopStep: row.stopStep,
        hulls: Object.values(row.nodes).filter(node => node.name.startsWith('Hull')),
        drivingSurfaces: Object.values(row.nodes).filter(node => node.name.startsWith('DrivingSurface_')),
        collidingAtFinish: row.collidingBodies.at(-1)};
});
const summary = {status: result.status, source, sourceSha256: crypto.createHash('sha256').update(fs.readFileSync(source)).digest('hex'),
    runtime: result.runtime, boundary: result.boundary, vehicle: result.vehicle, sourceFlags: result.sourceFlags,
    totalContacts: result.totalContacts, fullProductionBuild: result.fullProductionBuild, enginePit: result.enginePit, paths};
const destination = path.join(path.dirname(source), path.basename(source, '.json') + '-summary.json');
fs.writeFileSync(destination, JSON.stringify(summary, null, 2));
console.log(JSON.stringify({destination, paths: paths.map(row => ({name: row.name, mode: row.mode, progress: row.forwardProgress, histogram: row.histogram}))}, null, 2));
