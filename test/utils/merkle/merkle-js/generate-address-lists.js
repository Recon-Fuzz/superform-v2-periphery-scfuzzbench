#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Generate individual address list JSON files from the master address registry
 */
class AddressListGenerator {
    constructor() {
        this.registryPath = path.join(__dirname, '../config/address_registry.json');
        this.targetDir = path.join(__dirname, '../target');
    }

    /**
     * Load the master address registry
     */
    loadRegistry() {
        try {
            const registryContent = fs.readFileSync(this.registryPath, 'utf8');
            return JSON.parse(registryContent);
        } catch (error) {
            throw new Error(`Failed to load address registry: ${error.message}`);
        }
    }

    /**
     * Generate token_list.json from registry tokens AND yieldSources
     * (yield sources must appear in both lists as per plan)
     */
    generateTokenList(registry) {
        const tokenList = {};
        
        for (const [chainId, tokens] of Object.entries(registry.tokens)) {
            tokenList[chainId] = tokens.map(token => ({
                symbol: token.symbol,
                address: token.address
            }));
        }
        
        // Add yield sources to token list as well (required by plan)
        for (const [chainId, yieldSources] of Object.entries(registry.yieldSources)) {
            if (!tokenList[chainId]) {
                tokenList[chainId] = [];
            }
            
            // Add yield sources to tokens, avoiding duplicates
            for (const yieldSource of yieldSources) {
                const exists = tokenList[chainId].some(token => 
                    token.symbol === yieldSource.symbol && token.address === yieldSource.address
                );
                
                if (!exists) {
                    tokenList[chainId].push({
                        symbol: yieldSource.symbol,
                        address: yieldSource.address
                    });
                }
            }
        }
        
        return tokenList;
    }

    /**
     * Generate yield_sources_list.json from registry yieldSources
     */
    generateYieldSourcesList(registry) {
        const yieldSourcesList = {};
        
        for (const [chainId, yieldSources] of Object.entries(registry.yieldSources)) {
            yieldSourcesList[chainId] = yieldSources.map(source => ({
                symbol: source.symbol,
                address: source.address
            }));
        }
        
        return yieldSourcesList;
    }

    /**
     * Generate owner_list.json from registry beneficiaries
     */
    generateOwnerList(registry) {
        return registry.beneficiaries;
    }

    /**
     * Generate staking_list.json from registry staking
     */
    generateStakingList(registry) {
        const stakingList = {};
        
        for (const [chainId, stakingAddresses] of Object.entries(registry.staking)) {
            stakingList[chainId] = stakingAddresses.map(staking => ({
                symbol: staking.symbol,
                address: staking.address
            }));
        }
        
        return stakingList;
    }

    /**
     * Write JSON file with proper formatting
     */
    writeJsonFile(filename, data) {
        const filePath = path.join(this.targetDir, filename);
        const jsonContent = JSON.stringify(data, null, 2);
        fs.writeFileSync(filePath, jsonContent);
        console.log(`Generated: ${filename}`);
    }

    /**
     * Generate all address list files
     */
    generateAll() {
        console.log('Loading address registry...');
        const registry = this.loadRegistry();

        console.log('Generating address list files...');
        
        // Generate token list
        const tokenList = this.generateTokenList(registry);
        this.writeJsonFile('token_list.json', tokenList);

        // Generate yield sources list
        const yieldSourcesList = this.generateYieldSourcesList(registry);
        this.writeJsonFile('yield_sources_list.json', yieldSourcesList);

        // Generate owner list
        const ownerList = this.generateOwnerList(registry);
        this.writeJsonFile('owner_list.json', ownerList);

        // Generate staking list
        const stakingList = this.generateStakingList(registry);
        this.writeJsonFile('staking_list.json', stakingList);

        console.log('Address list generation complete!');
    }

    /**
     * Add detected vault addresses to the registry
     */
    addDetectedVaults(detectedVaults) {
        const registry = this.loadRegistry();
        
        // SuperVaults that should only appear in beneficiaries, not in yieldSources
        // These are the main SuperVault contracts, not yield source vaults
        const superVaults = ['globalSVStrategy', 'globalSVGearStrategy', 'globalRuggableVault'];
        
        // Add detected vaults to yieldSources for testing (excluding SuperVaults)
        for (const [vaultName, address] of Object.entries(detectedVaults)) {
            // Skip SuperVaults - they should only be in beneficiaries
            if (superVaults.includes(vaultName)) {
                continue;
            }
            
            // Strip VAULT_ prefix if present (from console output like "VAULT_MOCK_ETH_RECEIVER")
            const cleanVaultName = vaultName.startsWith('VAULT_') ? vaultName.substring(6) : vaultName;
            
            // Create regular vault entry
            const vaultEntry = {
                symbol: cleanVaultName,
                address: address,
                category: "test_vault"
            };

            // Create coverage variant entry
            const coverageEntry = {
                symbol: `${cleanVaultName}_Coverage`,
                address: address, // Same address as regular vault
                category: "test_vault_coverage"
            };

            // Add to yieldSources for chain 1 (mainnet) only
            if (!registry.yieldSources["1"]) {
                registry.yieldSources["1"] = [];
            }
            
            // Remove existing entries if they exist
            registry.yieldSources["1"] = registry.yieldSources["1"].filter(source => 
                source.symbol !== cleanVaultName && source.symbol !== `${cleanVaultName}_Coverage`
            );
            
            // Add both regular and coverage variants
            registry.yieldSources["1"].push(vaultEntry);
            registry.yieldSources["1"].push(coverageEntry);
        }

        // Write updated registry back
        const registryContent = JSON.stringify(registry, null, 2);
        fs.writeFileSync(this.registryPath, registryContent);
        console.log(`Updated registry with ${Object.keys(detectedVaults).length} detected vaults (including _Coverage variants)`);

        // Regenerate all lists (this will automatically add yield sources to tokens)
        this.generateAll();
    }
}

// Export for use in other scripts
module.exports = AddressListGenerator;

// CLI usage
if (require.main === module) {
    const generator = new AddressListGenerator();
    
    // Check command line arguments
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        // Generate all lists
        generator.generateAll();
    } else if (args[0] === '--add-vaults' && args[1]) {
        // Add detected vaults from JSON string
        try {
            const detectedVaults = JSON.parse(args[1]);
            generator.addDetectedVaults(detectedVaults);
        } catch (error) {
            console.error('Failed to parse detected vaults JSON:', error.message);
            process.exit(1);
        }
    } else {
        console.log('Usage:');
        console.log('  node generate-address-lists.js                    # Generate all lists');
        console.log('  node generate-address-lists.js --add-vaults JSON  # Add detected vaults');
        process.exit(1);
    }
}
