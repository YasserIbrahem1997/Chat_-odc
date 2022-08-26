import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String name;
  final String text;

  MessageModel({
    required this.name,
    required this.text,
  });
}
