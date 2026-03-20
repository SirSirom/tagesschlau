import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import './api/util/ApiHelper.dart';
import './api/models/NewsModel.dart';

void main() {
  runApp(const ConnectionsApp());
}

class ConnectionsApp extends StatelessWidget {
  const ConnectionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NYT Connections Clone',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Georgia',
      ),
      home: const ConnectionsScreen(),
    );
  }
}

class GridTileData {
  final List<String> keywords;
  final NewsModel? article;
  bool isMerged;

  GridTileData(this.keywords, {this.isMerged = false, this.article});
}

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  Map<String, List<NewsModel>>? _historyData;
  String? _selectedDate;
  List<GridTileData> _currentGridTiles = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      final data = await ApiHelper.loadNewsHistory();
      if (data.isNotEmpty) {
        // Sort keys (dates) descending to get latest first
        final sortedDates = data.keys.toList()
          ..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)));

        setState(() {
          _historyData = data;
          _updateActiveDate(sortedDates.first); // latest date
          _isLoading = false;
        });
      } else {
        setState(() {
          _historyData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading news: $e");
      setState(() => _isLoading = false);
    }
  }

  void _updateActiveDate(String date) {
    setState(() {
      _selectedDate = date;
      _selectedIndices.clear();
      _currentGridTiles.clear();

      if (_historyData != null && _historyData![date] != null) {
        final articles = _historyData![date]!;

        _currentGridTiles = articles
            .expand((news) =>
            news.keywords.map((k) => GridTileData([k.toUpperCase()])))
            .take(16)
            .toList();

        while (_currentGridTiles.length < 16) {
          _currentGridTiles.add(GridTileData([""]));
        }

        _currentGridTiles.shuffle();
      }
    });

    // 🔥 Prefetch images AFTER setState (important!)
    _prefetchImages();
  }

  void _prefetchImages() {
    if (_historyData == null || _selectedDate == null) return;

    final articles = _historyData![_selectedDate]!;

    for (final article in articles) {
      precacheImage(
        NetworkImage(article.imageURL),
        context,
      );
    }
  }

  Future<void> _openArticle(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open article")),
      );
    }
  }

  void _submitGroup() {
    if (_selectedIndices.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select 4 items to form a group")),
      );
      return;
    }

    final selectedKeywords = _selectedIndices
        .map((i) => _currentGridTiles[i].keywords.first.toUpperCase())
        .toList();

    final selectedSorted = List<String>.from(selectedKeywords)..sort();

    bool found = false;
    bool oneOff = false;
    NewsModel? matchedArticle;

    final articles = _historyData![_selectedDate]!;

    for (final article in articles) {
      final group = article.keywords.map((k) => k.toUpperCase()).toList();
      final groupSorted = List<String>.from(group)..sort();

      if (listEquals(selectedSorted, groupSorted)) {
        found = true;
        matchedArticle = article;
        break;
      } else {
        // Check if 3 out of 4 match
        final matches = selectedKeywords.where((k) => group.contains(k)).length;
        if (matches == 3) oneOff = true;
      }
    }

    if (found && matchedArticle != null) {
      setState(() {
        final selectedTiles =
        _selectedIndices.toList()..sort((a, b) => b.compareTo(a));

        for (final idx in selectedTiles) {
          _currentGridTiles.removeAt(idx);
        }

        _currentGridTiles.insert(
          0,
          GridTileData(
            selectedKeywords,
            isMerged: true,
            article: matchedArticle,
          ),
        );

        _selectedIndices.clear();
      });
    } else if (oneOff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You are one keyword off!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid group. Try again!")),
      );
    }
  }

  void _shuffleTiles() {
    setState(() {
      final merged = _currentGridTiles.where((t) => t.isMerged).toList();
      final unmerged = _currentGridTiles.where((t) => !t.isMerged).toList();

      unmerged.shuffle();

      _currentGridTiles = [...merged, ...unmerged];
      _selectedIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }

    final screenWidth = MediaQuery.of(context).size.width;
    const spacing = 8.0;
    final normalTileWidth = (screenWidth - spacing * 3 - 32) / 4;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("CONNECTIONS",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: "Earlier Days",
            onPressed: _showDateSelector, // <-- this opens your bottom sheet
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text("Date: $_selectedDate",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Text("Create four groups of four!"),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: List.generate(_currentGridTiles.length, (index) {
                final tile = _currentGridTiles[index];
                final isSelected = _selectedIndices.contains(index);
                final width = tile.isMerged
                    ? normalTileWidth * 4 + spacing * 3
                    : normalTileWidth;

                return SizedBox(
                  width: width,
                  child: _buildTile(index, tile, isSelected),
                );
              }),
            ),
          ),
          const Spacer(),
          _buildActionButtons(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildTile(int index, GridTileData tile, bool isSelected) {
    if (tile.keywords.first.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: tile.isMerged
          ? () {
        if (tile.article != null) {
          _openArticle(tile.article!.shareURL);
        }
      }
          : () {
        setState(() {
          if (_selectedIndices.contains(index)) {
            _selectedIndices.remove(index);
          } else if (_selectedIndices.length < 4) {
            _selectedIndices.add(index);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: tile.isMerged
              ? null
              : (isSelected
              ? const Color(0xFF5A594E)
              : const Color(0xFFEFEFE6)),
          image: tile.isMerged && tile.article != null
              ? DecorationImage(
            image: NetworkImage(tile.article!.imageURL),
            fit: BoxFit.cover,
          )
              : null,
        ),
        child: tile.isMerged
            ? Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black54,
              ],
            ),
          ),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          child: Text(
            tile.article!.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        )
            : Center(
          child: Text(
            tile.keywords.first,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _nytButton("Shuffle", _shuffleTiles),
        const SizedBox(width: 12),
        _nytButton("Deselect all",
                () => setState(() => _selectedIndices.clear())),
        const SizedBox(width: 12),
        _nytButton("Submit", _submitGroup, isFilled: true),
      ],
    );
  }

  Widget _nytButton(String label, VoidCallback onPressed,
      {bool isFilled = false}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isFilled ? Colors.black : Colors.white,
        foregroundColor: isFilled ? Colors.white : Colors.black,
        side: const BorderSide(color: Colors.black),
        shape: const StadiumBorder(),
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label),
    );
  }
  void _showDateSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Earlier Day",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              Expanded(
                child: ListView(
                  children: _historyData!.keys.map((date) {
                    return ListTile(
                      title: Text(date, textAlign: TextAlign.center),
                      selected: date == _selectedDate,
                      onTap: () {
                        _updateActiveDate(date);
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}