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
    name: "Can transfer photo ownership",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        const wallet_2 = accounts.get('wallet_2')!;
        
        // Upload photo
        let uploadBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'upload-photo', [
                types.ascii("Test Photo"),
                types.ascii("A test photo description"),
                types.ascii("QmTest123")
            ], wallet_1.address)
        ]);
        
        // Transfer ownership
        let transferBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'transfer-photo-ownership', [
                types.uint(0),
                types.principal(wallet_2.address)
            ], wallet_1.address)
        ]);
        
        transferBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify new owner
        let getPhotoBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'get-photo', [
                types.uint(0)
            ], wallet_1.address)
        ]);
        
        const photo = getPhotoBlock.receipts[0].result.expectSome();
        assertEquals(photo['owner'], wallet_2.address);
    }
});

Clarinet.test({
    name: "Rate limiting prevents rapid gallery ratings",
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
        
        // First rating should succeed
        let firstRating = chain.mineBlock([
            Tx.contractCall('frame_hive', 'rate-gallery', [
                types.uint(0),
                types.uint(5)
            ], wallet_2.address)
        ]);
        
        firstRating.receipts[0].result.expectOk().expectBool(true);
        
        // Second immediate rating should fail
        let secondRating = chain.mineBlock([
            Tx.contractCall('frame_hive', 'rate-gallery', [
                types.uint(0),
                types.uint(4)
            ], wallet_2.address)
        ]);
        
        secondRating.receipts[0].result.expectErr().expectUint(104); // err-rate-limit
    }
});
