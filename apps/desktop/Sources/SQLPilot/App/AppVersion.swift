import Foundation

/// The version builds stamp into Info.plist: 0.<commit count>, like Vitals.
/// make-dmg.sh and CI set both keys to the same value.
enum AppVersion {
  static var short: String { info("CFBundleShortVersionString") }
  static var build: String { info("CFBundleVersion") }

  /// "0.42", or "0.42 (7)" if a build ever carries a separate build number.
  static var display: String { build == short ? short : "\(short) (\(build))" }

  private static func info(_ key: String) -> String {
    Bundle.main.infoDictionary?[key] as? String ?? "0.0"
  }
}
