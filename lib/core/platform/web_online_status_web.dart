// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool? get isBrowserOnline => html.window.navigator.onLine;
