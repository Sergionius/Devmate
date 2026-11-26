import 'package:sembast_web/sembast_web.dart';

Future<Database> openChatHistoryDatabase() =>
    databaseFactoryWeb.openDatabase('devmate-chats');
