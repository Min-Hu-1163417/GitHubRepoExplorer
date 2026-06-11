import Testing
@testable import GitHubRepoExplorer

/// Small derived-value logic on the models.
@Suite("Repository model")
struct ModelTests {

    @Test(
        "displayDescription treats nil and empty as nothing to show",
        arguments: [
            (nil, nil),
            ("", nil),
            ("A real description", "A real description")
        ] as [(String?, String?)]
    )
    func displayDescription(raw: String?, expected: String?) {
        let repository = Repository.stub(description: raw)
        #expect(repository.displayDescription == expected)
    }

    @Test("isOrganization matches the owner type string")
    func isOrganization() {
        #expect(Repository.stub(ownerType: "Organization").owner.isOrganization)
        #expect(!Repository.stub(ownerType: "User").owner.isOrganization)
    }
}
