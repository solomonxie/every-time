import Foundation
import Testing

struct PrivacyManifestTests {
    @Test func privacyManifestBundled() throws {
        #expect(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
        let widget = try #require(Bundle.main.builtInPlugInsURL?.appendingPathComponent("EveryTimeWidget.appex"))
        #expect(Bundle(url: widget)?.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") != nil)
    }
}
