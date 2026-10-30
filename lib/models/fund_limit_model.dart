class FundLimitModel {
  final String dhanClientId;
  final double availableBalance;
  final double sodLimit;
  final double collateralAmount;
  final double receiveableAmount;
  final double utilizedAmount;
  final double blockedPayoutAmount;
  final double withdrawableBalance;

  const FundLimitModel({
    required this.dhanClientId,
    required this.availableBalance,
    required this.sodLimit,
    required this.collateralAmount,
    required this.receiveableAmount,
    required this.utilizedAmount,
    required this.blockedPayoutAmount,
    required this.withdrawableBalance,
  });

  factory FundLimitModel.fromJson(Map<String, dynamic> json) {
    // Dhan API response may have typo "availabelBalance" or "availableBalance"
    final dynamic rawAvail = json['availabelBalance'] ?? json['availableBalance'] ?? 0;
    final dynamic rawSod = json['sodLimit'] ?? 0;
    final dynamic rawCollateral = json['collateralAmount'] ?? 0;
    final dynamic rawReceive = json['receiveableAmount'] ?? json['receivableAmount'] ?? 0;
    final dynamic rawUtilized = json['utilizedAmount'] ?? 0;
    final dynamic rawBlocked = json['blockedPayoutAmount'] ?? 0;
    final dynamic rawWithdrawable = json['withdrawableBalance'] ?? 0;

    return FundLimitModel(
      dhanClientId: (json['dhanClientId'] ?? '').toString(),
      availableBalance: (rawAvail is num) ? rawAvail.toDouble() : (double.tryParse(rawAvail.toString()) ?? 0.0),
      sodLimit: (rawSod is num) ? rawSod.toDouble() : (double.tryParse(rawSod.toString()) ?? 0.0),
      collateralAmount: (rawCollateral is num) ? rawCollateral.toDouble() : (double.tryParse(rawCollateral.toString()) ?? 0.0),
      receiveableAmount: (rawReceive is num) ? rawReceive.toDouble() : (double.tryParse(rawReceive.toString()) ?? 0.0),
      utilizedAmount: (rawUtilized is num) ? rawUtilized.toDouble() : (double.tryParse(rawUtilized.toString()) ?? 0.0),
      blockedPayoutAmount: (rawBlocked is num) ? rawBlocked.toDouble() : (double.tryParse(rawBlocked.toString()) ?? 0.0),
      withdrawableBalance: (rawWithdrawable is num) ? rawWithdrawable.toDouble() : (double.tryParse(rawWithdrawable.toString()) ?? 0.0),
    );
  }

  Map<String, dynamic> toJson() => {
    'dhanClientId': dhanClientId,
    'availableBalance': availableBalance,
    'sodLimit': sodLimit,
    'collateralAmount': collateralAmount,
    'receiveableAmount': receiveableAmount,
    'utilizedAmount': utilizedAmount,
    'blockedPayoutAmount': blockedPayoutAmount,
    'withdrawableBalance': withdrawableBalance,
  };
}

