//
//  ServiceHelper.swift
//  gRPC-PoC
//
//  Created by Francisco Gindre on 29/08/2019.
//  Copyright © 2019 Electric Coin Company. All rights reserved.
//

import Foundation
import GRPC
import NIO
import NIOHPACK

public typealias Channel = GRPC.GRPCChannel

public protocol LightWalletdInfo {
    var version: String { get }

    var vendor: String { get }

    /// true
    var taddrSupport: Bool { get }

    /// either "main" or "test"
    var chainName: String { get }

    /// depends on mainnet or testnet
    var saplingActivationHeight: UInt64 { get }

    /// protocol identifier, see consensus/upgrades.cpp
    var consensusBranchID: String { get }

    /// latest block on the best chain
    var blockHeight: UInt64 { get }

    var gitCommit: String { get }

    var branch: String { get }

    var buildDate: String { get }

    var buildUser: String { get }

    /// less than tip height if zcashd is syncing
    var estimatedHeight: UInt64 { get }

    /// example: "v4.1.1-877212414"
    var zcashdBuild: String { get }

    /// example: "/MagicBean:4.1.1/"
    var zcashdSubversion: String { get }
}

extension LightdInfo: LightWalletdInfo {}

/**
Swift GRPC implementation of Lightwalletd service
*/
public enum GRPCResult: Equatable {
    case success
    case error(_ error: LightWalletServiceError)
}

public protocol CancellableCall {
    func cancel()
}

extension ServerStreamingCall: CancellableCall {
    public func cancel() {
        self.cancel(promise: self.eventLoop.makePromise(of: Void.self))
    }
}

public struct BlockProgress: Equatable {
    public var startHeight: BlockHeight
    public var targetHeight: BlockHeight
    public var progressHeight: BlockHeight

    public var progress: Float {
        let overall = self.targetHeight - self.startHeight

        return overall > 0 ? Float((self.progressHeight - self.startHeight)) / Float(overall) : 0
    }
}

public extension BlockProgress {
    static let nullProgress = BlockProgress(startHeight: 0, targetHeight: 0, progressHeight: 0)
}

public class LightWalletGRPCService {
    let channel: Channel
    let connectionManager: ConnectionStatusManager
    let compactTxStreamer: CompactTxStreamerClient
    let singleCallTimeout: TimeLimit
    let streamingCallTimeout: TimeLimit

    var queue: DispatchQueue
    
    public convenience init(endpoint: LightWalletEndpoint) {
        self.init(
            host: endpoint.host,
            port: endpoint.port,
            secure: endpoint.secure,
            singleCallTimeout: endpoint.singleCallTimeoutInMillis,
            streamingCallTimeout: endpoint.streamingCallTimeoutInMillis
        )
    }

    public init(host: String, port: Int = 9067, secure: Bool = true, singleCallTimeout: Int64 = 10000, streamingCallTimeout: Int64 = 10000) {
        self.connectionManager = ConnectionStatusManager()
        self.queue = DispatchQueue.init(label: "LightWalletGRPCService")
        self.streamingCallTimeout = TimeLimit.timeout(.milliseconds(streamingCallTimeout))
        self.singleCallTimeout = TimeLimit.timeout(.milliseconds(singleCallTimeout))

        let connectionBuilder = secure ?
        ClientConnection.usingPlatformAppropriateTLS(for: MultiThreadedEventLoopGroup(numberOfThreads: 1)) :
        ClientConnection.insecure(group: MultiThreadedEventLoopGroup(numberOfThreads: 1))

        let channel = connectionBuilder
            .withConnectivityStateDelegate(connectionManager, executingOn: queue)
            .withKeepalive(
                ClientConnectionKeepalive(
                  interval: .seconds(15),
                  timeout: .seconds(10)
                )
            )
            .connect(host: host, port: port)

        self.channel = channel

        compactTxStreamer = CompactTxStreamerClient(
            channel: self.channel,
            defaultCallOptions: Self.callOptions(
                timeLimit: TimeLimit.timeout(.seconds(Int64(singleCallTimeout)))
            )
        )
    }

    deinit {
        _ = channel.close()
        _ = compactTxStreamer.channel.close()
    }

    func stop() {
        _ = channel.close()
    }
    
    func blockRange(startHeight: BlockHeight, endHeight: BlockHeight? = nil, result: @escaping (CompactBlock) -> Void) throws -> ServerStreamingCall<BlockRange, CompactBlock> {
        compactTxStreamer.getBlockRange(BlockRange(startHeight: startHeight, endHeight: endHeight), handler: result)
    }
    
    func latestBlock() throws -> BlockID {
        try compactTxStreamer.getLatestBlock(ChainSpec()).response.wait()
    }
    
    func getTx(hash: String) throws -> RawTransaction {
        var filter = TxFilter()
        filter.hash = Data(hash.utf8)

        return try compactTxStreamer.getTransaction(filter).response.wait()
    }
    
    static func callOptions(timeLimit: TimeLimit) -> CallOptions {
        CallOptions(
            customMetadata: HPACKHeaders(),
            timeLimit: timeLimit,
            messageEncoding: .disabled,
            requestIDProvider: .autogenerated,
            requestIDHeader: nil,
            cacheable: false
        )
    }
}

extension LightWalletGRPCService: LightWalletService {
    @discardableResult
    public func blockStream(
        startHeight: BlockHeight,
        endHeight: BlockHeight,
        result: @escaping (Result<GRPCResult, LightWalletServiceError>) -> Void,
        handler: @escaping (ZcashCompactBlock) -> Void,
        progress: @escaping  (BlockProgress) -> Void
    ) -> CancellableCall {
        let future = compactTxStreamer.getBlockRange(
            BlockRange(
                startHeight: startHeight,
                endHeight: endHeight
            ),
            callOptions: Self.callOptions(timeLimit: self.streamingCallTimeout),
            handler: { compactBlock in
                handler(ZcashCompactBlock(compactBlock: compactBlock))
                progress(
                    BlockProgress(
                        startHeight: startHeight,
                        targetHeight: endHeight,
                        progressHeight: BlockHeight(compactBlock.height)
                    )
                )
            }
        )
        
        future.status.whenComplete { completionResult in
            switch completionResult {
            case .success(let status):
                switch status.code {
                case .ok:
                    result(.success(GRPCResult.success))
                default:
                    result(.failure(LightWalletServiceError.mapCode(status)))
                }
            case .failure(let error):
                result(.failure(LightWalletServiceError.genericError(error: error)))
            }
        }
        return future
    }
     
    public func getInfo() throws -> LightWalletdInfo {
        try compactTxStreamer.getLightdInfo(Empty()).response.wait()
    }
    
    public func getInfo(result: @escaping (Result<LightWalletdInfo, LightWalletServiceError>) -> Void) {
        compactTxStreamer.getLightdInfo(Empty()).response.whenComplete { completionResult in
            switch completionResult {
            case .success(let info):
                result(.success(info))
            case .failure(let error):
                result(.failure(error.mapToServiceError()))
            }
        }
    }
    
    public func closeConnection() {
        _ = channel.close()
    }
    
    public func fetchTransaction(txId: Data) throws -> TransactionEntity {
        var txFilter = TxFilter()
        txFilter.hash = txId
        
        do {
            let rawTx = try compactTxStreamer.getTransaction(txFilter).response.wait()
            
            return TransactionBuilder.createTransactionEntity(txId: txId, rawTransaction: rawTx)
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    public func fetchTransaction(txId: Data, result: @escaping (Result<TransactionEntity, LightWalletServiceError>) -> Void) {
        var txFilter = TxFilter()
        txFilter.hash = txId
        
        compactTxStreamer.getTransaction(txFilter).response.whenComplete { response in
            switch response {
            case .failure(let error):
                result(.failure(error.mapToServiceError()))
            case .success(let rawTx):
                result(.success(TransactionBuilder.createTransactionEntity(txId: txId, rawTransaction: rawTx)))
            }
        }
    }
    
    public func submit(spendTransaction: Data, result: @escaping (Result<LightWalletServiceResponse, LightWalletServiceError>) -> Void) {
        do {
            let transaction = try RawTransaction(serializedData: spendTransaction)
            let response = self.compactTxStreamer.sendTransaction(transaction).response
            
            response.whenComplete { responseResult in
                switch responseResult {
                case .failure(let error):
                    result(.failure(LightWalletServiceError.sentFailed(error: error)))
                case .success(let success):
                    result(.success(success))
                }
            }
        } catch {
            result(.failure(error.mapToServiceError()))
        }
    }
    
    public func submit(spendTransaction: Data) throws -> LightWalletServiceResponse {
        let rawTx = RawTransaction.with { raw in
            raw.data = spendTransaction
        }
        do {
            return try compactTxStreamer.sendTransaction(rawTx).response.wait()
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    public func blockRange(_ range: CompactBlockRange) throws -> [ZcashCompactBlock] {
        var blocks: [CompactBlock] = []
        
        let response = compactTxStreamer.getBlockRange(
            range.blockRange(),
            handler: { blocks.append($0) }
        )
        
        let status = try response.status.wait()

        switch status.code {
        case .ok:
            return blocks.asZcashCompactBlocks()
        default:
            throw LightWalletServiceError.mapCode(status)
        }
    }
    
    public func latestBlockHeight(result: @escaping (Result<BlockHeight, LightWalletServiceError>) -> Void) {
        let response = compactTxStreamer.getLatestBlock(ChainSpec()).response
        
        response.whenSuccessBlocking(onto: queue) { blockID in
            guard let blockHeight = Int(exactly: blockID.height) else {
                result(.failure(LightWalletServiceError.generalError(message: "error creating blockheight from BlockID \(blockID)")))
                return
            }
            result(.success(blockHeight))
        }
        
        response.whenFailureBlocking(onto: queue) { error in
            result(.failure(error.mapToServiceError()))
        }
    }
    
    public func blockRange(_ range: CompactBlockRange, result: @escaping (Result<[ZcashCompactBlock], LightWalletServiceError>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }

            var blocks: [CompactBlock] = []
            let response = self.compactTxStreamer.getBlockRange(range.blockRange(), handler: { blocks.append($0) })

            do {
                let status = try response.status.wait()
                switch status.code {
                case .ok:
                    result(.success(blocks.asZcashCompactBlocks()))
                    
                default:
                    result(.failure(.mapCode(status)))
                }
            } catch {
                result(.failure(error.mapToServiceError()))
            }
        }
    }
    
    public func latestBlockHeight() throws -> BlockHeight {
        guard let height = try? latestBlock().compactBlockHeight() else {
            throw LightWalletServiceError.invalidBlock
        }
        return height
    }
    
    public func fetchUTXOs(for tAddress: String, height: BlockHeight) throws -> [UnspentTransactionOutputEntity] {
        let arg = GetAddressUtxosArg.with { utxoArgs in
            utxoArgs.addresses = [tAddress]
            utxoArgs.startHeight = UInt64(height)
        }
        do {
            return try self.compactTxStreamer.getAddressUtxos(arg).response.wait().addressUtxos.map { reply in
                UTXO(
                    id: nil,
                    address: tAddress,
                    prevoutTxId: reply.txid,
                    prevoutIndex: Int(reply.index),
                    script: reply.script,
                    valueZat: Int(reply.valueZat),
                    height: Int(reply.height),
                    spentInTx: nil
                )
            }
        } catch {
            throw error.mapToServiceError()
        }
    }
    
    public func fetchUTXOs(for tAddress: String, height: BlockHeight, result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let arg = GetAddressUtxosArg.with { utxoArgs in
                utxoArgs.addresses = [tAddress]
                utxoArgs.startHeight = UInt64(height)
            }
            var utxos: [UnspentTransactionOutputEntity] = []
            let response = self.compactTxStreamer.getAddressUtxosStream(arg) { reply in
                utxos.append(
                    UTXO(
                        id: nil,
                        address: tAddress,
                        prevoutTxId: reply.txid,
                        prevoutIndex: Int(reply.index),
                        script: reply.script,
                        valueZat: Int(reply.valueZat),
                        height: Int(reply.height),
                        spentInTx: nil
                    )
                )
            }
            
            do {
                let status = try response.status.wait()
                switch status.code {
                case .ok:
                    result(.success(utxos))
                default:
                    result(.failure(.mapCode(status)))
                }
            } catch {
                result(.failure(error.mapToServiceError()))
            }
        }
    }
    
    public func fetchUTXOs(for tAddresses: [String], height: BlockHeight) throws -> [UnspentTransactionOutputEntity] {
        guard !tAddresses.isEmpty else {
            return [] // FIXME: throw a real error
        }
        
        var utxos: [UnspentTransactionOutputEntity] = []
        
        let arg = GetAddressUtxosArg.with { utxoArgs in
            utxoArgs.addresses = tAddresses
            utxoArgs.startHeight = UInt64(height)
        }
        utxos.append(
            contentsOf:
            try self.compactTxStreamer.getAddressUtxos(arg).response.wait().addressUtxos.map { reply in
            UTXO(
                id: nil,
                address: reply.address,
                prevoutTxId: reply.txid,
                prevoutIndex: Int(reply.index),
                script: reply.script,
                valueZat: Int(reply.valueZat),
                height: Int(reply.height),
                spentInTx: nil
                )
            }
        )
       
        return utxos
    }
    
    public func fetchUTXOs(
        for tAddresses: [String],
        height: BlockHeight,
        result: @escaping (Result<[UnspentTransactionOutputEntity], LightWalletServiceError>) -> Void
    ) {
        guard !tAddresses.isEmpty else {
            return result(.success([])) // FIXME: throw a real error
        }
        
        var utxos: [UnspentTransactionOutputEntity] = []
        self.queue.async { [weak self] in
            guard let self = self else { return }
            let args = GetAddressUtxosArg.with { utxoArgs in
                utxoArgs.addresses = tAddresses
                utxoArgs.startHeight = UInt64(height)
            }
            do {
                let response = try self.compactTxStreamer.getAddressUtxosStream(args) { reply in
                    utxos.append(
                        UTXO(
                            id: nil,
                            address: reply.address,
                            prevoutTxId: reply.txid,
                            prevoutIndex: Int(reply.index),
                            script: reply.script,
                            valueZat: Int(reply.valueZat),
                            height: Int(reply.height),
                            spentInTx: nil
                        )
                    )
                }
                .status
                .wait()

                switch response.code {
                case .ok:
                    result(.success(utxos))
                default:
                    result(.failure(.mapCode(response)))
                }
            } catch {
                result(.failure(error.mapToServiceError()))
            }
        }
    }
}

// MARK: - Extensions

extension Notification.Name {
    static let connectionStatusChanged = Notification.Name("LightWalletServiceConnectivityStatusChanged")
}

extension TimeAmount {
    static let singleCallTimeout = TimeAmount.seconds(30)
    static let streamingCallTimeout = TimeAmount.minutes(10)
}

extension CallOptions {
    static var lwdCall: CallOptions {
        CallOptions(
            customMetadata: HPACKHeaders(),
            timeLimit: .timeout(.singleCallTimeout),
            messageEncoding: .disabled,
            requestIDProvider: .autogenerated,
            requestIDHeader: nil,
            cacheable: false
        )
    }
}

extension Error {
    func mapToServiceError() -> LightWalletServiceError {
        guard let grpcError = self as? GRPCStatusTransformable else {
            return LightWalletServiceError.genericError(error: self)
        }
        
        return LightWalletServiceError.mapCode(grpcError.makeGRPCStatus())
    }
}

extension LightWalletServiceError {
    static func mapCode(_ status: GRPCStatus) -> LightWalletServiceError {
        switch status.code {
        case .ok:
            return LightWalletServiceError.unknown
        case .cancelled:
            return LightWalletServiceError.userCancelled
        case .unknown:
            return LightWalletServiceError.generalError(message: status.message ?? "GRPC unknown error contains no message")
        case .deadlineExceeded:
            return LightWalletServiceError.timeOut
        default:
            return LightWalletServiceError.genericError(error: status)
        }
    }
}

class ConnectionStatusManager: ConnectivityStateDelegate {
    func connectivityStateDidChange(from oldState: ConnectivityState, to newState: ConnectivityState) {
        LoggerProxy.event("Connection Changed from \(oldState) to \(newState)")
        NotificationCenter.default.post(
            name: .blockProcessorConnectivityStateChanged,
            object: self,
            userInfo: [
                CompactBlockProcessorNotificationKey.currentConnectivityStatus: newState,
                CompactBlockProcessorNotificationKey.previousConnectivityStatus: oldState
            ]
        )
    }
}
