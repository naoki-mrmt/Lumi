// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "LumiKit",
    platforms: [.iOS("26.0"), .macOS(.v14)],
    products: [
        // Feature modules
        .library(name: "AppFeature", targets: ["AppFeature"]),
        .library(name: "MatchSetupFeature", targets: ["MatchSetupFeature"]),
        .library(name: "MatchInputFeature", targets: ["MatchInputFeature"]),
        .library(name: "MatchViewerFeature", targets: ["MatchViewerFeature"]),
        .library(name: "ReviewFeature", targets: ["ReviewFeature"]),
        .library(name: "TeamManagementFeature", targets: ["TeamManagementFeature"]),
        .library(name: "AuthFeature", targets: ["AuthFeature"]),

        // Domain modules
        .library(name: "Models", targets: ["Models"]),
        .library(name: "StatsEngine", targets: ["StatsEngine"]),
        .library(name: "ServiceOrderEngine", targets: ["ServiceOrderEngine"]),
        .library(name: "RallyTimeline", targets: ["RallyTimeline"]),

        // Infrastructure modules
        .library(name: "LocalStore", targets: ["LocalStore"]),
        .library(name: "SupabaseClient", targets: ["SupabaseClient"]),
        .library(name: "Sync", targets: ["Sync"]),
        .library(name: "PDFGenerator", targets: ["PDFGenerator"]),
        .library(name: "VideoSync", targets: ["VideoSync"]),
        .library(name: "CSVExporter", targets: ["CSVExporter"]),
        .library(name: "MatchBackup", targets: ["MatchBackup"]),
        .library(name: "Validators", targets: ["Validators"]),

        // Core modules
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Telemetry", targets: ["Telemetry"]),

        // Phase 2 Features
        .library(name: "ReportFeature", targets: ["ReportFeature"]),
        .library(name: "OpponentDatabaseFeature", targets: ["OpponentDatabaseFeature"]),
        .library(name: "VideoReviewFeature", targets: ["VideoReviewFeature"]),
        .library(name: "PlayerPageFeature", targets: ["PlayerPageFeature"]),
        .library(name: "VideoStreamFeature", targets: ["VideoStreamFeature"]),
        .library(name: "EmailAuthFeature", targets: ["EmailAuthFeature"]),
        .library(name: "TeamSwitcherFeature", targets: ["TeamSwitcherFeature"]),
        .library(name: "LegalFeature", targets: ["LegalFeature"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.15.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0"),
        .package(url: "https://github.com/getsentry/sentry-cocoa", from: "8.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
    ],
    targets: [
        // ── Core ──────────────────────────────────────────
        .target(
            name: "DesignSystem",
            dependencies: ["Models"]
        ),
        .target(
            name: "Telemetry",
            dependencies: [
                .product(name: "Sentry", package: "sentry-cocoa"),
            ]
        ),

        // ── Domain ────────────────────────────────────────
        .target(
            name: "Models",
            dependencies: []
        ),
        .target(
            name: "StatsEngine",
            dependencies: ["Models"]
        ),
        .target(
            name: "ServiceOrderEngine",
            dependencies: ["Models"]
        ),
        .target(
            name: "RallyTimeline",
            dependencies: ["Models"]
        ),

        // ── Infrastructure ────────────────────────────────
        .target(
            name: "LocalStore",
            dependencies: [
                "Models",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "SupabaseClient",
            dependencies: [
                "Models",
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .target(
            name: "Sync",
            dependencies: [
                "Models", "LocalStore", "SupabaseClient",
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),
        .target(
            name: "PDFGenerator",
            dependencies: ["Models", "StatsEngine"]
        ),
        .target(
            name: "CSVExporter",
            dependencies: ["Models", "StatsEngine"]
        ),
        .target(
            name: "MatchBackup",
            dependencies: ["Models"]
        ),
        .target(
            name: "Validators",
            dependencies: ["Models"]
        ),
        .target(
            name: "ReportFeature",
            dependencies: [
                "Models", "DesignSystem", "PDFGenerator", "StatsEngine",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "OpponentDatabaseFeature",
            dependencies: [
                "Models", "DesignSystem", "LocalStore", "StatsEngine",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "VideoReviewFeature",
            dependencies: [
                "Models", "DesignSystem", "LocalStore", "VideoSync",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "PlayerPageFeature",
            dependencies: [
                "Models", "DesignSystem", "StatsEngine",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "VideoStreamFeature",
            dependencies: [
                "DesignSystem", "VideoSync",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "EmailAuthFeature",
            dependencies: [
                "AuthFeature", "DesignSystem", "SupabaseClient",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "TeamSwitcherFeature",
            dependencies: [
                "Models", "DesignSystem", "LocalStore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "LegalFeature",
            dependencies: [
                "DesignSystem",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .target(
            name: "VideoSync",
            dependencies: [
                "Models",
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),

        // ── Feature ───────────────────────────────────────
        .target(
            name: "AppFeature",
            dependencies: [
                "DesignSystem",
                "Telemetry",
                "LocalStore",
                "Models",
                "MatchSetupFeature",
                "MatchInputFeature",
                "MatchViewerFeature",
                "ReviewFeature",
                "TeamManagementFeature",
                "AuthFeature",
                "ReportFeature",
                "OpponentDatabaseFeature",
                "VideoReviewFeature",
                "PlayerPageFeature",
                "VideoStreamFeature",
                "EmailAuthFeature",
                "TeamSwitcherFeature",
                "LegalFeature",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "MatchSetupFeature",
            dependencies: [
                "Models",
                "DesignSystem",
                "LocalStore",
                "ServiceOrderEngine",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "MatchInputFeature",
            dependencies: [
                "Models",
                "DesignSystem",
                "LocalStore",
                "StatsEngine",
                "RallyTimeline",
                "ServiceOrderEngine",
                "Sync",
                "Telemetry",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "MatchViewerFeature",
            dependencies: [
                "Models",
                "DesignSystem",
                "StatsEngine",
                "Sync",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "ReviewFeature",
            dependencies: [
                "Models",
                "DesignSystem",
                "StatsEngine",
                "PDFGenerator",
                "CSVExporter",
                "MatchBackup",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "TeamManagementFeature",
            dependencies: [
                "Models",
                "DesignSystem",
                "LocalStore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .target(
            name: "AuthFeature",
            dependencies: [
                "DesignSystem",
                "SupabaseClient",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "Supabase", package: "supabase-swift"),
            ]
        ),

        // ── Tests ─────────────────────────────────────────
        .testTarget(
            name: "ModelsTests",
            dependencies: ["Models"]
        ),
        .testTarget(
            name: "StatsEngineTests",
            dependencies: ["StatsEngine"]
        ),
        .testTarget(
            name: "ServiceOrderEngineTests",
            dependencies: ["ServiceOrderEngine"]
        ),
        .testTarget(
            name: "RallyTimelineTests",
            dependencies: ["RallyTimeline"]
        ),
        .testTarget(
            name: "SyncTests",
            dependencies: ["Sync", "Models"]
        ),
        .testTarget(
            name: "CSVExporterTests",
            dependencies: ["CSVExporter", "Models"]
        ),
        .testTarget(
            name: "MatchBackupTests",
            dependencies: ["MatchBackup", "Models"]
        ),
        .testTarget(
            name: "VideoSyncTests",
            dependencies: ["VideoSync", "Models"]
        ),
        .testTarget(
            name: "ValidatorsTests",
            dependencies: ["Validators", "Models"]
        ),
        .testTarget(
            name: "PhasesTests",
            dependencies: [
                "Models", "StatsEngine", "VideoSync", "AuthFeature", "LocalStore", "Telemetry"
            ]
        ),
        .testTarget(
            name: "E2ETests",
            dependencies: [
                "Models", "LocalStore", "ServiceOrderEngine", "StatsEngine", "RallyTimeline",
                "MatchSetupFeature", "MatchInputFeature", "MatchViewerFeature", "ReviewFeature",
                "CSVExporter", "MatchBackup",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "ReviewFeatureTests",
            dependencies: [
                "ReviewFeature",
                "Models",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            ]
        ),
        .testTarget(
            name: "AppFeatureTests",
            dependencies: [
                "AppFeature",
                "AuthFeature",
                "EmailAuthFeature",
                "LocalStore",
                "Models",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "MatchSetupFeatureTests",
            dependencies: [
                "MatchSetupFeature",
                "Models",
                "LocalStore",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "MatchInputFeatureTests",
            dependencies: [
                "MatchInputFeature",
                "MatchViewerFeature",
                "Models",
                "LocalStore",
                "ServiceOrderEngine",
                "StatsEngine",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
            ]
        ),
        .testTarget(
            name: "SnapshotTests",
            dependencies: [
                "AppFeature",
                "MatchInputFeature",
                "MatchViewerFeature",
                "ReviewFeature",
                "ReportFeature",
                "Models",
                "LocalStore",
                "ServiceOrderEngine",
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            exclude: ["README.md"]
        ),
    ]
)
