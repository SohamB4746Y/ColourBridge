import PackageDescription
import AppleProductTypes

/// Swift package manifest for the ColourBridge iOS application.
///
/// This manifest defines app metadata, platform constraints, runtime
/// capabilities, and the executable target used by Swift Playgrounds/Xcode.
let package = Package(
    name: "ColourBridge",
    platforms: [
        .iOS("17.0")
    ],
    products: [
        .iOSApplication(
            name: "ColourBridge",
            targets: ["AppModule"],
            bundleIdentifier: "srmist.edu.in.ColourBridge",
            teamIdentifier: "8ZSX2MP48K",
            displayVersion: "1.0",
            bundleVersion: "1",
            appIcon: .asset("AppIcon"),
            accentColor: .presetColor(.pink),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .photoLibrary(purposeString: "ColourBridge uses your photo library so you can analyze colors in saved images and charts."),
                .camera(purposeString: "ColourBridge uses the camera to sample and analyze colors in real time.")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: "."
        )
    ],
    swiftLanguageVersions: [.version("6")]
)
