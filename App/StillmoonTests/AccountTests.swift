import Testing
@testable import Stillmoon

struct AccountTests {
    @Test func providerButtonTitles() {
        #expect(ProviderButtons.title(.apple, .logIn) == "Continue with Apple")
        #expect(ProviderButtons.title(.google, .logIn) == "Continue with Google")
        #expect(ProviderButtons.title(.apple, .signUp) == "Sign up with Apple")
        #expect(ProviderButtons.title(.google, .signUp) == "Sign up with Google")
    }
}
