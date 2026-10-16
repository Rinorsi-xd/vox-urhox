# MatchVoice source Radio capture

This candidate follows manifest `35b14da3`; it is not part of that frozen build.
Only the battle `MatchVoice` route changes. Original `Sounds/BattleRadio/*.wav`
files remain available for other consumers. StoryRadio, match introductions and
other voice routes are outside this change.

## Source And Capture

Frozen baseline: `b276064942ae09c0227ec28d4cfda1d5ff006455`.
`shared/audio/radio.js` SHA256:
`2fb1173f9cf5ab0fba41090d3d7848cc7b05ef16d42e4ed6059e91115e6b7f69`.

The public Lua audio API has no exposed filter/compressor/waveshaper graph.
`import-match-radio.cjs` executes the actual frozen Radio constructor and `say`
under Chromium OfflineAudioContext at 48 kHz. Source filters, tanh waveshaper,
compressor, LFO, noise, beeps and decoded original hiss execute unchanged.
The master is set to one for capture. User settings and the route gain are not
baked; runtime applies `.7 * .4` through the existing voice control once.

Each line has processed voice, hiss, opening and return stems. Opening is shared;
the other three remain per line. Non-selected inputs are muted without removing
the decoded hiss connection, preserving channel topology. Since source `onended`
disconnects can change the shared FX filter topology during the return, the
return stem is the actual complete source output minus the other three captures,
starting at the authored voice end. This preserves that source transient instead
of rebuilding it with different filters.

All 116 full-source renders reconstruct from the captured float stems within
`2.9585498850792646e-7`; exported PCM16 reconstruction max error is
`3.0506081884588976e-5` (about one PCM16 step). These are waveform checks against
the actual source graph, not a manually configured filter approximation.

349 unique mono PCM16 WAV files total 70,124,796 bytes. Largest selected line has
1,157,544 PCM bytes across its four stems. No complete-library download or decode
is requested at MatchVoice construction. The obsolete intermediate `tail.wav`
and metadata were removed.

## Runtime And Resource Lifetime

The highest queued call chooses one line, retaining the no-consecutive-repeat
choice while it prepares. Only its four files enter ResourceGate. Download
completion publishes a flag; it never decodes in the download callback.
Prepare submits at most one BackgroundLoadResource request per frame, then
requires all four GetExistingResource results before starting the audio clock.
There is no synchronous Sound GetResource fallback.

A false background request result can mean already queued: the player observes
existing-cache/background completion rather than failing immediately. Explicit
ResourceBackgroundLoaded failures affect only a candidate using that path.
Cancellation does not make a late failure for an unrelated old path fail the
new candidate. Background completion callbacks only record state; Update owns
resource retirement. An independent Node retires successful or failed pending
decodes after battle disposal, then disposes itself. ReleaseResource uses false
to preserve other SoundSource owners.

The first preparation window retains source cold-load queue behavior: TTLs start
when that initial preparation resolves. Once ready, normal call TTLs continue to
expire during later on-demand downloads. Consequently, a new short-lived call
can be dropped on a slow first download; this is a deliberate resource-loading
tradeoff compared with the original entire-library preload. Failure and the
20-second preparation timeout retire the selected candidate.

Source clocks remain distinct: opening `.02`, hiss `.06`, processed voice `.26`,
return `raw duration + .26`; speaking ends at `raw duration + .5`; Radio total
is `raw duration + .52`, followed by the original `.35` queue gap. The card uses
the source `.26` lead and `total + .5` lifetime. Late frames seek into the stem
instead of shifting the authored timeline.

Stop cancels live and pending tracks. Fade cancels transients while fading voice
and hiss for `.35` seconds; those detached tracks survive a replacement Play.
Reset, focus loss, minimization and Dispose halt all owned tracks and preparation.
Speaking ownership continues to drive the existing music duck; every active
track follows the current voice setting without an SFX sample-master factor.

## Verification

Commands (bundled Python has Lupa through `.tmp/nav-python-deps`):

```
node tools/migration/import-match-radio.cjs
python tools/migration/check-match-radio-dsp.py
python tools/migration/check-match-mvp-audio.py
```

The dedicated checker passes 2225 assertions, all 116 Lua line schedules and six
negative controls: synchronous decoding, missing master, old failure poisoning
the new candidate, immediate voice onset, premature cold TTL and cutting detached
fade tracks. It verifies actual exported PCM hashes, format and duration, original
source inputs, cold download over six seconds, background already-queued handling,
cancel/TTL/focus/minimize/reset/disposal and late success/failure cleanup.
The existing independent radio-speaking/MVP check remains 611 assertions and
eight negative controls; its two-second ownership fixture now supplies prepared
DSP resources. Real PCM clocks are checked by the dedicated checker.

Evidence: `evidence/match-radio-source.json`,
`evidence/match-radio-dsp-offline.json`, and
`evidence/match-mvp-audio-offline.json`.

Build audit must verify all 349 payload hashes and their manifest lookup entries,
with no DSP WAV in startup preload groups. The actual Web route must observe
per-line requests, nonzero engine mixer output, source/card clocks, live voice
settings, duck and cleanup after leaving battle.

## Acceptance Boundary

Seeded noise and initial LFO phase are fixed captured variants, not fresh random
noise or the continuously advancing source LFO on every play. Frame scheduling
and Seek are not sample-accurate native scheduling. Applying a fade envelope to
already-processed voice is an approximation of the source fade before its
nonlinear DSP; timing/ownership are preserved but waveform equality during fade
is not claimed. Offline checks do not provide engine listening acceptance,
rendered validation, or user approval. Peak actual native resident PCM still
requires the Web resource probe; largest-line PCM is a file-format measurement,
not a claimed runtime memory peak.
