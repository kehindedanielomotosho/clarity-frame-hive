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
    name: "Can create collaboration and award reputation points",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet_1 = accounts.get('wallet_1')!;
        const wallet_2 = accounts.get('wallet_2')!;
        
        // Create collaboration
        let block = chain.mineBlock([
            Tx.contractCall('frame_hive', 'create-collaboration', [
                types.ascii("Test Collab"),
                types.ascii("A test collaboration")
            ], wallet_1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        
        // Award points
        let pointsBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'award-points', [
                types.principal(wallet_2.address),
                types.uint(10)
            ], wallet_1.address)
        ]);
        
        pointsBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Check reputation
        let reputationBlock = chain.mineBlock([
            Tx.contractCall('frame_hive', 'get-user-reputation', [
                types.principal(wallet_2.address)
            ], wallet_1.address)
        ]);
        
        const reputation = reputationBlock.receipts[0].result;
        assertEquals(reputation['score'], 10);
    }
});