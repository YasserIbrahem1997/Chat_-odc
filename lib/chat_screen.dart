import 'package:audio_session/audio_session.dart';
import 'package:chatodc/message_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record_mp3/record_mp3.dart';
import 'dart:io';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController messageController = TextEditingController();
  String statusText = "";
  bool isComplete = true;
  String recordFilePath = "";
  String? recordUrl;

  Stream<QuerySnapshot> getMessages() {
    return FirebaseFirestore.instance
        .collection("chat")
        .orderBy("time")
        .snapshots();
  }

  Future<bool> checkPermission() async {
    if (!await Permission.microphone.isGranted) {
      PermissionStatus status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  Future<String> getFilePath() async {
    Directory storageDirectory = await getApplicationDocumentsDirectory();
    String sdPath = storageDirectory.path + "/record";
    var d = Directory(sdPath);
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
    return sdPath + "/${DateTime.now().microsecondsSinceEpoch}.mp3";
  }

  void startRecord() async {
    bool hasPermission = await checkPermission();
    if (hasPermission) {
      statusText = "Recording...";
      recordFilePath = await getFilePath();
      isComplete = false;
      RecordMp3.instance.start(recordFilePath, (type) {
        statusText = "Record error--->$type";
        setState(() {});
      });
    } else {
      statusText = "No microphone permission";
    }
    setState(() {});
  }

  Future<void> stopRecord() async {
    bool s = RecordMp3.instance.stop();
    if (s) {
      statusText = "Record complete";
      isComplete = true;
      setState(() {});
    }
  }

  Future uploadRecord() async {
    Reference reference = FirebaseStorage.instance
        .ref()
        .child("chat")
        .child("Ehab")
        .child(recordFilePath.split("/").last);

    UploadTask uploadTask = reference.putFile(File(recordFilePath));
    await uploadTask.whenComplete(() async {
      await reference.getDownloadURL().then((urlRecord) {
        recordUrl = urlRecord;
      });
    });
  }

  @override
  void initState() {}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Chat App",
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey.shade200,
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
                stream: getMessages(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    var data = snapshot.data!.docs;
                    return ListView.builder(
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        MessageModel messageModel = MessageModel(
                          name: data[index]["name"],
                          text: data[index]["text"],
                        );
                        return messageModel.name == "Ehab Atef"
                            ? SizedBox(
                                width: 50,
                                child: Card(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(messageModel.name),
                                      Text(messageModel.text),
                                      IconButton(
                                              onPressed: () async {
                                                AudioPlayer _player = AudioPlayer();
                                                final session =
                                                    await AudioSession.instance;
                                                await session.configure(
                                                    const AudioSessionConfiguration
                                                        .speech());
                                                try {
                                                  await _player.setAudioSource(
                                                    LockCachingAudioSource(
                                                      Uri.parse(data[index]
                                                          ["record"]),
                                                    ),
                                                  ).whenComplete((){
                                                    _player.play();
                                                  });
                                                } catch (e) {
                                                  // catch load errors: 404, invalid url ...
                                                  print("An error occured $e");
                                                }
                                              },
                                              icon: Icon(Icons.play_arrow))
                                    ],
                                  ),
                                ),
                              )
                            : SizedBox(
                                width: 50,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          messageModel.name,
                                          style: const TextStyle(
                                              color: Colors.teal, fontSize: 20),
                                          textAlign: TextAlign.start,
                                        ),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                        Text(
                                          messageModel.text,
                                          style: const TextStyle(
                                              color: Colors.black),
                                          textAlign: TextAlign.start,
                                        ),
                                        const SizedBox(
                                          height: 10,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                      },
                    );
                  } else {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.teal,
                      ),
                    );
                  }
                }),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Flexible(
                  child: TextFormField(
                    keyboardType: TextInputType.text,
                    controller: messageController,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyText1!.color),
                    decoration: InputDecoration(
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.grey.shade800,
                            style: BorderStyle.solid,
                            width: 1),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Colors.red,
                              style: BorderStyle.solid,
                              width: 1)),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Colors.red,
                              style: BorderStyle.solid,
                              width: 1)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: Colors.grey,
                              style: BorderStyle.solid,
                              width: 1)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Colors.grey,
                            style: BorderStyle.solid,
                            width: 1),
                      ),
                      hintStyle: const TextStyle(color: Colors.grey),
                      hintText: "Message...",
                      labelText: "Message",
                      labelStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodyText1!.color),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: FloatingActionButton(
                    backgroundColor: Colors.teal[700],
                    onPressed: () {
                      if (messageController.text != "") {
                        DateTime currentPhoneDate = DateTime.now(); //DateTime
                        FirebaseFirestore.instance.collection("chat").add({
                          "name": "Ehab Atef",
                          "text": messageController.text,
                          "time": currentPhoneDate,
                        }).whenComplete(() {
                          messageController.clear();
                        });
                      } else {
                        if (isComplete) {
                          startRecord();
                        } else {
                          DateTime currentPhoneDate = DateTime.now();
                          stopRecord().whenComplete(() {
                            uploadRecord().whenComplete(() {
                              FirebaseFirestore.instance
                                  .collection("chat")
                                  .add({
                                "name": "Ehab Atef",
                                "text": "",
                                "time": currentPhoneDate,
                                "record": recordUrl,
                              });
                            });
                          });
                        }
                      }
                    },
                    child: Center(
                        child: Icon(
                      messageController.text != ""
                          ? Icons.send
                          : isComplete
                              ? Icons.record_voice_over
                              : Icons.stop,
                      color: Colors.white,
                    )),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
