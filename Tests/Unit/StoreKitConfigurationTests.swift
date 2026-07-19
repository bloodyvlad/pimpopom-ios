import Foundation
import XCTest

final class StoreKitConfigurationTests: XCTestCase {
    func testLocalCatalogMatchesAcceptedFiveProductContract() throws {
        let data = try Data(contentsOf: repositoryRoot.appending(path: "Config/PimPoPom.storekit"))
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let products = try XCTUnwrap(root["products"] as? [[String: Any]])

        let expected: [String: (type: String, price: String, familyShareable: Bool)] = [
            "com.otcsoftware.pimpopom.coins.50.v1": ("Consumable", "2.99", false),
            "com.otcsoftware.pimpopom.coins.100.v1": ("Consumable", "4.99", false),
            "com.otcsoftware.pimpopom.coins.500.v1": ("Consumable", "9.99", false),
            "com.otcsoftware.pimpopom.coins.1000.v1": ("Consumable", "14.99", false),
            "com.otcsoftware.pimpopom.removeads.lifetime": ("NonConsumable", "1.99", true),
        ]

        XCTAssertEqual(products.count, expected.count)
        XCTAssertEqual(Set(products.compactMap { $0["productID"] as? String }), Set(expected.keys))

        for product in products {
            let productID = try XCTUnwrap(product["productID"] as? String)
            let contract = try XCTUnwrap(expected[productID])
            XCTAssertEqual(product["type"] as? String, contract.type)
            XCTAssertEqual(product["displayPrice"] as? String, contract.price)
            XCTAssertEqual(product["familyShareable"] as? Bool, contract.familyShareable)
        }
    }

    func testLocalStoreKitSchemeIsDebugOnlyAndUsesOfflineCreditService() throws {
        let scheme = try String(
            contentsOf: repositoryRoot.appending(
                path: "PimPoPom.xcodeproj/xcshareddata/xcschemes/PimPoPom StoreKit Local.xcscheme"
            ),
            encoding: .utf8
        )

        XCTAssertTrue(scheme.contains("buildConfiguration = \"Debug\""))
        XCTAssertTrue(scheme.contains("argument = \"--local-storekit-credit\""))
        XCTAssertTrue(scheme.contains("identifier = \"../../Config/PimPoPom.storekit\""))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
