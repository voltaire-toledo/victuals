# Linux Speech-to-Text Dictation Comparison

## Scope and method

This is a decision note for the Ubuntu hydrator, researched on 2026-09-01.
It compares the projects actually named in the hydration discussion: **Voquill**,
**Vocalinux**, **Speech Note**, and **Voxtype**.  It uses the projects' official
repositories, documentation, source, and GitHub release/issue trackers.  The
"last 90 days" window is 2026-06-03 through 2026-09-01.

Important disambiguation: the Omarchy-relevant project is
[`peteonrails/voxtype`](https://github.com/peteonrails/voxtype), a local-first
dictation tool.  It is distinct from [`atheerium/voxtype`](https://github.com/atheerium/voxtype),
which defaults to a Groq API and requires the user's provider key.

## Comparison

| Criterion | Voquill | Vocalinux | Speech Note | Voxtype |
| --- | --- | --- | --- | --- |
| Primary use | Polished cross-platform dictation, transcript cleanup, glossary, writing styles, history/replay, and an in-app AI chat. [Official README](https://github.com/voquill/voquill) | Linux desktop dictation into the focused app: push-to-talk/toggle hotkeys, continuous dictation, and GTK settings. [Official README](https://github.com/VocaHQ/vocalinux) | Broad offline speech suite: notes, STT, TTS, machine translation, subtitle work, and active-window insertion. [Official README](https://github.com/mkiol/dsnote) | Linux-first push-to-talk/toggle dictation: OSD, profiles, text substitutions/punctuation, meeting transcription/export, and a configuration TUI. [Official README](https://github.com/peteonrails/voxtype) |
| Local STT | Local Whisper, optionally GPU-accelerated. | Local whisper.cpp, OpenAI Whisper, or VOSK after model download. | Local Coqui/DeepSpeech, Vosk, whisper.cpp, Faster Whisper, and April-ASR. | Local Whisper, Parakeet, Moonshine, SenseVoice, Paraformer, Dolphin, Omnilingual, Cohere Transcribe, and OpenVINO Whisper. |
| Remote STT / LLM | Yes: user-selected transcription and post-processing providers; its Providers UI accepts API keys. | Yes for ASR: official HTTP documentation supports whisper.cpp and OpenAI-compatible servers, including self-hosted Speaches, LocalAI, and FunASR/SenseVoice. It does **not** document an LLM cleanup feature. [Remote-API guide](https://github.com/VocaHQ/vocalinux/blob/main/docs/HTTP_REMOTE.md) | No remote STT or LLM endpoint is documented; the stated design is offline/local. | Optional remote Whisper server for ASR. Its post-processing command can use any local or remote command; official examples include Ollama, LM Studio, and llama.cpp. Meeting summaries can use Ollama. [User manual](https://github.com/peteonrails/voxtype/blob/dev/docs/USER_MANUAL.md) |
| GPU versus CPU | CPU local mode works; GPU is optional for Whisper. Exact supported backends are not prominently documented. | CPU works. whisper.cpp can use Vulkan across Intel/AMD/NVIDIA; the PyTorch Whisper engine is NVIDIA-only. VOSK is the low-resource option. | CPU works. Base Flatpak includes Vulkan Whisper; optional NVIDIA/CUDA and AMD/ROCm Flatpak add-ons accelerate selected engines. The add-ons are very large: the project lists 15 GiB temporary installation space for NVIDIA and 55 GiB for AMD. | CPU first: project claims 9–11× realtime on a Zen 4 CPU with Cohere Transcribe. Optional Vulkan Whisper; CUDA 12/13 for NVIDIA and MIGraphX for AMD Parakeet; packaged OpenVINO support targets Intel hardware. |
| Linux and device support | Linux, macOS, Windows, plus a mobile app in the monorepo. Linux packaging/reliability should be verified separately before hydrator adoption. | Linux only: X11 and Wayland; supports Ubuntu/Debian, Fedora, Arch, and openSUSE. Official AppImage assets cover x86_64 and aarch64. | Linux desktop and Sailfish OS. Wayland focused-window insertion needs `ydotool`; global shortcuts require a desktop portal implementation. | Linux X11 and Wayland including GNOME, KDE, Sway, Hyprland, Niri, and River. Uses compositor bindings where available, with `wtype`, `dotool`, `ydotool`, and clipboard fallbacks. |
| Extensibility | Provider configuration, dictionary, and writing styles. No general plug-in/add-on API is documented. | Configuration and remote-server protocol; no plug-in/add-on framework documented. | Editable `models.json` permits custom model definitions. GPU capability ships as official Flatpak add-ons, not a general plug-in system. | Command-based post-processing, compositor/Waybar integrations, configuration profiles, and an Omarchy integration directory. No arbitrary plug-in SDK is documented. |
| License and price | AGPLv3 source. The desktop source contains login, trial, plan, and upgrade components; pricing is fetched dynamically, so this review does **not** claim a fixed price. | AGPL-3.0; no paid plan, subscription, or account requirement is described in its local-install documentation. | MPL-2.0; no paid plan, subscription, or account requirement is described in its documentation. | MIT; official documentation explicitly says no cloud, subscription, or telemetry by default. Remote services or LLMs may of course have their own costs. |
| Account reminders / nags | **Caution.** The source contains sign-in and pricing/upgrade UI and a free-word quota (default 2,000 words/week in the plan component). That is evidence of an account/plan path, though not proof that every self-hosted/local configuration shows a nag. [Plan source](https://github.com/voquill/voquill/blob/main/apps/desktop/src/components/pricing/PlanList.tsx) | No account/signup reminder or paid-plan UI found in the official README, installer, and remote-API documentation reviewed. Absence of documentation is not proof that no future prompt exists. | No account/signup reminder or paid-plan UI found in the official README and package documentation reviewed. | No account/signup reminder or paid-plan UI found; official documentation states no subscription. |
| Packaging | Official releases currently include Linux `.deb`, AppImage, and RPM artifacts. [Releases](https://github.com/voquill/voquill/releases) | Installer/source, AppImage, PyPI, and AUR. Its Flatpak status should be checked at execution time. [Install guide](https://github.com/VocaHQ/vocalinux/blob/main/docs/INSTALL.md) | Flathub `net.mkiol.SpeechNote`, optional AMD/NVIDIA add-ons, AUR, openSUSE package, and Sailfish package. | Signed `.deb`, `.rpm`, AppImage, and AUR releases. [Install guide](https://github.com/peteonrails/voxtype/blob/dev/docs/INSTALL.md) |
| Release cadence in the 90-day window | Four published desktop releases: 2026-07-13 and three on 2026-08-01, plus active source updates. | Fast: stable 0.14.1/0.14.2 (July), 0.15.0 (August 2), 0.16.0 (August 23), 0.16.1 (August 30), and nightlies. | Regular stable desktop releases: 4.8.0 (June 20), 4.8.1 (July 12), 4.8.2 (August 2), and 4.8.3 (August 15). | Very fast around 1.0: release candidates in June/August and 1.0.0/1.0.1 on August 29/31. |
| Recent public sentiment: bounded signal, not a rating | **Mixed / cautionary.** Public issues include positive wording (“Love the app”) alongside repeated concern about excessive logging and open Linux hotkey/model-download bugs. 22 non-PR issues were created in the window, 15 open at snapshot. [Issues](https://github.com/voquill/voquill/issues?q=is%3Aissue%20created%3A2026-06-03..2026-09-01) | **Constructive but turbulent.** Rapid releases and equal split of 36 new issues (18 closed, 18 open) suggest active maintenance, while recent reports focus on injection, audio architecture, and Wayland limitations. [Issues](https://github.com/VocaHQ/vocalinux/issues?q=is%3Aissue%20created%3A2026-06-03..2026-09-01) | **Mixed / mature-project maintenance.** 27 new issues, 21 still open at snapshot; requests and reports concentrate on GPU loading, global shortcuts, packaging, and features. No reliable aggregate user-rating signal was found. [Issues](https://github.com/mkiol/dsnote/issues?q=is%3Aissue%20created%3A2026-06-03..2026-09-01) | **Enthusiastic but volatile.** 46 new issues, 32 open at snapshot, with active feature work and first-week 1.0 fixes. This shows high activity, not a quality score. Recent reports include input-method, model-mirror, Vulkan, and display-scaling bugs. [Issues](https://github.com/peteonrails/voxtype/issues?q=is%3Aissue%20created%3A2026-06-03..2026-09-01) |

## Interpretation for the hydrator

- **Best primary recommendation: Voxtype.** It has the strongest documented
  combination of Wayland-aware dictation, CPU operation, optional acceleration,
  local/remote ASR, and practical local-LLM integration. It is also the
  Omarchy-aligned choice. Its unusually rapid 1.0-era change rate means the
  hydrator should install a pinned, validated release rather than an unbounded
  "latest" download.
- **Best low-resource GUI alternative: Vocalinux with VOSK or whisper.cpp.**
  It is purpose-built for Linux dictation and documents a self-hostable remote
  escape hatch, but current Wayland injection reports make end-to-end testing on
  GNOME essential.
- **Best full offline speech workstation: Speech Note.** It is much more than
  dictation: choose it for TTS, translation, subtitles, and models. Do not make
  its large GPU Flatpak add-ons a default installation.
- **Do not position Voquill as the privacy/no-nag default.** Its local backend
  capability is real, but the source also contains account, trial, quota, and
  upgrade flows. It is the most polished cross-platform option, not the most
  predictable zero-account installer.

## Source record

All capability and package claims above are linked inline. Release cadence was
read from the projects' official [Voquill](https://github.com/voquill/voquill/releases),
[Vocalinux](https://github.com/VocaHQ/vocalinux/releases),
[Speech Note](https://github.com/mkiol/dsnote/releases), and
[Voxtype](https://github.com/peteonrails/voxtype/releases) release feeds on the
research date. Issue counts are a snapshot from the linked GitHub issue searches
and deliberately exclude pull requests. They are evidence of public activity
and reported experience, not statistically representative sentiment.
