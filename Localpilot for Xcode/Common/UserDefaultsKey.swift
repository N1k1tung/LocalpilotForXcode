import Foundation

@propertyWrapper
public class UserDefaultsKey<T> {
    private let key: String
    private let defaults: UserDefaults

    public init(_ defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key = key
    }

    public var wrappedValue: T? {
        get {
            defaults.object(forKey: key) as? T
        }
        set {
            defaults.setValue(newValue, forKey: key)
            defaults.synchronize()
        }
    }
}

@propertyWrapper
public class UserDefaultsNonNilKey<T> {
    private let key: String
    private let defaultValue: T
    private let defaults: UserDefaults

    public init(_ defaults: UserDefaults = .standard, key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
        self.defaults = defaults
    }

    public var wrappedValue: T {
        get {
            defaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            defaults.setValue(newValue, forKey: key)
            defaults.synchronize()
        }
    }
}
