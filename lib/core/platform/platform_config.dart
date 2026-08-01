/// Platform-wide, admin-editable configuration stored at `platform/config`.
/// Lets the operator change trial length and pricing without a code change.
class PlatformConfig {
  const PlatformConfig({
    this.demoDays = 7,
    this.starterPrice = 0,
    this.proPrice = 0,
    this.currency = 'BDT',
  });

  /// Length of the free Demo trial, in days.
  final int demoDays;

  /// Monthly price of the Starter plan.
  final num starterPrice;

  /// Monthly price of the Pro plan.
  final num proPrice;

  final String currency;

  PlatformConfig copyWith({
    int? demoDays,
    num? starterPrice,
    num? proPrice,
    String? currency,
  }) {
    return PlatformConfig(
      demoDays: demoDays ?? this.demoDays,
      starterPrice: starterPrice ?? this.starterPrice,
      proPrice: proPrice ?? this.proPrice,
      currency: currency ?? this.currency,
    );
  }

  Map<String, dynamic> toMap() => {
        'demoDays': demoDays,
        'starterPrice': starterPrice,
        'proPrice': proPrice,
        'currency': currency,
      };

  factory PlatformConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const PlatformConfig();
    return PlatformConfig(
      demoDays: (data['demoDays'] ?? 7) as int,
      starterPrice: (data['starterPrice'] ?? 0) as num,
      proPrice: (data['proPrice'] ?? 0) as num,
      currency: (data['currency'] ?? 'BDT') as String,
    );
  }
}
