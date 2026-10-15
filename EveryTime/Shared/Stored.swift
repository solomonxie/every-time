import SwiftUI

/// Codable value persisted as JSON in UserDefaults, through `StoreCodec`.
@propertyWrapper
struct Stored<Value: Codable>: DynamicProperty {
    @AppStorage private var data: Data
    private let defaultValue: Value
    private let key: String
    private let store: UserDefaults?

    init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) {
        defaultValue = wrappedValue
        self.key = key
        self.store = store
        _data = AppStorage(wrappedValue: Data(), key, store: store)
    }

    var wrappedValue: Value {
        get { StoreCodec.decode(Value.self, from: data) ?? defaultValue }
        nonmutating set {
            let defaults = store ?? AppData.defaults
            guard let new = StoreCodec.encode(newValue, replacing: defaults.data(forKey: key), key: key, in: defaults) else { return }
            data = new
        }
    }

    var projectedValue: Binding<Value> {
        Binding(get: { wrappedValue }, set: { wrappedValue = $0 })
    }
}
