import Foundation
import Testing
@testable import CleanerFeatures

/// L'indirizzo Buy Me a Coffee è uno solo e non porta barra finale, parametri o tracciamento.
struct SupportLinksTests {
    @Test func buyMeACoffeeIsTheExactAddressWithoutTracking() {
        let url = SupportLinks.buyMeACoffee

        #expect(url.absoluteString == "https://buymeacoffee.com/bugbrew")
        #expect(url.scheme == "https")
        #expect(url.host == "buymeacoffee.com")
        #expect(url.path == "/bugbrew")
        #expect(url.query == nil)
        #expect(url.fragment == nil)
        #expect(url.user == nil)
        #expect(url.port == nil)
        #expect(!url.absoluteString.hasSuffix("/"))
    }
}
