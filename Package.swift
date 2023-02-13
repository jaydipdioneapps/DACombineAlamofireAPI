// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DACombineAlamofireAPI",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "DACombineAlamofireAPI",
            targets: ["DACombineAlamofireAPI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/tapnot/DACombineAlamofireAPI", from: "1.0.0"),
            .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.2.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "DACombineAlamofireAPI",
            dependencies: ["Alamofire"]),
        .testTarget(
            name: "DACombineAlamofireAPITests",
            dependencies: ["DACombineAlamofireAPI"]),
    ],
    swiftLanguageVersions: [.v5]

)
