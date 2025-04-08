import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert'; // Added import for JSON decoding
import 'dart:typed_data'; // For handling image bytes


class ChatInterface extends StatefulWidget {
  const ChatInterface({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChatInterfaceState createState() => _ChatInterfaceState();
}

String _getLanguageCode(String language) {
  switch (language) {
    case 'Hindi':
      return 'hi';
    case 'Telugu':
      return 'te';
    case 'Tamil':
      return 'ta';
    default:
      return 'en'; // Default to English
  }
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _messages = []; // Stores both text and image messages
  bool _isSeller = false; // Tracks whether the user is a seller or buyer
  final ImagePicker _picker = ImagePicker();
  String _selectedLanguage = 'English'; // Default language

  final Map<String, Map<String, String>> _translations = {
    'English': {
      'choose_role': 'Choose Your Role',
      'buyer': 'Buyer',
      'seller': 'Seller',
      'enter_message': 'Enter your message',
      'send': 'Send',
    },
    'Hindi': {
      'choose_role': 'अपनी भूमिका चुनें',
      'buyer': 'खरीदार',
      'seller': 'विक्रेता',
      'enter_message': 'अपना संदेश दर्ज करें',
      'send': 'भेजें',
    },
    'Telugu': {
      'choose_role': 'మీ పాత్రను ఎంచుకోండి',
      'buyer': 'కొనుగోలుదారు',
      'seller': 'అమ్మకందారు',
      'enter_message': 'మీ సందేశాన్ని నమోదు చేయండి',
      'send': 'పంపండి',
    },
    'Tamil': {
      'choose_role': 'உங்கள் பாத்திரத்தைத் தேர்ந்தெடுக்கவும்',
      'buyer': 'வாங்குபவர்',
      'seller': 'விற்பனையாளர்',
      'enter_message': 'உங்கள் செய்தியை உள்ளிடவும்',
      'send': 'அனுப்பு',
    },
  };

  @override
  void initState() {
    super.initState();
    _showLanguageSelectionPopup(); // Show language selection pop-up when the interface is opened
    _loadMessages(); // Load messages when the chat interface is opened
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMessages = prefs.getStringList('messages') ?? [];
    setState(() {
    _getLanguageCode(_selectedLanguage);
      for (var messageData in savedMessages) {
        final parsedData = Map<String, dynamic>.from(json.decode(messageData));
        if (parsedData['type'] == 'image') {
          parsedData['content'] = base64Decode(parsedData['content']);
        }
        _messages.add(parsedData);
      }
    });
  }

  void _sendMessage({String? text, Uint8List? imageBytes}) async {
  if (text != null && text.trim().isNotEmpty) {
    final targetLanguageCode = _getLanguageCode(_selectedLanguage);

    // Translate the message
    final translatedText = await _translateMessage(text, targetLanguageCode); // Translate the message

    setState(() {
      _messages.add({
        'type': 'text',
        'content': translatedText,
        'isSeller': _isSeller,
      });
    });
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
  _saveMessage(messageData); // Save the message to persistent storage
}

  Future<void> _saveMessage(Map<String, dynamic> messageData) async {
    final prefs = await SharedPreferences.getInstance();
    final savedMessages = prefs.getStringList('messages') ?? [];
    savedMessages.add(json.encode(messageData)); // Encode messageData as JSON string
    await prefs.setStringList('messages', savedMessages);
  }

  Future<String> _translateMessage(String text, String targetLanguageCode) async {
    // Placeholder for translation logic
    // Replace this with actual translation API integration
    return Future.value(text); // For now, return the original text
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes(); // Read the image as bytes
      _sendMessage(imageBytes: bytes);
    }
  }

  void _showLanguageSelectionPopup() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent closing the dialog without choosing
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Select Language'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text('English'),
                  onTap: () {
                    setState(() {
                      _selectedLanguage = 'English';
                    });
                    Navigator.of(context).pop();
                    _showRoleSelectionPopup();
                  },
                ),
                ListTile(
                  title: Text('Hindi'),
                  onTap: () {
                    setState(() {
                      _selectedLanguage = 'Hindi';
                    });
                    Navigator.of(context).pop();
                    _showRoleSelectionPopup();
                  },
                ),
                ListTile(
                  title: Text('Telugu'),
                  onTap: () {
                    setState(() {
                      _selectedLanguage = 'Telugu';
                    });
                    Navigator.of(context).pop();
                    _showRoleSelectionPopup();
                  },
                ),
                ListTile(
                  title: Text('Tamil'),
                  onTap: () {
                    setState(() {
                      _selectedLanguage = 'Tamil';
                    });
                    Navigator.of(context).pop();
                    _showRoleSelectionPopup();
                  },
                ),
              ],
            ),
          );
        },
      );
    });
  }

  void _showRoleSelectionPopup() {
    final t = _translations[_selectedLanguage]!;
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing the dialog without choosing
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(t['choose_role']!),
          content: Text('${t['buyer']} or ${t['seller']}?'),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _isSeller = false; // Set role to Buyer
                });
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(t['buyer']!),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isSeller = true; // Set role to Seller
                });
                Navigator.of(context).pop(); // Close the dialog
              },
              child: Text(t['seller']!),
            ),
          ],
        );
      },
    );
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
            message['content'], // Display the image from bytes
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
    final t = _translations[_selectedLanguage]!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Chat Interface'),
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
                      hintText: t['enter_message'],
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _sendMessage(text: _controller.text),
                  child: Text(t['send']!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}