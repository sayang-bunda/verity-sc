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
     * Propose Market - User deposit $5 USDC (anti-spam). CRE listen MarketProposed, lalu createMarket atau rejectMarketProposal.
     */
    async proposeMarket(payloadJSON: string): Promise<{ txHash: string; proposalId: bigint }> {
        try {
            const tx = await this.contract.proposeMarket(payloadJSON);
            const receipt = await tx.wait();
            const event = receipt.logs.find((log: any) => log.eventName === 'MarketProposed');
            const proposalId = event?.args?.proposalId ?? 0n;
            return { txHash: receipt.hash, proposalId };
        } catch (error) {
            console.error('Error proposing market:', error);
            throw error;
        }
    }

    /**
     * Create Market - Fungsi CRE untuk membuat market baru (wajib ada proposalId dari proposeMarket)
     */
    async createMarket(params: {
        proposalId: bigint; // Wajib: dari proposeMarket (user harus deposit $5 dulu)
        creator: string;
        deadline: number; // Unix timestamp
        feeBps: number; // 0-1000 (0-10%)
        category: number; // 0=Crypto, 1=Political, 2=Sports, 3=Other
        question: string;
        resolutionCriteria: string;
        dataSources: string;
        riskScore: number; // 0-100 dari CRE — disimpan on-chain untuk FE
        targetValue?: bigint;
        priceFeedAddress?: string;
    }): Promise<{ txHash: string; marketId: bigint }> {
        try {
            const tx = await this.contract.createMarketFromCre(
                params.proposalId,
                params.creator,
                params.deadline,
                params.feeBps,
                params.category,
                params.question,
                params.resolutionCriteria,
                params.dataSources,
                params.targetValue ?? 0,
                params.priceFeedAddress ?? ethers.ZeroAddress,
                params.riskScore
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
        confidence: number, // 0-100
        params?: { reason?: string; evidenceUrls?: string[] }
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
                confidence,
                params?.reason ?? "",
                params?.evidenceUrls ?? []
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
     * Get Market Risk Score - FE baca risk score (0-100) dari CRE
     */
    async getMarketRiskScore(marketId: bigint): Promise<number> {
        return Number(await this.contract.getMarketRiskScore(marketId));
    }

    /**
     * Get Resolution Evidence - FE baca reason + evidence URLs pas settlement
     */
    async getResolutionEvidence(marketId: bigint): Promise<{ reason: string; evidenceUrls: string[] }> {
        const [reason, evidenceUrls] = await this.contract.getResolutionEvidence(marketId);
        return { reason, evidenceUrls };
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

    /**
     * Listen MarketResolvedWithEvidence - dapat reason + evidenceUrls pas settlement
     */
    onMarketResolvedWithEvidence(
        callback: (marketId: bigint, outcome: number, confidence: number, reason: string, evidenceUrls: string[]) => void
    ) {
        this.contract.on('MarketResolvedWithEvidence', (marketId, outcome, confidence, reason, evidenceUrls, event) => {
            callback(marketId, Number(outcome), Number(confidence), reason, evidenceUrls);
        });
    }
}



