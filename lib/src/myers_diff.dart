import 'package:animated_stream_list/src/diff_payload.dart';
import 'package:animated_stream_list/src/path_node.dart';
import 'package:flutter/foundation.dart';

class DiffUtil<T> {
  Future<List<Diff>> calculateDiff(List<T> oldList, List<T> newList) {
    final args = _DiffArguments<T>(oldList, newList);
    return compute(_myersDiff, args);
  }
}

class _DiffArguments<T> {
  final List<T> oldList;
  final List<T> newList;

  _DiffArguments(this.oldList, this.newList);
}

List<Diff> _myersDiff<T>(_DiffArguments<T> args) {
  final List<T> oldList = args.oldList;
  final List<T> newList = args.newList;

  if (oldList == newList) return [];

  final oldSize = oldList.length;
  final newSize = newList.length;

  if (oldSize == 0) {
    return [InsertDiff(0, newSize, newList)];
  }

  if (newSize == 0) {
    return [DeleteDiff(0, oldSize)];
  }

  final equals = (a, b) => a == b;
  final path = _buildPath(oldList, newList, equals);
  final diffs = _buildPatch(path, oldList, newList)..sort();
  return diffs.reversed.toList(growable: true);
}

PathNode _buildPath<T>(List<T> oldList, List<T> newList, bool Function(T,T) equals) {
  final oldSize = oldList.length;
  final newSize = newList.length;

  final int max = oldSize + newSize + 1;
  final size = (2 * max) + 1;
  final int middle = size ~/ 2;
  final List<PathNode?> diagonal = List.filled(size, null);

  diagonal[middle + 1] = Snake(0, -1, null);
  
  for (int d = 0; d < max; d++) {
    for (int k = -d; k <= d; k += 2) {
      final int kmiddle = middle + k;
      final int kplus = kmiddle + 1;
      final int kminus = kmiddle - 1;
      PathNode? prev;

      int i;
      if ((k == -d) ||
          (k != d &&
              diagonal[kminus]!.originIndex < diagonal[kplus]!.originIndex)) {
        i = diagonal[kplus]!.originIndex;
        prev = diagonal[kplus];
      } else {
        i = diagonal[kminus]!.originIndex + 1;
        prev = diagonal[kminus];
      }

      diagonal[kminus] = null;

      int j = i - k;

      PathNode node;

      if(prev != null){
        node= DiffNode(i,j,prev);
       }else{
         throw Exception('Previous node is null');
       }

       while (i < oldSize && j < newSize && equals(oldList[i], newList[j])) {
         i++;
         j++;
       }
      
       if (i > node.originIndex) {
         node= Snake(i,j,node);
       }

       diagonal[kmiddle]=node;

       if(i>=oldSize && j>=newSize){
         return diagonal[kmiddle]!;
       }
     }
     diagonal[middle+d-1]=null;
   }
   throw Exception();
}

List<Diff> _buildPatch<T>(PathNode? path, List<T> oldList, List<T> newList) {

  PathNode? _path = path;

  if (_path == null) throw ArgumentError("path is null");

  final List<Diff> diffs = [];
  if (_path.isSnake()) {
    _path = _path.previousNode;
  }

  while (_path != null &&
      _path.previousNode != null &&
      _path.previousNode!.revisedIndex >= 0) {
    if (_path.isSnake()) throw Exception();
    int i = _path.originIndex;
    int j = _path.revisedIndex;

    path = path?.previousNode;
    int iAnchor = _path.originIndex;
    int jAnchor = _path.revisedIndex;

    List<T> original = oldList.sublist(iAnchor, i);
    List<T> revised = newList.sublist(jAnchor, j);

    if (original.length == 0 && revised.length != 0) {
      diffs.add(InsertDiff(iAnchor, revised.length, revised));
    } else if (original.length > 0 && revised.length == 0) {
      diffs.add(DeleteDiff(iAnchor, original.length));
    } else {
      diffs.add(ChangeDiff(iAnchor, original.length, revised));
    }

    if (_path.isSnake()) {
      path = _path.previousNode;
    }
  }

  return diffs;
}
