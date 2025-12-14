# IPFS Premium Dashboard (Flutter)

A high-fidelity demonstration of `dart_ipfs` capabilities using Flutter.

## Features
- **Premium UI**: Glassmorphism, dark mode, animated indicators.
- **Node Management**: Start/stop the embedded P2P node.
- **File System**: Add files and retrieve content by CID.
- **Real-time Logs**: Visual terminal for node events.

## Prerequisites
- Flutter SDK installed.
- **macOS**: Requires full Xcode installation (not just Command Line Tools).
- **Linux**: Requires build tools (`build-essential`).
- **Windows**: Requires Visual Studio C++ build tools.

## Running the App
### macOS Desktop (Requires Xcode)
```bash
flutter pub get
flutter run -d macos
```

### Web (Demo Mode)
Run the app in your browser to explore the UI (uses a simulated IPFS node):
```bash
flutter run -d chrome
```

> **Note**: This example integrates `dart_ipfs` directly. On **Desktop**, it uses the real `dart_ipfs` node with native performance. On **Web**, it switches to a "Mock Mode" to demonstrate the UI without requiring `dart:ffi`.
