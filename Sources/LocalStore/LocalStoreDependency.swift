// LocalStoreDependency — TCA @Dependency 統合

import Foundation
import Dependencies

extension LocalStore: DependencyKey {
    public static let liveValue: LocalStore = .inMemory()  // M1 段階では SwiftData 実装は後続。inMemory を live としても代用
    public static let testValue: LocalStore = .unimplemented
    public static let previewValue: LocalStore = .inMemory()
}

extension DependencyValues {
    public var localStore: LocalStore {
        get { self[LocalStore.self] }
        set { self[LocalStore.self] = newValue }
    }
}
