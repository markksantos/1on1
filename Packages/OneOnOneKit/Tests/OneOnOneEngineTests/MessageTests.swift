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
        let types: [MessageType] = [.text, .screenshot, .typingStarted, .typingStopped, .readReceipt]

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

    @Test("Received remote copy preserves payload but flips ownership")
    func receivedRemoteCopy() {
        let original = Message(
            senderName: "Alice",
            body: "From another device",
            type: .text,
            isFromMe: true
        )

        let received = original.receivedFromRemote()

        #expect(received.id == original.id)
        #expect(received.senderName == original.senderName)
        #expect(received.body == original.body)
        #expect(received.type == original.type)
        #expect(received.timestamp == original.timestamp)
        #expect(received.isFromMe == false)
    }

    @Test("Screenshot payload roundtrip")
    func screenshotPayloadRoundtrip() throws {
        let payload = Data([0, 1, 2, 3, 4, 5])
        let original = Message(
            senderName: "Alice",
            body: "Screenshot",
            type: .screenshot,
            isFromMe: true,
            attachmentData: payload,
            attachmentMimeType: "image/jpeg"
        )

        let data = try original.encoded()
        let decoded = try Message.decoded(from: data)

        #expect(decoded.type == .screenshot)
        #expect(decoded.attachmentData == payload)
        #expect(decoded.attachmentMimeType == "image/jpeg")
    }
}
