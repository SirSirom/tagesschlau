import 'package:http/http.dart' as http;
import '../models/NewsModel.dart';
/**
 * Class to handle api request
 */
class ApiHelper{
  /// Sets the endpoint for the api
  /// different release states possible
  static String endpoint = "https://tagesschlau.gameteamspeak.de/";

   static Future<http.Response> sendRequest(String uri,HttpMethod httpMethod,{Map<String, String>? additionalHeaders,Object? postBody}) async {

     ///Handle Requests
     switch (httpMethod){
       case HttpMethod.POST:
         return await http.post(
             Uri.parse('$endpoint$uri'),
             headers: additionalHeaders,
             body: postBody);
       case HttpMethod.GET:
         return await http.get(
             Uri.parse('$endpoint$uri'),
             headers: additionalHeaders
        );
     }
   }

   static Future<Map<String,List<NewsModel>>> loadNewsHistory() async {
     ///send Request and Parse by method from NewsModel
     String body = (await sendRequest('history', HttpMethod.GET)).body;
     Map<String,List<NewsModel>> news = NewsModel.fromHistoryMapJson(body);
     return news ;
   }
}

///enum to handle Http Methods
enum HttpMethod{ POST,GET}