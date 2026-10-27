// 웹에서만 HTML 로딩 화면(web/index.html)에 진행률을 알린다. 앱에서는 아무것도 안 함.
export 'web_loader_stub.dart' if (dart.library.js_interop) 'web_loader_web.dart';
