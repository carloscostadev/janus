import Foundation

/// Short helper for `NSLocalizedString` against the SPM module bundle.
/// Use `L("key")` for plain strings and `L("key", args...)` for format strings.
func L(_ key: String) -> String {
    NSLocalizedString(key, bundle: .module, comment: "")
}

func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, bundle: .module, comment: ""), arguments: args)
}
