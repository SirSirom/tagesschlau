import 'dart:convert';
import 'dart:developer' as developer;

class NewsModel {
  String title;
  DateTime date;
  String shareURL;
  String imageURL;
  List<String> keywords;

  NewsModel({
    required this.title,
    required this.date,
    required this.shareURL,
    required this.imageURL,
    required this.keywords,
  });

  factory NewsModel.fromJson(Map<String, dynamic> jsonMap) {
    // Check for missing fields and log them to help debug the API response
    final missingFields = <String>[];
    if (jsonMap["title"] == null) missingFields.add("title");
    if (jsonMap["date"] == null) missingFields.add("date");
    if (jsonMap["shareURL"] == null) missingFields.add("shareURL");
    if (jsonMap["imageURL"] == null) missingFields.add("imageURL");
    if (jsonMap["keywords"] == null) missingFields.add("keywords");

    if (missingFields.isNotEmpty) {
      developer.log(
        'Missing fields $missingFields in news article. Title: ${jsonMap["title"]}. Full JSON: $jsonMap',
        name: 'NewsModel',
      );
    }

    return NewsModel(
      title: jsonMap["title"]?.toString() ?? "",
      shareURL: jsonMap["shareURL"]?.toString() ?? "",
      imageURL: jsonMap["imageURL"]?.toString() ?? "",
      date: DateTime.tryParse(jsonMap["date"]?.toString() ?? "") ?? DateTime.now(),
      keywords: (jsonMap["keywords"] as List?)
              ?.map((k) => k?.toString() ?? "")
              .toList() ??
          [],
    );
  }

  static List<NewsModel> fromListJson(String str) {
    try {
      final decoded = json.decode(str);
      if (decoded is List) {
        return decoded
            .map((x) => NewsModel.fromJson(x as Map<String, dynamic>))
            .toList();
      } else {
        developer.log('fromListJson: Expected List but got ${decoded.runtimeType}', name: 'NewsModel');
      }
    } catch (e, stack) {
      developer.log('Error parsing news list', error: e, stackTrace: stack, name: 'NewsModel');
    }
    return [];
  }

  static Map<DateTime, List<NewsModel>> fromHistoryMapJson(String str) {
    try {
      final decoded = json.decode(str);
      if (decoded is Map) {
        return decoded.map((k, x) {
          final date = DateTime.tryParse(k.toString()) ?? DateTime.now();
          final list = x is List
              ? x.map((i) => NewsModel.fromJson(i as Map<String, dynamic>)).toList()
              : <NewsModel>[];
          return MapEntry(date, list);
        });
      } else {
        developer.log('fromHistoryMapJson: Expected Map but got ${decoded.runtimeType}', name: 'NewsModel');
      }
    } catch (e, stack) {
      developer.log('Error parsing news history map', error: e, stackTrace: stack, name: 'NewsModel');
    }
    return {};
  }

  @override
  String toString() {
    return '''{
      "title": "$title",
      "date": "$date",
      "shareURL": "$shareURL",
      "imageURL": "$imageURL",
      "keywords": "$keywords"
     }''';
  }
}
