import SwiftUI

/// Codable value persisted as JSON in UserDefaults.
@propertyWrapper
struct Stored<Value: Codable>: DynamicProperty {
    @AppStorage private var data: Data
    private let defaultValue: Value

    init(wrappedValue: Value, _ key: String) {
        defaultValue = wrappedValue
        _data = AppStorage(wrappedValue: Data(), key)
    }

    var wrappedValue: Value {
        get { (try? JSONDecoder().decode(Value.self, from: data)) ?? defaultValue }
        nonmutating set { data = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
