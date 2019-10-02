//
// Copyright 2010-2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
// http://aws.amazon.com/apache2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//

import Foundation

// MARK: - OTABlockRequest

/**
 Encapsulates the request of a new block for an OTA job. Subclasses NSObject for compatibility with the CBOR encoding
 library.

 Format of the map:

 ```json
 {
   "c":"<String: client token>",
   "f":<Integer: File ID from the OTAJobResponse>,
   "l":<Integer: Block size, 1024>
   "o":<Integer: Block offset>
   "b":<Byte string: Block bitmap for the full file, set to 1 if that block is not received>
   "n":<Integer: Number of blocks Requested = window size = 128>
 }
 ```

 ## Byte string
 The "b" field is a bitMap representing the whole file, with each byte of the map representing 8 blocks of the file.
 */
struct OTAWindowRequest {
    let clientToken: String
    let fileId: Int
    let blockSize: Int
    let offset: Int
    let bitmap: [UInt8]
    let numBlocks: Int
}

extension OTAWindowRequest: CBOREncodable {
    var cborEncoded: Data {
        return Data(encode())
    }

    func encode() -> [UInt8] {
        let cborWrapper: CBOR = [
            "c": CBOR(stringLiteral: clientToken),
            "f": CBOR(integerLiteral: fileId),
            "l": CBOR(integerLiteral: blockSize),
            "o": CBOR(integerLiteral: offset),
            "b": .byteString(bitmap),
            "n": CBOR(integerLiteral: numBlocks)
        ]
        return cborWrapper.encode()
    }
}

extension OTAWindowRequest: CustomDebugStringConvertible {
    var debugDescription: String {
        return """
        {
          clientToken: \(clientToken)
          fileId: \(fileId)
          blockSize: \(blockSize)
          offset: \(offset)
          bitmap: \(IoTTestHelpers.hexString(from: bitmap))
          numBlocks: \(numBlocks)
        }
        """
    }
}

// MARK: - OTAFilePayload

/// A holder for the in-process payload, used to reconstruct the full file once all blocks are received.
struct OTAFilePayload {
    /// Maximum number of blocks in a single window
    static let maxWindowSize = 128

    /// The default block size to use
    static let defaultBlockSize = 512

    /// The client token associated with this request
    let clientToken: String

    /// The file being fulfilled
    let file: OTAJobResponse.Execution.JobDocument.OTASpec.File

    /// The size of each payload block
    let blockSize: Int

    /// Size of the file being requested
    let fileSize: Int

    /// Total number of blocks required to fulfill the file
    let numBlocks: Int

    /// The responses received so far, from which the final payload will be concatenated
    var responses: [OTABlockResponse?]

    /// The OTA file is broken delivered in `fileSize / blockSize` blocks of `blockSize` bytes each. In order to keep track
    /// of the blocks delivered, the client sends a bitmap with each window request, representing the remaining unfulfilled
    /// blocks.
    var bitmapOfUnfufilledBlocks: [UInt8] {
        var digits = [UInt8]()
        for offset in stride(from: 0, to: responses.count, by: 8) {
            let bitmap = bitmapOfUnfulfilledBlocks(at: offset)
            digits.append(bitmap)
        }
        return digits
    }

    var unfufilledBlockCount: Int {
        return responses.filter { $0 == nil }.count
    }

    init(clientToken: String,
         file: OTAJobResponse.Execution.JobDocument.OTASpec.File) {
        self.clientToken = clientToken
        self.file = file
        self.blockSize = OTAFilePayload.defaultBlockSize
        self.fileSize = file.filesize

        let fileSizeDouble = Double(fileSize)
        let blockSizeDouble = Double(blockSize)
        let numBlocks = (fileSizeDouble / blockSizeDouble).rounded(FloatingPointRoundingRule.awayFromZero)

        self.numBlocks = Int(numBlocks)
        responses = Array(repeating: nil, count: self.numBlocks)
    }

    /// Get an OTAWindowRequest for the next set of unfulfilled blocks
    func nextWindowRequest() -> OTAWindowRequest {
        let numBlocks = min(unfufilledBlockCount, OTAFilePayload.maxWindowSize)
        let request = OTAWindowRequest(clientToken: clientToken,
                                       fileId: file.fileid,
                                       blockSize: blockSize,
                                       offset: 0,
                                       bitmap: bitmapOfUnfufilledBlocks,
                                       numBlocks: numBlocks)
        return request
    }

    mutating func fulfill(response: OTABlockResponse) {
        let blockIndex = response.blockIndex
        responses[blockIndex] = response
    }

    /// Get a bitmap representing the fulfilled status of blocks[offset ..< offset + 8]. A "1" means the block is
    /// *unfulfilled* Blocks are in L-R order, so the most significant bit represents the earliest block in the
    /// sequence.
    private func bitmapOfUnfulfilledBlocks(at offset: Int) -> UInt8 {
        let length = offset + 8 <= responses.count ? 8 : responses.count - offset
        let responsesToMap = responses[offset ..< (offset + length)]
        var bitmap: UInt8 = 0

        for (i, response) in responsesToMap.enumerated() {
            guard response == nil else {
                continue
            }
            let shiftWidth = 7 - i
            let bit: UInt8 = 1 << shiftWidth
            bitmap |= bit
        }

        return bitmap
    }
}

// MARK: - OTABlockResponse

/**
 A block response

 Format of the map:

 ```json
 {
   "f": <Integer: fileid>,
   "i": <Integer: block index>,
   "l": <Integer: block length>,
   "p": <HexString: binary payload>
 }
 ```
 */
struct OTABlockResponse {
    let blockLength: Int
    let fileId: Int
    let blockIndex: Int
    let payload: [UInt8]

    init?(fromCBOR cbor: CBOR?) {
        guard let cbor = cbor else {
            return nil
        }

        guard case CBOR.map(let map) = cbor else {
            return nil
        }

        guard let blockLengthCBOR = map["l"], case CBOR.unsignedInt(let blockLength) = blockLengthCBOR else {
            return nil
        }
        self.blockLength = Int(blockLength)

        guard let fileIdCBOR = map["f"], case CBOR.unsignedInt(let fileId) = fileIdCBOR else {
            return nil
        }
        self.fileId = Int(fileId)

        guard let blockIndexCBOR = map["i"], case CBOR.unsignedInt(let blockIndex) = blockIndexCBOR else {
            return nil
        }
        self.blockIndex = Int(blockIndex)

        guard let payloadCBOR = map["p"], case CBOR.byteString(let payload) = payloadCBOR else {
            return nil
        }
        self.payload = payload
    }
}
