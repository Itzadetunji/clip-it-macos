# ClipIt for macOS

ClipIt is a macOS screen clipping app built with SwiftUI. It runs as a small desktop/menu bar app, records a rolling buffer of your screen and audio, and lets you save the last few seconds as a clip when something worth keeping happens.

The app uses Apple's ScreenCaptureKit and AVFoundation APIs to capture the display, system audio, and optional microphone input. Users can choose preset clip lengths of 15, 30, or 60 seconds, or enable a custom duration.

## Features

- Start and stop rolling screen recording from the app window.
- Save recent footage with the "Clip It" button.
- Capture screen video, system audio, and optional microphone audio.
- Choose preset clip lengths or a custom clip duration.
- Receive a notification after a clip is saved.
- Access the app from the macOS menu bar.

## Requirements

- macOS with ScreenCaptureKit support.
- Xcode 16 or newer.
- Screen Recording permission for the built app.
- Microphone permission if microphone capture is enabled.

## Clone And Run

1. Clone the repository:

   ```sh
   git clone https://github.com/itzadetunji/clip-it-macos
   cd clip-it-macos
   ```

2. Open the Xcode project:

   ```sh
   open ClipIt.xcodeproj
   ```

3. In Xcode, select the `ClipIt` scheme.

4. Choose a macOS run destination, then press `Cmd + R`.

5. When macOS asks for permissions, allow Screen Recording and Microphone access as needed. If you change Screen Recording permission, you may need to restart the app.

## Project Structure

```text
macOS
|-- ClipIt.xcodeproj
|   |-- project.pbxproj
|   `-- project.xcworkspace
|-- ClipIt
|   |-- ClipItApp.swift
|   |-- ClipIt.swift
|   |-- Info.plist
|   |-- Assets.xcassets
|   |-- Components
|   |   |-- MenuBar.swift
|   |   `-- NavBar.swift
|   |-- Models
|   |   |-- Settings.swift
|   |   `-- SofiaFont.swift
|   |-- Utilities
|   |   |-- Alert.swift
|   |   |-- Notification.swift
|   |   |-- Capture
|   |   |   |-- ScreenCaptureEngine.swift
|   |   |   |-- RecordingCoordinator.swift
|   |   |   |-- RollingBufferRecorder.swift
|   |   |   |-- RollingClipExporter.swift
|   |   |   |-- RollingSegmentsDirectory.swift
|   |   |   |-- RollingBufferConstants.swift
|   |   |   |-- ClipCaptureOutput.swift
|   |   |   |-- ClipStreamDelegate.swift
|   |   |   |-- MicrophoneCapture.swift
|   |   |   |-- SegmentMetadata.swift
|   |   |   `-- RollingBufferError.swift
|   |   |-- CloseApp
|   |   `-- Extensions
|   `-- Views
|       |-- AboutView.swift
|       `-- HomeView
|           |-- HomeView.swift
|           `-- HomeViewModel.swift
|-- README.md
`-- LICENSE
```

## How It Works

`ScreenCaptureEngine` starts a ScreenCaptureKit stream for the current display and sends screen/audio samples into `ClipCaptureOutput`.

`RollingBufferRecorder` writes incoming samples into short rolling segment files. Old segments are trimmed so the app only keeps the recent recording window it needs.

When the user clicks "Clip It", `HomeViewModel` asks `RecordingCoordinator` to export the selected duration. `RollingClipExporter` combines the newest matching segments into a saved clip and the app sends a completion notification.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
