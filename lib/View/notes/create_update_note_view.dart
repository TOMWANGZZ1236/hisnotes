import 'package:flutter/material.dart';
import 'package:hisnotes/constants/colors.dart';
import 'package:hisnotes/services/auth/auth_service.dart';
import 'package:hisnotes/services/cloud/cloud_note.dart';
import 'package:hisnotes/utilities/dialogs/cannot_share_empty_note_dialog.dart';
import 'package:hisnotes/utilities/dialogs/error_dialog.dart';
import 'package:hisnotes/utilities/generics/get_arguments.dart';

import 'package:hisnotes/services/cloud/firebase_cloud_storage.dart';
import 'package:share_plus/share_plus.dart';

class NewNoteView extends StatefulWidget {
  const NewNoteView({super.key});

  @override
  State<NewNoteView> createState() => _NewNoteViewState();
}

class _NewNoteViewState extends State<NewNoteView> {
  CloudNote? _note;
  late final FirebaseCloudStorage _notesService;
  late final TextEditingController _textEditingController;

  @override
  void initState() {
    _notesService = FirebaseCloudStorage();
    _textEditingController = TextEditingController();
    super.initState();
  }

  void _textControllerListener() async {
    final note = _note;
    if (note == null) {
      return;
    }
    final text = TextEditingController().text;
    try {
      await _notesService.updateNote(
        text: text,
        documentId: note.documentId,
      );
    } catch (e) {
      return;
    }
  }

  void _setUpTextControllerListener() {
    _textEditingController.removeListener(_textControllerListener);
    _textEditingController.addListener(_textControllerListener);
  }

  Future<CloudNote> createOrGetExistingNote(BuildContext context) async {
    final widgetNote = context.getArgument<CloudNote>();

    if (widgetNote != null) {
      _note = widgetNote;
      _textEditingController.text = widgetNote.text;
      return widgetNote;
    }

    final existingNote = _note;
    if (existingNote != null) {
      return existingNote;
    }
    final currentUser = AuthService.firebase().currentUser!;
    final userId = currentUser.id;
    final newNote = await _notesService.createNewNote(ownerUserId: userId);
    _note = newNote;
    return newNote;
  }

  //this check is to avoid putting it in the database if note is not entered
  void _deleteNoteIfTextIsEmpty() {
    final note = _note;
    if (_textEditingController.text.isEmpty && note != null) {
      _notesService.deleteNote(documentId: note.documentId);
    }
  }

  void _createNoteIfTextIsNotEmpty() {
    final note = _note;
    final text = _textEditingController.text;
    if (text.isNotEmpty && note != null) {
      try {
        _notesService.updateNote(
          text: text,
          documentId: note.documentId,
        );
      } catch (e) {
        return;
      }
    }
  }

  @override
  void dispose() {
    _deleteNoteIfTextIsEmpty();
    _createNoteIfTextIsNotEmpty();
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("New Notes:"),
          backgroundColor: appBarColor,
          actions: [
            IconButton(
              onPressed: () async {
                final text = _textEditingController.text;
                if (_note == null || text.isEmpty) {
                  await showCannotShareEmptyNoteDialog(context);
                } else {
                  Share.share(text);
                }
              },
              icon: const Icon(Icons.share),
            )
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FutureBuilder(
            future: createOrGetExistingNote(context),
            builder: (context, snapshot) {
              switch (snapshot.connectionState) {
                case ConnectionState.done:
                  // _note = snapshot.data;
                  _setUpTextControllerListener();
                  return TextField(
                    controller: _textEditingController,
                    keyboardType: TextInputType.multiline,
                    maxLines: null,
                    decoration: const InputDecoration(
                        hintText: "Please enter your notes"),
                  );

                default:
                  return const CircularProgressIndicator();
              }
            },
          ),
        ));
  }
}
