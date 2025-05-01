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
    return Scaffold(
      appBar: AppBar(title: const Text('NextLeap'), centerTitle: true),
      body: Center(
        child: ElevatedButton(
          child: const Text('診断をスタートする'),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => QuestionScreen()),
            );
          },
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
  final List<String> questions = [
    'あなたが得意だと感じることは？',
    'あなたが働く上で大事にしたいことは？',
    'チームワークと個人作業、どちらが得意？',
    'どんな業界に興味がある？',
    '将来、どんな働き方をしていたい？',
  ];

  late List<TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    controllers = List.generate(
      questions.length,
      (index) => TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (var controller in controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> handleSubmit() async {
    List<String> answers = controllers.map((c) => c.text.trim()).toList();
    if (answers.any((ans) => ans.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべての質問に回答してください。')),
      );
      return;
    }

    String prompt = '';
    for (int i = 0; i < questions.length; i++) {
      prompt += '${questions[i]}\n${answers[i]}\n\n';
    }
    prompt += '上記の回答をもとに、ユーザーに向いているキャリアタイプを200文字以内で説明してください。';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final result = await sendToOpenAI(prompt);

      await FirebaseFirestore.instance.collection('diagnoses').add({
        'timestamp': Timestamp.now(),
        'answers': answers,
        'result': result,
      });

      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            result: result,
            answers: answers,
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
    return Scaffold(
      appBar: AppBar(title: const Text('キャリア診断')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: questions.length + 1,
          itemBuilder: (context, index) {
            if (index < questions.length) {
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        questions[index],
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: controllers[index],
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          hintText: 'ここに入力してください',
                        ),
                        maxLines: null,
                      ),
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
                    child: const Text('診断する'),
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class ResultScreen extends StatelessWidget {
  final String result;
  final List<String> answers;

  const ResultScreen({required this.result, required this.answers});

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
    return Scaffold(
      appBar: AppBar(title: const Text('診断結果')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  result,
                  style: const TextStyle(fontSize: 18),
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
