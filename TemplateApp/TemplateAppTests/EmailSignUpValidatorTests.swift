import XCTest
@testable import TemplateApp

final class EmailSignUpValidatorTests: XCTestCase {
    func testEmailMustContainAtSymbolAndDot() {
        XCTAssertFalse(EmailSignUpValidator.isValidEmail("userexample.com"))
        XCTAssertFalse(EmailSignUpValidator.isValidEmail("user@examplecom"))
        XCTAssertTrue(EmailSignUpValidator.isValidEmail("user@example.com"))
    }

    func testFormRequiresMatchingPasswords() {
        XCTAssertFalse(
            EmailSignUpValidator.isFormValid(
                email: "user@example.com",
                password: "Password1234",
                confirmPassword: "Password0000"
            )
        )

        XCTAssertTrue(
            EmailSignUpValidator.isFormValid(
                email: "user@example.com",
                password: "Password1234",
                confirmPassword: "Password1234"
            )
        )
    }
}
