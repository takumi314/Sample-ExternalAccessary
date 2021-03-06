//
//  ExternalAccessoryDispatcher.swift
//  Sample-ExternalAccessory
//
//  Created by NishiokaKohei on 2017/12/29.
//  Copyright © 2017年 Kohey.Nishioka. All rights reserved.
//

import Foundation
import ExternalAccessory

public protocol ExternalAccessoryDispatching {
    func connect()
    func close()
    func send(_ data: Data)
}

protocol EADispatcherDelegate {
    func receivedMessage<T>(message: T)
}


open class ExternalAccessoryDispatcher: NSObject, ExternalAccessoryDispatching {

    private let session: EADispatchable
    private let maxReadLength: Int

    init(_ session: EADispatchable, maxLength maxReadLength: Int = MAX_READ_LENGTH, reciever delegate: EADispatcherDelegate?) {
        self.session        = session
        self.maxReadLength  = maxReadLength
        self.delegate       = delegate
    }

    deinit {
        stop()
    }

    // MARK: - Public properties

    var protocolString: String {
        return session.protocolString ?? ""
    }

    var info: AccessoryInfo? {
        guard let accessory = session.accessory else {
            return nil
        }
        return AccessoryInfo(accessory: accessory, protocolString: protocolString)
    }

    private var delegate: EADispatcherDelegate?


    // MARK: - Public methods

    open func connect() {
        session.input?.delegate = self
        session.output?.delegate = self

        session.input?.schedule(in: .current, forMode: .commonModes)
        session.output?.schedule(in: .current, forMode: .commonModes)

        start()
    }

    open func close() {
        stop()
    }

    open func send(_ data: Data) {
        guard let code = write(data, maxLength: data.count, on: session) else {
            return
        }
        switch code {
        case (-1):
            print(session.output?.streamError?.localizedDescription ?? "Error")
            break
        case (0):
            print("Result 0: A fixed-length stream and has reached its capacity.")
            break
        default:
            print("Result: \(code) bytes written")
            break
        }
    }

    // MARK: Private properies

    private var accessory: EAAccessing? {
        return session.accessory
    }

    private var input: InputStream? {
        return session.input
    }

    private var output: OutputStream? {
        return session.output
    }

    // MARK: - Private methods

    private func start() {
        session.input?.open()
        session.output?.open()
    }

    private func stop() {
        session.input?.close()
        session.output?.close()

        session.input?.remove(from: .current, forMode: .commonModes)
        session.output?.remove(from: .current, forMode: .commonModes)
    }

    private func write(_ data: Data, maxLength length: Int, on session: EADispatchable?) -> Int? {
        return data.withUnsafeBytes {
            return session?.output?.write($0, maxLength: length)
        }
    }

}


// MARK: - StreamDelegate

extension ExternalAccessoryDispatcher: StreamDelegate {

    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case Stream.Event.hasBytesAvailable:
            print("new message received")
            readAvailableBytes(aStream as! InputStream, capacity: maxReadLength)
            break
        case Stream.Event.hasSpaceAvailable:
            print("has space available")
            break
        case Stream.Event.errorOccurred:
            print("error occurred")
            break
        case Stream.Event.endEncountered:
            print("new message received")
            stop()
            break
        default:
            print("some other event...")
            break
        }
    }

    // MARK: - Private methods

    private func readAvailableBytes(_ stream: InputStream, capacity length: Int) {
        // set up a buffer, into which you can read the incoming bytes
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: length)

        //  loop for as long as the input stream has bytes to be read
        while stream.hasBytesAvailable {
            // read bytes from the stream and put them into the buffer you pass in
            let numberOfByteRead = stream.read(buffer, maxLength: length)
            // error occured or not
            if numberOfByteRead < 0 {
                let e = stream.streamError
                print(e?.localizedDescription ?? "Error occured")
                break
            }
            // notify interested parties
            if let messageString = processedMessageString(buffer, length: numberOfByteRead) {
                delegate?.receivedMessage(message: messageString)
            }
        }
    }

    private func processedMessageString(_ buffer: UnsafeMutablePointer<UInt8>, length: Int) -> String? {
        guard let string = String(bytesNoCopy: buffer, length: length, encoding: .ascii, freeWhenDone: true) else {
            return nil
        }
        return string
    }

}

