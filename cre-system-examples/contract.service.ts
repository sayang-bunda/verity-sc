/**
 * Contract Service - Interaksi dengan Verity Smart Contract
 * 
 * Service ini menghandle semua interaksi dengan smart contract Verity
 * menggunakan ethers.js atau viem
 */

import { ethers } from 'ethers';
import VerityABI from '../abis/Verity.json';


export class ContractService {
    private contract: ethers.Contract;
    private wallet: ethers.Wallet;
    private provider: ethers.Provider;

    constructor(
        privateKey: string,
        rpcUrl: string,
        contractAddress: string
    ) {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.wallet = new ethers.Wallet(privateKey, this.provider);
        this.contract = new ethers.Contract(
            contractAddress,
            VerityABI,
            this.wallet
        );
    }

    /**
     * Create Market - Fungsi CRE untuk membuat market baru
     */
    async createMarket(params: {
        creator: string;
        deadline: number; // Unix timestamp
        feeBps: number; // 0-1000 (0-10%)
        category: number; // 0=Crypto, 1=Political, 2=Sports, 3=Other
        question: string;
        resolutionCriteria: string;
        dataSources: string;
    }): Promise<{ txHash: string; marketId: bigint }> {
        try {
            const tx = await this.contract.createMarketFromCre(
                params.creator,
                params.deadline,
                params.feeBps,
                params.category,
                params.question,
                params.resolutionCriteria,
                params.dataSources
            );

            const receipt = await tx.wait();

            // Parse event untuk mendapatkan marketId
            const event = receipt.logs.find(
                (log: any) => log.eventName === 'MarketCreated'
            );
            const marketId = event.args.marketId;

            return {
                txHash: receipt.hash,
                marketId: marketId
            };
        } catch (error) {
            console.error('Error creating market:', error);
            throw error;
        }
    }

    /**
     * Report Manipulation - Melaporkan manipulasi trading
     */
    async reportManipulation(
        marketId: bigint,
        score: number, // 0-100
        reason: string
    ): Promise<{ txHash: string; paused: boolean }> {
        try {
            const tx = await this.contract.reportManipulation(
                marketId,
                score,
                reason
            );

            const receipt = await tx.wait();

            // Check jika market di-pause (score >= 70)
            const paused = score >= 70;

            return {
                txHash: receipt.hash,
                paused
            };
        } catch (error) {
            console.error('Error reporting manipulation:', error);
            throw error;
        }
    }

    /**
     * Resolve Market - Menentukan hasil akhir market
     */
    async resolveMarket(
        marketId: bigint,
        outcome: number, // 0=Unresolved, 1=Yes, 2=No
        confidence: number // 0-100
    ): Promise<{ txHash: string; resolved: boolean }> {
        try {
            // Check deadline sudah lewat
            const market = await this.contract.getMarket(marketId);
            const deadline = Number(market.deadline);

            if (Date.now() / 1000 < deadline) {
                throw new Error('Deadline not reached yet');
            }

            const tx = await this.contract.resolveMarketFromCre(
                marketId,
                outcome,
                confidence
            );

            const receipt = await tx.wait();

            // Check jika resolved (confidence >= 90) atau escalated
            const resolved = confidence >= 90;

            return {
                txHash: receipt.hash,
                resolved
            };
        } catch (error) {
            console.error('Error resolving market:', error);
            throw error;
        }
    }

    /**
     * Get Market Data - Read market dari blockchain
     */
    async getMarket(marketId: bigint) {
        return await this.contract.getMarket(marketId);
    }

    /**
     * Listen to Events - Real-time monitoring
     */
    onMarketCreated(callback: (marketId: bigint, creator: string) => void) {
        this.contract.on('MarketCreated', (marketId, creator, event) => {
            callback(marketId, creator);
        });
    }

    onManipulationDetected(
        callback: (marketId: bigint, score: number, reason: string) => void
    ) {
        this.contract.on('ManipulationDetected', (marketId, score, reason, event) => {
            callback(marketId, score, reason);
        });
    }

    onMarketResolved(
        callback: (marketId: bigint, outcome: number) => void
    ) {
        this.contract.on('MarketResolved', (marketId, outcome, event) => {
            callback(marketId, outcome);
        });
    }
}



