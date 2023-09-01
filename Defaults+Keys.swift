import Defaults

extension Defaults.Keys {
    public static let isBypass = Key<Bool>("isBypass", default: false, suite: defaultsSuite)
    public static let message = Key<String>("message", default: "Hello World", suite: defaultsSuite)
}
