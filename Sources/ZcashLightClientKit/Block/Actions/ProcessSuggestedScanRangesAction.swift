//
//  ProcessSuggestedScanRangesAction.swift
//  
//
//  Created by Lukáš Korba on 02.08.2023.
//

import Foundation

final class ProcessSuggestedScanRangesAction {
    let rustBackend: ZcashRustBackendWelding
    let service: LightWalletService
    let logger: Logger
    
    init(container: DIContainer) {
        service = container.resolve(LightWalletService.self)
        rustBackend = container.resolve(ZcashRustBackendWelding.self)
        logger = container.resolve(Logger.self)
    }
}

extension ProcessSuggestedScanRangesAction: Action {
    var removeBlocksCacheWhenFailed: Bool { false }

    func run(with context: ActionContext, didUpdate: @escaping (CompactBlockProcessor.Event) async -> Void) async throws -> ActionContext {
        logger.info("Getting the suggested scan ranges from the wallet database.")
        let scanRanges = try await rustBackend.suggestScanRanges()

        if let firstRange = scanRanges.first {
            let rangeStartExclusive = firstRange.range.lowerBound - 1
            let rangeEndInclusive = firstRange.range.upperBound - 1
            
            let syncControlData = SyncControlData(
                latestBlockHeight: rangeEndInclusive,
                latestScannedHeight: rangeStartExclusive,
                firstUnenhancedHeight: rangeStartExclusive + 1
            )
            
            logger.debug("""
                Init numbers:
                latestBlockHeight [BC]:         \(rangeEndInclusive)
                latestScannedHeight [DB]:       \(rangeStartExclusive)
                firstUnenhancedHeight [DB]:     \(rangeStartExclusive + 1)
                """)

            await context.update(lastEnhancedHeight: nil)
            await context.update(lastScannedHeight: rangeStartExclusive)
            await context.update(lastDownloadedHeight: rangeStartExclusive)
            await context.update(syncControlData: syncControlData)

            await context.update(state: .download)
        } else {
            await context.update(state: .finished)
        }
        
        return context
    }

    func stop() async { }
}
