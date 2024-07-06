// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "ZLX_Package",
    platforms: [
        .iOS(.v14), .tvOS(.v14)
    ],
    products: [
        .library(
            name: "ZLX_Package",
            targets: ["APIManager", "DownloadsManager", "LocalStorage"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ReactiveX/RxSwift.git", exact: "6.6.0"),
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.0.0"),
        .package(url: "https://github.com/hyperoslo/Cache.git", exact: "7.2.0")
    ],
    targets: [
        .target(
            name: "APIManager",
            dependencies: [
                .product(name: "RxSwift", package: "RxSwift"),
                .product(name: "RxCocoa", package: "RxSwift"), 
                 "Alamofire",
                "Cache"
            ]
        ),
        .target(
            name: "DownloadsManager",
            dependencies: ["LocalStorage"]),
        .target(
            name: "LocalStorage",
            dependencies: []),
        .testTarget(
            name: "ZLX_PackageTests",
            dependencies: ["APIManager", "DownloadsManager", "LocalStorage"]),
    ]
)
