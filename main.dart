import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:safe_device/safe_device.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:device_apps/device_apps.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'package:notification_listener_service/notification_event.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:marquee/marquee.dart';

// ================= BẢNG MÀU =================
class RobertColors {
  static const wall = Color(0xFFFFEFC5); static const brown = Color(0xFFCB8F66);
  static const brownBorder = Color(0xFFB86F3C); static const brownDark = Color(0xFF82481E);
  static const note = Color(0xFFF8C760); static const noteBorder = Color(0xFFB47605);
  static const textMain = Color(0xFF2D2926); static const textDone = Color(0xFFCDA247);
  static const highlightPink = Color(0xFFFF8685); static const highlightRed = Color(0xFFDF6665);
  static const highlightRedDark = Color(0xFFBD3C41); static const doneGreen = Color(0xFF639922);
  static const bubbleBg = Color(0xFFD0D3EB); static const bubbleText = Color(0xFF495DA5);
  static const laptopGrey = Color(0xFF6D7075); static const polaroidPh = Color(0xFFCBB4A8);
  static const shirtWhite = Color(0xFFF2E8E4); static const polaroidBorder = Color(0xFF8F7C72);
}

// ================= BIẾN TOÀN CỤC =================
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);
final ValueNotifier<Color?> customColorNotifier = ValueNotifier(null);
List<CameraDescription> cameras = [];
final ValueNotifier<List<Map<String, String>>> globalLocalSongs = ValueNotifier([]);
final ValueNotifier<bool> globalSpatialAudio = ValueNotifier(false);
final ValueNotifier<bool> globalLosslessAudio = ValueNotifier(false);
String currentDeviceType = 'phone'; 

Color getAppTextColor(BuildContext context) {
  if (customColorNotifier.value != null) return customColorNotifier.value!;
  return Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try { cameras = await availableCameras(); } catch (e) {}
  
  if (Platform.isAndroid) {
    AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
    double screenInches = (info.displayMetrics.widthPx / info.displayMetrics.xDpi + info.displayMetrics.heightPx / info.displayMetrics.yDpi) / 2;
    if (screenInches > 7.0) currentDeviceType = 'tablet';
  } else if (Platform.isWindows || Platform.isMacOS) {
    currentDeviceType = 'laptop';
  }

  await LocalDataManager.initFolder();
  globalLocalSongs.value = await LocalDataManager.loadLocalMusic();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return ValueListenableBuilder<Color?>(
          valueListenable: customColorNotifier,
          builder: (context, customColor, child) {
            return MaterialApp(
              title: 'Co-op', debugShowCheckedModeBanner: false,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              theme: ThemeData(brightness: Brightness.light, scaffoldBackgroundColor: RobertColors.wall, fontFamily: 'Rissa'),
              darkTheme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: const Color(0xFF0B1220), fontFamily: 'Rissa'),
              home: const WalletPage(),
            );
          }
        );
      },
    );
  }
}

// ================= DATA & MODELS =================
class LocalDataManager {
  static late Directory mainFolder; static late Directory publicDownloadFolder; 
  static Future<void> initFolder() async { Directory appDocDir = await getApplicationDocumentsDirectory(); mainFolder = Directory('${appDocDir.path}/money_schedule'); if (!await mainFolder.exists()) await mainFolder.create(recursive: true); if (Platform.isAndroid) { publicDownloadFolder = Directory('/storage/emulated/0/Download/Flutter'); if (!await publicDownloadFolder.exists()) { try { await publicDownloadFolder.create(recursive: true); } catch (e) {} } } }
  static Future<String> saveImage(File tempImage) async { String fileName = "IMG_${DateTime.now().millisecondsSinceEpoch}.jpg"; File newFile; if (Platform.isAndroid && await publicDownloadFolder.exists()) { newFile = await tempImage.copy('${publicDownloadFolder.path}/$fileName'); } else { newFile = await tempImage.copy('${mainFolder.path}/$fileName'); } return newFile.path; }
  static Future<void> saveAppData(List<CardModel> cards, List<Transaction> transactions) async { Map<String, dynamic> data = {"cards": cards.map((c) => c.toJson()).toList(), "transactions": transactions.map((t) => t.toJson()).toList()}; await File('${mainFolder.path}/data.json').writeAsString(jsonEncode(data)); }
  static Future<Map<String, dynamic>?> loadAppData() async { File jsonFile = File('${mainFolder.path}/data.json'); if (await jsonFile.exists()) return jsonDecode(await jsonFile.readAsString()); return null; }
  static Future<void> saveNotis(List<NotiModel> notis) async { List<dynamic> data = notis.map((n) => n.toJson()).toList(); await File('${mainFolder.path}/noti.json').writeAsString(jsonEncode(data)); }
  static Future<List<NotiModel>> loadNotis() async { File jsonFile = File('${mainFolder.path}/noti.json'); if (await jsonFile.exists()) { List<dynamic> data = jsonDecode(await jsonFile.readAsString()); return data.map((e) => NotiModel.fromJson(e)).toList(); } return []; }
  static Future<void> saveLocalMusic(List<Map<String, String>> songs) async { await File('${mainFolder.path}/local_music.json').writeAsString(jsonEncode(songs)); }
  static Future<List<Map<String, String>>> loadLocalMusic() async { File f = File('${mainFolder.path}/local_music.json'); if (await f.exists()) { List<dynamic> data = jsonDecode(await f.readAsString()); return data.map((e) => Map<String, String>.from(e)).toList(); } return []; }
  static Future<void> saveNotes(List<NoteModel> notes) async { await File('${mainFolder.path}/notes_robert.json').writeAsString(jsonEncode(notes.map((e) => e.toJson()).toList())); }
  static Future<List<NoteModel>> loadNotes() async { File f = File('${mainFolder.path}/notes_robert.json'); if (await f.exists()) { List<dynamic> data = jsonDecode(await f.readAsString()); return data.map((e) => NoteModel.fromJson(e)).toList(); } return []; }
  static Future<void> clearAllData() async { if (await mainFolder.exists()) await mainFolder.delete(recursive: true); await initFolder(); }
  static Future<int> getFolderSize() async { int size = 0; if (await mainFolder.exists()) { await for (var entity in mainFolder.list(recursive: true, followLinks: false)) { if (entity is File) size += await entity.length(); } } if (Platform.isAndroid && await publicDownloadFolder.exists()) { await for (var entity in publicDownloadFolder.list(recursive: true, followLinks: false)) { if (entity is File) size += await entity.length(); } } return size; }
}

enum TransactionType { income, expense } enum CardCategory { bank, door, parking, other }
class CardModel { final String name; final String number; final Color color1; final Color color2; final CardCategory category; CardModel(this.name, this.number, this.color1, this.color2, this.category); Map<String, dynamic> toJson() => {"name": name, "number": number, "color1": color1.value, "color2": color2.value, "category": category.index}; static CardModel fromJson(Map<String, dynamic> json) => CardModel(json["name"], json["number"], Color(json["color1"]), Color(json["color2"]), CardCategory.values[json["category"]]); }
class Transaction { final String? imagePath; final double amount; final String note; final DateTime date; final TransactionType type; Transaction(this.imagePath, this.amount, this.note, this.date, this.type); Map<String, dynamic> toJson() => {"imagePath": imagePath, "amount": amount, "note": note, "date": date.toIso8601String(), "type": type.index}; static Transaction fromJson(Map<String, dynamic> json) => Transaction(json["imagePath"], json["amount"], json["note"], DateTime.parse(json["date"]), TransactionType.values[json["type"]]); }
class NotiModel { final String id; final String packageName; final String title; final String body; final DateTime timestamp; NotiModel(this.id, this.packageName, this.title, this.body, this.timestamp); Map<String, dynamic> toJson() => {"id": id, "packageName": packageName, "title": title, "body": body, "timestamp": timestamp.toIso8601String()}; static NotiModel fromJson(Map<String, dynamic> json) => NotiModel(json["id"], json["packageName"], json["title"], json["body"], DateTime.parse(json["timestamp"])); }
class NoteModel { 
  String id; String type; String text; double dx; double dy; bool done; double w; double h;
  NoteModel({required this.id, required this.type, required this.text, required this.dx, required this.dy, this.done = false, this.w = 160, this.h = 160}); 
  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'text': text, 'dx': dx, 'dy': dy, 'done': done, 'w': w, 'h': h}; 
  static NoteModel fromJson(Map<String, dynamic> json) => NoteModel(id: json['id'], type: json['type'] ?? 'text', text: json['text'], dx: json['dx'], dy: json['dy'], done: json['done'] ?? false, w: json['w']?.toDouble() ?? 160.0, h: json['h']?.toDouble() ?? 160.0); 
}

// ================= FADE INDEXED STACK =================
class FadeIndexedStack extends StatefulWidget {
  final int index; final List<Widget> children;
  const FadeIndexedStack({super.key, required this.index, required this.children});
  @override State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}
class _FadeIndexedStackState extends State<FadeIndexedStack> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override void initState() { _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300))..forward(); super.initState(); }
  @override void didUpdateWidget(FadeIndexedStack oldWidget) { if (widget.index != oldWidget.index) _controller.forward(from: 0.0); super.didUpdateWidget(oldWidget); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return FadeTransition(opacity: _controller, child: IndexedStack(index: widget.index, children: widget.children)); }
}

// ================= GIAO DIỆN CHÍNH (WALLET PAGE) =================
class WalletPage extends StatefulWidget { const WalletPage({super.key}); @override State<WalletPage> createState() => _WalletPageState(); }
class _WalletPageState extends State<WalletPage> with SingleTickerProviderStateMixin {
  int selectedIndex = 6; 
  int? expandedCardIndex; bool isScanningNFC = false; CardCategory selectedFilter = CardCategory.bank;
  List<CardModel> cards = []; List<Transaction> transactions = [];
  
  @override void initState() { super.initState(); _requestAppPermissionsOnInit(); }
  Future<void> _requestAppPermissionsOnInit() async { await [Permission.storage, Permission.manageExternalStorage, Permission.camera, Permission.location, Permission.bluetooth, Permission.bluetoothAdvertise, Permission.bluetoothConnect, Permission.bluetoothScan, Permission.nearbyWifiDevices, Permission.audio].request(); await LocalDataManager.initFolder(); _loadDataFromStorage(); }
  Future<void> _loadDataFromStorage() async { var data = await LocalDataManager.loadAppData(); if (data != null) { setState(() { cards = (data["cards"] as List).map((e) => CardModel.fromJson(e)).toList(); transactions = (data["transactions"] as List).map((e) => Transaction.fromJson(e)).toList(); }); } else { setState(() => cards = []); _saveData(); } }
  Future<void> _saveData() async => await LocalDataManager.saveAppData(cards, transactions);
  String _bytesToHex(List<int> bytes) => bytes.map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase()).join(':');
  Future<void> scanNFC() async { bool isAvailable = await NfcManager.instance.isAvailable(); if (!isAvailable) return; setState(() => isScanningNFC = true); HapticFeedback.heavyImpact(); NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async { NfcManager.instance.stopSession(); HapticFeedback.vibrate(); String uidStr = "UNKNOWN"; String atqa = "N/A"; String sak = "N/A"; String memory = "Unknown"; List<String> techList = []; try { if (Platform.isAndroid && tag.data['techList'] != null) techList = (tag.data['techList'] as List).map((e) => e.toString().split('.').last).toList(); var nfca = tag.data['nfca']; if (nfca != null) { if (nfca['identifier'] != null) uidStr = _bytesToHex(List<int>.from(nfca['identifier'])); if (nfca['atqa'] != null) atqa = "0x" + _bytesToHex(List<int>.from(nfca['atqa'])).replaceAll(":", ""); if (nfca['sak'] != null) sak = "0x" + nfca['sak'].toRadixString(16).padLeft(2, '0').toUpperCase(); } else { List<int>? idBytes = tag.data['nfcb']?['identifier'] ?? tag.data['nfcv']?['identifier'] ?? tag.data['isodep']?['identifier']; if (idBytes != null) uidStr = _bytesToHex(idBytes); } var ndef = Ndef.from(tag); if (ndef != null) memory = "${ndef.maxSize} bytes"; } catch (e) {} setState(() => isScanningNFC = false); _showNfcToolsDialog(tag, uidStr, techList, atqa, sak, memory); }).catchError((e) { setState(() => isScanningNFC = false); }); }
  void _showNfcToolsDialog(NfcTag tag, String uid, List<String> techList, String atqa, String sak, String memory) { showModalBottomSheet(context: context, backgroundColor: const Color(0xFF1E1E1E), isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) { return SizedBox(height: MediaQuery.of(context).size.height * 0.85, child: DefaultTabController(length: 3, child: Column(children: [AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)), title: const Text("NFC Tools", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Rissa', fontSize: 24)), bottom: const TabBar(indicatorColor: Colors.deepOrangeAccent, labelColor: Colors.deepOrangeAccent, unselectedLabelColor: Colors.white54, tabs: [Tab(text: "READ"), Tab(text: "WRITE"), Tab(text: "OTHER")])), Expanded(child: TabBarView(children: [ListView(padding: const EdgeInsets.all(0), children: [ _nfcRow(Icons.memory, "Tag type", techList.isNotEmpty ? techList.first : "ISO 14443-3A"), const Divider(color: Colors.white12, height: 1), _nfcRow(Icons.info_outline, "Technologies", techList.join(", ")), const Divider(color: Colors.white12, height: 1), _nfcRow(Icons.vpn_key, "Serial number", uid, subtitleColor: Colors.amberAccent), const Divider(color: Colors.white12, height: 1), _nfcRow(Icons.settings_input_antenna, "ATQA", atqa), const Divider(color: Colors.white12, height: 1), _nfcRow(Icons.strikethrough_s, "SAK", sak), const Divider(color: Colors.white12, height: 1), _nfcRow(Icons.data_usage, "Memory", memory) ]), ListView(padding: const EdgeInsets.all(20), children: [ _actionBtn(Icons.text_fields, "Ghi Văn Bản", () { Navigator.pop(context); _writeNfcDialog("text"); }), const SizedBox(height: 10), _actionBtn(Icons.link, "Ghi URL", () { Navigator.pop(context); _writeNfcDialog("url"); }), const SizedBox(height: 10), _actionBtn(Icons.save, "Lưu vào Ví ảo", () { Navigator.pop(context); _showSaveCardDialog(uid); }) ]), ListView(padding: const EdgeInsets.all(20), children: [ _actionBtn(Icons.delete_outline, "Erase tag", () => _executeNfcAction("erase")), const SizedBox(height: 10), _actionBtn(Icons.lock_outline, "Lock tag", () => _executeNfcAction("lock"))])]))]))); }); }
  Widget _nfcRow(IconData icon, String title, String subtitle, {Color subtitleColor = Colors.white70}) => ListTile(leading: Icon(icon, color: Colors.white, size: 26), title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Rissa', fontSize: 18)), subtitle: Text(subtitle, style: TextStyle(color: subtitleColor, fontFamily: 'Rissa', fontSize: 14)));
  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(border: Border.all(color: Colors.white24), borderRadius: BorderRadius.circular(10), color: Colors.white.withOpacity(0.05)), child: Row(children: [Icon(icon, color: Colors.white), const SizedBox(width: 15), Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Rissa'))])));
  void _writeNfcDialog(String type) { TextEditingController textCtrl = TextEditingController(); showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF1E1E1E), title: Text(type == "text" ? "Write Text" : "Write URL", style: const TextStyle(color: Colors.white, fontFamily: 'Rissa', fontSize: 22)), content: TextField(controller: textCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Rissa', fontSize: 18), decoration: InputDecoration(hintText: type == "text" ? "Nhập văn bản..." : "https://...", hintStyle: const TextStyle(color: Colors.white38, fontFamily: 'Rissa', fontSize: 16))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy", style: TextStyle(fontFamily: 'Rissa', fontSize: 16))), ElevatedButton(onPressed: () async { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Áp thẻ và GIỮ YÊN 2 GIÂY để ghi...", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.orange, duration: Duration(seconds: 3))); NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async { try { NdefMessage msg = type == "text" ? NdefMessage([NdefRecord.createText(textCtrl.text)]) : NdefMessage([NdefRecord.createUri(Uri.parse(textCtrl.text))]); Ndef? ndef = Ndef.from(tag); if (ndef != null) { if (!ndef.isWritable) { NfcManager.instance.stopSession(errorMessage: "Thẻ bị khóa (Read-only)!"); return; } await ndef.write(msg); NfcManager.instance.stopSession(); HapticFeedback.heavyImpact(); } else { NdefFormatable? formatable = NdefFormatable.from(tag); if (formatable != null) { await formatable.format(msg); NfcManager.instance.stopSession(); HapticFeedback.heavyImpact(); } else { NfcManager.instance.stopSession(errorMessage: "Thẻ không hỗ trợ chuẩn NDEF!"); } } } catch (e) { NfcManager.instance.stopSession(errorMessage: "Lỗi kết nối: $e"); } }); }, child: const Text("Bắt đầu Ghi", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)))])); }
  void _executeNfcAction(String action) { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(action == "erase" ? "Áp thẻ và GIỮ YÊN để XÓA..." : "Đang xử lý...", style: const TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.redAccent, duration: const Duration(seconds: 3))); NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async { try { if (action == "erase") { Ndef? ndef = Ndef.from(tag); NdefMessage emptyMsg = NdefMessage([NdefRecord.createText("")]); if (ndef != null) { if (!ndef.isWritable) throw "Thẻ bị khóa!"; await ndef.write(emptyMsg); } else { NdefFormatable? formatable = NdefFormatable.from(tag); if (formatable != null) { await formatable.format(emptyMsg); } else { throw "Thẻ không hỗ trợ NDEF"; } } NfcManager.instance.stopSession(); HapticFeedback.heavyImpact(); } else if (action == "lock") { NfcManager.instance.stopSession(errorMessage: "Chức năng khóa thẻ yêu cầu Native Code (Root)."); } } catch (e) { NfcManager.instance.stopSession(errorMessage: "Lỗi: $e"); } }); }
  void _showSaveCardDialog(String uid) { TextEditingController nameCtrl = TextEditingController(); CardCategory tempCategory = CardCategory.door; showModalBottomSheet(context: context, backgroundColor: const Color(0xFF151C2C), isScrollControlled: true, builder: (context) { return StatefulBuilder(builder: (context, setModalState) { return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: nameCtrl, style: const TextStyle(color: Colors.white, fontFamily: 'Rissa', fontSize: 18), decoration: const InputDecoration(labelText: "Tên thẻ", labelStyle: TextStyle(color: Colors.white54, fontFamily: 'Rissa', fontSize: 16))), const SizedBox(height: 20), Wrap(spacing: 10, children: [_categoryChip("Thẻ Cửa", CardCategory.door, tempCategory, () => setModalState(() => tempCategory = CardCategory.door)), _categoryChip("Thẻ Xe", CardCategory.parking, tempCategory, () => setModalState(() => tempCategory = CardCategory.parking)), _categoryChip("Ngân Hàng", CardCategory.bank, tempCategory, () => setModalState(() => tempCategory = CardCategory.bank))]), const SizedBox(height: 30), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: () { setState(() { Color c1 = tempCategory == CardCategory.door ? Colors.blueGrey.shade900 : (tempCategory == CardCategory.parking ? Colors.orange.shade900 : const Color(0xFF1E3C72)); Color c2 = tempCategory == CardCategory.door ? Colors.grey.shade700 : (tempCategory == CardCategory.parking ? Colors.deepOrangeAccent : const Color(0xFF2A5298)); cards.add(CardModel(nameCtrl.text.isEmpty ? "Thẻ mới" : nameCtrl.text, "UID: $uid", c1, c2, tempCategory)); selectedFilter = tempCategory; _saveData(); }); Navigator.pop(context); }, child: const Text("Lưu vào Ví", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))))])); }); }); }
  Widget _categoryChip(String label, CardCategory cat, CardCategory current, VoidCallback onTap) { bool isSelected = cat == current; return GestureDetector(onTap: onTap, child: Chip(label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontFamily: 'Rissa', fontSize: 14)), backgroundColor: isSelected ? Colors.amberAccent : Colors.white12, side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)))); }
  void _openQuickPay() { HapticFeedback.heavyImpact(); List<CardModel> bankCards = cards.where((c) => c.category == CardCategory.bank).toList(); showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (context) { bool isDark = Theme.of(context).brightness == Brightness.dark; return Container(decoration: BoxDecoration(color: isDark ? const Color(0xFF1E2433) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), child: Column(children: [const SizedBox(height: 20), Text("Quick Pay", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87, fontFamily: 'Rissa')), Expanded(child: bankCards.isEmpty ? Center(child: Text("Chưa có thẻ ngân hàng", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16, fontFamily: 'Rissa'))) : PageView.builder(controller: PageController(viewportFraction: 0.85), itemCount: bankCards.length, itemBuilder: (context, index) => Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20), child: _buildWalletCard(bankCards[index]))))])); }); }
  
  void _showiOSGlassMenu() {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: "Menu", barrierColor: Colors.black.withOpacity(0.4), transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 120, left: 20, right: 20),
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Container(
                    height: 480, 
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5)
                    ),
                    padding: const EdgeInsets.only(top: 15, left: 30, right: 30, bottom: 15),
                    child: Column(
                      children: [
                        Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.white.withOpacity(0.4), borderRadius: BorderRadius.circular(10))),
                        const SizedBox(height: 20),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: GridView.count(
                              crossAxisCount: 3, mainAxisSpacing: 15, crossAxisSpacing: 15, childAspectRatio: 0.85, physics: const NeverScrollableScrollPhysics(), shrinkWrap: true,
                              children: [
                                _menuIconiOS(Icons.account_balance_wallet, "My Wallet", 0, ctx),
                                _menuIconiOS(Icons.camera_alt, "Locket", 1, ctx),
                                _menuIconiOS(Icons.sports_esports, "Games", 2, ctx),
                                _menuIconiOS(Icons.notifications_active, "Noti", 3, ctx),
                                _menuIconiOS(Icons.share, "LocalSend", 4, ctx),
                                _menuIconiOS(Icons.music_note, "Music", 5, ctx),
                                _menuIconiOS(Icons.sticky_note_2, "Notes", 6, ctx), 
                              ]
                            ),
                          )
                        )
                      ]
                    )
                  )
                )
              )
            )
          )
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) { return FadeTransition(opacity: anim1, child: SlideTransition(position: Tween(begin: const Offset(0, 0.1), end: const Offset(0, 0)).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)), child: ScaleTransition(scale: Tween(begin: 0.95, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)), child: child))); }
    );
  }

  Widget _menuIconiOS(IconData icon, String label, int index, BuildContext dialogContext) { 
    bool isActive = selectedIndex == index; 
    return GestureDetector(
      onTap: () { HapticFeedback.selectionClick(); setState(() => selectedIndex = index); Navigator.pop(dialogContext); }, 
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), 
            child: Container(
              height: 60, width: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: isActive ? [Colors.amberAccent.withOpacity(0.8), Colors.orange.withOpacity(0.5)] : [Colors.white.withOpacity(0.2), Colors.white.withOpacity(0.05)], begin: Alignment.topLeft, end: Alignment.bottomRight), border: Border.all(color: isActive ? Colors.amberAccent : Colors.white.withOpacity(0.2), width: 1.5)), 
              child: Icon(icon, color: isActive ? Colors.black : Colors.white, size: 28)
            )
          )
        ), 
        const SizedBox(height: 10), 
        Text(label, style: TextStyle(color: isActive ? Colors.amberAccent : Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'Rissa'), maxLines: 1, overflow: TextOverflow.ellipsis)
      ])
    ); 
  }

  Widget cardView(BuildContext context) { List<CardModel> filteredCards = cards.where((c) => c.category == selectedFilter).toList(); Color textColor = getAppTextColor(context); bool isDark = Theme.of(context).brightness == Brightness.dark; return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 20), Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("My Wallet", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Rissa')), Row(children: [GestureDetector(onTap: scanNFC, child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 20))), const SizedBox(width: 10), GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage(onClearData: () async { await LocalDataManager.clearAllData(); setState(() { cards.clear(); transactions.clear(); }); }))), child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, shape: BoxShape.circle), child: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87, size: 20)))])])), const SizedBox(height: 15), SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), child: Row(children: [_filterBtn("Ngân Hàng", CardCategory.bank, Icons.account_balance_wallet, isDark), const SizedBox(width: 10), _filterBtn("Thẻ Cửa", CardCategory.door, Icons.door_front_door, isDark), const SizedBox(width: 10), _filterBtn("Thẻ Xe", CardCategory.parking, Icons.local_parking, isDark)])), Expanded(child: filteredCards.isEmpty ? Center(child: Text("Chưa có thẻ nào", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16, fontFamily: 'Rissa'))) : Stack(children: List.generate(filteredCards.length, (index) { bool isExpanded = expandedCardIndex == index; bool isAnyExpanded = expandedCardIndex != null; double topOffset = isAnyExpanded ? (isExpanded ? 20.0 : MediaQuery.of(context).size.height) : index * 65.0 + 20.0; return AnimatedPositioned(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic, top: topOffset, left: 20, right: 20, height: 220, child: GestureDetector(onTap: () { HapticFeedback.selectionClick(); setState(() => expandedCardIndex = isExpanded ? null : index); }, child: _buildWalletCard(filteredCards[index]))); })))]); }
  Widget _filterBtn(String label, CardCategory cat, IconData icon, bool isDark) { bool isSelected = selectedFilter == cat; return GestureDetector(onTap: () { HapticFeedback.lightImpact(); setState(() { selectedFilter = cat; expandedCardIndex = null; }); }, child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10), decoration: BoxDecoration(color: isDark ? (isSelected ? Colors.white : Colors.white12) : (isSelected ? Colors.black : Colors.black12), borderRadius: BorderRadius.circular(25)), child: Row(children: [Icon(icon, size: 16, color: isDark ? (isSelected ? Colors.black : Colors.white54) : (isSelected ? Colors.white : Colors.black54)), const SizedBox(width: 5), Text(label, style: TextStyle(color: isDark ? (isSelected ? Colors.black : Colors.white54) : (isSelected ? Colors.white : Colors.black54), fontWeight: FontWeight.bold, fontFamily: 'Rissa', fontSize: 14))]))); }
  Widget _buildWalletCard(CardModel card) { bool isLight = card.color1 == Colors.white; return Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), gradient: LinearGradient(colors: [card.color1, card.color2]), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))]), padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(card.name, style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rissa')), Icon(Icons.contactless, color: isLight ? Colors.black54 : Colors.white70)]), const Spacer(), Text(card.number, style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 20, letterSpacing: 2, fontFamily: 'Rissa', fontWeight: FontWeight.bold))])); }

  @override
  Widget build(BuildContext context) {
    bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            bottom: false, 
            child: FadeIndexedStack(
              index: selectedIndex,
              children: [
                cardView(context),
                LocketCameraTab(
                  isActive: selectedIndex == 1, // CHỈ BẬT CAM KHI Ở ĐÚNG TAB LOCKET
                  transactions: transactions, 
                  onNewTransaction: (t) async { if (t.imagePath != null) { String p = await LocalDataManager.saveImage(File(t.imagePath!)); setState(() => transactions.add(Transaction(p, t.amount, t.note, t.date, t.type))); await _saveData(); } }
                ),
                const GameSpaceTab(),
                const NotiLogTab(),
                const LocalSendTab(),
                const MusicTab(),
                const NotesTab()
              ],
            )
          ),
          
          Positioned(
            bottom: isLandscape ? 10 : 30, left: 0, right: 0, 
            child: Center(
              child: GestureDetector(
                onTap: _showiOSGlassMenu, 
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40), 
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30), 
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: isLandscape ? 8 : 15), 
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)]), borderRadius: BorderRadius.circular(40), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]), 
                      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.widgets_rounded, color: Colors.white, size: isLandscape ? 18 : 22), const SizedBox(width: 10), const Text("MENU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16, fontFamily: 'Rissa'))])
                    )
                  )
                )
              )
            )
          ),
          if (selectedIndex == 0 && !isLandscape) Positioned(bottom: 0, left: 0, right: 0, child: GestureDetector(onVerticalDragEnd: (details) { if (details.primaryVelocity! < -100) _openQuickPay(); }, onTap: _openQuickPay, child: Container(height: 25, color: Colors.transparent, alignment: Alignment.bottomCenter, padding: const EdgeInsets.only(bottom: 8), child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white38 : Colors.black26, borderRadius: BorderRadius.circular(10))))))
        ],
      ),
    );
  }
}

// ================= CÁC TAB CHỨC NĂNG FULL =================

class NotiLogTab extends StatefulWidget { const NotiLogTab({super.key}); @override State<NotiLogTab> createState() => _NotiLogTabState(); }
class _NotiLogTabState extends State<NotiLogTab> { 
  List<NotiModel> notifications = []; bool isSelectionMode = false; Set<int> selectedIndexes = {}; 
  @override void initState() { super.initState(); _initNotiListener(); } 
  Future<void> _initNotiListener() async { 
    notifications = await LocalDataManager.loadNotis(); setState(() {}); 
    bool isGranted = await NotificationListenerService.isPermissionGranted(); 
    if (!isGranted) await NotificationListenerService.requestPermission(); 
    NotificationListenerService.notificationsStream.listen((event) async { 
      if (event.packageName == null || event.title == null) return; 
      if (event.title!.isEmpty && (event.content == null || event.content!.isEmpty)) return; 
      setState(() { notifications.insert(0, NotiModel(event.id.toString(), event.packageName!, event.title ?? "Không", event.content ?? "", DateTime.now())); }); 
      await LocalDataManager.saveNotis(notifications); 
    }); 
  } 
  void _deleteSelected() async { 
    List<NotiModel> remaining = []; 
    for (int i = 0; i < notifications.length; i++) { if (!selectedIndexes.contains(i)) remaining.add(notifications[i]); } 
    setState(() { notifications = remaining; selectedIndexes.clear(); isSelectionMode = false; }); 
    await LocalDataManager.saveNotis(notifications); HapticFeedback.vibrate(); 
  } 
  void _showNotiDetail(NotiModel noti) { 
    showDialog(context: context, builder: (_) => AlertDialog(backgroundColor: const Color(0xFF1E2433), title: Text(noti.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontFamily: 'Rissa')), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(noti.packageName, style: const TextStyle(color: Colors.amberAccent, fontSize: 14, fontFamily: 'Rissa')), const SizedBox(height: 15), Text(noti.body, style: const TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Rissa')), const SizedBox(height: 20), Text("Lúc: ${DateFormat('dd/MM/yyyy - HH:mm').format(noti.timestamp)}", style: const TextStyle(color: Colors.white38, fontSize: 12, fontFamily: 'Rissa'))]))); 
  } 
  @override Widget build(BuildContext context) { 
    bool isDark = Theme.of(context).brightness == Brightness.dark; Color textColor = getAppTextColor(context); 
    return Column(children: [ 
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [if (isSelectionMode) ...[Text("Đã chọn ${selectedIndexes.length}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent, fontFamily: 'Rissa')), Row(children: [IconButton(icon: Icon(Icons.select_all, color: textColor), onPressed: () { setState(() { selectedIndexes = Set.from(Iterable.generate(notifications.length)); }); }), IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _deleteSelected), IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => setState(() { isSelectionMode = false; selectedIndexes.clear(); }))])] else ...[Text("Noti Log", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Rissa')), const Icon(Icons.history, color: Colors.grey)]])), 
      Expanded(child: notifications.isEmpty ? Center(child: Text("Nhật ký trống", style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16, fontFamily: 'Rissa'))) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: notifications.length, itemBuilder: (context, index) { NotiModel noti = notifications[index]; bool isSelected = selectedIndexes.contains(index); return GestureDetector(onLongPress: () { HapticFeedback.heavyImpact(); setState(() { isSelectionMode = true; selectedIndexes.add(index); }); }, onTap: () { if (isSelectionMode) { setState(() { if (isSelected) selectedIndexes.remove(index); else selectedIndexes.add(index); if (selectedIndexes.isEmpty) isSelectionMode = false; }); } else _showNotiDetail(noti); }, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: isSelected ? Colors.redAccent.withOpacity(0.2) : (isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)), borderRadius: BorderRadius.circular(15), border: isSelected ? Border.all(color: Colors.redAccent) : null), child: Row(children: [if (isSelectionMode) ...[Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.redAccent : Colors.grey), const SizedBox(width: 15)], Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(noti.title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rissa'), maxLines: 1, overflow: TextOverflow.ellipsis)), Text(DateFormat('HH:mm').format(noti.timestamp), style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Rissa'))]), const SizedBox(height: 5), Text(noti.body, style: const TextStyle(color: Colors.grey, fontSize: 14, fontFamily: 'Rissa'), maxLines: 2, overflow: TextOverflow.ellipsis)]))]))); })) 
    ]); 
  } 
}

class GameSpaceTab extends StatefulWidget { const GameSpaceTab({super.key}); @override State<GameSpaceTab> createState() => _GameSpaceTabState(); }
class _GameSpaceTabState extends State<GameSpaceTab> { 
  List<Application> apps = []; bool isLoading = true; 
  @override void initState() { super.initState(); _loadGamesFast(); } 
  Future<void> _loadGamesFast() async { List<Application> allApps = await DeviceApps.getInstalledApplications(includeAppIcons: false, includeSystemApps: false, onlyAppsWithLaunchIntent: true); var rawGames = allApps.where((app) => app.category == ApplicationCategory.game || app.packageName.toLowerCase().contains("game") || app.packageName.toLowerCase().contains("tencent") || app.packageName.toLowerCase().contains("mojang")).toList(); List<Application> gamesWithIcon = []; for (var app in rawGames) { Application? appWithIcon = await DeviceApps.getApp(app.packageName, true); if (appWithIcon != null) gamesWithIcon.add(appWithIcon); } if (mounted) setState(() { apps = gamesWithIcon; isLoading = false; }); } 
  void _launchGameWithBooster(Application app) async { showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(backgroundColor: Colors.black87, content: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(color: Colors.amberAccent), const SizedBox(height: 20), Text("Đang khởi động ${app.appName}...", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))] ))); await Future.delayed(const Duration(seconds: 2)); if (mounted) Navigator.pop(context); DeviceApps.openApp(app.packageName); } 
  @override Widget build(BuildContext context) { 
    bool isDark = Theme.of(context).brightness == Brightness.dark; Color textColor = getAppTextColor(context); 
    return Column(children: [ Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), child: Row(children: [Text("Game Space", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Rissa'))])), Expanded(child: isLoading ? const Center(child: CircularProgressIndicator()) : apps.isEmpty ? Center(child: Text("Chưa có game tải về", style: TextStyle(color: textColor, fontSize: 16, fontFamily: 'Rissa'))) : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: apps.length, itemBuilder: (context, index) { Application app = apps[index]; return Container(margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(20)), child: Row(children: [if (app is ApplicationWithIcon) ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.memory(app.icon, width: 60, height: 60)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(app.appName, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rissa')), const SizedBox(height: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(5)), child: Text("android/data/${app.packageName}", style: const TextStyle(color: Colors.blueAccent, fontSize: 12, fontFamily: 'Rissa'), maxLines: 1, overflow: TextOverflow.ellipsis))])), const SizedBox(width: 10), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.amberAccent, shape: const CircleBorder(), padding: const EdgeInsets.all(15)), onPressed: () => _launchGameWithBooster(app), child: const Icon(Icons.play_arrow, color: Colors.black))])); }))]); 
  } 
}

class SettingsPage extends StatefulWidget { final VoidCallback onClearData; const SettingsPage({super.key, required this.onClearData}); @override State<SettingsPage> createState() => _SettingsPageState(); }
class _SettingsPageState extends State<SettingsPage> { 
  String folderSizeStr = "Đang tính..."; String osVersion = "Đang tải..."; bool isRooted = false; bool isDevMode = false; bool isRealDevice = true; 
  @override void initState() { super.initState(); _loadSystemInfo(); } 
  Future<void> _loadSystemInfo() async { int sizeBytes = await LocalDataManager.getFolderSize(); DeviceInfoPlugin deviceInfo = DeviceInfoPlugin(); String os = ""; if (Platform.isAndroid) { AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo; os = "Android ${androidInfo.version.release} (API ${androidInfo.version.sdkInt})"; } try { isRooted = await SafeDevice.isJailBroken; isDevMode = await SafeDevice.isDevelopmentModeEnable; isRealDevice = await SafeDevice.isRealDevice; } catch (e) {} if (mounted) setState(() { folderSizeStr = "${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB"; osVersion = os; }); } 
  Widget _colorBtn(Color? color, String label) { bool isSelected = customColorNotifier.value == color; return GestureDetector(onTap: () { HapticFeedback.selectionClick(); customColorNotifier.value = color; }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: color ?? Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(20), border: isSelected ? Border.all(color: Colors.white, width: 2) : null), child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Rissa')))); } 
  Widget _infoRow(String title, String val, Color valColor) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.grey, fontSize: 16, fontFamily: 'Rissa')), Text(val, style: TextStyle(color: valColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rissa'))])); 
  @override Widget build(BuildContext context) { 
    bool isDark = Theme.of(context).brightness == Brightness.dark; Color textColor = getAppTextColor(context); Color cardColor = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05); 
    return Scaffold(appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textColor), title: Text("Cài đặt hệ thống", style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 22, fontFamily: 'Rissa'))), body: ListView(padding: const EdgeInsets.all(20), children: [Row(children: [const Icon(Icons.palette, color: Colors.blueAccent), const SizedBox(width: 10), const Text("Giao diện & Tùy biến", style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))]), const SizedBox(height: 15), Container(margin: const EdgeInsets.only(bottom: 30), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SwitchListTile(activeColor: Colors.blueAccent, title: Text("Chế độ Tối (Dark Mode)", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rissa')), value: isDarkModeNotifier.value, onChanged: (val) { HapticFeedback.lightImpact(); isDarkModeNotifier.value = val; }), const Divider(color: Colors.grey, height: 1), Padding(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Màu chữ ứng dụng", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rissa')), const SizedBox(height: 10), Wrap(spacing: 10, runSpacing: 10, children: [_colorBtn(null, "Mặc định"), _colorBtn(Colors.blue, "Xanh dương"), _colorBtn(Colors.greenAccent, "Xanh ngọc"), _colorBtn(Colors.orangeAccent, "Cam"), _colorBtn(Colors.pinkAccent, "Hồng")])]))])), Row(children: [const Icon(Icons.memory, color: Colors.blueAccent), const SizedBox(width: 10), const Text("Thông tin Thiết bị", style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))]), const SizedBox(height: 15), Container(margin: const EdgeInsets.only(bottom: 30), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)), child: Column(children: [_infoRow("Hệ điều hành", osVersion, Colors.greenAccent), _infoRow("Trạng thái Root", isRooted ? "Đã Root" : "Chưa Root (An toàn)", isRooted ? Colors.redAccent : Colors.greenAccent), _infoRow("Unlock Bootloader", isRooted ? "Đã Unlock (Cảnh báo)" : "Khóa / Không xác định", isRooted ? Colors.orangeAccent : Colors.grey), _infoRow("USB Debugging", isDevMode ? "Đang bật" : "Đã tắt", isDevMode ? Colors.orangeAccent : Colors.grey)])), Row(children: [const Icon(Icons.storage, color: Colors.blueAccent), const SizedBox(width: 10), const Text("Lưu trữ", style: TextStyle(color: Colors.blueAccent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))]), const SizedBox(height: 15), Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Dung lượng Data", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rissa')), Text(folderSizeStr, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rissa'))])), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), foregroundColor: Colors.redAccent, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), icon: const Icon(Icons.delete_forever), label: const Text("Xóa toàn bộ dữ liệu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rissa')), onPressed: () { widget.onClearData(); setState(() => folderSizeStr = "0.00 MB"); Navigator.pop(context); }), const SizedBox(height: 30)])); 
  } 
}

// ================= LOCKET CAMERA (ĐÃ FIX LỖI LIFECYCLE & TẮT CAMERA KHI THOÁT) =================
class LocketCameraTab extends StatefulWidget { 
  final List<Transaction> transactions; 
  final Function(Transaction) onNewTransaction; 
  final bool isActive; // Thêm biến cờ kiểm tra xem tab có đang được bật không

  const LocketCameraTab({
    super.key, 
    required this.transactions, 
    required this.onNewTransaction, 
    required this.isActive
  }); 

  @override State<LocketCameraTab> createState() => _LocketCameraTabState(); 
}

class _LocketCameraTabState extends State<LocketCameraTab> with WidgetsBindingObserver { 
  CameraController? _cameraController; int _selectedCameraIndex = 0; bool _isFlashOn = false; 
  
  @override void initState() { 
    super.initState(); 
    WidgetsBinding.instance.addObserver(this); 
    if (widget.isActive && cameras.isNotEmpty) _initCamera(_selectedCameraIndex); 
  } 

  // Lắng nghe sự kiện chuyển Tab để tự động Tắt/Bật camera
  @override void didUpdateWidget(LocketCameraTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (cameras.isNotEmpty) _initCamera(_selectedCameraIndex);
    } else if (!widget.isActive && oldWidget.isActive) {
      _cameraController?.dispose();
      _cameraController = null;
    }
  }

  // Lắng nghe sự kiện thoát App (về màn hình Home) để tắt hẳn camera chống tốn pin
  @override void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      if (widget.isActive && cameras.isNotEmpty) _initCamera(_selectedCameraIndex);
    }
  }

  @override void dispose() { 
    WidgetsBinding.instance.removeObserver(this); 
    _cameraController?.dispose(); 
    super.dispose(); 
  } 

  Future<void> _initCamera(int cameraIndex) async { 
    if (!mounted) return; 
    if (_cameraController != null) await _cameraController!.dispose(); 
    _cameraController = CameraController(cameras[cameraIndex], ResolutionPreset.high, enableAudio: false); 
    try { await _cameraController!.initialize(); if (mounted) setState(() {}); } catch (e) {} 
  } 
  
  void _toggleFlash() { if (_cameraController == null) return; setState(() { _isFlashOn = !_isFlashOn; _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off); }); } 
  void _switchCamera() { if (cameras.length < 2) return; HapticFeedback.lightImpact(); _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0; _initCamera(_selectedCameraIndex); } 
  Future<void> _takePicture() async { if (_cameraController == null || !_cameraController!.value.isInitialized) return; HapticFeedback.heavyImpact(); try { final XFile image = await _cameraController!.takePicture(); if (_isFlashOn) _toggleFlash(); if (!mounted) return; final newTransaction = await Navigator.push(context, MaterialPageRoute(builder: (context) => LocketEditorScreen(imageFile: File(image.path)))); if (newTransaction != null && newTransaction is Transaction) widget.onNewTransaction(newTransaction); } catch (e) {} } 
  Future<void> _pickFromGallery() async { final picker = ImagePicker(); final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100); if (image != null && mounted) { final newTransaction = await Navigator.push(context, MaterialPageRoute(builder: (context) => LocketEditorScreen(imageFile: File(image.path)))); if (newTransaction != null && newTransaction is Transaction) widget.onNewTransaction(newTransaction); } } 
  
  @override Widget build(BuildContext context) { 
    if (!widget.isActive) return const Center(child: Text("Camera paused", style: TextStyle(color: Colors.grey)));
    if (_cameraController == null || !_cameraController!.value.isInitialized) return const Center(child: CircularProgressIndicator(color: Colors.amberAccent)); 
    return Column(children: [ Expanded(child: Padding(padding: const EdgeInsets.only(top: 20, left: 10, right: 10), child: ClipRRect(borderRadius: BorderRadius.circular(40), child: Stack(fit: StackFit.expand, children: [FittedBox(fit: BoxFit.cover, child: SizedBox(width: _cameraController!.value.previewSize!.height, height: _cameraController!.value.previewSize!.width, child: CameraPreview(_cameraController!))), Positioned(top: 20, left: 20, child: GestureDetector(onTap: _toggleFlash, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.white, size: 24))))])))), Padding(padding: const EdgeInsets.only(top: 25, bottom: 15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [IconButton(onPressed: _pickFromGallery, icon: const Icon(Icons.photo_library, color: Colors.white, size: 32)), GestureDetector(onTap: _takePicture, child: Container(height: 80, width: 80, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.amberAccent, width: 4)), child: Center(child: Container(height: 65, width: 65, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))))), IconButton(onPressed: _switchCamera, icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32))])), GestureDetector(onTap: () => showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (context) => HistoryBottomSheet(transactions: widget.transactions)), child: const Padding(padding: EdgeInsets.only(bottom: 100), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Lịch sử", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rissa')), Icon(Icons.keyboard_arrow_down, color: Colors.white)]))) ]); 
  } 
}

class HistoryBottomSheet extends StatelessWidget { 
  final List<Transaction> transactions; const HistoryBottomSheet({super.key, required this.transactions}); 
  @override Widget build(BuildContext context) { 
    Map<String, List<Transaction>> grouped = {}; List<Transaction> sorted = List.from(transactions)..sort((a, b) => b.date.compareTo(a.date)); for (var t in sorted) { String date = DateFormat('EEE, dd/MM/yyyy').format(t.date); grouped.putIfAbsent(date, () => []); grouped[date]!.add(t); } 
    return DraggableScrollableSheet(initialChildSize: 0.9, maxChildSize: 0.9, minChildSize: 0.5, builder: (_, controller) { return Container(decoration: const BoxDecoration(color: Color(0xFF151C2C), borderRadius: BorderRadius.vertical(top: Radius.circular(30))), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), child: Column(children: [Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))), const SizedBox(height: 20), const Text("Lịch sử chi tiêu", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'Rissa')), const SizedBox(height: 20), Expanded(child: grouped.isEmpty ? const Center(child: Text("Chưa có giao dịch", style: TextStyle(color: Colors.white54, fontSize: 16, fontFamily: 'Rissa'))) : ListView(controller: controller, children: grouped.entries.map((entry) { return Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.key, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Rissa')), const SizedBox(height: 10), GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: entry.value.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.8), itemBuilder: (_, i) { final t = entry.value[i]; return ClipRRect(borderRadius: BorderRadius.circular(15), child: Stack(fit: StackFit.expand, children: [if (t.imagePath != null) Image.file(File(t.imagePath!), fit: BoxFit.cover) else Container(color: Colors.grey.shade900), Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.9), Colors.transparent]))), Positioned(bottom: 5, left: 5, right: 5, child: Text("${t.type == TransactionType.expense ? '-' : '+'}${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(t.amount)}", style: TextStyle(color: t.type == TransactionType.expense ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Rissa')))])); })])); }).toList()))])); }); 
  } 
}

class LocketEditorScreen extends StatefulWidget { final File imageFile; const LocketEditorScreen({super.key, required this.imageFile}); @override State<LocketEditorScreen> createState() => _LocketEditorScreenState(); }
class _LocketEditorScreenState extends State<LocketEditorScreen> { 
  String amountStr = "0"; String note = ""; TransactionType type = TransactionType.expense; 
  void save() { double amount = double.tryParse(amountStr.replaceAll('.', '')) ?? 0; if (amount > 0) Navigator.pop(context, Transaction(widget.imageFile.path, amount, note, DateTime.now(), type)); } 
  void onKey(String val) { setState(() { if (val == "<") amountStr = amountStr.length > 1 ? amountStr.substring(0, amountStr.length - 1) : "0"; else { if (amountStr == "0") amountStr = val; else if (amountStr.length < 10) amountStr += val; } }); } 
  @override Widget build(BuildContext context) { return Scaffold(backgroundColor: Colors.black, body: Stack(fit: StackFit.expand, children: [Image.file(widget.imageFile, fit: BoxFit.cover), Container(color: Colors.black.withOpacity(0.5)), SafeArea(child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)), TextButton(onPressed: save, child: const Text("Post", style: TextStyle(color: Colors.amberAccent, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Rissa')))]), const Spacer(), Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: TextField(textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Rissa'), decoration: const InputDecoration(hintText: "Thêm ghi chú...", hintStyle: TextStyle(color: Colors.white54, fontFamily: 'Rissa'), border: InputBorder.none), onChanged: (v) => note = v)), GestureDetector(onTap: () => setState(() => type = type == TransactionType.expense ? TransactionType.income : TransactionType.expense), child: Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5), decoration: BoxDecoration(color: type == TransactionType.expense ? Colors.redAccent.withOpacity(0.8) : Colors.green.withOpacity(0.8), borderRadius: BorderRadius.circular(30)), child: Text("${type == TransactionType.expense ? '-' : '+'}${NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0).format(double.tryParse(amountStr) ?? 0)}", style: const TextStyle(fontSize: 45, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'Rissa')))), const SizedBox(height: 10), const Text("Chạm vào số tiền để đổi Thu/Chi", style: TextStyle(color: Colors.white54, fontSize: 14, fontFamily: 'Rissa')), const Spacer(), Container(padding: const EdgeInsets.only(bottom: 20, left: 20, right: 20), height: 250, child: GridView.count(crossAxisCount: 3, childAspectRatio: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, physics: const NeverScrollableScrollPhysics(), children: [_btn("1"), _btn("2"), _btn("3"), _btn("4"), _btn("5"), _btn("6"), _btn("7"), _btn("8"), _btn("9"), _btn("000"), _btn("0"), _btn("<")]))]))])); } 
  Widget _btn(String t) => GestureDetector(onTap: () { HapticFeedback.lightImpact(); onKey(t); }, child: Container(color: Colors.transparent, alignment: Alignment.center, child: t == "<" ? const Icon(Icons.backspace, color: Colors.white) : Text(t, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Rissa')))); 
}


// ================= LOCAL SEND TAB =================
class LocalSendTab extends StatefulWidget {
  const LocalSendTab({super.key});
  @override
  State<LocalSendTab> createState() => _LocalSendTabState();
}

class _LocalSendTabState extends State<LocalSendTab> with SingleTickerProviderStateMixin {
  bool isSendMode = true;
  TextEditingController nameCtrl = TextEditingController(text: "Co-op :: $currentDeviceType");
  Map<String, Map<String, dynamic>> discoveredDevices = {}; // { id: {name, type, pos} }
  File? selectedFile;
  final ValueNotifier<double> transferProgress = ValueNotifier(-1.0);
  Map<int, String> fileNamesMap = {};
  Map<int, String> fileTempPathsMap = {};
  String? lastReceivedFileName;

  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _startScanning();
  }

  @override
  void dispose() {
    _cleanUpConnections();
    _radarController.dispose();
    super.dispose();
  }

  void _cleanUpConnections() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
  }

  Future<bool> _checkAndRequestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location, Permission.bluetooth, Permission.bluetoothAdvertise,
      Permission.bluetoothConnect, Permission.bluetoothScan, Permission.nearbyWifiDevices,
    ].request();
    
    if (await Permission.location.serviceStatus.isDisabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Vui lòng vuốt thanh trạng thái và BẬT Vị trí (GPS) để quét thiết bị lân cận!", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.orange));
      return false;
    }
    
    if (statuses[Permission.location]!.isDenied || statuses[Permission.bluetooth]!.isDenied) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Vui lòng cấp quyền Vị trí & Bluetooth!", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.red));
      return false;
    }
    return true;
  }

  void _startScanning() async {
    _cleanUpConnections();
    discoveredDevices.clear();
    if (mounted) setState(() {});
    
    if (!await _checkAndRequestPermissions()) return;
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await Nearby().startDiscovery(
        nameCtrl.text,
        Strategy.P2P_STAR, 
        onEndpointFound: (id, name, serviceId) {
          if (serviceId == "com.coop.localsend") {
             String dName = name; String dType = 'phone';
             if (name.contains(' :: ')) {
               var parts = name.split(' :: ');
               dName = parts[0];
               dType = parts.length > 1 ? parts[1] : 'phone';
             }
             double angle = math.Random().nextDouble() * 2 * math.pi;
             double radius = 0.4 + math.Random().nextDouble() * 0.4; 
             Offset pos = Offset(math.cos(angle) * radius, math.sin(angle) * radius);

             if (mounted) setState(() => discoveredDevices[id] = {'name': dName, 'type': dType, 'pos': pos});
          }
        },
        onEndpointLost: (id) {
          if (mounted) setState(() => discoveredDevices.remove(id));
        },
        serviceId: "com.coop.localsend",
      );
    } catch (e) {
      debugPrint("Lỗi quét: $e");
    }
  }

  void _startReceiving() async {
    _cleanUpConnections();
    if (!await _checkAndRequestPermissions()) return;
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      await Nearby().startAdvertising(
        nameCtrl.text,
        Strategy.P2P_STAR,
        onConnectionInitiated: (id, info) async {
          Nearby().acceptConnection(id, 
            onPayLoadRecieved: (endId, payload) async {
              if (payload.type == PayloadType.BYTES) {
                String text = utf8.decode(payload.bytes!);
                if (text == "ACCEPT") {
                  await Future.delayed(const Duration(milliseconds: 1500));
                  await Nearby().sendFilePayload(id, selectedFile!.path);
                } else if (text == "REJECT") {
                  Nearby().disconnectFromEndpoint(id);
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bị từ chối nhận file!", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.red));
                } else if (text.contains("|")) {
                  List<String> parts = text.split("|");
                  String fileName = parts[0]; String fileSize = parts[1];
                  lastReceivedFileName = fileName;

                  String senderName = info.endpointName.split(' :: ')[0];
                  bool accept = await showDialog(
                    context: context, barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      content: Text("Máy $senderName muốn gửi 1 file $fileName $fileSize MB. Bạn có đồng ý nhận không?", style: const TextStyle(color: Colors.white, fontFamily: 'Rissa', fontSize: 18)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Từ chối", style: TextStyle(color: Colors.redAccent, fontFamily: 'Rissa', fontSize: 16))),
                        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green), onPressed: () => Navigator.pop(context, true), child: const Text("Chấp nhận", style: TextStyle(color: Colors.white, fontFamily: 'Rissa', fontSize: 16)))
                      ],
                    )
                  ) ?? false;

                  if (accept) {
                    transferProgress.value = 0.0;
                    _showProgressDialog(senderName);
                    Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode("ACCEPT")));
                  } else {
                    Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode("REJECT")));
                    Nearby().disconnectFromEndpoint(id);
                  }
                }
              } else if (payload.type == PayloadType.FILE) {
                fileNamesMap[payload.id] = lastReceivedFileName ?? "Co_op_File_${DateTime.now().millisecondsSinceEpoch}.dat";
                fileTempPathsMap[payload.id] = payload.filePath!;
              }
            }, 
            onPayloadTransferUpdate: (endId, update) async {
              if (update.totalBytes < 1000) return;
              if (update.status == PayloadStatus.IN_PROGRESS) {
                transferProgress.value = update.bytesTransferred / update.totalBytes;
              } else if (update.status == PayloadStatus.SUCCESS) {
                transferProgress.value = 1.0;
                
                if (!isSendMode && fileTempPathsMap.containsKey(update.id)) {
                  String tempPath = fileTempPathsMap[update.id]!;
                  String originalName = fileNamesMap[update.id]!;
                  try {
                    File tempFile = File(tempPath);
                    File newFile = await tempFile.copy('${LocalDataManager.publicDownloadFolder.path}/$originalName');
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã lưu vào: ${newFile.path}", style: const TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.green));
                  } catch(e) { debugPrint("Lỗi ghi tệp: $e"); }
                  fileNamesMap.remove(update.id); fileTempPathsMap.remove(update.id);
                }

                Future.delayed(const Duration(seconds: 4), () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  if (isSendMode) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gửi file thành công!", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.green));
                    setState(() => selectedFile = null);
                  }
                  Nearby().disconnectFromEndpoint(endId);
                });
              } else if (update.status == PayloadStatus.FAILURE) {
                if (Navigator.canPop(context)) Navigator.pop(context);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lỗi truyền file!", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.red));
              }
            }
          );
        },
        onConnectionResult: (id, status) {}, onDisconnected: (id) {}, serviceId: "com.coop.localsend",
      );
    } catch (e) {
      debugPrint("Lỗi phát sóng: $e");
    }
  }

  void _initiateTransfer(String endpointId, File file) async {
    transferProgress.value = 0.0;
    _showProgressDialog(discoveredDevices[endpointId]!['name']);

    await Nearby().requestConnection(
      nameCtrl.text, 
      endpointId,
      onConnectionInitiated: (id, info) {
        Nearby().acceptConnection(id, onPayLoadRecieved: (endId, payload) {
           if (payload.type == PayloadType.BYTES) {
             String text = utf8.decode(payload.bytes!);
             if (text == "ACCEPT") {
                Future.delayed(const Duration(milliseconds: 1500), () {
                   Nearby().sendFilePayload(id, file.path);
                });
             } else if (text == "REJECT") {
                if (Navigator.canPop(context)) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bị từ chối nhận file!", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.red));
                Nearby().disconnectFromEndpoint(id);
             }
           }
        }, onPayloadTransferUpdate: (endId, update) {
           if (update.totalBytes > 1000 && update.status == PayloadStatus.IN_PROGRESS) transferProgress.value = update.bytesTransferred / update.totalBytes;
           else if (update.status == PayloadStatus.SUCCESS) {
             transferProgress.value = 1.0;
             Future.delayed(const Duration(seconds: 4), () {
               if (Navigator.canPop(context)) Navigator.pop(context);
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gửi file thành công!", style: TextStyle(fontFamily: 'Rissa', fontSize: 16)), backgroundColor: Colors.green));
               setState(() => selectedFile = null); Nearby().disconnectFromEndpoint(id);
             });
           } else if (update.status == PayloadStatus.FAILURE) { if (Navigator.canPop(context)) Navigator.pop(context); }
        });
      },
      onConnectionResult: (id, status) async {
        if (status == Status.CONNECTED) {
          String fileName = file.path.split('/').last;
          String fileSizeMB = (file.lengthSync() / (1024*1024)).toStringAsFixed(2);
          String fileInfo = "$fileName|$fileSizeMB";
          await Nearby().sendBytesPayload(id, Uint8List.fromList(utf8.encode(fileInfo)));
        }
      },
      onDisconnected: (id) {}
    );
  }
  
  void _openFileMenu() {
    showGeneralDialog(
      context: context, barrierDismissible: true, barrierLabel: "FileMenu", barrierColor: Colors.transparent, transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              top: 80, right: 20,
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.greenAccent.withOpacity(0.4), Colors.green.withOpacity(0.1)]), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.2))),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _fileOption(Icons.image, "Tải Ảnh", FileType.image, ctx),
                          _fileOption(Icons.videocam, "Video", FileType.video, ctx),
                          _fileOption(Icons.insert_drive_file, "Tài liệu", FileType.custom, ctx, ex: ['pdf', 'doc', 'docx', 'txt']),
                          _fileOption(Icons.folder_zip, "Tệp nén", FileType.custom, ctx, ex: ['zip', 'rar']),
                          _fileOption(Icons.android, "Gói cài đặt", FileType.custom, ctx, ex: ['apk']),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) => FadeTransition(opacity: anim1, child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)), alignment: Alignment.topRight, child: child))
    );
  }

  Widget _fileOption(IconData icon, String label, FileType type, BuildContext dialogCtx, {List<String>? ex}) { 
    return InkWell(onTap: () async { Navigator.pop(dialogCtx); FilePickerResult? result = await FilePicker.platform.pickFiles(type: type, allowedExtensions: ex); if (result != null && result.files.single.path != null) { setState(() => selectedFile = File(result.files.single.path!)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã chuẩn bị file: ${result.files.single.name}", style: const TextStyle(fontFamily: 'Rissa', fontSize: 14)))); } }, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), child: Row(children: [Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 15), Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))]))); 
  }

  void _showProgressDialog(String deviceName) { 
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => ValueListenableBuilder<double>(valueListenable: transferProgress, builder: (ctx, progress, child) { 
      bool isDone = progress >= 1.0; double displayProgress = progress < 0 ? 0 : (progress > 1 ? 1 : progress); 
      return AlertDialog(backgroundColor: const Color(0xFF1E1E1E), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), content: Column(mainAxisSize: MainAxisSize.min, children: [Text(isDone ? "Hoàn tất!" : "Đang truyền tải:\n$deviceName", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Rissa')), const SizedBox(height: 25), SizedBox(height: 120, width: 120, child: Stack(fit: StackFit.expand, children: [CircularProgressIndicator(value: isDone ? 1.0 : displayProgress, backgroundColor: Colors.white12, color: isDone ? Colors.greenAccent : Colors.blueAccent, strokeWidth: 10), Center(child: isDone ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 60) : Text("${(displayProgress * 100).toInt()}%", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Rissa')))])), const SizedBox(height: 25), if (!isDone) const Text("App-to-App Transfer...", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Rissa')), if (isDone) const Text("Thành công!", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rissa'))])); 
    })); 
  }

  Widget _buildToggle() {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color glassColor = isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          Expanded(child: GestureDetector(onTap: () { HapticFeedback.lightImpact(); setState(() { isSendMode = true; _startScanning(); }); }, child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSendMode ? Colors.blueAccent : Colors.transparent, borderRadius: BorderRadius.circular(25)), child: Center(child: Text("GỬI FILE", style: TextStyle(color: isSendMode ? Colors.white : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rissa')))))),
          Expanded(child: GestureDetector(onTap: () { HapticFeedback.lightImpact(); setState(() { isSendMode = false; _startReceiving(); }); }, child: AnimatedContainer(duration: const Duration(milliseconds: 300), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: !isSendMode ? Colors.greenAccent.shade700 : Colors.transparent, borderRadius: BorderRadius.circular(25)), child: Center(child: Text("NHẬN FILE", style: TextStyle(color: !isSendMode ? Colors.white : Colors.grey, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))))))
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    Color textColor = getAppTextColor(context);
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("LocalSend", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor, fontFamily: 'Rissa')), GestureDetector(onTap: _openFileMenu, child: Container(padding: const EdgeInsets.all(10), decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle), child: Icon(Icons.add, color: textColor, size: 24)))])),
        _buildToggle(),
        const SizedBox(height: 20),
        
        Expanded(
          child: isSendMode
            ? Stack(
                children: [
                  Center(child: AnimatedBuilder(animation: _radarController, builder: (context, child) { return CustomPaint(painter: RadarPainter(_radarController.value, isDark ? Colors.blueAccent : Colors.blue.shade200), size: const Size(300, 300)); })),
                  Center(child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)]), child: Icon(currentDeviceType == 'tablet' ? Icons.tablet_mac : (currentDeviceType == 'laptop' ? Icons.laptop_mac : Icons.smartphone), color: Colors.white, size: 30))),
                  ...discoveredDevices.entries.map((entry) {
                    Offset pos = entry.value['pos']; String name = entry.value['name']; String type = entry.value['type'];
                    return Align(
                      alignment: FractionalOffset((pos.dx + 1) / 2, (pos.dy + 1) / 2),
                      child: DragTarget<File>(
                        onAccept: (file) => _initiateTransfer(entry.key, file),
                        builder: (context, candidateData, rejectedData) {
                          bool isHovering = candidateData.isNotEmpty;
                          return AnimatedContainer(duration: const Duration(milliseconds: 200), width: isHovering ? 80 : 60, height: isHovering ? 80 : 60, decoration: BoxDecoration(color: isHovering ? Colors.greenAccent : (isDark ? Colors.white24 : Colors.black12), shape: BoxShape.circle, border: Border.all(color: isHovering ? Colors.white : Colors.transparent, width: 2), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(type == 'tablet' ? Icons.tablet_mac : (type == 'laptop' ? Icons.laptop_mac : Icons.smartphone), color: isHovering ? Colors.black87 : textColor, size: 20), Text(name, style: TextStyle(color: isHovering ? Colors.black87 : textColor, fontSize: 10, fontFamily: 'Rissa', fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)]));
                        }
                      ),
                    );
                  }),
                  if (selectedFile != null)
                    Positioned(bottom: 40, left: 0, right: 0, child: Center(child: Draggable<File>(data: selectedFile, feedback: Material(color: Colors.transparent, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orangeAccent, borderRadius: BorderRadius.circular(15), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)]), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.insert_drive_file, color: Colors.white, size: 20), const SizedBox(width: 10), Text(selectedFile!.path.split('/').last, style: const TextStyle(color: Colors.white, fontFamily: 'Rissa', fontSize: 14))]))), childWhenDragging: Opacity(opacity: 0.3, child: _buildFileChip(selectedFile!.path.split('/').last)), child: _buildFileChip(selectedFile!.path.split('/').last))))
                  else
                    Positioned(bottom: 40, left: 0, right: 0, child: Center(child: Text("Bấm nút [+] ở góc phải để chọn file\nsau đó kéo file thả vào thiết bị", textAlign: TextAlign.center, style: TextStyle(color: textColor.withOpacity(0.5), fontFamily: 'Rissa', fontSize: 14)))),
                ],
              )
            : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(40), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), shape: BoxShape.circle), child: Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.wifi_tethering, color: Colors.greenAccent, size: 60))), const SizedBox(height: 30), Text("Đang phát sóng...", style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Rissa')), const SizedBox(height: 10), Text("File nhận được sẽ tự động lưu vào máy", textAlign: TextAlign.center, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 14, fontFamily: 'Rissa'))]))
        )
      ],
    );
  }

  Widget _buildFileChip(String name) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0,2))]), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.insert_drive_file, color: Colors.blue, size: 20), const SizedBox(width: 10), Text(name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Rissa', fontSize: 14))]));
  }
}

class RadarPainter extends CustomPainter {
  final double progress; final Color color;
  RadarPainter(this.progress, this.color);
  @override void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.5;
    Offset center = Offset(size.width / 2, size.height / 2); double maxRadius = size.width / 2;
    for (int i = 0; i < 3; i++) { double r = (progress + i / 3) % 1.0; paint.color = color.withOpacity(1.0 - r); canvas.drawCircle(center, r * maxRadius, paint); }
  }
  @override bool shouldRepaint(RadarPainter old) => old.progress != progress;
}

// ================= LOCAL MUSIC PLAYER =================
class MusicTab extends StatefulWidget {
  const MusicTab({super.key});
  @override
  State<MusicTab> createState() => _MusicTabState();
}
class _MusicTabState extends State<MusicTab> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;
  bool isBuffering = false; 
  bool _showSearch = false;
  String _searchQuery = "";
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  int currentSongIndex = 0;
  Timer? _spatialTimer;
  double _angle = 0.0;

  @override
  void initState() {
    super.initState();
    globalSpatialAudio.addListener(_manageSpatialAudio);
    _audioPlayer.onPlayerStateChanged.listen((state) { 
      if (mounted) setState(() { isPlaying = state == PlayerState.playing; }); 
      _manageSpatialAudio();
    });
    _audioPlayer.onDurationChanged.listen((newDuration) { if (mounted) setState(() => _duration = newDuration); });
    _audioPlayer.onPositionChanged.listen((newPosition) { if (mounted) setState(() => _position = newPosition); });
    _audioPlayer.onPlayerComplete.listen((event) { _nextSong(); });

    if (globalLocalSongs.value.isNotEmpty) {
      _setAudioSource();
    }
  }

  void _manageSpatialAudio() {
    _spatialTimer?.cancel();
    if (globalSpatialAudio.value && isPlaying) {
      _spatialTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        _angle += 0.04; double pan = math.sin(_angle); double volume = 0.75 + (0.25 * math.cos(_angle));
        _audioPlayer.setBalance(pan); _audioPlayer.setVolume(volume); 
      });
    } else {
      _audioPlayer.setBalance(0.0); _audioPlayer.setVolume(1.0); 
    }
  }

  @override void dispose() { _spatialTimer?.cancel(); globalSpatialAudio.removeListener(_manageSpatialAudio); _audioPlayer.dispose(); super.dispose(); }
  Future<void> _setAudioSource() async { if (globalLocalSongs.value.isEmpty) return; await _audioPlayer.setSource(DeviceFileSource(globalLocalSongs.value[currentSongIndex]["path"]!)); }
  void _playSpecificSong(int index) async { if (globalLocalSongs.value.isEmpty) return; setState(() => currentSongIndex = index); await _audioPlayer.play(DeviceFileSource(globalLocalSongs.value[index]["path"]!)); }
  void _togglePlay() async { if (globalLocalSongs.value.isEmpty) return; HapticFeedback.lightImpact(); if (isPlaying) { await _audioPlayer.pause(); } else { if (_position == Duration.zero) { _playSpecificSong(currentSongIndex); } else { await _audioPlayer.resume(); } } }
  void _nextSong() { if (globalLocalSongs.value.isEmpty) return; HapticFeedback.selectionClick(); int next = currentSongIndex + 1; if (next >= globalLocalSongs.value.length) next = 0; _playSpecificSong(next); }
  void _prevSong() { if (globalLocalSongs.value.isEmpty) return; HapticFeedback.selectionClick(); int prev = currentSongIndex - 1; if (prev < 0) prev = globalLocalSongs.value.length - 1; _playSpecificSong(prev); }
  String _formatTime(Duration duration) { String twoDigits(int n) => n.toString().padLeft(2, '0'); final minutes = twoDigits(duration.inMinutes.remainder(60)); final seconds = twoDigits(duration.inSeconds.remainder(60)); return "$minutes:$seconds"; }

  Future<void> _addLocalMusic() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['mp3', 'wav', 'flac', 'm4a', 'aac', 'mp4', 'mkv', 'avi']);
    if (result != null) {
      List<Map<String, String>> currentList = List.from(globalLocalSongs.value);
      for (var file in result.files) {
        if (file.path != null) {
          String fileName = file.name.replaceAll(RegExp(r'\.(mp3|wav|flac|m4a|aac|mp4|mkv|avi)$'), '');
          currentList.add({ "title": fileName, "artist": "Local Music", "path": file.path!, "cover": "https://images.unsplash.com/photo-1614613535308-eb5fbd3d2c17?q=80&w=600&auto=format&fit=crop" });
        }
      }
      globalLocalSongs.value = currentList;
      await LocalDataManager.saveLocalMusic(currentList); 
      if (!isPlaying && currentList.length == result.files.length) _setAudioSource(); 
      if (mounted) setState(() {});
    }
  }

  Widget _buildHomeContent(List<Map<String, String>> displayedSongs) {
    bool isDark = Theme.of(context).brightness == Brightness.dark; Color textColor = isDark ? Colors.white : Colors.black;
    if (globalLocalSongs.value.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.library_music, size: 60, color: Colors.grey.shade700), const SizedBox(height: 20), Text("Thư viện nhạc trống", style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Rissa')), const SizedBox(height: 10), Text("Bấm nút [+] ở góc trên để thêm nhạc từ máy", style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontFamily: 'Rissa'))]));
    }
    if (displayedSongs.isEmpty) return Center(child: Text("Không tìm thấy bài hát nào", style: TextStyle(color: textColor, fontFamily: 'Rissa')));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10, bottom: 200), 
      itemCount: displayedSongs.length,
      itemBuilder: (context, index) {
        int realIndex = globalLocalSongs.value.indexWhere((song) => song["path"] == displayedSongs[index]["path"]);
        bool isSelected = currentSongIndex == realIndex;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          leading: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(displayedSongs[index]["cover"]!, width: 45, height: 45, fit: BoxFit.cover)),
          title: Text(displayedSongs[index]["title"]!, style: TextStyle(color: isSelected ? Colors.redAccent : textColor, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Rissa'), maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(displayedSongs[index]["artist"]!, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Rissa'), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: isSelected && isPlaying ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.redAccent, strokeWidth: 2)) : IconButton(icon: Icon(Icons.play_arrow, color: isSelected ? Colors.redAccent : Colors.grey, size: 24), onPressed: () => _playSpecificSong(realIndex)),
          onTap: () => _playSpecificSong(realIndex),
        );
      }
    );
  }

  Widget _buildMiniPlayer() {
    if (globalLocalSongs.value.isEmpty) return const SizedBox.shrink();
    Map<String, String> currentSong = globalLocalSongs.value[currentSongIndex];

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white), onPressed: () => Navigator.pop(context))),
          extendBodyBehindAppBar: true,
          body: OrientationBuilder(
            builder: (context, orientation) {
              bool isLandscape = orientation == Orientation.landscape;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(currentSong["cover"]!, fit: BoxFit.cover),
                  BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.black.withOpacity(0.6))),
                  SafeArea(child: isLandscape ? _buildLandscape(currentSong) : _buildPortrait(currentSong)),
                ],
              );
            }
          )
        )));
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF212121), borderRadius: BorderRadius.circular(50), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)]),
        child: Row(
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(25), child: Image.network(currentSong["cover"]!, width: 40, height: 40, fit: BoxFit.cover)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 20, child: Marquee(text: currentSong["title"]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Rissa'), scrollAxis: Axis.horizontal, blankSpace: 50.0, velocity: 30.0)),
                  Text(currentSong["artist"]!, style: const TextStyle(color: Colors.grey, fontSize: 12, fontFamily: 'Rissa'), maxLines: 1, overflow: TextOverflow.ellipsis)
                ],
              ),
            ),
            IconButton(icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 26), onPressed: _togglePlay),
            IconButton(icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 26), onPressed: _nextSong),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDark ? Colors.white : Colors.black;

    List<Map<String, String>> displayedSongs = _searchQuery.isEmpty 
      ? globalLocalSongs.value 
      : globalLocalSongs.value.where((song) => song["title"]!.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: isDark ? Colors.black : Colors.white,
                pinned: true, elevation: 0, expandedHeight: 60,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 20, bottom: 15),
                  title: Text("Thư viện Nhạc", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Rissa')),
                ),
                actions: [
                  IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.redAccent, size: 26), onPressed: _addLocalMusic),
                  IconButton(icon: Icon(Icons.search, color: textColor), onPressed: () { setState(() { _showSearch = !_showSearch; if(!_showSearch) _searchQuery = ""; }); }),
                  IconButton(icon: Icon(Icons.settings, color: textColor), onPressed: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const MusicSettingsPage())); }),
                ],
              ),
              if (_showSearch)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: isDark ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Icon(Icons.search, color: Colors.grey), const SizedBox(width: 10), 
                        Expanded(child: TextField(
                          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Rissa'),
                          decoration: InputDecoration(border: InputBorder.none, hintText: "Tìm bài hát...", hintStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal, fontFamily: 'Rissa')),
                          onChanged: (val) => setState(() => _searchQuery = val), 
                        ))
                      ]),
                    ),
                  ),
                ),
              SliverFillRemaining(child: _buildHomeContent(displayedSongs))
            ],
          ),
          Positioned(bottom: 110, left: 0, right: 0, child: _buildMiniPlayer())
        ],
      ),
    );
  }

  Widget _buildPortrait(Map<String, String> currentSong) {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.only(top: 20.0, bottom: 20.0), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("ĐANG PHÁT TỪ THIẾT BỊ", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3, fontFamily: 'Rissa'))])),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic,
          width: isPlaying ? MediaQuery.of(context).size.width * 0.85 : MediaQuery.of(context).size.width * 0.75,
          height: isPlaying ? MediaQuery.of(context).size.width * 0.85 : MediaQuery.of(context).size.width * 0.75,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), boxShadow: [if (isPlaying) BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20))], image: DecorationImage(image: NetworkImage(currentSong["cover"]!), fit: BoxFit.cover)),
        ),
        const SizedBox(height: 30),
        ValueListenableBuilder<bool>(valueListenable: globalLosslessAudio, builder: (context, isLossless, _) { return ValueListenableBuilder<bool>(valueListenable: globalSpatialAudio, builder: (context, isSpatial, _) { if (!isLossless && !isSpatial) return const SizedBox(height: 16); return Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (isLossless) Container(margin: const EdgeInsets.only(right: 5), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)), child: const Text("Hi-Res Lossless", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))), if (isSpatial) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)), child: const Text("Dolby Atmos", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Rissa')))]); }); }),
        const SizedBox(height: 10),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: SizedBox(height: 40, child: Marquee(text: currentSong["title"]!, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Rissa'), scrollAxis: Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.center, blankSpace: 50.0, velocity: 30.0))),
        const SizedBox(height: 5),
        Text(currentSong["artist"]!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, fontFamily: 'Rissa')),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: Colors.white, trackHeight: 4.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0)), child: Slider(min: 0.0, max: _duration.inSeconds.toDouble(), value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()), onChanged: (val) { _audioPlayer.seek(Duration(seconds: val.toInt())); })), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_formatTime(_position), style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Rissa')), Text(_formatTime(_duration), style: const TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Rissa'))]))])),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(iconSize: 40, color: Colors.white, icon: const Icon(Icons.skip_previous_rounded), onPressed: _prevSong), const SizedBox(width: 20), GestureDetector(onTap: _togglePlay, child: Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: 40))), const SizedBox(width: 20), IconButton(iconSize: 40, color: Colors.white, icon: const Icon(Icons.skip_next_rounded), onPressed: _nextSong)]),
      ],
    );
  }

  Widget _buildLandscape(Map<String, String> currentSong) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(width: 20),
          AnimatedContainer(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic, width: isPlaying ? MediaQuery.of(context).size.height * 0.75 : MediaQuery.of(context).size.height * 0.65, height: isPlaying ? MediaQuery.of(context).size.height * 0.75 : MediaQuery.of(context).size.height * 0.65, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [if (isPlaying) BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40, offset: const Offset(0, 20))], image: DecorationImage(image: NetworkImage(currentSong["cover"]!), fit: BoxFit.cover))),
          const SizedBox(width: 40),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(height: 70, child: Marquee(text: currentSong["title"]!, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, fontFamily: 'Rissa'), scrollAxis: Axis.horizontal, crossAxisAlignment: CrossAxisAlignment.center, blankSpace: 100.0, velocity: 40.0)), const SizedBox(height: 5), Text(currentSong["artist"]!, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 20, fontFamily: 'Rissa')), const SizedBox(height: 20), SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: Colors.white, trackHeight: 4.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0)), child: Slider(min: 0.0, max: _duration.inSeconds.toDouble(), value: _position.inSeconds.toDouble().clamp(0.0, _duration.inSeconds.toDouble()), onChanged: (val) { _audioPlayer.seek(Duration(seconds: val.toInt())); })), Row(mainAxisAlignment: MainAxisAlignment.start, children: [IconButton(iconSize: 40, color: Colors.white, icon: const Icon(Icons.skip_previous_rounded), onPressed: _prevSong), const SizedBox(width: 20), GestureDetector(onTap: _togglePlay, child: Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.black, size: 40))), const SizedBox(width: 20), IconButton(iconSize: 40, color: Colors.white, icon: const Icon(Icons.skip_next_rounded), onPressed: _nextSong)])])),
        ]
      ),
    );
  }
}

class MusicSettingsPage extends StatefulWidget { const MusicSettingsPage({super.key}); @override State<MusicSettingsPage> createState() => _MusicSettingsPageState(); }
class _MusicSettingsPageState extends State<MusicSettingsPage> {
  bool soundCheck = true;
  @override Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark; Color bgColor = isDark ? Colors.black : Colors.white; Color textColor = isDark ? Colors.white : Colors.black; Color subtitleColor = isDark ? Colors.white54 : Colors.grey.shade500; Color redColor = const Color(0xFFFA233B); 
    return Scaffold(backgroundColor: bgColor, appBar: AppBar(backgroundColor: bgColor, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back, color: redColor), onPressed: () => Navigator.pop(context)), title: Text("Cài đặt", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))), body: ListView(children: [ListTile(title: Text("Transfer Music from Other Services", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), subtitle: Text("Add saved music and playlists you made in other music services to your Apple Music library.", style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Rissa'))), Divider(height: 1, color: isDark ? Colors.white24 : Colors.grey.shade300), Padding(padding: const EdgeInsets.only(left: 15, top: 20, bottom: 5), child: Text("Âm thanh", style: TextStyle(color: redColor, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Rissa'))), ValueListenableBuilder<bool>(valueListenable: globalSpatialAudio, builder: (context, val, child) { return SwitchListTile(activeColor: redColor, title: Text("Âm thanh không gian (Hiệu ứng 3D)", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), value: val, onChanged: (newValue) => globalSpatialAudio.value = newValue); }), Divider(height: 1, indent: 15, color: isDark ? Colors.white24 : Colors.grey.shade300), ListTile(title: Text("Chất lượng âm thanh", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AudioQualityPage()))), Divider(height: 1, indent: 15, color: isDark ? Colors.white24 : Colors.grey.shade300), ListTile(title: Text("Đan xen", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), subtitle: Text("Tự động", style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Rissa'))), Divider(height: 1, indent: 15, color: isDark ? Colors.white24 : Colors.grey.shade300), ListTile(title: Text("Bộ chỉnh âm", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), subtitle: Text("Điều chỉnh cài đặt đầu ra âm thanh.", style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Rissa'))), Divider(height: 1, indent: 15, color: isDark ? Colors.white24 : Colors.grey.shade300), SwitchListTile(activeColor: redColor, title: Text("Kiểm tra âm thanh", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), value: soundCheck, onChanged: (val) => setState(() => soundCheck = val)), Divider(height: 1, color: isDark ? Colors.white24 : Colors.grey.shade300), Padding(padding: const EdgeInsets.only(left: 15, top: 20, bottom: 5), child: Text("Tùy chọn tải về", style: TextStyle(color: redColor, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Rissa')))]));
  }
}

class AudioQualityPage extends StatefulWidget { const AudioQualityPage({super.key}); @override State<AudioQualityPage> createState() => _AudioQualityPageState(); }
class _AudioQualityPageState extends State<AudioQualityPage> {
  @override Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark; Color bgColor = isDark ? Colors.black : Colors.white; Color textColor = isDark ? Colors.white : Colors.black; Color subtitleColor = isDark ? Colors.white54 : Colors.grey.shade500; Color redColor = const Color(0xFFFA233B); 
    return Scaffold(backgroundColor: bgColor, appBar: AppBar(backgroundColor: bgColor, elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back, color: redColor), onPressed: () => Navigator.pop(context)), title: Text("Chất lượng âm thanh", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontFamily: 'Rissa'))), body: ListView(children: [ValueListenableBuilder<bool>(valueListenable: globalLosslessAudio, builder: (context, val, child) { return SwitchListTile(activeColor: redColor, title: Text("Âm thanh Lossless", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), subtitle: Text("Tệp lossless bảo lưu mọi chi tiết của âm thanh gốc. Bật tùy chọn này sẽ hiện huy hiệu trên Trình Phát Nhạc.", style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Rissa')), value: val, onChanged: (newValue) => globalLosslessAudio.value = newValue); }), Divider(height: 1, color: isDark ? Colors.white24 : Colors.grey.shade300), ListTile(title: Text("Truyền phát qua mạng di động", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), subtitle: Text("Hi-Res Lossless", style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Rissa'))), Divider(height: 1, indent: 15, color: isDark ? Colors.white24 : Colors.grey.shade300), ListTile(title: Text("Truyền phát qua Wi-Fi", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), subtitle: Text("Hi-Res Lossless", style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Rissa'))), Divider(height: 1, indent: 15, color: isDark ? Colors.white24 : Colors.grey.shade300), ListTile(title: Text("Tải về", style: TextStyle(color: textColor, fontSize: 14, fontFamily: 'Rissa')), subtitle: Text("Hi-Res Lossless", style: TextStyle(color: subtitleColor, fontSize: 12, fontFamily: 'Rissa'))), Divider(height: 1, color: isDark ? Colors.white24 : Colors.grey.shade300)]));
  }
}

// ================= TAB GHI CHÚ VÔ CỰC NÂNG CẤP KÉO GIÃN VÀ FONT =================

class StrikeThrough extends StatefulWidget {
  final String text; final bool done; final double fontSize;
  const StrikeThrough({super.key, required this.text, required this.done, required this.fontSize});
  @override State<StrikeThrough> createState() => _StrikeThroughState();
}
class _StrikeThroughState extends State<StrikeThrough> with SingleTickerProviderStateMixin {
  late AnimationController _controller; late Animation<double> _animation;
  @override void initState() { super.initState(); _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500)); _animation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut)); if (widget.done) _controller.forward(); }
  @override void didUpdateWidget(StrikeThrough oldWidget) { super.didUpdateWidget(oldWidget); if (widget.done && !oldWidget.done) _controller.forward(); else if (!widget.done && oldWidget.done) _controller.reverse(); }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { return Stack(alignment: Alignment.centerLeft, children: [Text(widget.text, style: TextStyle(color: widget.done ? RobertColors.textDone : RobertColors.textMain, fontSize: widget.fontSize, fontFamily: 'Rissa', decoration: TextDecoration.none)), AnimatedBuilder(animation: _animation, builder: (context, child) { return FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: _animation.value, child: Container(height: widget.fontSize * 0.15, color: RobertColors.textDone)); })]); }
}

class NotesTab extends StatefulWidget {
  const NotesTab({super.key});
  @override State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> with TickerProviderStateMixin {
  List<NoteModel> notes = []; bool isLoading = true; String currentTool = 'pencil'; 
  late AnimationController _pulseController; late Animation<double> _pulseAnim;

  @override void initState() { super.initState(); _loadNotes(); _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true); _pulseAnim = Tween<double>(begin: 1.0, end: 1.07).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)); }
  @override void dispose() { _pulseController.dispose(); super.dispose(); }
  Future<void> _loadNotes() async { notes = await LocalDataManager.loadNotes(); setState(() => isLoading = false); }

  void _addNote() {
    HapticFeedback.heavyImpact();
    double randomDx = 50 + math.Random().nextInt(100).toDouble();
    double randomDy = 80 + math.Random().nextInt(150).toDouble();
    setState(() { notes.add(NoteModel(id: DateTime.now().millisecondsSinceEpoch.toString(), type: 'sticky', text: "", dx: randomDx, dy: randomDy, w: 180, h: 180)); });
    LocalDataManager.saveNotes(notes);
  }

  void _bringToFront(NoteModel note) { setState(() { notes.remove(note); notes.add(note); }); }
  void _clearAllNotes() { HapticFeedback.heavyImpact(); setState(() => notes.clear()); LocalDataManager.saveNotes(notes); }

  void _showHelp() {
    HapticFeedback.selectionClick();
    showDialog(context: context, builder: (_) => Dialog(backgroundColor: RobertColors.wall, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [_helpRow(Icons.add_circle, "Nhấn dấu CỘNG nhấp nháy để thêm Note", RobertColors.noteBorder), _helpRow(Icons.edit, "Chọn bút chì để gõ chữ", RobertColors.textMain), _helpRow(Icons.border_color, "Chọn bút dạ quang để gạch bỏ mục", RobertColors.highlightRed), _helpRow(Icons.open_in_full, "Kéo góc phải dưới để phóng to chữ/giấy", RobertColors.bubbleText), _helpRow(Icons.delete_sweep, "Kéo giấy xuống đáy màn hình để Xóa", RobertColors.highlightRedDark), const SizedBox(height: 15), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: RobertColors.brownDark, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10)), onPressed: () => Navigator.pop(context), child: const Text("Đã hiểu!", style: TextStyle(color: Colors.white, fontFamily: 'Rissa', fontSize: 18)))]))));
  }

  Widget _helpRow(IconData icon, String text, Color c) => Padding(padding: const EdgeInsets.only(bottom: 15), child: Row(children: [CircleAvatar(backgroundColor: Colors.white, child: Icon(icon, color: c)), const SizedBox(width: 15), Expanded(child: Text(text, style: const TextStyle(fontFamily: 'Rissa', fontSize: 16, color: RobertColors.textMain)))]));

  Widget _buildNote(NoteModel note) {
    double bodySize = math.max(14.0, note.w * 0.1); // Chữ note thu nhỏ lại tinh tế hơn
    double titleSize = bodySize * 0.5; // Chữ tiêu đề = 1/2 chữ viết

    Widget innerContent = GestureDetector(
      onTap: () { if (currentTool == 'highlighter') { setState(() => note.done = !note.done); LocalDataManager.saveNotes(notes); HapticFeedback.lightImpact(); } },
      child: Column(
        children: [
          Text("today's focus", style: TextStyle(color: RobertColors.textMain, fontSize: titleSize, fontFamily: 'Rissa', height: 1.0)),
          Expanded(
            child: currentTool == 'pencil' 
              ? TextField(controller: TextEditingController(text: note.text)..selection = TextSelection.fromPosition(TextPosition(offset: note.text.length)), onChanged: (val) { note.text = val; LocalDataManager.saveNotes(notes); }, maxLines: null, expands: true, style: TextStyle(color: RobertColors.textMain, fontSize: bodySize, fontFamily: 'Rissa'), decoration: const InputDecoration(border: InputBorder.none, hintText: "tap to add...", hintStyle: TextStyle(color: Colors.black26, fontFamily: 'Rissa')))
              : StrikeThrough(text: note.text.isEmpty ? "..." : note.text, done: note.done, fontSize: bodySize),
          )
        ],
      ),
    );

    return Positioned(
      left: note.dx, top: note.dy,
      child: GestureDetector(
        onPanDown: (_) => _bringToFront(note),
        onPanUpdate: (details) => setState(() { note.dx += details.delta.dx; note.dy += details.delta.dy; }),
        onPanEnd: (details) { double deleteZoneY = MediaQuery.of(context).size.height - 180; if (note.dy > deleteZoneY) { HapticFeedback.vibrate(); setState(() => notes.remove(note)); } LocalDataManager.saveNotes(notes); },
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100), opacity: note.dy > MediaQuery.of(context).size.height - 180 ? 0.3 : 1.0,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(width: note.w, height: note.h, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: RobertColors.note, border: Border.all(color: RobertColors.noteBorder, width: 3), borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8), bottomLeft: Radius.circular(8), bottomRight: Radius.circular(25)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(4, 4))]), child: Padding(padding: const EdgeInsets.all(10.0), child: innerContent)),
              Positioned(top: 0, left: 0, right: 0, child: Center(child: Container(width: 16, height: 16, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const RadialGradient(colors: [RobertColors.highlightPink, RobertColors.highlightRedDark]), boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(2, 3))])))),
              Positioned(right: 0, bottom: 0, child: GestureDetector(onPanUpdate: (details) => setState(() { note.w = math.max(120.0, note.w + details.delta.dx); note.h = math.max(120.0, note.h + details.delta.dy); }), onPanEnd: (_) => LocalDataManager.saveNotes(notes), child: Container(width: 30, height: 30, decoration: const BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.only(bottomRight: Radius.circular(25))), child: const Align(alignment: Alignment.bottomRight, child: Padding(padding: EdgeInsets.all(4.0), child: Icon(Icons.open_in_full_rounded, size: 14, color: Colors.black38))))))
            ],
          ),
        ),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF3A2B23) : const Color(0xFFC48B60),
      body: Stack(
        children: [
          Positioned.fill(child: Opacity(opacity: 0.05, child: CustomPaint(painter: GridPainter()))),
          if (!isLoading) ...notes.map((note) => _buildNote(note)),

          // THANH CÔNG CỤ LƠ LỬNG
          Positioned(
            bottom: 100, left: 0, right: 0, 
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, spreadRadius: 1)]),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(onTap: _addNote, child: ScaleTransition(scale: _pulseAnim, child: Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: RobertColors.note, shape: BoxShape.circle), child: const Icon(Icons.add, color: RobertColors.brownDark, size: 26)))), const SizedBox(width: 15),
                        GestureDetector(onTap: () { HapticFeedback.lightImpact(); setState(() => currentTool = 'pencil'); }, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: currentTool == 'pencil' ? Colors.white : Colors.transparent, shape: BoxShape.circle), child: Icon(Icons.edit, color: currentTool == 'pencil' ? RobertColors.textMain : Colors.grey, size: 24))), const SizedBox(width: 10),
                        GestureDetector(onTap: () { HapticFeedback.lightImpact(); setState(() => currentTool = 'highlighter'); }, child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: currentTool == 'highlighter' ? RobertColors.highlightPink.withOpacity(0.3) : Colors.transparent, shape: BoxShape.circle), child: Icon(Icons.border_color, color: currentTool == 'highlighter' ? RobertColors.highlightRed : Colors.grey, size: 24))), const SizedBox(width: 15),
                        GestureDetector(onTap: _clearAllNotes, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.cleaning_services_rounded, color: Colors.redAccent, size: 24))), const SizedBox(width: 10),
                        GestureDetector(onTap: _showHelp, child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.lightbulb_outline, color: Colors.blueAccent, size: 24))),
                      ],
                    ),
                  )
                )
              )
            )
          )
        ],
      )
    );
  }
}

class GridPainter extends CustomPainter {
  @override void paint(Canvas canvas, Size size) { var paint = Paint()..color = Colors.black..strokeWidth = 1.0; for (double i = 0; i < size.width; i += 40) { canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint); } for (double i = 0; i < size.height; i += 40) { canvas.drawLine(Offset(0, i), Offset(size.width, i), paint); } }
  @override bool shouldRepaint(CustomPainter oldDelegate) => false;
}
