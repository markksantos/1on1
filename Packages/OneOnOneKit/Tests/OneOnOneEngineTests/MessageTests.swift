import Testing
import Foundation
@testable import OneOnOneEngine

@Suite("Message Encoding/Decoding")
struct MessageTests {
    @Test("Text message roundtrip")
    func textMessageRoundtrip() throws {
        let original = Message(
            senderName: "Alice",
            body: "Hello, Bob!",
            type: .text,
            isFromMe: true
        )

        let data = try original.encoded()
        let decoded = try Message.decoded(from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.senderName == original.senderName)
        #expect(decoded.body == original.body)
        #expect(decoded.type == original.type)
        #expect(decoded.isFromMe == original.isFromMe)
    }

    @Test("All message types encode correctly")
    func allMessageTypes() throws {
        let types: [MessageType] = [.text, .typingStarted, .typingStopped, .readReceipt]

        for type in types {
            let msg = Message(senderName: "Test", body: "", type: type, isFromMe: false)
            let data = try msg.encoded()
            let decoded = try Message.decoded(from: data)
            #expect(decoded.type == type)
        }
    }

    @Test("Message identity via UUID")
    func messageIdentity() {
        let msg1 = Message(senderName: "A", body: "Hi", isFromMe: true)
        let msg2 = Message(senderName: "A", body: "Hi", isFromMe: true)
        #expect(msg1.id != msg2.id)
    }

    @Test("Empty body allowed for typing indicators")
    func emptyBody() throws {
        let msg = Message(senderName: "A", body: "", type: .typingStarted, isFromMe: true)
        let data = try msg.encoded()
        let decoded = try Message.decoded(from: data)
        #expect(decoded.body.isEmpty)
        #expect(decoded.type == .typingStarted)
    }
}
