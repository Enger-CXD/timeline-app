void main() {
  for (final s in ['当前位置', '湖北省恩施市', '北京市朝阳区']) {
    final sep = s.indexOf('省');
    if (sep >= 0) { print('$s -> [$sep] province=${s.substring(0, sep+1)} city=${s.substring(sep+1)}'); continue; }
    final m = RegExp(r'[市区盟州]').firstMatch(s);
    print('$s -> match=${m?.start}');
  }
}
