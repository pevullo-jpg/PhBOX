class RecurringGroup {
  final String id;
  String name;

  RecurringGroup({
    required this.id,
    required this.name,
  });

  factory RecurringGroup.fromJson(Map<String, dynamic> json) {
    return RecurringGroup(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
    };
  }
}
