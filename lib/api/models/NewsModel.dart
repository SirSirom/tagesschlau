import 'dart:convert';

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

  factory NewsModel.fromJson(Map<String, dynamic> jsonMap){

    // Convert Map<String, dynamic> to NewsModel object
    return NewsModel(
      title: jsonMap["title"] as String,
      shareURL: jsonMap["shareURL"] as String,
      imageURL: jsonMap["imageURL"] as String,
      date: DateTime.parse(jsonMap["date"]),
      keywords: List<String>.from(jsonMap["keywords"]),
    );}

  static List<NewsModel> fromListJson(String str) => List<NewsModel>.from(json.decode(str).map((x) => NewsModel.fromJson(x)));
  static Map<DateTime,List<NewsModel>> fromHistoryMapJson(String str) => Map<DateTime,List<NewsModel>>.from(
      json.decode(str).map(
              (k,x) => MapEntry(
                  DateTime.parse(k), NewsModel.fromListJson(
                  json.encode(x)
              )))
  );

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