function grid = physicalComRobustnessABConditionGrid(cfg)
%PHYSICALCOMROBUSTNESSABCONDITIONGRID Build the frozen 18-row method grid.
baseMethods = cfg.historicalMethods(1:3);
rows = cell(18, 1);
cursor = 0;
for snr = cfg.snrDb
    for methodIndex = 1:4
        cursor = cursor + 1;
        rows{cursor} = localRow("A", snr, 200, ...
            cfg.historicalMethods(methodIndex), true, false);
    end
end
for fd = [100 300]
    for methodIndex = 1:numel(baseMethods)
        cursor = cursor + 1;
        rows{cursor} = localRow("B", 20, fd, ...
            baseMethods(methodIndex), false, true);
    end
end
grid = vertcat(rows{:});
grid = sortrows(grid, {'snrDb','dopplerHz','historicalMethodName'});
grid.paperMethodName = strings(height(grid), 1);
for index = 1:height(grid)
    methodIndex = find(cfg.historicalMethods == grid.historicalMethodName(index), 1);
    grid.paperMethodName(index) = cfg.paperMethods(methodIndex);
end
grid.packetCount = repmat(cfg.packetCount, height(grid), 1);
grid.packetIdFirst = ones(height(grid), 1);
grid.packetIdLast = repmat(cfg.packetCount, height(grid), 1);
grid.plannedRuns = grid.packetCount;
grid.conditionKey = strings(height(grid), 1);
for index = 1:height(grid)
    grid.conditionKey(index) = sprintf('SNR%g_fd%g', ...
        grid.snrDb(index), grid.dopplerHz(index));
end
grid.sharedCenterCondition = grid.snrDb == 20 & grid.dopplerHz == 200 & ...
    grid.historicalMethodName ~= "PerfectCSI_EP";
grid.experimentB(grid.sharedCenterCondition) = true;
grid.experimentMembership = strings(height(grid), 1);
grid.experimentMembership(grid.experimentA & grid.experimentB) = "A+B";
grid.experimentMembership(grid.experimentA & ~grid.experimentB) = "A";
grid.experimentMembership(~grid.experimentA & grid.experimentB) = "B";
grid = movevars(grid, {'conditionKey','experimentMembership'}, 'Before', 1);
end

function row = localRow(experiment, snr, fd, method, experimentA, experimentB)
row = table(string(experiment), double(snr), double(fd), string(method), ...
    logical(experimentA), logical(experimentB), ...
    'VariableNames', {'experiment','snrDb','dopplerHz', ...
    'historicalMethodName','experimentA','experimentB'});
end
