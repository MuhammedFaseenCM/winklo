import 'cell.dart';

class Wall {
  const Wall(this.a, this.b);

  final Cell a;
  final Cell b;

  bool blocks(Cell from, Cell to) {
    return (from == a && to == b) || (from == b && to == a);
  }

  factory Wall.fromJson(Map<String, dynamic> json) {
    return Wall(
      Cell.fromJson(json['a']),
      Cell.fromJson(json['b']),
    );
  }

  Map<String, dynamic> toJson() => {'a': a.toList(), 'b': b.toList()};
}
