function seed=auditPairedSnrScenarioSeed(masterSeed,scenarioIndex)
%AUDITPAIREDSNRSCENARIOSEED SNR-independent scenario seed.
assert(scenarioIndex>=1&&scenarioIndex==floor(scenarioIndex));seed=masterSeed+100000*scenarioIndex;
assert(seed<2^32-1000,'Scenario seed exceeds twister range.');
end

