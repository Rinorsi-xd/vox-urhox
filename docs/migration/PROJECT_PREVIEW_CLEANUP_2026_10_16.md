# Project preview cleanup - 2026-10-16

Authorized cleanup of the 82 obsolete preview servers inventoried before the next package. Production code was not changed. No files were deleted, no process trees were stopped, and no GPU/browser run was started.

## Actual result

- Started: 2026-10-16T06:15:00.2822025+08:00
- Finished: 2026-10-16T06:16:40.4395897+08:00
- Candidates: 82; stopped and exit-confirmed: 82; skipped/errors: 0.
- Stopped processes immediately before stop: working set sum 4997251072 bytes (4.6541 GiB), private bytes sum 9059434496 (8.4373 GiB).
- OS free physical memory before: 26467736 KiB; after: 29951928 KiB; observed change: 3484192 KiB. This is a concurrent system observation, not an attribution of reclaimed memory. Summed working sets include shared pages.
- Structured evidence: `docs/migration/evidence/project-preview-cleanup-2026-10-16.json`.

Each candidate was checked immediately before stopping: node.exe Win32 process and exact serve-outgame command pattern; expected loopback listener/PID/port; HTTP identity project source/PID/port/manifest; zero Established connections after the identity request completed with connection close; unchanged process start time. Only that Process object was stopped and its exit confirmed.

## Remaining project preview listeners

| PID | Port | Manifest | Mode | Status |
| --- | --- | --- | --- | --- |
| 51016 | 4369 | manifest-14f59378.json | ordinary | preserved |
| 41564 | 4379 | manifest-9b1ad62f.json | ordinary | preserved |
| 66092 | 4380 | manifest-9b1ad62f.json | QA | preserved |
| 3856 | 4381 | manifest-82a41dd6.json | ordinary | preserved |
| 37884 | 4382 | manifest-82a41dd6.json | QA | preserved |

Ports 4369/4379/4380 were the original protected servers. New package servers 4381/4382 appeared during cleanup and were outside the authorized 82 candidates; they were preserved. Other projects, applications, MCP processes, and unrelated Node listeners were not targeted.

## Installed Maker tool paths

The existing `C:\Users\XD\.taptap-maker\python.json` records Python 3.12.14 at:

```text
C:\Users\XD\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe
```

The installed builder was located and verified to exist at:

```text
C:\Users\XD\.taptap-maker\preview-tools\8db996c74e3f74c55b9c6dca29bdf410f049f99a0decac94ebeb1e5a0a28d908\project_builder.py
```

Builder SHA-256: `e3c8e69003a62bb10c2126449e91c52233b1e724e5837efae40ced30720dd961`.

These paths map to `VOX_MAKER_PYTHON` and `VOX_MAKER_BUILDER` for `tools/migration/prepare-cached-outgame.cjs`. No Maker configuration was changed and the builder was not invoked by this cleanup task.

## Confirmed stopped processes

| PID | Port | Manifest hash | Mode | Working set bytes | Private bytes | Result |
| --- | --- | --- | --- | --- | --- | --- |
| 34176 | 4277 | 935b3961 | ordinary | 43548672 | 27172864 | stopped |
| 34696 | 4278 | 935b3961 | QA | 44204032 | 178249728 | stopped |
| 36576 | 4279 | 935b3961 | QA | 43139072 | 166981632 | stopped |
| 9844 | 4280 | b8b63ade | QA | 44650496 | 176345088 | stopped |
| 6364 | 4281 | b8b63ade | ordinary | 43896832 | 26238976 | stopped |
| 18856 | 4282 | 8db734ff | ordinary | 43819008 | 26791936 | stopped |
| 35624 | 4283 | 8db734ff | QA | 47050752 | 174374912 | stopped |
| 43176 | 4284 | 8db734ff | QA | 45379584 | 175849472 | stopped |
| 30772 | 4285 | 6d18072e | ordinary | 43950080 | 26398720 | stopped |
| 26456 | 4286 | 6d18072e | QA | 44064768 | 27025408 | stopped |
| 43704 | 4287 | 6d18072e | QA | 44630016 | 180637696 | stopped |
| 43404 | 4288 | 6d18072e | QA | 44576768 | 182079488 | stopped |
| 46628 | 4289 | d6764c9c | ordinary | 46653440 | 25935872 | stopped |
| 48728 | 4290 | d6764c9c | QA | 47419392 | 175140864 | stopped |
| 35384 | 4291 | d6764c9c | QA | 47812608 | 165638144 | stopped |
| 48740 | 4292 | d6764c9c | QA | 50524160 | 169537536 | stopped |
| 51780 | 4293 | 2729bc84 | ordinary | 46710784 | 25169920 | stopped |
| 47684 | 4294 | 2729bc84 | QA | 47796224 | 184733696 | stopped |
| 3144 | 4295 | 11e3cbe9 | ordinary | 46972928 | 26431488 | stopped |
| 50408 | 4296 | 11e3cbe9 | QA | 49229824 | 188866560 | stopped |
| 52104 | 4299 | 11e3cbe9 | QA | 48820224 | 180355072 | stopped |
| 2644 | 4298 | dbd65e2b | QA | 48484352 | 165076992 | stopped |
| 40832 | 4300 | 0e775676 | ordinary | 48099328 | 25145344 | stopped |
| 35300 | 4302 | 0e775676 | QA | 48152576 | 25509888 | stopped |
| 41360 | 4304 | 561eef79 | ordinary | 46698496 | 26193920 | stopped |
| 23752 | 4305 | 561eef79 | QA | 58433536 | 182624256 | stopped |
| 49676 | 4306 | e1faa514 | ordinary | 46665728 | 25309184 | stopped |
| 42984 | 4307 | e1faa514 | QA | 47304704 | 168312832 | stopped |
| 45988 | 4308 | 264a138b | ordinary | 47554560 | 61399040 | stopped |
| 49020 | 4309 | 264a138b | QA | 48730112 | 177074176 | stopped |
| 47944 | 4311 | b24c5ecb | ordinary | 48054272 | 25866240 | stopped |
| 45368 | 4312 | b24c5ecb | QA | 48619520 | 166862848 | stopped |
| 45116 | 4313 | b24c5ecb | QA | 47702016 | 167399424 | stopped |
| 45400 | 4314 | 5e477668 | ordinary | 46837760 | 25395200 | stopped |
| 49984 | 4315 | 5e477668 | QA | 47431680 | 170000384 | stopped |
| 51680 | 4316 | 5e477668 | QA | 47595520 | 167419904 | stopped |
| 56100 | 4317 | 0b4790c3 | QA | 48074752 | 166391808 | stopped |
| 50980 | 4318 | c346cd29 | QA | 47673344 | 166006784 | stopped |
| 47860 | 4319 | 8c7a8107 | QA | 47702016 | 163155968 | stopped |
| 40704 | 4326 | 04a23389 | QA | 49319936 | 177049600 | stopped |
| 15048 | 4327 | 04a23389 | ordinary | 46850048 | 25616384 | stopped |
| 55616 | 4328 | 706d3d0b | QA | 48017408 | 166498304 | stopped |
| 13544 | 4329 | 706d3d0b | ordinary | 46788608 | 26198016 | stopped |
| 54188 | 4330 | d7af571f | QA | 48828416 | 166592512 | stopped |
| 21620 | 4331 | d7af571f | ordinary | 48185344 | 26075136 | stopped |
| 48052 | 4332 | d7af571f | QA | 49291264 | 175964160 | stopped |
| 54284 | 4335 | 8d1859cd | QA | 48177152 | 179023872 | stopped |
| 53660 | 4336 | 8d1859cd | ordinary | 48353280 | 26337280 | stopped |
| 58704 | 4337 | d966b4f2 | QA | 51023872 | 161968128 | stopped |
| 3428 | 4338 | d966b4f2 | ordinary | 47661056 | 25174016 | stopped |
| 37636 | 4340 | b2399110 | ordinary | 48742400 | 25915392 | stopped |
| 51308 | 4341 | b2399110 | QA | 53612544 | 175902720 | stopped |
| 12780 | 4342 | e266101a | ordinary | 50282496 | 25899008 | stopped |
| 43388 | 4343 | e266101a | QA | 65851392 | 167235584 | stopped |
| 57868 | 4344 | 971b2f95 | ordinary | 47439872 | 25903104 | stopped |
| 34496 | 4345 | 971b2f95 | QA | 48893952 | 25214976 | stopped |
| 61060 | 4350 | 4227f9e4 | ordinary | 94711808 | 185016320 | stopped |
| 60016 | 4351 | 4227f9e4 | QA | 67092480 | 170700800 | stopped |
| 22464 | 4352 | 046debe2 | ordinary | 47550464 | 26202112 | stopped |
| 32640 | 4353 | 046debe2 | QA | 62464000 | 168939520 | stopped |
| 10840 | 4354 | e31a194a | ordinary | 48177152 | 25616384 | stopped |
| 61536 | 4355 | e31a194a | QA | 68841472 | 167317504 | stopped |
| 56900 | 4356 | c787bbd6 | ordinary | 48087040 | 26054656 | stopped |
| 59052 | 4357 | c787bbd6 | QA | 60391424 | 165195776 | stopped |
| 61868 | 4358 | c787bbd6 | QA | 66678784 | 173027328 | stopped |
| 60820 | 4359 | 19556941 | ordinary | 49143808 | 24887296 | stopped |
| 9652 | 4360 | 19556941 | QA | 64241664 | 173539328 | stopped |
| 9968 | 4361 | 3e9b0260 | ordinary | 49270784 | 25882624 | stopped |
| 47840 | 4362 | 3e9b0260 | QA | 82518016 | 177958912 | stopped |
| 7400 | 4363 | 5198310b | ordinary | 51408896 | 26181632 | stopped |
| 51452 | 4364 | 5198310b | QA | 132427776 | 171974656 | stopped |
| 55144 | 4365 | a7d7050c | ordinary | 60198912 | 25264128 | stopped |
| 63160 | 4366 | a7d7050c | QA | 167489536 | 171388928 | stopped |
| 62980 | 4367 | 0bcd53d6 | ordinary | 60235776 | 25231360 | stopped |
| 41772 | 4368 | 0bcd53d6 | QA | 177324032 | 178782208 | stopped |
| 44572 | 4370 | 14f59378 | QA | 174604288 | 174137344 | stopped |
| 62748 | 4373 | 3ba43bd8 | ordinary | 59854848 | 25034752 | stopped |
| 37944 | 4374 | 3ba43bd8 | QA | 165437440 | 168824832 | stopped |
| 62704 | 4375 | 5f39f096 | ordinary | 60313600 | 26144768 | stopped |
| 63276 | 4376 | 5f39f096 | QA | 172974080 | 176009216 | stopped |
| 66392 | 4377 | e9f25319 | ordinary | 60608512 | 25903104 | stopped |
| 51652 | 4378 | e9f25319 | QA | 163221504 | 166551552 | stopped |
