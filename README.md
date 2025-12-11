# Desktop Goose for macOS

A chaotic 3D goose that waddles across your desktop, honks, grabs your cursor, drags memes, and perches on windows!

## Features

- **3D Goose**: A procedurally generated 3D goose rendered with SceneKit
- **Wanders Around**: The goose walks randomly across your screen
- **Honks**: Occasional honking with sound effects
- **Grabs Cursor**: Sometimes the goose will grab your mouse cursor and drag it around
- **Drags Memes**: Pulls meme images across your desktop
- **Perches on Windows**: Sits on top of your application windows
- **Menu Bar Control**: Pause, resume, or configure the goose from the menu bar

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (to build)

## Building

1. Open `DesktopGoose.xcodeproj` in Xcode
2. Select the "DesktopGoose" scheme
3. Build and run (⌘R)

## Permissions

The app may request the following permissions:

- **Accessibility**: Required for cursor grabbing and window detection
  - Go to System Settings → Privacy & Security → Accessibility
  - Enable Desktop Goose

## Configuration

Click the goose icon (🐦) in the menu bar to access:

- **Pause/Resume**: Stop the goose temporarily
- **Settings**: Configure chaos level, speed, and which behaviors are enabled
- **Quit**: Close the app

## Adding Custom Content

### 3D Model

To use a custom goose model:

1. Get a 3D model in FBX, DAE, or USDZ format
2. Drag it into Xcode to convert to SceneKit format (.scn)
3. Place it in `DesktopGoose/Resources/` as `goose.scn`
4. The app will automatically load it instead of the procedural goose

### Honk Sounds

Add audio files named `honk.mp3` or `honk2.mp3` to the Resources folder.

### Meme Images

Add image files to the Resources folder. Supported names:
- `meme1.png`, `meme2.png`, `meme3.png`
- `deal_with_it.png`
- `trollface.png`

## Architecture

```
DesktopGoose/
├── App/                    # Application lifecycle
│   ├── AppDelegate.swift   # Main app entry point
│   └── MenuBarController   # Status bar menu
├── Overlay/                # Transparent overlay system
│   ├── OverlayWindow       # Always-on-top transparent window
│   └── GooseSceneView      # SceneKit rendering view
├── Goose/                  # Goose model and animation
│   ├── GooseNode           # 3D goose SCNNode
│   ├── GooseController     # Movement and behavior coordinator
│   └── GooseAnimations     # Animation loading and playback
├── Behaviors/              # Goose behavior system
│   ├── BehaviorStateMachine
│   ├── WanderBehavior
│   ├── HonkBehavior
│   ├── CursorGrabBehavior
│   ├── MemeDragBehavior
│   └── WindowPerchBehavior
├── System/                 # OS integration
│   ├── WindowObserver      # Window position detection
│   ├── CursorController    # Mouse cursor manipulation
│   └── ScreenManager       # Multi-monitor support
└── Settings/               # User preferences
    ├── Preferences         # UserDefaults wrapper
    └── SettingsWindow      # Settings UI
```

## How It Works

The app creates a transparent, always-on-top window that covers the entire screen. The goose is rendered inside this window using SceneKit with an orthographic camera, giving it a 2.5D appearance. Mouse clicks pass through the window to apps underneath, so you can continue using your computer normally while the goose causes chaos.

The behavior system uses a weighted state machine that randomly transitions between different behaviors based on configurable chaos levels and cooldown timers.

## License

MIT License - Feel free to fork and make your own chaotic desktop pets!

