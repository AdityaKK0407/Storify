import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Added for TTS
import 'dart:convert'; // For JSON encoding/decoding
import 'dart:typed_data'; // For handling image bytes

// Main entry point
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => AppModel(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel',
      theme: ThemeData(primarySwatch: Colors.green),
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// Model for state management (Language, Cart, and Inventory)
class AppModel extends ChangeNotifier {
  String _selectedLanguage = 'English';
  int _customerCartItemCount = 0;
  int _ownerCartItemCount = 0;
  List<Map<String, dynamic>> _customerCartItems = [];
  List<Map<String, dynamic>> _ownerCartItems = [];
  List<Map<String, dynamic>> _inventory = [
    {'itemName': 'Apple', 'category': 'Fruits', 'expiry': '1 Month', 'quantity': 50, 'unit': 'Kilograms', 'inStock': true},
    {'itemName': 'Milk', 'category': 'Food', 'expiry': '3 Months', 'quantity': 20, 'unit': 'Litres', 'inStock': true},
    {'itemName': 'Cola', 'category': 'Cool Drinks', 'expiry': '6 Months', 'quantity': 0, 'unit': 'Litres', 'inStock': false},
    {'itemName': 'Ice Cream', 'category': 'Ice Creams', 'expiry': '1 Year', 'quantity': 30, 'unit': 'Boxes', 'inStock': true},
    {'itemName': 'Bread', 'category': 'Food', 'expiry': '1 Month', 'quantity': 0, 'unit': 'Packets', 'inStock': false},
  ];
  static String? selectedAudioTone; // Kept for consistency, though unused now

  String get selectedLanguage => _selectedLanguage;

  set selectedLanguage(String value) {
    _selectedLanguage = value;
    notifyListeners();
  }

  int get customerCartItemCount => _customerCartItemCount;

  int get ownerCartItemCount => _ownerCartItemCount;

  List<Map<String, dynamic>> get customerCartItems => _customerCartItems;

  List<Map<String, dynamic>> get ownerCartItems => _ownerCartItems;

  List<Map<String, dynamic>> get inventory => _inventory;

  void addToCustomerCart(String itemName, String category, String expiry, int quantity, String unit) {
    int inventoryIndex = _inventory.indexWhere((item) => item['itemName'] == itemName);
    if (inventoryIndex != -1 && _inventory[inventoryIndex]['inStock'] == true && _inventory[inventoryIndex]['quantity'] >= quantity) {
      _customerCartItems.add({
        'itemName': itemName,
        'category': category,
        'expiry': expiry,
        'quantity': quantity,
        'unit': unit,
      });
      _customerCartItemCount += quantity;
      _inventory[inventoryIndex]['quantity'] -= quantity;
      if (_inventory[inventoryIndex]['quantity'] == 0) {
        _inventory[inventoryIndex]['inStock'] = false;
      }
      notifyListeners();
    }
  }

  void addToOwnerCart(String itemName, String category, String expiry, int quantity, String unit) {
    int inventoryIndex = _inventory.indexWhere((item) => item['itemName'] == itemName);
    if (inventoryIndex != -1) {
      _inventory[inventoryIndex]['quantity'] += quantity;
      _inventory[inventoryIndex]['inStock'] = true;
    } else {
      _inventory.add({
        'itemName': itemName,
        'category': category,
        'expiry': expiry,
        'quantity': quantity,
        'unit': unit,
        'inStock': true,
      });
    }
    _ownerCartItems.add({
      'itemName': itemName,
      'category': category,
      'expiry': expiry,
      'quantity': quantity,
      'unit': unit,
    });
    _ownerCartItemCount += quantity;
    notifyListeners();
  }

  void updateCustomerQuantity(int index, int newQuantity, String unit) {
    if (index >= 0 && index < _customerCartItems.length && newQuantity >= 0) {
      int oldQuantity = (_customerCartItems[index]['quantity'] as num?)?.toInt() ?? 0;
      String itemName = _customerCartItems[index]['itemName'];
      int inventoryIndex = _inventory.indexWhere((item) => item['itemName'] == itemName);

      if (inventoryIndex != -1) {
        int availableStock = _inventory[inventoryIndex]['quantity'] as int;
        if (newQuantity > oldQuantity && availableStock < (newQuantity - oldQuantity)) {
          return; // Not enough stock
        }
        _inventory[inventoryIndex]['quantity'] += oldQuantity - newQuantity;
        _inventory[inventoryIndex]['inStock'] = _inventory[inventoryIndex]['quantity'] > 0;
      }

      _customerCartItems[index]['quantity'] = newQuantity;
      _customerCartItems[index]['unit'] = unit;
      _customerCartItemCount = _customerCartItemCount - oldQuantity + newQuantity;
      if (newQuantity == 0) {
        _customerCartItems.removeAt(index);
        _customerCartItemCount = _customerCartItems.fold(0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0));
      }
      notifyListeners();
    }
  }

  void updateOwnerItem(String itemName, String category, String expiry, int newQuantity, String unit) {
    int index = _ownerCartItems.indexWhere((item) => item['itemName'] == itemName);
    int inventoryIndex = _inventory.indexWhere((item) => item['itemName'] == itemName);

    if (index != -1) {
      int oldQuantity = (_ownerCartItems[index]['quantity'] as num?)?.toInt() ?? 0;
      _ownerCartItems[index] = {
        'itemName': itemName,
        'category': category,
        'expiry': expiry,
        'quantity': newQuantity,
        'unit': unit,
      };
      _ownerCartItemCount = _ownerCartItemCount - oldQuantity + newQuantity;
      if (newQuantity == 0) {
        _ownerCartItems.removeAt(index);
        _ownerCartItemCount = _ownerCartItems.fold(0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0));
      }
    } else {
      _ownerCartItems.add({
        'itemName': itemName,
        'category': category,
        'expiry': expiry,
        'quantity': newQuantity,
        'unit': unit,
      });
      _ownerCartItemCount += newQuantity;
    }

    if (inventoryIndex != -1) {
      _inventory[inventoryIndex]['quantity'] = newQuantity;
      _inventory[inventoryIndex]['inStock'] = newQuantity > 0;
    } else {
      _inventory.add({
        'itemName': itemName,
        'category': category,
        'expiry': expiry,
        'quantity': newQuantity,
        'unit': unit,
        'inStock': newQuantity > 0,
      });
    }
    notifyListeners();
  }

  void updateOwnerQuantity(int index, int newQuantity, String unit) {
    if (index >= 0 && index < _ownerCartItems.length && newQuantity >= 0) {
      int oldQuantity = (_ownerCartItems[index]['quantity'] as num?)?.toInt() ?? 0;
      String itemName = _ownerCartItems[index]['itemName'];
      int inventoryIndex = _inventory.indexWhere((item) => item['itemName'] == itemName);

      _ownerCartItems[index]['quantity'] = newQuantity;
      _ownerCartItems[index]['unit'] = unit;
      _ownerCartItemCount = _ownerCartItemCount - oldQuantity + newQuantity;

      if (inventoryIndex != -1) {
        _inventory[inventoryIndex]['quantity'] = newQuantity;
        _inventory[inventoryIndex]['inStock'] = newQuantity > 0;
      }

      if (newQuantity == 0) {
        _ownerCartItems.removeAt(index);
        _ownerCartItemCount = _ownerCartItems.fold(0, (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0));
      }
      notifyListeners();
    }
  }

  void removeFromCustomerCart(int index) {
    if (index >= 0 && index < _customerCartItems.length) {
      int quantity = (_customerCartItems[index]['quantity'] as num?)?.toInt() ?? 0;
      String itemName = _customerCartItems[index]['itemName'];
      int inventoryIndex = _inventory.indexWhere((item) => item['itemName'] == itemName);

      if (inventoryIndex != -1) {
        _inventory[inventoryIndex]['quantity'] += quantity;
        _inventory[inventoryIndex]['inStock'] = true;
      }

      _customerCartItemCount -= quantity;
      _customerCartItems.removeAt(index);
      notifyListeners();
    }
  }

  void removeFromOwnerCart(int index) {
    if (index >= 0 && index < _ownerCartItems.length) {
      int quantity = (_ownerCartItems[index]['quantity'] as num?)?.toInt() ?? 0;
      String itemName = _ownerCartItems[index]['itemName'];
      int inventoryIndex = _inventory.indexWhere((item) => item['itemName'] == itemName);

      if (inventoryIndex != -1) {
        _inventory[inventoryIndex]['quantity'] -= quantity;
        _inventory[inventoryIndex]['inStock'] = _inventory[inventoryIndex]['quantity'] > 0;
      }

      _ownerCartItemCount -= quantity;
      _ownerCartItems.removeAt(index);
      notifyListeners();
    }
  }

  void clearCustomerCart() {
    for (var item in _customerCartItems) {
      int inventoryIndex = _inventory.indexWhere((i) => i['itemName'] == item['itemName']);
      if (inventoryIndex != -1) {
        _inventory[inventoryIndex]['quantity'] += (item['quantity'] as num?)?.toInt() ?? 0;
        _inventory[inventoryIndex]['inStock'] = true;
      }
    }
    _customerCartItems.clear();
    _customerCartItemCount = 0;
    notifyListeners();
  }

  void clearOwnerCart() {
    for (var item in _ownerCartItems) {
      int inventoryIndex = _inventory.indexWhere((i) => i['itemName'] == item['itemName']);
      if (inventoryIndex != -1) {
        _inventory[inventoryIndex]['quantity'] -= (item['quantity'] as num?)?.toInt() ?? 0;
        _inventory[inventoryIndex]['inStock'] = _inventory[inventoryIndex]['quantity'] > 0;
      }
    }
    _ownerCartItems.clear();
    _ownerCartItemCount = 0;
    notifyListeners();
  }
}

// Centralized Translations
class AppTranslations {
  static final Map<String, Map<String, String>> translations = {
    'English': {
      'splash_screen_title': 'STORIFY',
      'splash_screen_subtitle': 'Fabulous Five',
      'user_selection_title': 'Select User',
      'customer_button': 'Customer',
      'owner_button': 'Owner',
      'choose_language': 'Choose Language',
      'item_name_label': 'Item Name',
      'quantity_label': 'Quantity',
      'unit_label': 'Unit',
      'category_label': 'Category',
      'expiry_label': 'Expiry',
      'add_item_button': 'Add Item',
      'item_added_message': 'Item added successfully',
      'required_field': 'Required',
      'add_item_screen_title': 'Add Item',
      'search_hint': 'Search Inventory...',
      'no_items_found': 'No items found',
      'inventory_empty': 'Inventory is empty',
      'owner_screen_title': 'Owner Panel',
      'add_button': 'Add',
      'update_button': 'Update',
      'remove_button': 'Remove',
      'item_updated_message': 'Item updated successfully',
      'item_removed_message': 'Item removed successfully',
      'cart_title': 'Cart',
      'buy_now': 'Buy Now',
      'remove': 'Remove',
      'all': 'All',
      'fresh': 'Fresh',
      'bestsellers': 'Bestsellers',
      'special_discounts': 'Special Discounts',
      'today_deals': "Today's Deals",
      'chat_title': 'Chat Interface',
      'send_button': 'Send',
    },
    'Hindi': {
      'splash_screen_title': 'स्टोरिफाई',
      'splash_screen_subtitle': 'फैबुलस फाइव',
      'user_selection_title': 'उपयोगकर्ता चुनें',
      'customer_button': 'ग्राहक',
      'owner_button': 'मालिक',
      'choose_language': 'भाषा चुनें',
      'item_name_label': 'आइटम का नाम',
      'quantity_label': 'मात्रा',
      'unit_label': 'इकाई',
      'category_label': 'श्रेणी',
      'expiry_label': 'समाप्ति',
      'add_item_button': 'आइटम जोड़ें',
      'item_added_message': 'आइटम सफलतापूर्वक जोड़ा गया',
      'required_field': 'आवश्यक',
      'add_item_screen_title': 'आइटम जोड़ें',
      'search_hint': 'इन्वेंट्री खोजें...',
      'no_items_found': 'कोई आइटम नहीं मिला',
      'inventory_empty': 'इन्वेंट्री खाली है',
      'owner_screen_title': 'मालिक पैनल',
      'add_button': 'जोड़ें',
      'update_button': 'अपडेट करें',
      'remove_button': 'हटाएं',
      'item_updated_message': 'आइटम सफलतापूर्वक अपडेट किया गया',
      'item_removed_message': 'आइटम सफलतापूर्वक हटाया गया',
      'cart_title': 'कार्ट',
      'buy_now': 'अभी खरीदें',
      'remove': 'हटाएं',
      'all': 'सभी',
      'fresh': 'ताजा',
      'bestsellers': 'सर्वश्रेष्ठ बिक्री',
      'special_discounts': 'विशेष छूट',
      'today_deals': 'आज के ऑफर',
      'chat_title': 'चैट इंटरफेस',
      'send_button': 'भेजें',
    },
    'Tamil': {
      'splash_screen_title': 'ஸ்டோரிஃபை',
      'splash_screen_subtitle': 'ஃபாபுலஸ் ஃபைவ்',
      'user_selection_title': 'பயனரைத் தேர்ந்தெடுக்கவும்',
      'customer_button': 'வாடிக்கையாளர்',
      'owner_button': 'உரிமையாளர்',
      'choose_language': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'item_name_label': 'உரuppடியின் பெயர்',
      'quantity_label': 'அளவு',
      'unit_label': 'அலகு',
      'category_label': 'வகை',
      'expiry_label': 'காலாவதி',
      'add_item_button': 'உரuppடியைச் சேர்க்கவும்',
      'item_added_message': 'உரuppடி வெற்றிகரமாக சேர்க்கப்பட்டது',
      'required_field': 'தேவையானது',
      'add_item_screen_title': 'உரuppடி சேர்க்கவும்',
      'search_hint': 'கையகப்படுத்தலைத் தேடு...',
      'no_items_found': 'எந்த உரuppடிகளும் கிடைக்கவில்லை',
      'inventory_empty': 'கையகப்படுத்தல் காலியாக உள்ளது',
      'owner_screen_title': 'உரிமையாளர் பேனல்',
      'add_button': 'சேர்க்கவும்',
      'update_button': 'புதுப்பிக்கவும்',
      'remove_button': 'நீக்கவும்',
      'item_updated_message': 'உரuppடி வெற்றிகரமாக புதுப்பிக்கப்பட்டது',
      'item_removed_message': 'உரuppடி வெற்றிகரமாக நீக்கப்பட்டது',
      'cart_title': 'கார்ட்',
      'buy_now': 'இப்போது வாங்கவும்',
      'remove': 'நீக்கு',
      'all': 'அனைத்தும்',
      'fresh': 'புதிய',
      'bestsellers': 'சிறந்த விற்பனைகள்',
      'special_discounts': 'சிறப்பு தள்ளுபடி',
      'today_deals': 'இன்றைய டீல்ஸ்',
      'chat_title': 'சாட் இடைமுகம்',
      'send_button': 'அனுப்பு',
    },
    'Telugu': {
      'splash_screen_title': 'స్టోరిఫై',
      'splash_screen_subtitle': 'ఫాబులస్ ఫైవ్',
      'user_selection_title': 'వినియోగదారుని ఎంచుకోండి',
      'customer_button': 'వినియోగదారు',
      'owner_button': 'సంపాదకుడు',
      'choose_language': 'భాషను ఎంచుకోండి',
      'item_name_label': 'అంశం పేరు',
      'quantity_label': 'పరిమాణం',
      'unit_label': 'యూనిట్',
      'category_label': 'వర్గం',
      'expiry_label': 'గడువు',
      'add_item_button': 'అంశాన్ని జోడించండి',
      'item_added_message': 'అంశం విజయవంతంగా జోడించబడింది',
      'required_field': 'అవసరం',
      'add_item_screen_title': 'అంశాన్ని జోడించండి',
      'search_hint': 'ఇన్వెంటరీ శోధించండి...',
      'no_items_found': 'ఐటమ్‌లు కనుగొనబడలేదు',
      'inventory_empty': 'ఇన్వెంటరీ ఖాళీగా ఉంది',
      'owner_screen_title': 'సంపాదకుడు ప్యానెల్',
      'add_button': 'జోడించండి',
      'update_button': 'నవీకరించండి',
      'remove_button': 'తొలగించండి',
      'item_updated_message': 'అంశం విజయవంతంగా నవీకరించబడింది',
      'item_removed_message': 'అంశం విజయవంతంగా తొలగించబడింది',
      'cart_title': 'కార్ట్',
      'buy_now': 'ఇప్పుడు కొనండి',
      'remove': 'తొలగించు',
      'all': 'అన్నీ',
      'fresh': 'తాజా',
      'bestsellers': 'బెస్ట్ సెల్లర్స్',
      'special_discounts': 'స్పెషల్ డిస్కౌంట్స్',
      'today_deals': 'ఈ రోజు డీల్స్',
      'chat_title': 'చాట్ ఇంటర్ఫేస్',
      'send_button': 'పంపండి',
    },
  };
}

// Reusable Language Selector Widget
class LanguageSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<String>(
          value: appModel.selectedLanguage,
          items: AppTranslations.translations.keys.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Text(
                lang,
                style: TextStyle(color: Colors.black),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              appModel.selectedLanguage = value;
            }
          },
          icon: Icon(Icons.language, color: Colors.black),
        ),
      ),
    );
  }
}

// Reusable Customer Cart Icon Widget
class CustomerCartIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: InkWell(
        splashColor: Colors.grey.withOpacity(0.3),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CustomerCartScreen()),
          );
        },
        child: Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.black),
            SizedBox(width: 4),
            Text(
              appModel.customerCartItemCount.toString(),
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable Owner Cart Icon Widget
class OwnerCartIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: InkWell(
        splashColor: Colors.grey.withOpacity(0.3),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OwnerCartScreen()),
          );
        },
        child: Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.black),
            SizedBox(width: 4),
            Text(
              appModel.ownerCartItemCount.toString(),
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// Empty Page for Navigation Buttons
class EmptyPage extends StatelessWidget {
  final String title;

  EmptyPage({required this.title});

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);
    final t = AppTranslations.translations[appModel.selectedLanguage]!;

    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text(title),
        actions: [
          LanguageSelector(),
          CustomerCartIcon(),
        ],
      ),
      body: Center(
        child: Text('This page is empty for now.'),
      ),
    );
  }
}

// Chat Interface Implementation (With TTS Added)
class ChatInterface extends StatefulWidget {
  @override
  _ChatInterfaceState createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isSeller = false;
  final ImagePicker _picker = ImagePicker();
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _showRoleSelectionPopup();
    _loadMessages();
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVoice({"name": "en-us-x-tpc-local", "locale": "en-US"});
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMessages = prefs.getStringList('messages') ?? [];
    setState(() {
      _messages.clear();
      for (var messageData in savedMessages) {
        final parsedData = Map<String, dynamic>.from(json.decode(messageData));
        if (parsedData['type'] == 'image') {
          parsedData['content'] = base64Decode(parsedData['content']);
        }
        _messages.add(parsedData);
      }
    });
    _speakMessages();
  }

  void _sendMessage({String? text, Uint8List? imageBytes}) {
    if (text != null && text.trim().isNotEmpty) {
      setState(() {
        _messages.add({'type': 'text', 'content': text, 'isSeller': _isSeller});
      });
      _flutterTts.speak(text);
      _controller.clear();
    } else if (imageBytes != null) {
      setState(() {
        _messages.add({'type': 'image', 'content': imageBytes, 'isSeller': _isSeller});
      });
    }

    final messageData = {
      'type': text != null ? 'text' : 'image',
      'content': text ?? base64Encode(imageBytes!),
      'isSeller': _isSeller,
    };
    _saveMessage(messageData);
  }

  Future<void> _saveMessage(Map<String, dynamic> messageData) async {
    final prefs = await SharedPreferences.getInstance();
    final savedMessages = prefs.getStringList('messages') ?? [];
    savedMessages.add(json.encode(messageData));
    await prefs.setStringList('messages', savedMessages);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      _sendMessage(imageBytes: bytes);
    }
  }

  void _showRoleSelectionPopup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appModel = Provider.of<AppModel>(context, listen: false);
      final t = AppTranslations.translations[appModel.selectedLanguage]!;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(t['user_selection_title']!),
            content: Text('Are you a Buyer or a Seller?'),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSeller = false; // Buyer
                  });
                  Navigator.of(context).pop();
                },
                child: Text(t['customer_button']!),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isSeller = true; // Seller
                  });
                  Navigator.of(context).pop();
                },
                child: Text(t['owner_button']!),
              ),
            ],
          );
        },
      );
    });
  }

  void _speakMessages() {
    String textToSpeak = _messages
        .where((msg) => msg['type'] == 'text')
        .map((msg) => msg['content'] as String)
        .join(". ");
    if (textToSpeak.isNotEmpty) {
      _flutterTts.speak(textToSpeak);
    }
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isSellerMessage = message['isSeller'];
    final alignment = isSellerMessage ? Alignment.centerLeft : Alignment.centerRight;
    final color = isSellerMessage ? Colors.red : Colors.blue;

    if (message['type'] == 'text') {
      return Align(
        alignment: alignment,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            message['content'],
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } else if (message['type'] == 'image') {
      return Align(
        alignment: alignment,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          child: Image.memory(
            message['content'],
            width: 200,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    return SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);
    final t = AppTranslations.translations[appModel.selectedLanguage]!;

    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text(t['chat_title']!),
        actions: [
          LanguageSelector(),
          CustomerCartIcon(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.image),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Enter your message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendMessage(text: _controller.text),
                  child: Text(t['send_button']!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _flutterTts.stop();
    super.dispose();
  }
}

// Splash Screen
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => UserSelectionScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);
    final t = AppTranslations.translations[appModel.selectedLanguage]!;

    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_rounded, size: 80, color: Colors.white),
            SizedBox(height: 16),
            Text(
              t['splash_screen_title']!,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// User Selection Screen
class UserSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);
    final t = AppTranslations.translations[appModel.selectedLanguage]!;

    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text(t['user_selection_title']!),
        actions: [
          LanguageSelector(),
          CustomerCartIcon(),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0),
          child: Container(
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['all']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['all']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['fresh']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['fresh']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['bestsellers']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['bestsellers']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['special_discounts']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['special_discounts']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['today_deals']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['today_deals']!),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.shopping_cart),
                  label: Text(t['customer_button']!),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.0),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddItemScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: Icon(Icons.store),
                  label: Text(t['owner_button']!),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15.0),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SellerScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatInterface()),
              );
            },
            child: Text('Chat Interface'),
          ),
        ],
      ),
    );
  }
}

// Add Item Screen (Customer)
class AddItemScreen extends StatefulWidget {
  @override
  _AddItemScreenState createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? selectedCategory;
  String? selectedExpiry;
  String? selectedUnit;

  final List<String> categories = ['Food', 'Fruits', 'Cool Drinks', 'Ice Creams'];
  final List<String> expiryOptions = ['3 Months', '6 Months', '1 Year'];
  final List<String> unitOptions = ['Litres', 'Kilograms', 'Packets', 'Boxes'];

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final appModel = Provider.of<AppModel>(context, listen: false);
      final t = AppTranslations.translations[appModel.selectedLanguage]!;
      final quantity = int.parse(_quantityController.text);
      int inventoryIndex = appModel.inventory.indexWhere((item) => item['itemName'] == _itemNameController.text);
      if (inventoryIndex != -1 && appModel.inventory[inventoryIndex]['inStock'] == true && appModel.inventory[inventoryIndex]['quantity'] >= quantity) {
        appModel.addToCustomerCart(
          _itemNameController.text,
          selectedCategory ?? '',
          selectedExpiry ?? '',
          quantity,
          selectedUnit ?? 'Packets',
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t['item_added_message']!)),
        );
        _itemNameController.clear();
        _quantityController.clear();
        setState(() {
          selectedCategory = null;
          selectedExpiry = null;
          selectedUnit = null;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Item not available or insufficient stock')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterInventory(String query) {
    final appModel = Provider.of<AppModel>(context, listen: false);
    if (query.isEmpty) return appModel.inventory;
    return appModel.inventory
        .where((item) => item['itemName'].toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);
    final t = AppTranslations.translations[appModel.selectedLanguage]!;

    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text(t['add_item_screen_title']!),
        actions: [
          LanguageSelector(),
          CustomerCartIcon(),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0),
          child: Container(
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['all']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['all']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['fresh']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['fresh']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['bestsellers']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['bestsellers']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['special_discounts']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['special_discounts']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['today_deals']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['today_deals']!),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'STORIFY',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [LanguageSelector()],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: t['search_hint']!,
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filterInventory(_searchController.text).length,
              itemBuilder: (context, index) {
                final item = _filterInventory(_searchController.text)[index];
                return ListTile(
                  title: Text(item['itemName'] ?? ''),
                  subtitle: Text('Cat: ${item['category']}, Exp: ${item['expiry']}, Qty: ${item['quantity']} ${item['unit']}'),
                  trailing: Icon(
                    item['inStock'] ? Icons.check_circle : Icons.cancel,
                    color: item['inStock'] ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ),
          _filterInventory(_searchController.text).isEmpty && _searchController.text.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    t['no_items_found']!,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  TextFormField(
                    controller: _itemNameController,
                    decoration: InputDecoration(labelText: t['item_name_label']!),
                    validator: (value) => value == null || value.trim().isEmpty ? t['required_field']! : null,
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _quantityController,
                          decoration: InputDecoration(labelText: t['quantity_label']!),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return t['required_field']!;
                            if (int.tryParse(value) == null) return 'Enter a valid number';
                            return null;
                          },
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedUnit,
                          items: unitOptions.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                          onChanged: (value) => setState(() => selectedUnit = value),
                          decoration: InputDecoration(labelText: t['unit_label']!),
                          validator: (value) => value == null ? t['required_field']! : null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                          onChanged: (value) => setState(() => selectedCategory = value),
                          decoration: InputDecoration(labelText: t['category_label']!),
                          validator: (value) => value == null ? t['required_field']! : null,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedExpiry,
                          items: expiryOptions.map((exp) => DropdownMenuItem(value: exp, child: Text(exp))).toList(),
                          onChanged: (value) => setState(() => selectedExpiry = value),
                          decoration: InputDecoration(labelText: t['expiry_label']!),
                          validator: (value) => value == null ? t['required_field']! : null,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _submitForm,
                    child: Text(t['add_item_button']!),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Seller Screen (Owner Screen)
class SellerScreen extends StatefulWidget {
  @override
  _SellerScreenState createState() => _SellerScreenState();
}

class _SellerScreenState extends State<SellerScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String? selectedCategory;
  String? selectedExpiry;
  String? selectedUnit;

  final List<String> categories = ['Food', 'Fruits', 'Cool Drinks', 'Ice Creams'];
  final List<String> expiryOptions = ['1 Month', '3 Months', '6 Months', '1 Year'];
  final List<String> unitOptions = ['Litres', 'Kilograms', 'Packets', 'Boxes'];

  void _submitAction(String action) {
    if (_formKey.currentState!.validate()) {
      final appModel = Provider.of<AppModel>(context, listen: false);
      final t = AppTranslations.translations[appModel.selectedLanguage]!;
      String message = '';
      final quantity = int.parse(_quantityController.text);
      switch (action) {
        case 'add':
          appModel.addToOwnerCart(
            _itemNameController.text,
            selectedCategory ?? '',
            selectedExpiry ?? '',
            quantity,
            selectedUnit ?? 'Packets',
          );
          message = t['item_added_message']!;
          break;
        case 'update':
          appModel.updateOwnerItem(
            _itemNameController.text,
            selectedCategory ?? '',
            selectedExpiry ?? '',
            quantity,
            selectedUnit ?? 'Packets',
          );
          message = t['item_updated_message']!;
          break;
        case 'remove':
          int index = appModel.ownerCartItems.indexWhere((item) => item['itemName'] == _itemNameController.text);
          if (index != -1) {
            appModel.removeFromOwnerCart(index);
            message = t['item_removed_message']!;
          } else {
            message = 'Item not found in cart';
          }
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

      if (action != 'update') {
        _itemNameController.clear();
        _quantityController.clear();
        setState(() {
          selectedCategory = null;
          selectedExpiry = null;
          selectedUnit = null;
        });
      }
    }
  }

  List<Map<String, dynamic>> _filterInventory(String query) {
    final appModel = Provider.of<AppModel>(context, listen: false);
    if (query.isEmpty) return appModel.inventory;
    return appModel.inventory
        .where((item) => item['itemName'].toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _quantityController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);
    final t = AppTranslations.translations[appModel.selectedLanguage]!;

    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text(t['owner_screen_title']!),
        actions: [
          LanguageSelector(),
          OwnerCartIcon(),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0),
          child: Container(
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['all']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['all']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['fresh']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['fresh']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['bestsellers']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['bestsellers']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['special_discounts']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['special_discounts']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['today_deals']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['today_deals']!),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'STORIFY',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [LanguageSelector()],
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: t['search_hint']!,
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (value) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filterInventory(_searchController.text).length,
              itemBuilder: (context, index) {
                final item = _filterInventory(_searchController.text)[index];
                return ListTile(
                  title: Text(item['itemName'] ?? ''),
                  subtitle: Text('Cat: ${item['category']}, Exp: ${item['expiry']}, Qty: ${item['quantity']} ${item['unit']}'),
                  trailing: Icon(
                    item['inStock'] ? Icons.check_circle : Icons.cancel,
                    color: item['inStock'] ? Colors.green : Colors.red,
                  ),
                );
              },
            ),
          ),
          _filterInventory(_searchController.text).isEmpty && _searchController.text.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    t['no_items_found']!,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      children: [
                        TextFormField(
                          controller: _itemNameController,
                          decoration: InputDecoration(labelText: t['item_name_label']!),
                          validator: (value) => value == null || value.trim().isEmpty ? t['required_field']! : null,
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _quantityController,
                                decoration: InputDecoration(labelText: t['quantity_label']!),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) return t['required_field']!;
                                  if (int.tryParse(value) == null) return 'Enter a valid number';
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedUnit,
                                items: unitOptions.map((unit) => DropdownMenuItem(value: unit, child: Text(unit))).toList(),
                                onChanged: (value) => setState(() => selectedUnit = value),
                                decoration: InputDecoration(labelText: t['unit_label']!),
                                validator: (value) => value == null ? t['required_field']! : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedCategory,
                                items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                                onChanged: (value) => setState(() => selectedCategory = value),
                                decoration: InputDecoration(labelText: t['category_label']!),
                                validator: (value) => value == null ? t['required_field']! : null,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedExpiry,
                                items: expiryOptions.map((exp) => DropdownMenuItem(value: exp, child: Text(exp))).toList(),
                                onChanged: (value) => setState(() => selectedExpiry = value),
                                decoration: InputDecoration(labelText: t['expiry_label']!),
                                validator: (value) => value == null ? t['required_field']! : null,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      ElevatedButton(
                        onPressed: () => _submitAction('add'),
                        child: Text(t['add_button']!),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _submitAction('update'),
                        child: Text(t['update_button']!),
                      ),
                      SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () => _submitAction('remove'),
                        child: Text(t['remove_button']!),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Customer Cart Screen
class CustomerCartScreen extends StatefulWidget {
  @override
  _CustomerCartScreenState createState() => _CustomerCartScreenState();
}

class _CustomerCartScreenState extends State<CustomerCartScreen> {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);
    final t = AppTranslations.translations[appModel.selectedLanguage]!;

    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text(t['cart_title']!),
        actions: [
          LanguageSelector(),
          CustomerCartIcon(),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0),
          child: Container(
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['all']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['all']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['fresh']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['fresh']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['bestsellers']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['bestsellers']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['special_discounts']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['special_discounts']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['today_deals']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['today_deals']!),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: appModel.customerCartItems.length,
              itemBuilder: (context, index) {
                final item = appModel.customerCartItems[index];
                return ListTile(
                  title: Text(item['itemName'] ?? ''),
                  subtitle: Text('Cat: ${item['category']}, Exp: ${item['expiry']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          appModel.updateCustomerQuantity(index, ((item['quantity'] as num?)?.toInt() ?? 0) - 1, item['unit']);
                        },
                      ),
                      Text('${((item['quantity'] as num?)?.toInt() ?? 0)} ${item['unit']}'),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          appModel.updateCustomerQuantity(index, ((item['quantity'] as num?)?.toInt() ?? 0) + 1, item['unit']);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          appModel.removeFromCustomerCart(index);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t['item_removed_message']!)),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (appModel.customerCartItems.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Purchase completed! Cart cleared.')),
                      );
                      appModel.clearCustomerCart();
                    }
                  },
                  child: Text(t['buy_now']!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Owner Cart Screen
class OwnerCartScreen extends StatefulWidget {
  @override
  _OwnerCartScreenState createState() => _OwnerCartScreenState();
}

class _OwnerCartScreenState extends State<OwnerCartScreen> {
  @override
  Widget build(BuildContext context) {
    final appModel = Provider.of<AppModel>(context);
    final t = AppTranslations.translations[appModel.selectedLanguage]!;

    return Scaffold(
      backgroundColor: Colors.pink[50],
      appBar: AppBar(
        title: Text(t['cart_title']!),
        actions: [
          LanguageSelector(),
          OwnerCartIcon(),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(40.0),
          child: Container(
            color: Colors.black87,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['all']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['all']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['fresh']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['fresh']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['bestsellers']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['bestsellers']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['special_discounts']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['special_discounts']!),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EmptyPage(title: t['today_deals']!))),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white),
                  child: Text(t['today_deals']!),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: appModel.ownerCartItems.length,
              itemBuilder: (context, index) {
                final item = appModel.ownerCartItems[index];
                return ListTile(
                  title: Text(item['itemName'] ?? ''),
                  subtitle: Text('Cat: ${item['category']}, Exp: ${item['expiry']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          appModel.updateOwnerQuantity(index, ((item['quantity'] as num?)?.toInt() ?? 0) - 1, item['unit']);
                        },
                      ),
                      Text('${((item['quantity'] as num?)?.toInt() ?? 0)} ${item['unit']}'),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          appModel.updateOwnerQuantity(index, ((item['quantity'] as num?)?.toInt() ?? 0) + 1, item['unit']);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          appModel.removeFromOwnerCart(index);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(t['item_removed_message']!)),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (appModel.ownerCartItems.isNotEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Owner cart cleared.')),
                      );
                      appModel.clearOwnerCart();
                    }
                  },
                  child: Text('Clear Cart'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}