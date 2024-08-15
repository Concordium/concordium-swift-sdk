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
        return switch payload {
        case .protocolUpdate: .protocolUpdate
        case .electionDifficultyUpdate: .electionDifficulty
        case .euroPerEnergyUpdate: .euroPerEnergy
        case .microCcdPerEuroUpdate: .microCCDPerEuro
        case .foundationAccountUpdate: .foundationAccount
        case .mintDistributionUpdate: .mintDistribution
        case .transactionFeeDistributionUpdate: .transactionFeeDistribution
        case .gasRewardsUpdate: .gasRewards
        case .bakerStakeThresholdUpdate: .bakerStakeThreshold
        case .rootUpdate: .root
        case .level1Update: .level1
        case .addAnonymityRevokerUpdate: .addAnonymityRevoker
        case .addIdentityProviderUpdate: .addIdentityProvider
        case .cooldownParametersCpv1Update: .cooldownParametersCPV1
        case .poolParametersCpv1Update: .poolParametersCPV1
        case .timeoutParametersUpdate: .timeoutParametersCPV2
        case .mintDistributionCpv1Update: .mintDistributionCPV1
        case .gasRewardsCpv2Update: .gasRewardsCPV2
        case .minBlockTimeUpdate: .minBlockTimeCPV2
        case .blockEnergyLimitUpdate: .blockEnergyLimitCPV2
        case .finalizationCommitteeParametersUpdate: .finalizationCommitteeParametersCPV2
        case .timeParametersCpv1Update: .timeParametersCPV1
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
