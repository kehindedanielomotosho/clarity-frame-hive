import {
    Clarinet,
    Tx,
    Chain,
    Account,
    types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

// [Previous tests remain unchanged]

Clarinet.test({
    name: "Validates IPFS hash format",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        
        // Invalid IPFS hash should fail
        let invalidUpload = chain.mineBlock([
            Tx.contractCall('frame_hive', 'upload-photo', [
                types.ascii("Test Photo"),
                types.ascii("A test photo description"),
                types.ascii("InvalidHash123")
            ], wallet_1.address)
        ]);
        
        invalidUpload.receipts[0].result.expectErr().expectUint(106); // err-invalid-input
        
        // Valid IPFS hash should succeed
        let validUpload = chain.mineBlock([
            Tx.contractCall('frame_hive', 'upload-photo', [
                types.ascii("Test Photo"),
                types.ascii("A test photo description"),
                types.ascii("QmTest123")
            ], wallet_1.address)
        ]);
        
        validUpload.receipts[0].result.expectOk();
    }
});

Clarinet.test({
    name: "Tracks gallery statistics correctly",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        const wallet_2 = accounts.get('wallet_2')!;
        
        // Setup gallery
        chain.mineBlock([
            Tx.contractCall('frame_hive', 'award-points', [
                types.principal(wallet_1.address),
                types.uint(60)
            ], wallet_1.address),
            Tx.contractCall('frame_hive', 'create-gallery', [
                types.ascii("Test Gallery"),
                types.ascii("A test gallery")
            ], wallet_1.address)
        ]);
        
        // Multiple ratings
        let ratings = chain.mineBlock([
            Tx.contractCall('frame_hive', 'rate-gallery', [
                types.uint(0),
                types.uint(5)
            ], wallet_2.address)
        ]);
        
        ratings.receipts[0].result.expectOk().expectBool(true);
        
        // Verify statistics
        let stats = chain.callReadOnlyFn(
            'frame_hive',
            'get-gallery-stats',
            [types.uint(0)],
            wallet_1.address
        );
        
        let statsData = stats.result.expectSome();
        assertEquals(statsData['total-ratings'], types.uint(1));
        assertEquals(statsData['rating-sum'], types.uint(5));
    }
});
