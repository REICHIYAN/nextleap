import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'api_keys.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(NextLeapApp());
}

class NextLeapApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NextLeap',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(title: const Text('NextLeap'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 24 : 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'あなたのキャリアタイプを診断しよう',
                style: TextStyle(fontSize: isMobile ? 20 : 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: isMobile ? 12 : 16),
                  textStyle: TextStyle(fontSize: isMobile ? 16 : 20),
                ),
                child: const Text('診断をスタートする'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => QuestionScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class QuestionScreen extends StatefulWidget {
  @override
  _QuestionScreenState createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  List<dynamic> questions = [];
  Map<String, int> scores = {};
  List<int?> selectedAnswers = [];

  @override
  void initState() {
    super.initState();
    loadQuestions();
  }

  Future<void> loadQuestions() async {
    final jsonString = await rootBundle.loadString('assets/questions.json');
    final data = json.decode(jsonString);
    setState(() {
      questions = data['questions'];
      selectedAnswers = List.filled(questions.length, null);
      for (var type in data['types'].keys) {
        scores[type] = 0;
      }
    });
  }

  void handleAnswer(List<String> tags) {
    for (var tag in tags) {
      scores[tag] = (scores[tag] ?? 0) + 1;
    }
  }

  Future<void> handleSubmit() async {
    if (selectedAnswers.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべての質問に回答してください。')),
      );
      return;
    }

    scores.updateAll((key, value) => 0);
    for (int i = 0; i < questions.length; i++) {
      final selectedIndex = selectedAnswers[i]!;
      final tags = List<String>.from(questions[i]['answers'][selectedIndex]['tags']);
      handleAnswer(tags);
    }

    final topType = scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    final answerTexts = [
      for (int i = 0; i < questions.length; i++)
        questions[i]['answers'][selectedAnswers[i]!]['text']
    ];

    final prompt = '''
以下の質問と回答に基づいて、ユーザーの適性を診断してください。
診断タイプ: $topType
回答内容: ${answerTexts.join(', ')}
200文字以内で解説してください。
''';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await sendToOpenAI(prompt);

      await FirebaseFirestore.instance.collection('diagnoses').add({
        'timestamp': Timestamp.now(),
        'answers': List<String>.from(answerTexts),
        'type': topType,
        'result': result,
      });

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            result: result,
            answers: List<String>.from(answerTexts),
            type: topType,
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('診断に失敗しました: $e')),
      );
    }
  }

  Future<String> sendToOpenAI(String prompt) async {
    const apiUrl = 'https://api.openai.com/v1/chat/completions';

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $openaiApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-3.5-turbo',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'temperature': 0.7,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('OpenAI APIエラー: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (questions.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('キャリア診断')),
      body: ListView.builder(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        itemCount: questions.length + 1,
        itemBuilder: (context, index) {
          if (index < questions.length) {
            final q = questions[index];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q['text'], style: TextStyle(fontSize: isMobile ? 16 : 18)),
                    const SizedBox(height: 12),
                    ...List.generate(q['answers'].length, (i) {
                      final answer = q['answers'][i];
                      return RadioListTile<int>(
                        title: Text(answer['text'], style: TextStyle(fontSize: isMobile ? 14 : 16)),
                        value: i,
                        groupValue: selectedAnswers[index],
                        onChanged: (int? val) {
                          setState(() {
                            selectedAnswers[index] = val;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: ElevatedButton(
                  onPressed: handleSubmit,
                  child: Text('診断する', style: TextStyle(fontSize: isMobile ? 16 : 18)),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final String result;
  final List<String> answers;
  final String type;

  const ResultScreen({required this.result, required this.answers, required this.type});

  String getTypeLabel(String key) {
    const labels = {
      'analyzer': '分析型',
      'creator': '創造型',
      'leader': '指導型',
      'helper': '支援型',
      'adventurer': '冒険型',
    };
    return labels[key] ?? '未分類';
  }

  Color getTypeColor(String key) {
    const colors = {
      'analyzer': Colors.blue,
      'creator': Colors.purple,
      'leader': Colors.red,
      'helper': Colors.green,
      'adventurer': Colors.orange,
    };
    return colors[key] ?? Colors.grey;
  }

  void _exportPdf(BuildContext context) async {
    final fontData = await rootBundle.load("assets/fonts/NotoSansJP-VariableFont_wght.ttf");
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());

    final pdfDoc = pw.Document();
    pdfDoc.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('NextLeap キャリア診断結果',
                style: pw.TextStyle(font: ttf, fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text('■ 診断タイプ：${getTypeLabel(type)}', style: pw.TextStyle(font: ttf)),
            pw.SizedBox(height: 8),
            pw.Text('■ 診断結果：', style: pw.TextStyle(font: ttf)),
            pw.Text(result, style: pw.TextStyle(font: ttf, fontSize: 16)),
            pw.SizedBox(height: 24),
            pw.Text('■ 回答内容：', style: pw.TextStyle(font: ttf)),
            ...answers.map((ans) => pw.Bullet(text: ans, style: pw.TextStyle(font: ttf))),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfDoc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = getTypeLabel(type);
    final typeColor = getTypeColor(type);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(title: const Text('診断結果')),
      body: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 6),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'あなたのタイプ：$typeLabel',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: typeColor,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  result,
                  style: TextStyle(fontSize: isMobile ? 14 : 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _exportPdf(context),
              child: const Text('PDFで保存'),
            ),
          ],
        ),
      ),
    );
  }
}
