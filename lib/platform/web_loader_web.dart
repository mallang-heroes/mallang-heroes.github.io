import 'dart:js_interop';

@JS('mallangLoader')
external _Loader? get _loader;

extension type _Loader(JSObject _) implements JSObject {
  external void progress(double p);
}

/// 웹: index.html의 로딩 화면에 그림 진행률(0~1)을 알린다. 1이면 로딩 화면이 사라진다.
void reportWebLoader(double progress) {
  try {
    _loader?.progress(progress);
  } catch (_) {}
}
