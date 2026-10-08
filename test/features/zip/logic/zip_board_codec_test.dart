import 'package:flutter_test/flutter_test.dart';
import 'package:winklo/domain/entities/cell.dart';
import 'package:winklo/features/zip/logic/zip_board_codec.dart';

void main() {
  test('round-trips a path', () {
    const path = [Cell(0, 0), Cell(0, 1), Cell(10, 7)];

    final board = ZipBoardCodec.encode(path);

    expect(board, '0,0;0,1;10,7');
    expect(ZipBoardCodec.decode(board), path);
  });

  test('missing or malformed boards decode to null', () {
    expect(ZipBoardCodec.decode(null), isNull);
    expect(ZipBoardCodec.decode(''), isNull);
    expect(ZipBoardCodec.decode('0,0;0'), isNull);
    expect(ZipBoardCodec.decode('0,0;a,1'), isNull);
    expect(ZipBoardCodec.decode('0,0;-1,1'), isNull);
    expect(ZipBoardCodec.decode('0,0,1'), isNull);
  });
}
