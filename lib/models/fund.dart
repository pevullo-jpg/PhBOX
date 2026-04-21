class Fund {
  final String id;
  String name;
  double initialAmount;

  Fund({
    required this.id,
    required this.name,
    required this.initialAmount,
  });

  factory Fund.fromJson(Map<String, dynamic> json) {
    return Fund(
      id: json['id'],
      name: json['name'],
      initialAmount: (json['initialAmount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "initialAmount": initialAmount,
    };
  }
}
