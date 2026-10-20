function packetSeed = physicalComRobustnessABPacketSeed(packetId, masterSeed)
%PHYSICALCOMROBUSTNESSABPACKETSEED Deterministic seed specification only.
if nargin < 2
    masterSeed = 2026072801;
end
packetId = double(packetId(:));
assert(all(isfinite(packetId)) && all(packetId == floor(packetId)) && ...
    all(packetId >= 1), 'PacketId must be a positive integer.');
packetSeed = double(masterSeed) + packetId;
end
