// TODO: this needs more detail, but should not be required for wallets...
public enum UpdatePayload {
    case protocolUpdate // "protocol" is a reserved word in swift
    case electionDifficulty
    case euroPerEnergy
    case microCCDPerEuro
    case foundationAccount
    case mintDistribution
    case transactionFeeDistribution
    case gASRewards
    case bakerStakeThreshold
    case root
    case level1
    case addAnonymityRevoker
    case addIdentityProvider
    case cooldownParametersCPV1
    case poolParametersCPV1
    case timeParametersCPV1
    case mintDistributionCPV1
    case gASRewardsCPV2
    case timeoutParametersCPV2
    case minBlockTimeCPV2
    case blockEnergyLimitCPV2
    case finalizationCommitteeParametersCPV2
}

/// Details of an update instruction. These are free, and we only ever get a
/// response for them if the update is successfully enqueued, hence no failure
/// cases.
public struct UpdateDetails {
    public let effectiveTime: TransactionTime
    public let payload: UpdatePayload
}