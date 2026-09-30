import XCTest
@testable import Pentaphor
final class ArtLocalizationTests: XCTestCase {
    func testAllArtHasTranslationsAndSearchUsesBothLanguages() {
        let en = AppLocalization.text(preferredLanguages: ["en"], locale: Locale(identifier: "en_US"))
        let ko = AppLocalization.text(preferredLanguages: ["ko"], locale: Locale(identifier: "ko_KR"))
        XCTAssertEqual(ArtCatalog.all.count, 60)
        for art in ArtCatalog.all {
            XCTAssertFalse(art.displayLabel(using: en).hasPrefix("art."))
            XCTAssertFalse(art.displayLabel(using: ko).hasPrefix("art."))
            XCTAssertFalse(art.displayCategory(using: en).hasPrefix("category."))
        }
        XCTAssertTrue(ArtCatalog.art("swimming").matches("swim", using: en))
        XCTAssertTrue(ArtCatalog.art("swimming").matches("수영", using: en))
        XCTAssertTrue(ArtCatalog.art("reading").matches("read", using: ko))
    }
}
