<div align="center">

<img src="lastwave-logo.png" alt="Orbit Audio Logo" width="120" height="120" />

# Orbit Audio

**A desktop music player with lossless-first playback, synced lyrics, discovery, WASAPI exclusive output, a 10-band equalizer, and a dedicated IEM Clarity preset.**

[Windows downloads](https://github.com/aryan1544/LastWave-Desktop/actions) · [Source code](https://github.com/aryan1544/LastWave-Desktop)

</div>

---

## About

Orbit Audio is a personal rebrand of LastWave Desktop for desktop listening. It aims to keep the original player's music, discovery, queue, lyrics, library, and audio features while giving the desktop interface its own name, visual identity, and headphone-focused tuning options.

## Highlights

- **Orbit interface:** deep aubergine surfaces, warm text, and lime accent highlights.
- **Music discovery:** personalized recommendations and quick-pick shelves when the feed is available.
- **Listening controls:** queue, previous/next, shuffle, repeat, and playback controls.
- **Lyrics and library:** retains the underlying LastWave Desktop features available in the current build.
- **Audio settings:** lossless-first source selection, Windows WASAPI output options, and a 10-band equalizer where supported.
- **IEM Clarity preset:** a gentle starting curve intended to add a little presence/detail while reducing some low-mid congestion. It is not a measurement-based calibration for every earphone; results vary by IEM, fit, source, and personal taste.

## Download for Windows

Download the latest version of Orbit Audio from the [GitHub Actions builds page](https://github.com/aryan1544/LastWave-Desktop/actions): choose the latest successful **Build Orbit Audio for Windows** run, then download the `Orbit-Audio-Windows-Setup` artifact. Extract the downloaded ZIP and run the included installer.

A successful build is required before a setup file will appear. The app does not automatically become a Google Play listing or appear instantly in Google Search; public distribution and search indexing are separate steps.

## Set up IEM sound

After installing a build that includes the IEM preset:

1. Open **Settings → Audio → IEM & Headphone Sound**.
2. Enable the equalizer if needed.
3. Choose **IEM Clarity** under Equalizer preset.
4. Start with a comfortable volume and adjust or disable the preset if it does not suit your IEM.

For the cleanest result, use a high-quality source when available and avoid excessive volume or heavy boosts. Lossless/high-resolution playback can preserve only the quality of the source actually received; it cannot recover detail absent from a lossy or low-quality source. WASAPI exclusive/bit-perfect options depend on the Windows output device, driver, and chosen format, and may bypass system mixing or other audio processing.

## Project and attribution

Orbit Audio is a personal custom build based on **LastWave Desktop**. It is not an official release from the upstream project and is not affiliated with the original maintainers. Original application code and third-party components remain subject to their respective licenses. See the repository's `LICENSE` files and notices for applicable terms.

## Build information

The Windows installer is built by GitHub Actions on a Windows runner; the developer workstation does not need to compile the native Windows target locally. Build artifacts are available for a limited time on the corresponding Actions run.

## About this build

Orbit Audio is a personal custom build based on LastWave Desktop for personal desktop listening. Branding and UI changes do not imply a separate streaming service, a Google Play listing, or different rights to the underlying music catalogs.
