import argparse
import json
from pathlib import Path


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8-sig"))


def compare(baseline, candidate):
    a, b = read(baseline), read(candidate)
    checks = []

    def check(name, equal):
        checks.append({"name": name, "pass": bool(equal)})

    for key in ("status", "mode", "seed", "runtime"):
        check(key, a[key] == b[key])
    check("successful equivalence runs", a["status"] == "PASS" and a["mode"] == "equivalence")
    check("scenario count", len(a["scenarios"]) == len(b["scenarios"]))
    for left, right in zip(a["scenarios"], b["scenarios"]):
        for key in ("name", "systems", "metadata", "equivalence", "steps", "counts", "stateDigest", "traceDigest", "snapshots", "randomTail"):
            check(left["name"] + ":" + key, left[key] == right[key])
    for path in (Path(baseline), Path(candidate)):
        identity = read(path.with_suffix(".identity.json"))
        process = read(path.with_suffix(".process.json"))
        check(path.stem + ":wait completed", process["waitForExitCompleted"] is True)
        check(path.stem + ":exit policy", not process["exitCodeAvailable"] or process["exitCode"] == 0)
        check(path.stem + ":label identity", identity["label"] == read(path)["label"])
    aid, bid = read(Path(baseline).with_suffix(".identity.json")), read(Path(candidate).with_suffix(".identity.json"))
    for key in ("runtimeSha256", "probeSha256"):
        check(key, aid[key] == bid[key])
    return {"status": "PASS" if all(row["pass"] for row in checks) else "FAIL", "checks": checks,
            "inputs": [str(Path(baseline).resolve()), str(Path(candidate).resolve())],
            "boundary": "Exact recorded module state, output traces, snapshots and RNG; Native static-target weapon fixture, not full battle or device FPS."}


def benchmark(directory):
    labels = ("baseline-1", "candidate-1", "candidate-2", "baseline-2")
    runs = {label: read(Path(directory) / (label + ".json")) for label in labels}
    identities = {label: read(Path(directory) / (label + ".identity.json")) for label in labels}
    first = runs[labels[0]]
    rows = []
    for label, run in runs.items():
        assert run["status"] == "PASS" and run["mode"] == "benchmark" and run["label"] == label
        assert run["seed"] == first["seed"] and run["runtime"] == first["runtime"]
        for key in ("runtimeSha256", "probeSha256"):
            assert identities[label][key] == identities[labels[0]][key]
        process = read(Path(directory) / (label + ".process.json"))
        assert process["waitForExitCompleted"] and (not process["exitCodeAvailable"] or process["exitCode"] == 0)
        for index, scenario in enumerate(run["scenarios"]):
            for key in ("name", "metadata", "systems", "steps", "counts", "randomTail"):
                assert scenario[key] == first["scenarios"][index][key], (label, key)
    assert identities["baseline-1"]["weaponSha256"] == identities["baseline-2"]["weaponSha256"]
    assert identities["candidate-1"]["weaponSha256"] == identities["candidate-2"]["weaponSha256"]
    for index, scenario in enumerate(first["scenarios"]):
        values = {label: runs[label]["scenarios"][index]["totalMs"] for label in labels}
        before = (values["baseline-1"] + values["baseline-2"]) / 2
        after = (values["candidate-1"] + values["candidate-2"]) / 2
        rows.append({"name": scenario["name"], "steps": scenario["steps"], "totalsMs": values,
                     "baselineMeanMs": before, "candidateMeanMs": after,
                     "changePercent": (after / before - 1) * 100})
    return {"status": "PASS", "order": list(labels), "scenarios": rows,
            "boundary": "Unwrapped isolated Native weapon fixture. Shared-machine variation, 1ms timer and no full battle/GPU/device FPS acceptance. Idle control has no projectile work."}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("baseline")
    parser.add_argument("candidate")
    parser.add_argument("--out", required=True)
    parser.add_argument("--benchmark-dir")
    args = parser.parse_args()
    result = compare(args.baseline, args.candidate)
    if args.benchmark_dir:
        result["benchmark"] = benchmark(args.benchmark_dir)
    Path(args.out).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(result["status"], len(result["checks"]), "checks")
    for row in result["checks"]:
        if not row["pass"]:
            print("FAIL", row["name"])
    raise SystemExit(0 if result["status"] == "PASS" else 1)
