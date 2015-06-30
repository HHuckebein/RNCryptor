//
//  Cryptor.swift
//  RNCryptor
//
//  Created by Rob Napier on 6/27/15.
//  Copyright © 2015 Rob Napier. All rights reserved.
//

import Foundation
import CommonCrypto

public enum CryptorOperation: CCOperation {
    case Encrypt = 0 // CCOperation(kCCEncrypt)
    case Decrypt = 1 // CCOperation(kCCDecrypt)
}

internal class Engine: DataSinkType {
    var sink: DataSinkType

    private let cryptor: CCCryptorRef
    var error: NSError?

    init(operation: CryptorOperation, key: [UInt8], IV: [UInt8], sink: DataSinkType) {
        self.sink = sink

        var cryptorOut = CCCryptorRef()
        let result = CCCryptorCreate(
            operation.rawValue,
            CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding),
            key, key.count,
            IV,
            &cryptorOut
        )
        self.cryptor = cryptorOut
        if result != CCCryptorStatus(kCCSuccess) {
            assertionFailure("Failed to create CCCryptor")
            self.error = NSError(domain: CCErrorDomain, code: Int(result), userInfo: nil)
        }
    }

    func put(data: UnsafeBufferPointer<UInt8>) throws {
        if let err = self.error {
            throw err
        }

        let outputLength = CCCryptorGetOutputLength(self.cryptor, data.count, false)
        var output = Array<UInt8>(count: outputLength, repeatedValue: 0)  // FIXME: Reuse buffer
        var dataOutMoved: Int = 0
        try checkResult(CCCryptorUpdate(
            self.cryptor,
            data.baseAddress, data.count,
            &output, outputLength,
            &dataOutMoved))

        if dataOutMoved > 0 {
            try output.withUnsafeBufferPointer { buf -> Void in
                try self.sink.put(buf[0..<dataOutMoved])
            }
        }
    }

    func finish() throws {
        let outputLength = CCCryptorGetOutputLength(self.cryptor, 0, true)
        var output = Array<UInt8>(count: outputLength, repeatedValue: 0) // FIXME: Reuse buffer
        var dataOutMoved: Int = 0
        try checkResult(
            CCCryptorFinal(
                self.cryptor,
                &output, outputLength,
                &dataOutMoved
            )
        )

        if dataOutMoved > 0 {
            try output.withUnsafeBufferPointer {
                try self.sink.put($0[0..<dataOutMoved])
            }
        }
    }
}