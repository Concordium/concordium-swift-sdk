// TODO: this needs more detail, but should not be required for wallets...
public enum UpdatePayload {
    case protocolUpdate // "protocol" is a reserved word in swift
    case electionDifficulty
    case euroPerEnergy
    case microCCDPerEuro
    case foundationAccount
    case mintDistribution
    case transactionFeeDistribution
    case gasRewards
    case bakerStakeThreshold
    case root
    case level1
    case addAnonymityRevoker
    case addIdentityProvider
    case cooldownParametersCPV1
    case poolParametersCPV1
    case timeParametersCPV1
    case mintDistributionCPV1
    case gasRewardsCPV2
    case timeoutParametersCPV2
    case minBlockTimeCPV2
    case blockEnergyLimitCPV2
    case finalizationCommitteeParametersCPV2
}

extension UpdatePayload: FromGRPC {
    typealias GRPC = Concordium_V2_UpdatePayload

    static func fromGRPC(_ g: GRPC) throws -> UpdatePayload {
        guard let payload = g.payload else { throw GRPCError.missingRequiredValue("Missing 'payload' of 'UpdatePayload'") }
        switch payload {
        case .protocolUpdate: return .protocolUpdate
        case .electionDifficultyUpdate: return .electionDifficulty
        case .euroPerEnergyUpdate: return .euroPerEnergy
        case .microCcdPerEuroUpdate: return .microCCDPerEuro
        case .foundationAccountUpdate: return .foundationAccount
        case .mintDistributionUpdate: return .mintDistribution
        case .transactionFeeDistributionUpdate: return .transactionFeeDistribution
        case .gasRewardsUpdate: return .gasRewards
        case .bakerStakeThresholdUpdate: return .bakerStakeThreshold
        case .rootUpdate: return .root
        case .level1Update: return .level1
        case .addAnonymityRevokerUpdate: return .addAnonymityRevoker
        case .addIdentityProviderUpdate: return .addIdentityProvider
        case .cooldownParametersCpv1Update: return .cooldownParametersCPV1
        case .poolParametersCpv1Update: return .poolParametersCPV1
        case .timeoutParametersUpdate: return .timeoutParametersCPV2
        case .mintDistributionCpv1Update: return .mintDistributionCPV1
        case .gasRewardsCpv2Update: return .gasRewardsCPV2
        case .minBlockTimeUpdate: return .minBlockTimeCPV2
        case .blockEnergyLimitUpdate: return .blockEnergyLimitCPV2
        case .finalizationCommitteeParametersUpdate: return .finalizationCommitteeParametersCPV2
        case .timeParametersCpv1Update: return .timeParametersCPV1
        }
    }
}

/// Details of an update instruction. These are free, and we only ever get a
/// response for them if the update is successfully enqueued, hence no failure
/// cases.
public struct UpdateDetails {
    public let effectiveTime: TransactionTime
    public let payload: UpdatePayload
}

extension UpdateDetails: FromGRPC {
    typealias GRPC = Concordium_V2_UpdateDetails

    static func fromGRPC(_ g: GRPC) throws -> UpdateDetails {
        try Self(effectiveTime: g.effectiveTime.value, payload: .fromGRPC(g.payload))
    }
}
