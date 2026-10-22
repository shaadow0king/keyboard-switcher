import Testing
@testable import MistypeCore

@Test func parsesTags() {
    #expect(Version("v1.2.3")?.description == "1.2.3")
    #expect(Version("0.2")?.description == "0.2")
    #expect(Version("1.2-beta")?.description == "1.2")
    #expect(Version("latest") == nil)
    #expect(Version("") == nil)
}

@Test func comparesNumberByNumber() {
    #expect(Version("1.10")! > Version("1.9")!)
    #expect(Version("0.2")! > Version("0.1.9")!)
    #expect(Version("1.0")! == Version("1")!)
    #expect(!(Version("0.1")! > Version("0.1")!))
}
