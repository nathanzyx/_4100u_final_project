import 'package:study_connect_server/study_connect_server.dart' as study_connect_server;
import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8080);
  print('StudyConnect server listening on http://localhost:8080');

}
