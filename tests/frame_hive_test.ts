import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can upload a photo and retrieve it",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('frame_hive', 'upload-photo', [
                types.ascii("Test Photo"),
                types.ascii("A test photo description"),
                types.ascii("QmTest123")
            ], wallet_1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        
        let getPhotoBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'get-photo', [
                types.uint(0)
            ], wallet_1.address)
        ]);
        
        const photo = getPhotoBlock.receipts[0].result.expectSome();
        assertEquals(photo['owner'], wallet_1.address);
        assertEquals(photo['title'], "Test Photo");
    }
});

Clarinet.test({
    name: "Can create and rate galleries with sufficient reputation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        const wallet_2 = accounts.get('wallet_2')!;
        
        // Award initial reputation
        let reputationBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'award-points', [
                types.principal(wallet_1.address),
                types.uint(60)
            ], wallet_1.address)
        ]);
        
        reputationBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Create gallery
        let galleryBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'create-gallery', [
                types.ascii("Test Gallery"),
                types.ascii("A test gallery")
            ], wallet_1.address)
        ]);
        
        galleryBlock.receipts[0].result.expectOk().expectUint(0);
        
        // Rate gallery
        let ratingBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'rate-gallery', [
                types.uint(0),
                types.uint(5)
            ], wallet_2.address)
        ]);
        
        ratingBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Check curator reputation increased
        let finalRepBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'get-user-reputation', [
                types.principal(wallet_1.address)
            ], wallet_1.address)
        ]);
        
        const finalRep = finalRepBlock.receipts[0].result;
        assertEquals(finalRep['score'], 110); // Initial 60 + (5 rating * 10 points)
    }
});

Clarinet.test({
    name: "Cannot create gallery without sufficient reputation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('frame_hive', 'create-gallery', [
                types.ascii("Test Gallery"),
                types.ascii("A test gallery")
            ], wallet_1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(102); // err-unauthorized
    }
});
