// Generate a hash for a given input string, using SHA-256 algorithm.
import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateMd5Hash(String input) {
  final bytes = utf8.encode(input.toLowerCase());
  final digest = md5.convert(bytes);

  return digest.toString();
}

void main(List<String> args) {
  final input = "Hello, World!";
  final hash = generateMd5Hash(input);
  print("MD5 hash of '$input' is: $hash");

  final input2 = "Hello, Dart!";
  final hash2 = generateMd5Hash(input2);
  print("MD5 hash of '$input2' is: $hash2");

  //  "model": "iPhone 14 Pro",
  // "name": "John's iPhone",
  // "person_external_id": "5ae46bc1-4534-4b04-8b35-27ab07451c93",

  final input3 =
      "iPhone 14 Pro-John's iPhone-5ae46bc1-4534-4b04-8b35-27ab07451c93";
  final hash3 = generateMd5Hash(input3);
  print("MD5 hash of '$input3' is: $hash3");
}
