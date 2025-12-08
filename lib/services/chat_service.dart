import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ChatService {
  // Singleton pattern
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  List<String> _knowledgeBase = [];
  bool _isInitialized = false;

  /// Loads the PDF and prepares the knowledge chunks
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load PDF from assets
      final byteData = await rootBundle.load('assets/docs/brochure.pdf');
      final bytes = byteData.buffer.asUint8List();

      // Extract text
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      String text = PdfTextExtractor(document).extractText();
      document.dispose();
      
      print("📄 Extracted Text Length: ${text.length}");
      print("📄 Text Sample (first 500chars): ${text.take(500)}");
      
      if (text.trim().isEmpty) {
        print("⚠️ WARNING: EXTRACTED TEXT IS EMPTY. PDF MIGHT BE SCANNED IMAGES.");
        // Add a dummy chunk so we verify the pipeline at least
        text = "EMSI is the Ecole Marocaine des Sciences de l'Ingenieur. Founded in 1986 by ... (Fallback content)";
      }

      // Split into chunks (paragraphs for now)
      // Cleaning text: remove excessive newlines
      text = text.replaceAll(RegExp(r'\n+'), '\n');
      
      // Improved Chunking: Sliding Window
      // 1. Clean text: remove excessive whitespaces/newlines to treat as continuous stream
      text = text.replaceAll(RegExp(r'\s+'), ' ');
      
      _knowledgeBase = [];
      const int chunkSize = 900;
      const int overlap = 200;
      
      if (text.length <= chunkSize) {
        _knowledgeBase.add(text);
      } else {
        for (int i = 0; i < text.length; i += (chunkSize - overlap)) {
          int end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
          _knowledgeBase.add(text.substring(i, end));
          if (end == text.length) break;
        }
      }

      _isInitialized = true;
      print("✅ RAG Initialized: ${_knowledgeBase.length} chunks loaded.");
    } catch (e) {
      print("❌ Error initializing RAG: $e");
    }
  }

  /// Sends the question to Ollama with retrieved context
  Stream<String> getAnswerStream(String question, List<Map<String, String>> history) async* {
    if (!_isInitialized) await initialize();

    // 1. Construct Search Query
    // Combine current question with previous user message for context (handle "and?" or "is that all?")
    String searchQuery = question;
    if (history.isNotEmpty) {
      final lastUserMsg = history.reversed.firstWhere((m) => m['role'] == 'user', orElse: () => {});
      if (lastUserMsg.isNotEmpty && question.length < 15) {
         // If current question is short, append context from previous question
         searchQuery = "${lastUserMsg['content']} $question";
      }
    }

    // 2. Retrieve relevant context (Boosted count)
    final context = _retrieveContext(searchQuery);
    print("🔍 Search Query: $searchQuery");
    print("📄 Retrieved Context Loop:\n$context\n----------------");

    // 3. Construct Prompt (History + Context)
    final historyText = history.map((m) => "${m['role'] == 'user' ? 'User' : 'Assistant'}: ${m['content']}").join("\n");
    
    final prompt = """
You are an expert assistant for EMSI (École Marocaine des Sciences de l'Ingénieur) in Morocco.
You have the following context from the school brochure (in French).
Answer the user's question strictly based on this context.
If the answer is not in the context, say "I couldn't find that information in the brochure".

Context:
$context

Conversation History:
$historyText

User: $question
Assistant:
""";

    // 3. Call Ollama API
    final url = Uri.parse('http://localhost:11434/api/generate');
    final request = http.Request('POST', url);
    request.body = jsonEncode({
      "model": "gemma:2b",
      "prompt": prompt,
      "stream": true, // We want streaming response
    });

    try {
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
          // Ollama sends JSON objects in the stream
          // e.g. {"model":"gemma:2b","created_at":"...","response":"Hello","done":false}
          
          // Chunk might contain multiple JSON objects
          try {
             // Split by newlines in case multiple JSONs are in one chunk
             final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);
             for (var line in lines) {
               final json = jsonDecode(line);
               if (json.containsKey('response')) {
                 yield json['response'];
               }
             }
          } catch (e) {
            // Ignore partial JSON parsing errors during stream
          }
        }
      } else {
        yield "Error: Ollama API returned ${streamedResponse.statusCode}. Is Ollama running?";
      }
    } catch (e) {
      yield "Error connecting to Ollama: $e. Please ensure 'ollama serve' is running.";
    }
  }

  /// Simple keyword matching to find top chunks
  String _retrieveContext(String question) {
    if (_knowledgeBase.isEmpty) return "";

    // 0. Manual English -> French mapping for common keywords
    Map<String, String> synonyms = {
      'founder': 'fondateur',
      'president': 'president', // covers président after normalization
      'programs': 'filiere genie informatique industriel civil automatismes reseaux', // boost keywords
      'majors': 'filiere genie informatique industriel civil automatismes reseaux',
      'located': 'sites',
      'location': 'ville',
      'emsi': 'emsi',
      'offered': 'formation',
    };

    String normalizedQuestion = _removeDiacritics(question.toLowerCase());
    
    // Expand keywords with synonyms
    List<String> keywords = normalizedQuestion.split(' ').where((w) => w.length > 3).toList();
    List<String> expandedKeywords = [...keywords];
    
    for (var word in keywords) {
      if (synonyms.containsKey(word)) {
        expandedKeywords.add(synonyms[word]!);
      }
      // Simple plural handling (remove 's')
      if (word.endsWith('s')) {
         expandedKeywords.add(word.substring(0, word.length - 1));
      }
    }

    if (expandedKeywords.isEmpty) return _knowledgeBase.take(3).join("\n\n");

    // Score chunks
    var scoredChunks = <MapEntry<String, int>>[];

    for (var chunk in _knowledgeBase) {
      int score = 0;
      final chunkNormalized = _removeDiacritics(chunk.toLowerCase());
      
      for (var word in expandedKeywords) {
        // Boost score for exact keyword matches
        if (chunkNormalized.contains(word)) score += 3;
        
        // Boost for specific department keywords if searching for programs
        if (expandedKeywords.contains('filiere') || expandedKeywords.contains('program')) {
           if (chunkNormalized.contains('genie') || chunkNormalized.contains('informatique')) score += 1;
        }
      }
      scoredChunks.add(MapEntry(chunk, score));
    }

    // Sort by score descending
    scoredChunks.sort((a, b) => b.value.compareTo(a.value));

    // Return top 8 most relevant chunks (Increased from 5) to capture broad lists
    final topChunks = scoredChunks.take(8).map((e) => e.key).toList();
    if (_knowledgeBase.isNotEmpty && !topChunks.contains(_knowledgeBase.first)) {
      topChunks.insert(0, _knowledgeBase.first);
    }
    
    return topChunks.join("\n\n");
  }

  String _removeDiacritics(String str) {
    var withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž';
    var withoutDia = 'AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz';
    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }
    return str;
  }
}

extension StringExtension on String {
  String take(int n) => length > n ? substring(0, n) + "..." : this;
}
