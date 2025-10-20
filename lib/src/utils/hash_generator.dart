// Generate a hash for a given input string, using SHA-256 algorithm.
import 'dart:convert';
import 'package:crypto/crypto.dart';

String generateMd5Hash(String input) {
  final bytes = utf8.encode(input.toLowerCase());
  final digest = md5.convert(bytes);

  return digest.toString();
}
