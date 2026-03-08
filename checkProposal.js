const viem = require('viem');
const { createPublicClient, http } = viem;

const client = createPublicClient({
    chain: require('viem/chains').baseSepolia,
    transport: http('https://sepolia.base.org')
});

const abi = [{
    "inputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
    "name": "proposals",
    "outputs": [
        { "internalType": "address", "name": "creator", "type": "address" },
        { "internalType": "uint256", "name": "amount", "type": "uint256" },
        { "internalType": "string", "name": "payloadJSON", "type": "string" },
        { "internalType": "uint8", "name": "status", "type": "uint8" }
    ],
    "stateMutability": "view", "type": "function"
}];

client.readContract({
    address: '0x357E246B17bEF83BE4eA3321cBCA1BB642D17150',
    abi,
    functionName: 'proposals',
    args: [11n]
}).then(console.log).catch(console.error);

client.readContract({
    address: '0x357E246B17bEF83BE4eA3321cBCA1BB642D17150',
    abi: [{
        "inputs": [],
        "name": "proposalCount",
        "outputs": [
            { "internalType": "uint256", "name": "", "type": "uint256" }
        ],
        "stateMutability": "view", "type": "function"
    }],
    functionName: 'proposalCount'
}).then(c => console.log('Current proposalCount:', c)).catch(console.error);
