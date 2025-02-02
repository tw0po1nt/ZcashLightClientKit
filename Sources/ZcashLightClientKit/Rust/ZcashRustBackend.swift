//
//  ZcashRustBackend.swift
//  ZcashLightClientKit
//
//  Created by Jack Grigg on 5/8/19.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//
// swiftlint:disable type_body_length
import Foundation
import libzcashlc

let globalDBLock = NSLock()

actor ZcashRustBackend: ZcashRustBackendWelding {
    let minimumConfirmations: UInt32 = 10
    let useZIP317Fees = false

    let dbData: (String, UInt)
    let fsBlockDbRoot: (String, UInt)
    let spendParamsPath: (String, UInt)
    let outputParamsPath: (String, UInt)
    let keyDeriving: ZcashKeyDerivationBackendWelding

    nonisolated let networkType: NetworkType

    static var tracingEnabled = false
    /// Creates instance of `ZcashRustBackend`.
    /// - Parameters:
    ///   - dbData: `URL` pointing to file where data database will be.
    ///   - fsBlockDbRoot: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    ///                    this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    ///                    format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    ///   - spendParamsPath: `URL` pointing to spend parameters file.
    ///   - outputParamsPath: `URL` pointing to output parameters file.
    ///   - networkType: Network type to use.
    ///   - enableTracing: this sets up whether the tracing system will dump logs onto the OSLogger system or not.
    ///   **Important note:** this will enable the tracing **for all instances** of ZcashRustBackend, not only for this one.
    init(dbData: URL, fsBlockDbRoot: URL, spendParamsPath: URL, outputParamsPath: URL, networkType: NetworkType, enableTracing: Bool = false) {
        self.dbData = dbData.osStr()
        self.fsBlockDbRoot = fsBlockDbRoot.osPathStr()
        self.spendParamsPath = spendParamsPath.osPathStr()
        self.outputParamsPath = outputParamsPath.osPathStr()
        self.networkType = networkType
        self.keyDeriving = ZcashKeyDerivationBackend(networkType: networkType)

        if enableTracing && !Self.tracingEnabled {
            Self.tracingEnabled = true
            Self.enableTracing()
        }
    }

    func createAccount(seed: [UInt8], treeState: TreeState, recoverUntil: UInt32?) async throws -> UnifiedSpendingKey {
        var rUntil: Int64 = -1
        
        if let recoverUntil {
            rUntil = Int64(recoverUntil)
        }
        
        let treeStateBytes = try treeState.serializedData(partial: false).bytes
        
        globalDBLock.lock()
        let ffiBinaryKeyPtr = zcashlc_create_account(
            dbData.0,
            dbData.1,
            seed,
            UInt(seed.count),
            treeStateBytes,
            UInt(treeStateBytes.count),
            rUntil,
            networkType.networkId
        )
        globalDBLock.unlock()

        guard let ffiBinaryKeyPtr else {
            throw ZcashError.rustCreateAccount(lastErrorMessage(fallback: "`createAccount` failed with unknown error"))
        }

        defer { zcashlc_free_binary_key(ffiBinaryKeyPtr) }

        return ffiBinaryKeyPtr.pointee.unsafeToUnifiedSpendingKey(network: networkType)
    }

    func createToAddress(
        usk: UnifiedSpendingKey,
        to address: String,
        value: Int64,
        memo: MemoBytes?
    ) async throws -> Data {
        var contiguousTxIdBytes = ContiguousArray<UInt8>([UInt8](repeating: 0x0, count: 32))

        globalDBLock.lock()
        let success = contiguousTxIdBytes.withUnsafeMutableBufferPointer { txIdBytePtr in
            usk.bytes.withUnsafeBufferPointer { uskPtr in
                zcashlc_create_to_address(
                    dbData.0,
                    dbData.1,
                    uskPtr.baseAddress,
                    UInt(usk.bytes.count),
                    [CChar](address.utf8CString),
                    value,
                    memo?.bytes,
                    spendParamsPath.0,
                    spendParamsPath.1,
                    outputParamsPath.0,
                    outputParamsPath.1,
                    networkType.networkId,
                    minimumConfirmations,
                    useZIP317Fees,
                    txIdBytePtr.baseAddress
                )
            }
        }
        globalDBLock.unlock()

        guard success else {
            throw ZcashError.rustCreateToAddress(lastErrorMessage(fallback: "`createToAddress` failed with unknown error"))
        }

        return contiguousTxIdBytes.withUnsafeBufferPointer { txIdBytePtr in
            Data(txIdBytePtr)
        }
    }

    func decryptAndStoreTransaction(txBytes: [UInt8], minedHeight: Int32) async throws {
        globalDBLock.lock()
        let result = zcashlc_decrypt_and_store_transaction(
            dbData.0,
            dbData.1,
            txBytes,
            UInt(txBytes.count),
            UInt32(minedHeight),
            networkType.networkId
        )
        globalDBLock.unlock()

        guard result != 0 else {
            throw ZcashError.rustDecryptAndStoreTransaction(lastErrorMessage(fallback: "`decryptAndStoreTransaction` failed with unknown error"))
        }
    }

    func getBalance(account: Int32) async throws -> Int64 {
        globalDBLock.lock()
        let balance = zcashlc_get_balance(dbData.0, dbData.1, account, networkType.networkId)
        globalDBLock.unlock()

        guard balance >= 0 else {
            throw ZcashError.rustGetBalance(Int(account), lastErrorMessage(fallback: "Error getting total balance from account \(account)"))
        }

        return balance
    }

    func getCurrentAddress(account: Int32) async throws -> UnifiedAddress {
        globalDBLock.lock()
        let addressCStr = zcashlc_get_current_address(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId
        )
        globalDBLock.unlock()

        guard let addressCStr else {
            throw ZcashError.rustGetCurrentAddress(lastErrorMessage(fallback: "`getCurrentAddress` failed with unknown error"))
        }

        defer { zcashlc_string_free(addressCStr) }

        guard let address = String(validatingUTF8: addressCStr) else {
            throw ZcashError.rustGetCurrentAddressInvalidAddress
        }

        return UnifiedAddress(validatedEncoding: address, networkType: networkType)
    }

    func getNearestRewindHeight(height: Int32) async throws -> Int32 {
        globalDBLock.lock()
        let result = zcashlc_get_nearest_rewind_height(
            dbData.0,
            dbData.1,
            height,
            networkType.networkId
        )
        globalDBLock.unlock()

        guard result > 0 else {
            throw ZcashError.rustGetNearestRewindHeight(lastErrorMessage(fallback: "`getNearestRewindHeight` failed with unknown error"))
        }

        return result
    }

    func getNextAvailableAddress(account: Int32) async throws -> UnifiedAddress {
        globalDBLock.lock()
        let addressCStr = zcashlc_get_next_available_address(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId
        )
        globalDBLock.unlock()

        guard let addressCStr else {
            throw ZcashError.rustGetNextAvailableAddress(lastErrorMessage(fallback: "`getNextAvailableAddress` failed with unknown error"))
        }

        defer { zcashlc_string_free(addressCStr) }

        guard let address = String(validatingUTF8: addressCStr) else {
            throw ZcashError.rustGetNextAvailableAddressInvalidAddress
        }

        return UnifiedAddress(validatedEncoding: address, networkType: networkType)
    }

    func getMemo(txId: Data, outputIndex: UInt16) async throws -> Memo? {
        guard txId.count == 32 else {
            throw ZcashError.rustGetMemoInvalidTxIdLength
        }

        var contiguousMemoBytes = ContiguousArray<UInt8>(MemoBytes.empty().bytes)
        var success = false

        globalDBLock.lock()
        contiguousMemoBytes.withUnsafeMutableBufferPointer { memoBytePtr in
            success = zcashlc_get_memo(dbData.0, dbData.1, txId.bytes, outputIndex, memoBytePtr.baseAddress, networkType.networkId)
        }
        globalDBLock.unlock()

        guard success else { return nil }

        return (try? MemoBytes(contiguousBytes: contiguousMemoBytes)).flatMap { try? $0.intoMemo() }
    }

    func getTransparentBalance(account: Int32) async throws -> Int64 {
        guard account >= 0 else {
            throw ZcashError.rustGetTransparentBalanceNegativeAccount(Int(account))
        }

        globalDBLock.lock()
        let balance = zcashlc_get_total_transparent_balance_for_account(
            dbData.0,
            dbData.1,
            networkType.networkId,
            account
        )
        globalDBLock.unlock()

        guard balance >= 0 else {
            throw ZcashError.rustGetTransparentBalance(
                Int(account),
                lastErrorMessage(fallback: "Error getting Total Transparent balance from account \(account)")
            )
        }

        return balance
    }

    func getVerifiedBalance(account: Int32) async throws -> Int64 {
        globalDBLock.lock()
        let balance = zcashlc_get_verified_balance(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId,
            minimumConfirmations
        )
        globalDBLock.unlock()

        guard balance >= 0 else {
            throw ZcashError.rustGetVerifiedBalance(
                Int(account),
                lastErrorMessage(fallback: "Error getting verified balance from account \(account)")
            )
        }

        return balance
    }

    func getVerifiedTransparentBalance(account: Int32) async throws -> Int64 {
        guard account >= 0 else {
            throw ZcashError.rustGetVerifiedTransparentBalanceNegativeAccount(Int(account))
        }

        globalDBLock.lock()
        let balance = zcashlc_get_verified_transparent_balance_for_account(
            dbData.0,
            dbData.1,
            networkType.networkId,
            account,
            minimumConfirmations
        )
        globalDBLock.unlock()

        guard balance >= 0 else {
            throw ZcashError.rustGetVerifiedTransparentBalance(
                Int(account),
                lastErrorMessage(fallback: "Error getting verified transparent balance from account \(account)")
            )
        }

        return balance
    }

    func initDataDb(seed: [UInt8]?) async throws -> DbInitResult {
        globalDBLock.lock()
        let initResult = zcashlc_init_data_database(dbData.0, dbData.1, seed, UInt(seed?.count ?? 0), networkType.networkId)
        globalDBLock.unlock()

        switch initResult {
        case 0: // ok
            return DbInitResult.success
        case 1:
            return DbInitResult.seedRequired
        default:
            throw ZcashError.rustInitDataDb(lastErrorMessage(fallback: "`initDataDb` failed with unknown error"))
        }
    }

    func initBlockMetadataDb() async throws {
        globalDBLock.lock()
        let result = zcashlc_init_block_metadata_db(fsBlockDbRoot.0, fsBlockDbRoot.1)
        globalDBLock.unlock()

        guard result else {
            throw ZcashError.rustInitBlockMetadataDb(lastErrorMessage(fallback: "`initBlockMetadataDb` failed with unknown error"))
        }
    }

    func writeBlocksMetadata(blocks: [ZcashCompactBlock]) async throws {
        var ffiBlockMetaVec: [FFIBlockMeta] = []

        for block in blocks {
            let meta = block.meta
            let hashPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: meta.hash.count)

            let contiguousHashBytes = ContiguousArray(meta.hash.bytes)

            let result: Void? = contiguousHashBytes.withContiguousStorageIfAvailable { hashBytesPtr in
                // swiftlint:disable:next force_unwrapping
                hashPtr.initialize(from: hashBytesPtr.baseAddress!, count: hashBytesPtr.count)
            }

            guard result != nil else {
                defer {
                    hashPtr.deallocate()
                    ffiBlockMetaVec.deallocateElements()
                }
                throw ZcashError.rustWriteBlocksMetadataAllocationProblem
            }

            ffiBlockMetaVec.append(
                FFIBlockMeta(
                    height: UInt32(block.height),
                    block_hash_ptr: hashPtr,
                    block_hash_ptr_len: UInt(contiguousHashBytes.count),
                    block_time: meta.time,
                    sapling_outputs_count: meta.saplingOutputs,
                    orchard_actions_count: meta.orchardOutputs
                )
            )
        }

        var contiguousFFIBlocks = ContiguousArray(ffiBlockMetaVec)

        let len = UInt(contiguousFFIBlocks.count)

        let fsBlocks = UnsafeMutablePointer<FFIBlocksMeta>.allocate(capacity: 1)

        defer { ffiBlockMetaVec.deallocateElements() }

        try contiguousFFIBlocks.withContiguousMutableStorageIfAvailable { ptr in
            var meta = FFIBlocksMeta()
            meta.ptr = ptr.baseAddress
            meta.len = len

            fsBlocks.initialize(to: meta)

            globalDBLock.lock()
            let res = zcashlc_write_block_metadata(fsBlockDbRoot.0, fsBlockDbRoot.1, fsBlocks)
            globalDBLock.unlock()

            guard res else {
                throw ZcashError.rustWriteBlocksMetadata(lastErrorMessage(fallback: "`writeBlocksMetadata` failed with unknown error"))
            }
        }
    }

    func latestCachedBlockHeight() async throws -> BlockHeight {
        globalDBLock.lock()
        let height = zcashlc_latest_cached_block_height(fsBlockDbRoot.0, fsBlockDbRoot.1)
        globalDBLock.unlock()

        if height >= 0 {
            return BlockHeight(height)
        } else if height == -1 {
            return BlockHeight.empty()
        } else {
            throw ZcashError.rustLatestCachedBlockHeight(lastErrorMessage(fallback: "`latestCachedBlockHeight` failed with unknown error"))
        }
    }

    func listTransparentReceivers(account: Int32) async throws -> [TransparentAddress] {
        globalDBLock.lock()
        let encodedKeysPtr = zcashlc_list_transparent_receivers(
            dbData.0,
            dbData.1,
            account,
            networkType.networkId
        )
        globalDBLock.unlock()

        guard let encodedKeysPtr else {
            throw ZcashError.rustListTransparentReceivers(lastErrorMessage(fallback: "`listTransparentReceivers` failed with unknown error"))
        }

        defer { zcashlc_free_keys(encodedKeysPtr) }

        var addresses: [TransparentAddress] = []

        for i in (0 ..< Int(encodedKeysPtr.pointee.len)) {
            let key = encodedKeysPtr.pointee.ptr.advanced(by: i).pointee

            guard let taddrStr = String(validatingUTF8: key.encoding) else {
                throw ZcashError.rustListTransparentReceiversInvalidAddress
            }

            addresses.append(
                TransparentAddress(validatedEncoding: taddrStr)
            )
        }

        return addresses
    }

    func putUnspentTransparentOutput(
        txid: [UInt8],
        index: Int,
        script: [UInt8],
        value: Int64,
        height: BlockHeight
    ) async throws {
        globalDBLock.lock()
        let result = zcashlc_put_utxo(
            dbData.0,
            dbData.1,
            txid,
            UInt(txid.count),
            Int32(index),
            script,
            UInt(script.count),
            value,
            Int32(height),
            networkType.networkId
        )
        globalDBLock.unlock()

        guard result else {
            throw ZcashError.rustPutUnspentTransparentOutput(lastErrorMessage(fallback: "`putUnspentTransparentOutput` failed with unknown error"))
        }
    }

    func rewindToHeight(height: Int32) async throws {
        globalDBLock.lock()
        let result = zcashlc_rewind_to_height(dbData.0, dbData.1, height, networkType.networkId)
        globalDBLock.unlock()

        guard result else {
            throw ZcashError.rustRewindToHeight(height, lastErrorMessage(fallback: "`rewindToHeight` failed with unknown error"))
        }
    }

    func rewindCacheToHeight(height: Int32) async throws {
        globalDBLock.lock()
        let result = zcashlc_rewind_fs_block_cache_to_height(fsBlockDbRoot.0, fsBlockDbRoot.1, height)
        globalDBLock.unlock()

        guard result else {
            throw ZcashError.rustRewindCacheToHeight(lastErrorMessage(fallback: "`rewindCacheToHeight` failed with unknown error"))
        }
    }

    func putSaplingSubtreeRoots(startIndex: UInt64, roots: [SubtreeRoot]) async throws {
        var ffiSubtreeRootsVec: [FfiSubtreeRoot] = []

        for root in roots {
            let hashPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: root.rootHash.count)

            let contiguousHashBytes = ContiguousArray(root.rootHash.bytes)

            let result: Void? = contiguousHashBytes.withContiguousStorageIfAvailable { hashBytesPtr in
                // swiftlint:disable:next force_unwrapping
                hashPtr.initialize(from: hashBytesPtr.baseAddress!, count: hashBytesPtr.count)
            }

            guard result != nil else {
                defer {
                    hashPtr.deallocate()
                    ffiSubtreeRootsVec.deallocateElements()
                }
                throw ZcashError.rustPutSaplingSubtreeRootsAllocationProblem
            }

            ffiSubtreeRootsVec.append(
                FfiSubtreeRoot(
                    root_hash_ptr: hashPtr,
                    root_hash_ptr_len: UInt(contiguousHashBytes.count),
                    completing_block_height: UInt32(root.completingBlockHeight)
                )
            )
        }

        var contiguousFfiRoots = ContiguousArray(ffiSubtreeRootsVec)

        let len = UInt(contiguousFfiRoots.count)

        let rootsPtr = UnsafeMutablePointer<FfiSubtreeRoots>.allocate(capacity: 1)

        defer {
            ffiSubtreeRootsVec.deallocateElements()
            rootsPtr.deallocate()
        }

        try contiguousFfiRoots.withContiguousMutableStorageIfAvailable { ptr in
            var roots = FfiSubtreeRoots()
            roots.ptr = ptr.baseAddress
            roots.len = len

            rootsPtr.initialize(to: roots)

            globalDBLock.lock()
            let res = zcashlc_put_sapling_subtree_roots(dbData.0, dbData.1, startIndex, rootsPtr, networkType.networkId)
            globalDBLock.unlock()

            guard res else {
                throw ZcashError.rustPutSaplingSubtreeRoots(lastErrorMessage(fallback: "`putSaplingSubtreeRoots` failed with unknown error"))
            }
        }
    }

    func updateChainTip(height: Int32) async throws {
        globalDBLock.lock()
        let result = zcashlc_update_chain_tip(dbData.0, dbData.1, height, networkType.networkId)
        globalDBLock.unlock()

        guard result else {
            throw ZcashError.rustUpdateChainTip(lastErrorMessage(fallback: "`updateChainTip` failed with unknown error"))
        }
    }

    func fullyScannedHeight() async throws -> BlockHeight? {
        globalDBLock.lock()
        let height = zcashlc_fully_scanned_height(dbData.0, dbData.1, networkType.networkId)
        globalDBLock.unlock()

        if height >= 0 {
            return BlockHeight(height)
        } else if height == -1 {
            return nil
        } else {
            throw ZcashError.rustFullyScannedHeight(lastErrorMessage(fallback: "`fullyScannedHeight` failed with unknown error"))
        }
    }

    func maxScannedHeight() async throws -> BlockHeight? {
        globalDBLock.lock()
        let height = zcashlc_max_scanned_height(dbData.0, dbData.1, networkType.networkId)
        globalDBLock.unlock()

        if height >= 0 {
            return BlockHeight(height)
        } else if height == -1 {
            return nil
        } else {
            throw ZcashError.rustMaxScannedHeight(lastErrorMessage(fallback: "`maxScannedHeight` failed with unknown error"))
        }
    }

    func getScanProgress() async throws -> ScanProgress? {
        globalDBLock.lock()
        let result = zcashlc_get_scan_progress(dbData.0, dbData.1, networkType.networkId)
        globalDBLock.unlock()

        if result.denominator == 0 {
            switch result.numerator {
            case 0:
                return nil
            default:
                throw ZcashError.rustGetScanProgress(lastErrorMessage(fallback: "`getScanProgress` failed with unknown error"))
            }
        } else {
            return ScanProgress(numerator: result.numerator, denominator: result.denominator)
        }
    }

    func suggestScanRanges() async throws -> [ScanRange] {
        globalDBLock.lock()
        let scanRangesPtr = zcashlc_suggest_scan_ranges(dbData.0, dbData.1, networkType.networkId)
        globalDBLock.unlock()

        guard let scanRangesPtr else {
            throw ZcashError.rustSuggestScanRanges(lastErrorMessage(fallback: "`suggestScanRanges` failed with unknown error"))
        }

        defer { zcashlc_free_scan_ranges(scanRangesPtr) }

        var scanRanges: [ScanRange] = []

        for i in (0 ..< Int(scanRangesPtr.pointee.len)) {
            let scanRange = scanRangesPtr.pointee.ptr.advanced(by: i).pointee

            scanRanges.append(
                ScanRange(
                    range: Range(uncheckedBounds: (
                        BlockHeight(scanRange.start),
                        BlockHeight(scanRange.end)
                    )),
                    priority: ScanRange.Priority(scanRange.priority)
                )
            )
        }

        return scanRanges
    }

    func scanBlocks(fromHeight: Int32, limit: UInt32 = 0) async throws {
        globalDBLock.lock()
        let result = zcashlc_scan_blocks(fsBlockDbRoot.0, fsBlockDbRoot.1, dbData.0, dbData.1, fromHeight, limit, networkType.networkId)
        globalDBLock.unlock()

        guard result != 0 else {
            throw ZcashError.rustScanBlocks(lastErrorMessage(fallback: "`scanBlocks` failed with unknown error"))
        }
    }

    func shieldFunds(
        usk: UnifiedSpendingKey,
        memo: MemoBytes?,
        shieldingThreshold: Zatoshi
    ) async throws -> Data {
        var contiguousTxIdBytes = ContiguousArray<UInt8>([UInt8](repeating: 0x0, count: 32))

        globalDBLock.lock()
        let success = contiguousTxIdBytes.withUnsafeMutableBufferPointer { txIdBytePtr in
            usk.bytes.withUnsafeBufferPointer { uskBuffer in
                zcashlc_shield_funds(
                    dbData.0,
                    dbData.1,
                    uskBuffer.baseAddress,
                    UInt(usk.bytes.count),
                    memo?.bytes,
                    UInt64(shieldingThreshold.amount),
                    spendParamsPath.0,
                    spendParamsPath.1,
                    outputParamsPath.0,
                    outputParamsPath.1,
                    networkType.networkId,
                    minimumConfirmations,
                    useZIP317Fees,
                    txIdBytePtr.baseAddress
                )
            }
        }
        globalDBLock.unlock()

        guard success else {
            throw ZcashError.rustShieldFunds(lastErrorMessage(fallback: "`shieldFunds` failed with unknown error"))
        }

        return contiguousTxIdBytes.withUnsafeBufferPointer { txIdBytePtr in
            Data(txIdBytePtr)
        }
    }

    nonisolated func consensusBranchIdFor(height: Int32) throws -> Int32 {
        let branchId = zcashlc_branch_id_for_height(height, networkType.networkId)

        guard branchId != -1 else {
            throw ZcashError.rustNoConsensusBranchId(height)
        }

        return branchId
    }
}

private extension ZcashRustBackend {
    static func enableTracing() {
        zcashlc_init_on_load(false)
    }
}

private extension ZcashRustBackend {
    nonisolated func lastErrorMessage(fallback: String) -> String {
        let errorLen = zcashlc_last_error_length()
        defer { zcashlc_clear_last_error() }

        if errorLen > 0 {
            let error = UnsafeMutablePointer<Int8>.allocate(capacity: Int(errorLen))
            defer { error.deallocate() }

            zcashlc_error_message_utf8(error, errorLen)
            if let errorMessage = String(validatingUTF8: error) {
                return errorMessage
            } else {
                return fallback
            }
        } else {
            return fallback
        }
    }
}

private extension URL {
    func osStr() -> (String, UInt) {
        let path = self.absoluteString
        return (path, UInt(path.lengthOfBytes(using: .utf8)))
    }

    /// use when the rust ffi needs to make filesystem operations
    func osPathStr() -> (String, UInt) {
        let path = self.path
        return (path, UInt(path.lengthOfBytes(using: .utf8)))
    }
}

extension String {
    /**
    Checks whether this string contains null bytes before it's real ending
    */
    func containsCStringNullBytesBeforeStringEnding() -> Bool {
        self.utf8CString.firstIndex(of: 0) != (self.utf8CString.count - 1)
    }

    func isDbNotEmptyErrorMessage() -> Bool {
        return contains("is not empty")
    }
}

extension FFIBinaryKey {
    /// converts an [`FFIBinaryKey`] into a [`UnifiedSpendingKey`]
    /// - Note: This does not check that the converted value actually holds a valid USK
    func unsafeToUnifiedSpendingKey(network: NetworkType) -> UnifiedSpendingKey {
        .init(
            network: network,
            bytes: self.encoding.toByteArray(
                length: Int(self.encoding_len)
            ),
            account: self.account_id
        )
    }
}

extension UnsafeMutablePointer where Pointee == UInt8 {
    /// copies the bytes pointed on
    func toByteArray(length: Int) -> [UInt8] {
        var bytes: [UInt8] = []

        for index in 0 ..< length {
            bytes.append(self.advanced(by: index).pointee)
        }

        return bytes
    }
}

extension Array where Element == FFIBlockMeta {
    func deallocateElements() {
        self.forEach { element in
            element.block_hash_ptr.deallocate()
        }
    }
}

extension Array where Element == FfiSubtreeRoot {
    func deallocateElements() {
        self.forEach { element in
            element.root_hash_ptr.deallocate()
        }
    }
}
