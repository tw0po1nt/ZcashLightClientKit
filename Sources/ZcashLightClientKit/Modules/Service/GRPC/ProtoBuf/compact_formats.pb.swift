// DO NOT EDIT.
// swift-format-ignore-file
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: compact_formats.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

// Copyright (c) 2019-2021 The Zcash developers
// Distributed under the MIT software license, see the accompanying
// file COPYING or https://www.opensource.org/licenses/mit-license.php .

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

/// ChainMetadata represents information about the state of the chain as of a given block.
struct ChainMetadata {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// the size of the Sapling note commitment tree as of the end of this block
  var saplingCommitmentTreeSize: UInt32 = 0

  /// the size of the Orchard note commitment tree as of the end of this block
  var orchardCommitmentTreeSize: UInt32 = 0

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

/// CompactBlock is a packaging of ONLY the data from a block that's needed to:
///   1. Detect a payment to your shielded Sapling address
///   2. Detect a spend of your shielded Sapling notes
///   3. Update your witnesses to generate new Sapling spend proofs.
struct CompactBlock {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// the version of this wire format, for storage
  var protoVersion: UInt32 = 0

  /// the height of this block
  var height: UInt64 = 0

  /// the ID (hash) of this block, same as in block explorers
  var hash: Data = Data()

  /// the ID (hash) of this block's predecessor
  var prevHash: Data = Data()

  /// Unix epoch time when the block was mined
  var time: UInt32 = 0

  /// (hash, prevHash, and time) OR (full header)
  var header: Data = Data()

  /// zero or more compact transactions from this block
  var vtx: [CompactTx] = []

  /// information about the state of the chain as of this block
  var chainMetadata: ChainMetadata {
    get {return _chainMetadata ?? ChainMetadata()}
    set {_chainMetadata = newValue}
  }
  /// Returns true if `chainMetadata` has been explicitly set.
  var hasChainMetadata: Bool {return self._chainMetadata != nil}
  /// Clears the value of `chainMetadata`. Subsequent reads from it will return its default value.
  mutating func clearChainMetadata() {self._chainMetadata = nil}

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _chainMetadata: ChainMetadata? = nil
}

/// CompactTx contains the minimum information for a wallet to know if this transaction
/// is relevant to it (either pays to it or spends from it) via shielded elements
/// only. This message will not encode a transparent-to-transparent transaction.
struct CompactTx {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// Index and hash will allow the receiver to call out to chain
  /// explorers or other data structures to retrieve more information
  /// about this transaction.
  var index: UInt64 = 0

  /// the ID (hash) of this transaction, same as in block explorers
  var hash: Data = Data()

  /// The transaction fee: present if server can provide. In the case of a
  /// stateless server and a transaction with transparent inputs, this will be
  /// unset because the calculation requires reference to prior transactions.
  /// If there are no transparent inputs, the fee will be calculable as:
  ///    valueBalanceSapling + valueBalanceOrchard + sum(vPubNew) - sum(vPubOld) - sum(tOut)
  var fee: UInt32 = 0

  var spends: [CompactSaplingSpend] = []

  var outputs: [CompactSaplingOutput] = []

  var actions: [CompactOrchardAction] = []

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

/// CompactSaplingSpend is a Sapling Spend Description as described in 7.3 of the Zcash
/// protocol specification.
struct CompactSaplingSpend {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// nullifier (see the Zcash protocol specification)
  var nf: Data = Data()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

/// output encodes the `cmu` field, `ephemeralKey` field, and a 52-byte prefix of the
/// `encCiphertext` field of a Sapling Output Description. These fields are described in
/// section 7.4 of the Zcash protocol spec:
/// https://zips.z.cash/protocol/protocol.pdf#outputencodingandconsensus
/// Total size is 116 bytes.
struct CompactSaplingOutput {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// note commitment u-coordinate
  var cmu: Data = Data()

  /// ephemeral public key
  var ephemeralKey: Data = Data()

  /// first 52 bytes of ciphertext
  var ciphertext: Data = Data()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

/// https://github.com/zcash/zips/blob/main/zip-0225.rst#orchard-action-description-orchardaction
/// (but not all fields are needed)
struct CompactOrchardAction {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// [32] The nullifier of the input note
  var nullifier: Data = Data()

  /// [32] The x-coordinate of the note commitment for the output note
  var cmx: Data = Data()

  /// [32] An encoding of an ephemeral Pallas public key
  var ephemeralKey: Data = Data()

  /// [52] The first 52 bytes of the encCiphertext field
  var ciphertext: Data = Data()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

#if swift(>=5.5) && canImport(_Concurrency)
extension ChainMetadata: @unchecked Sendable {}
extension CompactBlock: @unchecked Sendable {}
extension CompactTx: @unchecked Sendable {}
extension CompactSaplingSpend: @unchecked Sendable {}
extension CompactSaplingOutput: @unchecked Sendable {}
extension CompactOrchardAction: @unchecked Sendable {}
#endif  // swift(>=5.5) && canImport(_Concurrency)

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "cash.z.wallet.sdk.rpc"

extension ChainMetadata: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".ChainMetadata"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "saplingCommitmentTreeSize"),
    2: .same(proto: "orchardCommitmentTreeSize"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt32Field(value: &self.saplingCommitmentTreeSize) }()
      case 2: try { try decoder.decodeSingularUInt32Field(value: &self.orchardCommitmentTreeSize) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.saplingCommitmentTreeSize != 0 {
      try visitor.visitSingularUInt32Field(value: self.saplingCommitmentTreeSize, fieldNumber: 1)
    }
    if self.orchardCommitmentTreeSize != 0 {
      try visitor.visitSingularUInt32Field(value: self.orchardCommitmentTreeSize, fieldNumber: 2)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: ChainMetadata, rhs: ChainMetadata) -> Bool {
    if lhs.saplingCommitmentTreeSize != rhs.saplingCommitmentTreeSize {return false}
    if lhs.orchardCommitmentTreeSize != rhs.orchardCommitmentTreeSize {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension CompactBlock: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".CompactBlock"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "protoVersion"),
    2: .same(proto: "height"),
    3: .same(proto: "hash"),
    4: .same(proto: "prevHash"),
    5: .same(proto: "time"),
    6: .same(proto: "header"),
    7: .same(proto: "vtx"),
    8: .same(proto: "chainMetadata"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt32Field(value: &self.protoVersion) }()
      case 2: try { try decoder.decodeSingularUInt64Field(value: &self.height) }()
      case 3: try { try decoder.decodeSingularBytesField(value: &self.hash) }()
      case 4: try { try decoder.decodeSingularBytesField(value: &self.prevHash) }()
      case 5: try { try decoder.decodeSingularUInt32Field(value: &self.time) }()
      case 6: try { try decoder.decodeSingularBytesField(value: &self.header) }()
      case 7: try { try decoder.decodeRepeatedMessageField(value: &self.vtx) }()
      case 8: try { try decoder.decodeSingularMessageField(value: &self._chainMetadata) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if self.protoVersion != 0 {
      try visitor.visitSingularUInt32Field(value: self.protoVersion, fieldNumber: 1)
    }
    if self.height != 0 {
      try visitor.visitSingularUInt64Field(value: self.height, fieldNumber: 2)
    }
    if !self.hash.isEmpty {
      try visitor.visitSingularBytesField(value: self.hash, fieldNumber: 3)
    }
    if !self.prevHash.isEmpty {
      try visitor.visitSingularBytesField(value: self.prevHash, fieldNumber: 4)
    }
    if self.time != 0 {
      try visitor.visitSingularUInt32Field(value: self.time, fieldNumber: 5)
    }
    if !self.header.isEmpty {
      try visitor.visitSingularBytesField(value: self.header, fieldNumber: 6)
    }
    if !self.vtx.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.vtx, fieldNumber: 7)
    }
    try { if let v = self._chainMetadata {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 8)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: CompactBlock, rhs: CompactBlock) -> Bool {
    if lhs.protoVersion != rhs.protoVersion {return false}
    if lhs.height != rhs.height {return false}
    if lhs.hash != rhs.hash {return false}
    if lhs.prevHash != rhs.prevHash {return false}
    if lhs.time != rhs.time {return false}
    if lhs.header != rhs.header {return false}
    if lhs.vtx != rhs.vtx {return false}
    if lhs._chainMetadata != rhs._chainMetadata {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension CompactTx: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".CompactTx"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "index"),
    2: .same(proto: "hash"),
    3: .same(proto: "fee"),
    4: .same(proto: "spends"),
    5: .same(proto: "outputs"),
    6: .same(proto: "actions"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt64Field(value: &self.index) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self.hash) }()
      case 3: try { try decoder.decodeSingularUInt32Field(value: &self.fee) }()
      case 4: try { try decoder.decodeRepeatedMessageField(value: &self.spends) }()
      case 5: try { try decoder.decodeRepeatedMessageField(value: &self.outputs) }()
      case 6: try { try decoder.decodeRepeatedMessageField(value: &self.actions) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if self.index != 0 {
      try visitor.visitSingularUInt64Field(value: self.index, fieldNumber: 1)
    }
    if !self.hash.isEmpty {
      try visitor.visitSingularBytesField(value: self.hash, fieldNumber: 2)
    }
    if self.fee != 0 {
      try visitor.visitSingularUInt32Field(value: self.fee, fieldNumber: 3)
    }
    if !self.spends.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.spends, fieldNumber: 4)
    }
    if !self.outputs.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.outputs, fieldNumber: 5)
    }
    if !self.actions.isEmpty {
      try visitor.visitRepeatedMessageField(value: self.actions, fieldNumber: 6)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: CompactTx, rhs: CompactTx) -> Bool {
    if lhs.index != rhs.index {return false}
    if lhs.hash != rhs.hash {return false}
    if lhs.fee != rhs.fee {return false}
    if lhs.spends != rhs.spends {return false}
    if lhs.outputs != rhs.outputs {return false}
    if lhs.actions != rhs.actions {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension CompactSaplingSpend: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".CompactSaplingSpend"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "nf"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.nf) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.nf.isEmpty {
      try visitor.visitSingularBytesField(value: self.nf, fieldNumber: 1)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: CompactSaplingSpend, rhs: CompactSaplingSpend) -> Bool {
    if lhs.nf != rhs.nf {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension CompactSaplingOutput: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".CompactSaplingOutput"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "cmu"),
    2: .same(proto: "ephemeralKey"),
    3: .same(proto: "ciphertext"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.cmu) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self.ephemeralKey) }()
      case 3: try { try decoder.decodeSingularBytesField(value: &self.ciphertext) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.cmu.isEmpty {
      try visitor.visitSingularBytesField(value: self.cmu, fieldNumber: 1)
    }
    if !self.ephemeralKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.ephemeralKey, fieldNumber: 2)
    }
    if !self.ciphertext.isEmpty {
      try visitor.visitSingularBytesField(value: self.ciphertext, fieldNumber: 3)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: CompactSaplingOutput, rhs: CompactSaplingOutput) -> Bool {
    if lhs.cmu != rhs.cmu {return false}
    if lhs.ephemeralKey != rhs.ephemeralKey {return false}
    if lhs.ciphertext != rhs.ciphertext {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension CompactOrchardAction: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".CompactOrchardAction"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .same(proto: "nullifier"),
    2: .same(proto: "cmx"),
    3: .same(proto: "ephemeralKey"),
    4: .same(proto: "ciphertext"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularBytesField(value: &self.nullifier) }()
      case 2: try { try decoder.decodeSingularBytesField(value: &self.cmx) }()
      case 3: try { try decoder.decodeSingularBytesField(value: &self.ephemeralKey) }()
      case 4: try { try decoder.decodeSingularBytesField(value: &self.ciphertext) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.nullifier.isEmpty {
      try visitor.visitSingularBytesField(value: self.nullifier, fieldNumber: 1)
    }
    if !self.cmx.isEmpty {
      try visitor.visitSingularBytesField(value: self.cmx, fieldNumber: 2)
    }
    if !self.ephemeralKey.isEmpty {
      try visitor.visitSingularBytesField(value: self.ephemeralKey, fieldNumber: 3)
    }
    if !self.ciphertext.isEmpty {
      try visitor.visitSingularBytesField(value: self.ciphertext, fieldNumber: 4)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: CompactOrchardAction, rhs: CompactOrchardAction) -> Bool {
    if lhs.nullifier != rhs.nullifier {return false}
    if lhs.cmx != rhs.cmx {return false}
    if lhs.ephemeralKey != rhs.ephemeralKey {return false}
    if lhs.ciphertext != rhs.ciphertext {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}
