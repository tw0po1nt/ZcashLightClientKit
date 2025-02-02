//
//  ZcashRustBackendWelding.swift
//  ZcashLightClientKit
//
//  Created by Francisco Gindre on 12/09/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation

enum ZcashRustBackendWeldingConstants {
    static let validChain: Int32 = -1
}
/// Enumeration of potential return states for database initialization. If `seedRequired`
/// is returned, the caller must re-attempt initialization providing the seed
public enum DbInitResult {
    case success
    case seedRequired
}

// sourcery: mockActor
protocol ZcashRustBackendWelding {
    /// Adds the next available account-level spend authority, given the current set of [ZIP 316]
    /// account identifiers known, to the wallet database.
    ///
    /// Returns the newly created [ZIP 316] account identifier, along with the binary encoding of the
    /// [`UnifiedSpendingKey`] for the newly created account.  The caller should manage the memory of
    /// (and store) the returned spending keys in a secure fashion.
    ///
    /// If `seed` was imported from a backup and this method is being used to restore a
    /// previous wallet state, you should use this method to add all of the desired
    /// accounts before scanning the chain from the seed's birthday height.
    ///
    /// By convention, wallets should only allow a new account to be generated after funds
    /// have been received by the currently-available account (in order to enable
    /// automated account recovery).
    /// - parameter seed: byte array of the zip32 seed
    /// - parameter treeState: The TreeState Protobuf object for the height prior to the account birthday
    /// - parameter recoverUntil: the fully-scanned height up to which the account will be treated as "being recovered"
    /// - Returns: The `UnifiedSpendingKey` structs for the number of accounts created
    /// - Throws: `rustCreateAccount`.
    func createAccount(seed: [UInt8], treeState: TreeState, recoverUntil: UInt32?) async throws -> UnifiedSpendingKey

    /// Creates a transaction to the given address from the given account
    /// - Parameter usk: `UnifiedSpendingKey` for the account that controls the funds to be spent.
    /// - Parameter to: recipient address
    /// - Parameter value: transaction amount in Zatoshi
    /// - Parameter memo: the `MemoBytes` for this transaction. pass `nil` when sending to transparent receivers
    /// - Throws: `rustCreateToAddress`.
    func createToAddress(
        usk: UnifiedSpendingKey,
        to address: String,
        value: Int64,
        memo: MemoBytes?
    ) async throws -> Data

    /// Scans a transaction for any information that can be decrypted by the accounts in the wallet, and saves it to the wallet.
    /// - parameter tx:     the transaction to decrypt
    /// - parameter minedHeight: height on which this transaction was mined. this is used to fetch the consensus branch ID.
    /// - Throws: `rustDecryptAndStoreTransaction`.
    func decryptAndStoreTransaction(txBytes: [UInt8], minedHeight: Int32) async throws

    /// Get the (unverified) balance from the given account.
    /// - parameter account: index of the given account
    /// - Throws: `rustGetBalance`.
    func getBalance(account: Int32) async throws -> Int64

    /// Returns the most-recently-generated unified payment address for the specified account.
    /// - parameter account: index of the given account
    /// - Throws:
    ///     - `rustGetCurrentAddress` if rust layer returns error.
    ///     - `rustGetCurrentAddressInvalidAddress` if generated unified address isn't valid.
    func getCurrentAddress(account: Int32) async throws -> UnifiedAddress

    /// Wallets might need to be rewound because of a reorg, or by user request.
    /// There are times where the wallet could get out of sync for many reasons and
    /// users might be asked to rescan their wallets in order to fix that. This function
    /// returns the nearest height where a rewind is possible. Currently pruning gets rid
    /// of sapling witnesses older than 100 blocks. So in order to reconstruct the witness
    /// tree that allows to spend notes from the given wallet the rewind can't be more than
    /// 100 blocks or back to the oldest unspent note that this wallet contains.
    /// - parameter height: height you would like to rewind to.
    /// - Returns: the blockheight of the nearest rewind height.
    /// - Throws: `rustGetNearestRewindHeight`.
    func getNearestRewindHeight(height: Int32) async throws -> Int32

    /// Returns a newly-generated unified payment address for the specified account, with the next available diversifier.
    /// - parameter account: index of the given account
    /// - Throws:
    ///     - `rustGetNextAvailableAddress` if rust layer returns error.
    ///     - `rustGetNextAvailableAddressInvalidAddress` if generated unified address isn't valid.
    func getNextAvailableAddress(account: Int32) async throws -> UnifiedAddress

    /// Get memo from note.
    /// - parameter txId: ID of transaction containing the note
    /// - parameter outputIndex: output index of note
    func getMemo(txId: Data, outputIndex: UInt16) async throws -> Memo?

    /// Get the verified cached transparent balance for the given address
    /// - parameter account; the account index to query
    /// - Throws:
    ///     - `rustGetTransparentBalanceNegativeAccount` if `account` is < 0.
    ///     - `rustGetTransparentBalance` if rust layer returns error.
    func getTransparentBalance(account: Int32) async throws -> Int64

    /// Initializes the data db. This will performs any migrations needed on the sqlite file
    /// provided. Some migrations might need that callers provide the seed bytes.
    /// - Parameter seed: ZIP-32 compliant seed bytes for this wallet
    /// - Returns: `DbInitResult.success` if the dataDb was initialized successfully
    /// or `DbInitResult.seedRequired` if the operation requires the seed to be passed
    /// in order to be completed successfully.
    /// Throws `rustInitDataDb` if rust layer returns error.
    func initDataDb(seed: [UInt8]?) async throws -> DbInitResult

    /// Returns a list of the transparent receivers for the diversified unified addresses that have
    /// been allocated for the provided account.
    /// - parameter account: index of the given account
    /// - Throws:
    ///     - `rustListTransparentReceivers` if rust layer returns error.
    ///     - `rustListTransparentReceiversInvalidAddress` if transarent received generated by rust is invalid.
    func listTransparentReceivers(account: Int32) async throws -> [TransparentAddress]

    /// Get the verified balance from the given account
    /// - parameter account: index of the given account
    /// - Throws: `rustGetVerifiedBalance` when rust layer throws error.
    func getVerifiedBalance(account: Int32) async throws -> Int64

    /// Get the verified cached transparent balance for the given account
    /// - parameter account: account index to query the balance for.
    /// - Throws:
    ///     - `rustGetVerifiedTransparentBalanceNegativeAccount` if `account` is < 0.
    ///     - `rustGetVerifiedTransparentBalance` if rust layer returns error.
    func getVerifiedTransparentBalance(account: Int32) async throws -> Int64

    /// Resets the state of the database to only contain block and transaction information up to the given height. clears up all derived data as well
    /// - parameter height: height to rewind to.
    /// - Throws: `rustRewindToHeight` if rust layer returns error.
    func rewindToHeight(height: Int32) async throws

    /// Resets the state of the FsBlock database to only contain block and transaction information up to the given height.
    /// - Note: this does not delete the files. Only rolls back the database.
    /// - parameter height: height to rewind to. DON'T PASS ARBITRARY HEIGHT. Use `getNearestRewindHeight` when unsure
    /// - Throws: `rustRewindCacheToHeight` if rust layer returns error.
    func rewindCacheToHeight(height: Int32) async throws

    func putSaplingSubtreeRoots(startIndex: UInt64, roots: [SubtreeRoot]) async throws

    /// Updates the wallet's view of the blockchain.
    ///
    /// This method is used to provide the wallet with information about the state of the blockchain,
    /// and detect any previously scanned data that needs to be re-validated before proceeding with
    /// scanning. It should be called at wallet startup prior to calling `suggestScanRanges`
    /// in order to provide the wallet with the information it needs to correctly prioritize scanning
    /// operations.
    func updateChainTip(height: Int32) async throws

    /// Returns the height to which the wallet has been fully scanned.
    ///
    /// This is the height for which the wallet has fully trial-decrypted this and all
    /// preceding blocks beginning with the wallet's birthday height.
    func fullyScannedHeight() async throws -> BlockHeight?

    /// Returns the maximum height that the wallet has scanned.
    ///
    /// If the wallet is fully synced, this will be equivalent to `fullyScannedHeight`;
    /// otherwise the maximal scanned height is likely to be greater than the fully scanned
    /// height due to the fact that out-of-order scanning can leave gaps.
    func maxScannedHeight() async throws -> BlockHeight?

    /// Returns the scan progress derived from the current wallet state.
    func getScanProgress() async throws -> ScanProgress?

    /// Returns a list of suggested scan ranges based upon the current wallet state.
    ///
    /// This method should only be used in cases where the `CompactBlock` data that will be
    /// made available to `scanBlocks` for the requested block ranges includes note
    /// commitment tree size information for each block; or else the scan is likely to fail if
    /// notes belonging to the wallet are detected.
    func suggestScanRanges() async throws -> [ScanRange]

    /// Scans new blocks added to the cache for any transactions received by the tracked
    /// accounts, while checking that they form a valid chan.
    ///
    /// This function is built on the core assumption that the information provided in the
    /// block cache is more likely to be accurate than the previously-scanned information.
    /// This follows from the design (and trust) assumption that the `lightwalletd` server
    /// provides accurate block information as of the time it was requested.
    ///
    /// This function **assumes** that the caller is handling rollbacks.
    ///
    /// For brand-new light client databases, this function starts scanning from the Sapling
    /// activation height. This height can be fast-forwarded to a more recent block by calling
    /// [`initBlocksTable`] before this function.
    ///
    /// Scanned blocks are required to be height-sequential. If a block is missing from the
    /// cache, an error will be signalled.
    ///
    /// - parameter fromHeight: scan starting from the given height.
    /// - parameter limit: scan up to limit blocks.
    /// - Throws: `rustScanBlocks` if rust layer returns error.
    func scanBlocks(fromHeight: Int32, limit: UInt32) async throws

    /// Upserts a UTXO into the data db database
    /// - parameter txid: the txid bytes for the UTXO
    /// - parameter index: the index of the UTXO
    /// - parameter script: the script of the UTXO
    /// - parameter value: the value of the UTXO
    /// - parameter height: the mined height for the UTXO
    /// - Throws: `rustPutUnspentTransparentOutput` if rust layer returns error.
    func putUnspentTransparentOutput(
        txid: [UInt8],
        index: Int,
        script: [UInt8],
        value: Int64,
        height: BlockHeight
    ) async throws

    /// Creates a transaction to shield all found UTXOs in data db for the account the provided `UnifiedSpendingKey` has spend authority for.
    /// - Parameter usk: `UnifiedSpendingKey` that spend transparent funds and where the funds will be shielded to.
    /// - Parameter memo: the `Memo` for this transaction
    /// - Throws: `rustShieldFunds` if rust layer returns error.
    func shieldFunds(
        usk: UnifiedSpendingKey,
        memo: MemoBytes?,
        shieldingThreshold: Zatoshi
    ) async throws -> Data

    /// Gets the consensus branch id for the given height
    /// - Parameter height: the height you what to know the branch id for
    /// - Throws: `rustNoConsensusBranchId` if rust layer returns error.
    func consensusBranchIdFor(height: Int32) throws -> Int32

    /// Initializes Filesystem based block cache
    /// - Throws: `rustInitBlockMetadataDb` if rust layer returns error.
    func initBlockMetadataDb() async throws

    /// Write compact block metadata to a database known to the Rust layer
    /// - Parameter blocks: The `ZcashCompactBlock`s that are going to be marked as stored by the metadata Db.
    /// - Throws:
    ///     - `rustWriteBlocksMetadataAllocationProblem` if there problem with allocating memory on Swift side.
    ///     - `rustWriteBlocksMetadata` if there is problem with writing blocks metadata.
    func writeBlocksMetadata(blocks: [ZcashCompactBlock]) async throws

    /// Gets the latest block height stored in the filesystem based cache.
    /// -  Parameter fsBlockDbRoot: `URL` pointing to the filesystem root directory where the fsBlock cache is.
    /// this directory  is expected to contain a `/blocks` sub-directory with the blocks stored in the convened filename
    /// format `{height}-{hash}-block`. This directory has must be granted both write and read permissions.
    /// - Returns `BlockHeight` of the latest cached block or `.empty` if no blocks are stored.
    func latestCachedBlockHeight() async throws -> BlockHeight
}
