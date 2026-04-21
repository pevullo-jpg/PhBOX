class BoxModel {
  final String id;
  String name;
  double initialAmount;
  int color;

  BoxModel({
    required this.id,
    required this.name,
    required this.initialAmount,
    required this.color,
  });

  factory BoxModel.fromJson(Map<String, dynamic> json) {
    return BoxModel(
      id: json['id'],
      name: json['name'],
      initialAmount: (json['initialAmount'] ?? 0).toDouble(),
      color: json['color'] ?? 0xFFE91E8C,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "initialAmount": initialAmount,
      "color": color,
    };
  }
}
