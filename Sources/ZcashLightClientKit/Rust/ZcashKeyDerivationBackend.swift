//
//  ZcashKeyDerivationBackend.swift
//  
//
//  Created by Francisco Gindre on 4/7/23.
//

import Foundation
import libzcashlc

struct ZcashKeyDerivationBackend: ZcashKeyDerivationBackendWelding {
    let networkType: NetworkType

    init(networkType: NetworkType) {
        self.networkType = networkType
    }

    // MARK: Address metadata and validation
    static func getAddressMetadata(_ address: String) -> AddressMetadata? {
        var networkId: UInt32 = 0
        var addrId: UInt32 = 0
        guard zcashlc_get_address_metadata(
            [CChar](address.utf8CString),
            &networkId,
            &addrId
        ) else {
            return nil
        }

        guard
            let network = NetworkType.forNetworkId(networkId),
            let addrType = AddressType.forId(addrId)
        else {
            return nil
        }

        return AddressMetadata(network: network, addrType: addrType)
    }

    func receiverTypecodesOnUnifiedAddress(_ address: String) throws -> [UInt32] {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            throw ZcashError.rustReceiverTypecodesOnUnifiedAddressContainsNullBytes(address)
        }

        var len = UInt(0)

        guard let typecodesPointer = zcashlc_get_typecodes_for_unified_address_receivers(
            [CChar](address.utf8CString),
            &len
        ), len > 0
        else {
            throw ZcashError.rustRustReceiverTypecodesOnUnifiedAddressMalformed
        }

        var typecodes: [UInt32] = []

        for typecodeIndex in 0 ..< Int(len) {
            let pointer = typecodesPointer.advanced(by: typecodeIndex)

            typecodes.append(pointer.pointee)
        }

        defer {
            zcashlc_free_typecodes(typecodesPointer, len)
        }

        return typecodes
    }

    func isValidSaplingAddress(_ address: String) -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_shielded_address([CChar](address.utf8CString), networkType.networkId)
    }

    func isValidSaplingExtendedFullViewingKey(_ key: String) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_viewing_key([CChar](key.utf8CString), networkType.networkId)
    }

    func isValidSaplingExtendedSpendingKey(_ key: String) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_sapling_extended_spending_key([CChar](key.utf8CString), networkType.networkId)
    }

    func isValidTransparentAddress(_ address: String) -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_transparent_address([CChar](address.utf8CString), networkType.networkId)
    }

    func isValidUnifiedAddress(_ address: String) -> Bool {
        guard !address.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_unified_address([CChar](address.utf8CString), networkType.networkId)
    }

    func isValidUnifiedFullViewingKey(_ key: String) -> Bool {
        guard !key.containsCStringNullBytesBeforeStringEnding() else {
            return false
        }

        return zcashlc_is_valid_unified_full_viewing_key([CChar](key.utf8CString), networkType.networkId)
    }

    // MARK: Address Derivation

    func deriveUnifiedSpendingKey(
        from seed: [UInt8],
        accountIndex: Int32
    ) throws -> UnifiedSpendingKey {
        let binaryKeyPtr = seed.withUnsafeBufferPointer { seedBufferPtr in
            return zcashlc_derive_spending_key(
                seedBufferPtr.baseAddress,
                UInt(seed.count),
                accountIndex,
                networkType.networkId
            )
        }

        defer { zcashlc_free_binary_key(binaryKeyPtr) }

        guard let binaryKey = binaryKeyPtr?.pointee else {
            throw ZcashError.rustDeriveUnifiedSpendingKey(lastErrorMessage(fallback: "`deriveUnifiedSpendingKey` failed with unknown error"))
        }

        return binaryKey.unsafeToUnifiedSpendingKey(network: networkType)
    }
    
    func deriveUnifiedFullViewingKey(from spendingKey: UnifiedSpendingKey) throws -> UnifiedFullViewingKey {
        let extfvk = try spendingKey.bytes.withUnsafeBufferPointer { uskBufferPtr -> UnsafeMutablePointer<CChar> in
            guard let extfvk = zcashlc_spending_key_to_full_viewing_key(
                uskBufferPtr.baseAddress,
                UInt(spendingKey.bytes.count),
                networkType.networkId
            ) else {
                throw ZcashError.rustDeriveUnifiedFullViewingKey(
                    lastErrorMessage(fallback: "`deriveUnifiedFullViewingKey` failed with unknown error")
                )
            }

            return extfvk
        }

        defer { zcashlc_string_free(extfvk) }

        guard let derived = String(validatingUTF8: extfvk) else {
            throw ZcashError.rustDeriveUnifiedFullViewingKeyInvalidDerivedKey
        }

        return UnifiedFullViewingKey(validatedEncoding: derived, account: spendingKey.account)
    }

    func getSaplingReceiver(for uAddr: UnifiedAddress) throws -> SaplingAddress {
        guard let saplingCStr = zcashlc_get_sapling_receiver_for_unified_address(
            [CChar](uAddr.encoding.utf8CString)
        ) else {
            throw ZcashError.rustGetSaplingReceiverInvalidAddress(uAddr)
        }

        defer { zcashlc_string_free(saplingCStr) }

        guard let saplingReceiverStr = String(validatingUTF8: saplingCStr) else {
            throw ZcashError.rustGetSaplingReceiverInvalidReceiver
        }

        return SaplingAddress(validatedEncoding: saplingReceiverStr)
    }

    func getTransparentReceiver(for uAddr: UnifiedAddress) throws -> TransparentAddress {
        guard let transparentCStr = zcashlc_get_transparent_receiver_for_unified_address(
            [CChar](uAddr.encoding.utf8CString)
        ) else {
            throw ZcashError.rustGetTransparentReceiverInvalidAddress(uAddr)
        }

        defer { zcashlc_string_free(transparentCStr) }

        guard let transparentReceiverStr = String(validatingUTF8: transparentCStr) else {
            throw ZcashError.rustGetTransparentReceiverInvalidReceiver
        }

        return TransparentAddress(validatedEncoding: transparentReceiverStr)
    }

    // MARK: Error Handling

    private func lastErrorMessage(fallback: String) -> String {
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
