//
//  CombineSDKSynchronizer.swift
//  
//
//  Created by Michal Fousek on 16.03.2023.
//

import Combine
import Foundation

/// This is a super thin layer that implements the `CombineSynchronizer` protocol and translates the async API defined in `Synchronizer` to
/// Combine-based API. And it doesn't do anything else. It doesn't keep any state. It's here so each client can choose the API that suits its case the
/// best. And usage of this can be combined with usage of `ClosureSDKSynchronizer`. So devs can really choose the best SDK API for each part of the
/// client app.
///
/// If you are looking for documentation for a specific method or property look for it in the `Synchronizer` protocol.
public struct CombineSDKSynchronizer {
    private let synchronizer: Synchronizer

    public init(synchronizer: Synchronizer) {
        self.synchronizer = synchronizer
    }
}

extension CombineSDKSynchronizer: CombineSynchronizer {
    public var alias: ZcashSynchronizerAlias { synchronizer.alias }

    public var latestState: SynchronizerState { synchronizer.latestState }
    public var connectionState: ConnectionState { synchronizer.connectionState }

    public var stateStream: AnyPublisher<SynchronizerState, Never> { synchronizer.stateStream }
    public var eventStream: AnyPublisher<SynchronizerEvent, Never> { synchronizer.eventStream }

    public func prepare(
        with seed: [UInt8]?,
        viewingKeys: [UnifiedFullViewingKey],
        walletBirthday: BlockHeight
    ) -> SinglePublisher<Initializer.InitializationResult, Error> {
        return executeThrowingAction() {
            return try await self.synchronizer.prepare(with: seed, viewingKeys: viewingKeys, walletBirthday: walletBirthday)
        }
    }

    public func start(retry: Bool) -> CompletablePublisher<Error> {
        return executeThrowingAction() {
            try await self.synchronizer.start(retry: retry)
        }
    }

    public func stop() -> CompletablePublisher<Never> {
        return executeAction() {
            await self.synchronizer.stop()
        }
    }

    public func getSaplingAddress(accountIndex: Int) -> SinglePublisher<SaplingAddress, Error> {
        return executeThrowingAction() {
            try await self.synchronizer.getSaplingAddress(accountIndex: accountIndex)
        }
    }

    public func getUnifiedAddress(accountIndex: Int) -> SinglePublisher<UnifiedAddress, Error> {
        return executeThrowingAction() {
            try await self.synchronizer.getUnifiedAddress(accountIndex: accountIndex)
        }
    }

    public func getTransparentAddress(accountIndex: Int) -> SinglePublisher<TransparentAddress, Error> {
        return executeThrowingAction() {
            try await self.synchronizer.getTransparentAddress(accountIndex: accountIndex)
        }
    }

    public func sendToAddress(
        spendingKey: UnifiedSpendingKey,
        zatoshi: Zatoshi,
        toAddress: Recipient,
        memo: Memo?
    ) -> SinglePublisher<PendingTransactionEntity, Error> {
        return executeThrowingAction() {
            try await self.synchronizer.sendToAddress(spendingKey: spendingKey, zatoshi: zatoshi, toAddress: toAddress, memo: memo)
        }
    }

    public func shieldFunds(
        spendingKey: UnifiedSpendingKey,
        memo: Memo,
        shieldingThreshold: Zatoshi
    ) -> SinglePublisher<PendingTransactionEntity, Error> {
        return executeThrowingAction() {
            try await self.synchronizer.shieldFunds(spendingKey: spendingKey, memo: memo, shieldingThreshold: shieldingThreshold)
        }
    }

    public func cancelSpend(transaction: PendingTransactionEntity) -> SinglePublisher<Bool, Never> {
        executeAction() {
            await self.synchronizer.cancelSpend(transaction: transaction)
        }
    }

    public var pendingTransactions: SinglePublisher<[PendingTransactionEntity], Never> {
        executeAction() {
            await self.synchronizer.pendingTransactions
        }
    }

    public var clearedTransactions: SinglePublisher<[ZcashTransaction.Overview], Never> {
        executeAction() {
            await self.synchronizer.clearedTransactions
        }
    }

    public var sentTransactions: SinglePublisher<[ZcashTransaction.Sent], Never> {
        executeAction() {
            await self.synchronizer.sentTransactions
        }
    }

    public var receivedTransactions: SinglePublisher<[ZcashTransaction.Received], Never> {
        executeAction() {
            await self.synchronizer.receivedTransactions
        }
    }
    
    public func paginatedTransactions(of kind: TransactionKind) -> PaginatedTransactionRepository { synchronizer.paginatedTransactions(of: kind) }

    public func getMemos(for transaction: ZcashTransaction.Overview) -> SinglePublisher<[Memo], Error> {
        executeThrowingAction() {
            try await self.synchronizer.getMemos(for: transaction)
        }
    }

    public func getMemos(for receivedTransaction: ZcashTransaction.Received) -> SinglePublisher<[Memo], Error> {
        executeThrowingAction() {
            try await self.synchronizer.getMemos(for: receivedTransaction)
        }
    }

    public func getMemos(for sentTransaction: ZcashTransaction.Sent) -> SinglePublisher<[Memo], Error> {
        executeThrowingAction() {
            try await self.synchronizer.getMemos(for: sentTransaction)
        }
    }

    public func getRecipients(for transaction: ZcashTransaction.Overview) -> SinglePublisher<[TransactionRecipient], Never> {
        executeAction() {
            await self.synchronizer.getRecipients(for: transaction)
        }
    }

    public func getRecipients(for transaction: ZcashTransaction.Sent) -> SinglePublisher<[TransactionRecipient], Never> {
        executeAction() {
            await self.synchronizer.getRecipients(for: transaction)
        }
    }

    public func allConfirmedTransactions(from transaction: ZcashTransaction.Overview, limit: Int) -> SinglePublisher<[ZcashTransaction.Overview], Error> {
        executeThrowingAction() {
            try await self.synchronizer.allConfirmedTransactions(from: transaction, limit: limit)
        }
    }

    public func latestHeight() -> SinglePublisher<BlockHeight, Error> {
        return executeThrowingAction() {
            try await self.synchronizer.latestHeight()
        }
    }

    public func refreshUTXOs(address: TransparentAddress, from height: BlockHeight) -> SinglePublisher<RefreshedUTXOs, Error> {
        return executeThrowingAction() {
            try await self.synchronizer.refreshUTXOs(address: address, from: height)
        }
    }

    public func getTransparentBalance(accountIndex: Int) -> SinglePublisher<WalletBalance, Error> {
        return executeThrowingAction() {
            try await self.synchronizer.getTransparentBalance(accountIndex: accountIndex)
        }
    }

    public func getShieldedBalance(accountIndex: Int = 0) -> SinglePublisher<Zatoshi, Error> {
        return executeThrowingAction() {
            try await synchronizer.getShieldedBalance(accountIndex: accountIndex)
        }
    }

    public func getShieldedVerifiedBalance(accountIndex: Int = 0) -> SinglePublisher<Zatoshi, Error> {
        return executeThrowingAction() {
            try await synchronizer.getShieldedVerifiedBalance(accountIndex: accountIndex)
        }
    }

    public func rewind(_ policy: RewindPolicy) -> CompletablePublisher<Error> { synchronizer.rewind(policy) }
    public func wipe() -> CompletablePublisher<Error> { synchronizer.wipe() }
}

extension CombineSDKSynchronizer {
    private func executeAction(action: @escaping () async -> Void) -> CompletablePublisher<Never> {
        let subject = PassthroughSubject<Void, Never>()
        Task {
            await action()
            subject.send(completion: .finished)
        }
        return subject.eraseToAnyPublisher()
    }

    private func executeAction<R>(action: @escaping () async -> R) -> SinglePublisher<R, Never> {
        let subject = PassthroughSubject<R, Never>()
        Task {
            let result = await action()
            subject.send(result)
            subject.send(completion: .finished)
        }
        return subject.eraseToAnyPublisher()
    }

    private func executeThrowingAction(action: @escaping () async throws -> Void) -> CompletablePublisher<Error> {
        let subject = PassthroughSubject<Void, Error>()
        Task {
            do {
                try await action()
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(error))
            }
        }

        return subject.eraseToAnyPublisher()
    }

    private func executeThrowingAction<R>(action: @escaping () async throws -> R) -> SinglePublisher<R, Error> {
        let subject = PassthroughSubject<R, Error>()
        Task {
            do {
                let result = try await action()
                subject.send(result)
                subject.send(completion: .finished)
            } catch {
                subject.send(completion: .failure(error))
            }
        }

        return subject.eraseToAnyPublisher()
    }
}
