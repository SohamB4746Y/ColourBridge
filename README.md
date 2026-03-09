# ColourBridge 🌈

**An Accessibility-First Color Analysis Tool for iOS**

ColourBridge is an innovative offline accessibility tool designed to help people with color-vision deficiencies (CVD) interpret color-coded information in their daily lives. Whether it's understanding charts at work, reading maps while traveling, or distinguishing colored labels, ColourBridge bridges the gap between color-dependent information and those who perceive colors differently.

![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![License](https://img.shields.io/badge/License-Educational-green.svg)

---

## 🎯 Problem Statement

Approximately **8% of men** and **0.5% of women** worldwide have some form of color-vision deficiency. While this is a significant portion of the population, most visual information—charts, maps, graphs, diagrams, and UI elements—relies heavily on color to convey meaning. This creates daily accessibility challenges that are often overlooked.

ColourBridge addresses this by providing:
- Real-time color identification and analysis
- Color-blind simulation to understand how others perceive colors
- WCAG-compliant contrast analysis for accessibility validation
- Descriptive color names that are universally understandable

---

## ✨ Features

### 📷 Live Camera Analysis
Point your camera at any color-coded information and tap to identify colors in real-time. Perfect for:
- Reading color-coded charts and graphs
- Identifying colored wires or components
- Understanding traffic signals or warning signs
- Distinguishing colored products or labels

### 🖼️ Photo Analysis
Import photos from your library to analyze color-coded charts, maps, or diagrams at your own pace. Ideal for:
- Studying reports and presentations
- Analyzing data visualizations
- Understanding educational materials
- Reviewing work documents

### 📊 Sample Chart Demo
Try the app with a built-in programmatically generated sample chart to:
- Understand how the app works
- Test different color-vision deficiency simulations
- See accessibility ratings in action
- Experience the analysis workflow

### 🎨 Color-Vision Deficiency Simulation
Switch between different vision modes to see how colors appear:
- **Normal Vision**: Standard color perception
- **Protanopia**: Red-green CVD (missing L-cones, ~1% of males)
- **Deuteranopia**: Red-green CVD (missing M-cones, ~1% of males)

### ♿ WCAG Contrast Analysis
Get detailed accessibility metrics for each color:
- **Contrast Ratios**: Against both white and black backgrounds
- **Readability Ratings**: Good (7:1+), Acceptable (4.5:1+), or Low (<4.5:1)
- **Real-time Feedback**: Instant analysis as you sample colors

### 🏷️ Smart Color Naming
Colors are identified with descriptive, accessible names from a curated palette:
- Deep Red, Coral Red, Crimson
- Orange, Dark Orange
- Yellow, Gold
- Green, Dark Green, Lime Green
- Teal, Blue-Green
- Blue, Dark Blue, Sky Blue
- Purple, Lavender, Deep Purple
- Pink, Light Pink
- Brown, Dark Brown
- Neutrals (White, Gray, Black)

### 🔒 Privacy-First Design
All image processing and color analysis happens **100% on-device**:
- No photos are uploaded to servers
- No data is stored permanently
- No internet connection required
- Complete privacy and security

---

## 🏗️ Technical Architecture

### Technology Stack

| Component | Technology |
|-----------|-----------|
| **UI Framework** | SwiftUI with Swift 6.0 |
| **Image Processing** | Core Image (CIFilter, CIImage) |
| **Camera** | AVFoundation (AVCaptureSession) |
| **Charts** | Swift Charts |
| **Graphics** | Core Graphics (UIGraphicsImageRenderer) |
| **Platform** | iOS 17.0+ (iPhone & iPad) |

### Core Components

#### 1. **ColorAnalyzer** (`ColorAnalyzer.swift`)
The brain of the app—a pure-logic module handling:
- **Color Sampling**: Uses `CIAreaAverage` filter for efficient pixel averaging in defined regions
- **WCAG Contrast Calculation**: Implements relative luminance (sRGB linearization + BT.709 coefficients)
- **Color Naming**: Euclidean distance matching in RGB space against a curated 28-color palette
- **CVD Simulation**: Implements Viénot/Brettel matrices for Protanopia and Deuteranopia
- **Readability Evaluation**: Maps contrast ratios to WCAG AAA (7:1), AA (4.5:1), or below thresholds

#### 2. **CameraAnalyzeView** (`CameraAnalyzeView.swift`)
Real-time camera analysis interface:
- **CameraManager**: Manages AVCaptureSession lifecycle, authorization, and frame delivery
- **Live Preview**: Renders camera feed with color-blind simulation overlay
- **Tap-to-Sample**: Interactive gesture handling with visual feedback (animated ring)
- **Sample Collection**: Aggregates multiple samples for summary analysis
- **Mode Switching**: Real-time segmented control for vision mode selection

#### 3. **SampleAnalyzeView** (`SampleAnalyzeView.swift`)
Static image analysis interface:
- **Dual Mode**: Supports both built-in programmatic chart and user-imported photos
- **Chart Generation**: Core Graphics-based bar chart with rounded corners and labels
- **Coordinate Mapping**: Transforms tap locations through `scaledToFit()` geometry to image pixels
- **Background Filtering**: Ignores near-white pixels (likely chart backgrounds)
- **Orientation Handling**: Properly handles EXIF orientation for imported photos

#### 4. **SummaryView** (`SummaryView.swift`)
Data visualization and insights:
- **Swift Charts Integration**: Bar chart showing readable vs. hard-to-read color distribution
- **Accessibility Metrics**: Counts and categorizes samples by readability
- **Educational Content**: Explains findings and offers best practices
- **Navigation**: Restart button to return to welcome screen

#### 5. **ContentView** (`ContentView.swift`)
Root navigation and entry point:
- **Welcome Screen**: App overview with preview cards
- **Three Entry Points**: Camera, Sample Chart, Photo Picker
- **PhotosPicker Integration**: Loads photos with proper EXIF orientation handling
- **Navigation Stack**: SwiftUI NavigationStack for deep linking

### Key Algorithms

#### Color Sampling
```swift
// Uses CIAreaAverage for efficient mean color of a region
CIFilter(name: "CIAreaAverage", parameters: [
    kCIInputImageKey: ciImage,
    kCIInputExtentKey: CIVector(cgRect: sampleRect)
])
```

#### WCAG Contrast Ratio
```swift
// Relative luminance per WCAG 2.x
L = 0.2126 * linearize(R) + 0.7152 * linearize(G) + 0.0722 * linearize(B)
contrastRatio = (L_lighter + 0.05) / (L_darker + 0.05)
```

#### CVD Simulation (Deuteranopia Example)
```swift
// Linear RGB transformation matrix
R' = 0.625 * R + 0.375 * G + 0.000 * B
G' = 0.700 * R + 0.300 * G + 0.000 * B
B' = 0.000 * R + 0.300 * G + 0.700 * B
```

---

## 🚀 Getting Started

### Prerequisites
- macOS with Xcode 15.0 or later
- iOS 17.0+ device or simulator
- Apple Developer account (for device deployment)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/SohamB4746Y/ColourBridge.git
   cd ColourBridge
   ```

2. **Open in Xcode**
   - Double-click `Package.swift` or open the `.swiftpm` folder
   - Or use Swift Playgrounds on iPad

3. **Configure signing**
   - Select your development team in Package.swift
   - Update `teamIdentifier` in Package.swift if needed

4. **Run the app**
   - Select a device or simulator
   - Press `⌘R` or click the Run button

### Usage Guide

#### Analyzing with Camera
1. Launch the app and tap **"Start with Camera"**
2. Grant camera permissions when prompted
3. Point your camera at color-coded content
4. Tap anywhere on the preview to sample colors
5. Switch between Normal/Protan/Deutan modes using the segmented control
6. Tap **"See Summary"** to view collected samples

#### Analyzing a Photo
1. From the welcome screen, tap **"Choose from Photos"**
2. Select a photo containing color-coded information
3. Tap on different areas to sample colors
4. Compare how colors appear in different CVD simulations
5. Review summary statistics

#### Trying the Demo
1. Tap **"Try Sample Chart"** on the welcome screen
2. Explore the built-in bar chart
3. Tap bars to see color identification
4. Experiment with different simulation modes

---

## 📱 Requirements

- **Platform**: iOS 17.0 or later
- **Devices**: iPhone and iPad
- **Permissions**: 
  - Camera (for live analysis)
  - Photo Library (for photo import)
- **Storage**: ~5 MB
- **Network**: Not required (fully offline)

---

## 🎓 Educational Purpose

This project was created for the **Apple Swift Student Challenge 2026** to demonstrate:
- **Accessibility-First Design**: Building inclusive technology from the ground up
- **Modern iOS Development**: Leveraging Swift 6, SwiftUI, and Apple frameworks
- **Real-World Problem Solving**: Addressing a genuine accessibility challenge
- **Technical Excellence**: Clean architecture, efficient algorithms, and best practices

### Learning Outcomes
- Deep understanding of color theory and perception
- Practical application of image processing with Core Image
- Real-time camera handling with AVFoundation
- Accessibility standards (WCAG) implementation
- SwiftUI advanced patterns (MainActor, @StateObject, @Environment)
- Scientific algorithm implementation (color transformation matrices)

---

## 📁 Project Structure

```
ColourBridge.swiftpm/
├── MyApp.swift                 # App entry point (@main)
├── Package.swift               # Swift package manifest
├── ContentView.swift           # Root navigation and welcome screen
├── ColorAnalyzer.swift         # Core color analysis logic
├── CameraAnalyzeView.swift     # Real-time camera interface
├── SampleAnalyzeView.swift     # Static image/chart analysis
├── SummaryView.swift           # Data visualization and insights
├── Assets.xcassets/            # App icons and assets
├── README.md                   # This file
└── .gitignore                  # Git ignore rules
```

### File Responsibilities

| File | Purpose | Key Features |
|------|---------|--------------|
| `MyApp.swift` | Application lifecycle | SwiftUI App protocol, window configuration |
| `ContentView.swift` | Main navigation hub | Three entry points, PhotosPicker, preview cards |
| `ColorAnalyzer.swift` | Pure logic layer | Color sampling, contrast calculation, CVD simulation |
| `CameraAnalyzeView.swift` | Camera feature | AVFoundation, real-time preview, tap interaction |
| `SampleAnalyzeView.swift` | Photo/chart analysis | Chart generation, photo import, coordinate mapping |
| `SummaryView.swift` | Results dashboard | Swift Charts, statistics, educational content |

---

## 💡 Code Quality & Best Practices

### Architecture Principles
- **Separation of Concerns**: Pure logic (ColorAnalyzer) separate from UI
- **Single Responsibility**: Each view handles one primary function
- **Immutability**: ColorSample and enums are immutable structs/enums
- **Type Safety**: Strong typing with Swift 6, no force unwrapping

### Swift 6 & Concurrency
- **Actor Isolation**: `@MainActor` for UI components
- **Sendable Protocol**: All data models conform to Sendable
- **No Data Races**: Proper isolation of camera callback threads
- **Structured Concurrency**: Task-based async/await patterns

### Accessibility Features
- **VoiceOver Support**: Comprehensive accessibility labels and hints
- **Dynamic Type**: Respects user font size preferences
- **High Contrast**: Works well in all color schemes
- **Descriptive Labels**: Clear button and control labeling

### Performance Optimizations
- **Efficient Sampling**: CIAreaAverage filter for O(1) region averaging
- **Frame Throttling**: 30 FPS camera frame processing limit
- **Lazy Rendering**: SwiftUI's declarative updates minimize overdraw
- **Reusable Context**: Single CIContext instance for image rendering

---

## 🔮 Future Enhancements

### Planned Features
- [ ] **Tritanopia Simulation**: Add support for blue-yellow color blindness
- [ ] **Color Palette Export**: Save analyzed color palettes for reference
- [ ] **Batch Analysis**: Process multiple images at once
- [ ] **Color Suggestions**: Recommend accessible alternative colors
- [ ] **AR Mode**: Real-time color labels using ARKit
- [ ] **Haptic Feedback**: Vibration feedback for successful samples
- [ ] **Multi-Language Support**: Localization for global accessibility
- [ ] **iCloud Sync**: Sync analyzed palettes across devices
- [ ] **Widget Support**: Quick access to last analyzed colors
- [ ] **Apple Watch Extension**: Wrist-based color analysis

### Technical Improvements
- [ ] Machine Learning: Intelligent color clustering and categorization
- [ ] Better CVD Models: More accurate simulation algorithms
- [ ] PDF Export: Generate accessibility reports
- [ ] Historical Data: Track analyzed colors over time
- [ ] Color Theory Tips: Educational content about color combinations
- [ ] Integration with Color Palette APIs: Suggest professional palettes

---

## 🤝 Contributing

This is an educational project for the Swift Student Challenge, but suggestions and feedback are welcome!

### How to Contribute
1. **Report Issues**: Open an issue describing bugs or improvements
2. **Suggest Features**: Share ideas for accessibility enhancements
3. **Code Reviews**: Provide feedback on code quality and architecture
4. **Documentation**: Help improve or translate documentation
5. **Testing**: Test on different devices and report findings

### Development Guidelines
- Follow Swift API Design Guidelines
- Maintain Swift 6 strict concurrency compliance
- Add comprehensive comments for complex logic
- Ensure all UI has proper accessibility support
- Write clean, self-documenting code
- Keep performance in mind (especially for camera features)

---

## 🙏 Acknowledgments

### Inspiration & Research
- **WCAG Guidelines**: Web Content Accessibility Guidelines by W3C
- **Viénot et al. (1999)**: "Digital video colourmaps for checking the legibility of displays by dichromats"
- **Apple Human Interface Guidelines**: Accessibility best practices
- **Color Blind Awareness**: Educational resources on CVD

### Technologies & Frameworks
- **Apple Developer Ecosystem**: Swift, SwiftUI, Core Image, AVFoundation
- **Swift Charts**: Native data visualization framework
- **Swift Package Manager**: Dependency management and app packaging

### Special Thanks
- Apple Education Team for the Swift Student Challenge
- The iOS accessibility community for advocacy and education
- Open-source contributors who advance accessibility tools
- People with color-vision deficiencies who inspired this project

---

## 📄 License

This project is created for educational purposes as part of the **Apple Swift Student Challenge 2026**.

**Copyright © 2026 Soham**

Permission is granted to use this code for learning, educational purposes, and portfolio demonstrations. For any other use, please contact the author.

---

## 📬 Contact & Links

- **GitHub**: [@SohamB4746Y](https://github.com/SohamB4746Y)
- **Project Repository**: [ColourBridge](https://github.com/SohamB4746Y/ColourBridge)
- **Swift Student Challenge**: Apple WWDC 2026

### Useful Resources
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [Color Blindness Simulator](https://www.color-blindness.com/coblis-color-blindness-simulator/)
- [Swift Programming Language](https://docs.swift.org/swift-book/)

---

<p align="center">
  <strong>Built with ❤️ and Swift</strong><br>
  Making the world more accessible, one color at a time 🌈
</p>

---

**Note**: This app is designed as an assistive tool and educational demonstration. It should not be used as the sole method for critical color-dependent tasks. If you have color-vision deficiency, consider consulting with an eye care professional for comprehensive solutions.
