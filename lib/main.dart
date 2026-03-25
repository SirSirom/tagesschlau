import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import './api/util/ApiHelper.dart';
import './api/models/NewsModel.dart';
import 'dart:math' as math;

void main() {
  runApp(const ConnectionsApp());
}

class ConnectionsApp extends StatelessWidget {
  const ConnectionsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'tagesschlau',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black, surfaceTint: Colors.white),
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
  bool isNew; // 👈 for pop animation

  GridTileData(this.keywords, {this.isMerged = false, this.article, this.isNew = false});
}

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> with SingleTickerProviderStateMixin {
  Map<DateTime, List<NewsModel>>? _historyData;
  DateTime? _selectedDate;
  List<GridTileData> _currentGridTiles = [];
  final Set<int> _selectedIndices = {};
  bool _isLoading = true;
  int _attempts = 1;

  bool _animateTiles = true; // 👈 control animations

  OverlayEntry? _currentToast;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _initData();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _currentToast?.remove();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final data = await ApiHelper.loadNewsHistory();
      if (data.isNotEmpty) {
        final sortedDates = data.keys.toList()..sort((a, b) => b.compareTo(a));
        setState(() {
          _historyData = data;
          _updateActiveDate(sortedDates.first);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading news: $e");
      setState(() => _isLoading = false);
    }
  }

  void _updateActiveDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedIndices.clear();
      _currentGridTiles.clear();
      _attempts = 1;

      if (_historyData != null && _historyData![date] != null) {
        final articles = _historyData![date]!;
        _currentGridTiles = articles
            .expand((news) => news.keywords.map((k) => GridTileData([k.toUpperCase()])))
            .take(16)
            .toList();

        while (_currentGridTiles.length < 16) {
          _currentGridTiles.add(GridTileData([""]));
        }
        _currentGridTiles.shuffle();
      }
    });
    _prefetchImages();
  }

  void _prefetchImages() {
    if (_historyData == null || _selectedDate == null) return;
    final articles = _historyData![_selectedDate]!;
    for (final article in articles) {
      precacheImage(NetworkImage(article.imageURL), context);
    }
  }

  void _showMessage(String message) {
    _currentToast?.remove();
    _currentToast = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        onDismissed: () => _currentToast = null,
      ),
    );
    Overlay.of(context).insert(_currentToast!);
  }

  void _submitGroup() {
    if (_selectedIndices.length != 4) {
      _showMessage("Wähle 4 Begriffe aus");
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
        final matches = selectedKeywords.where((k) => group.contains(k)).length;
        if (matches == 3) oneOff = true;
      }
    }

    if (found && matchedArticle != null) {
      final selectedIndicesSorted = _selectedIndices.toList()
        ..sort((a, b) => b.compareTo(a));

      setState(() {
        _animateTiles = false; // 🚫 disable layout animation
        int lastMergeIdx = _currentGridTiles.indexWhere((element) => !element.isMerged);
        for (final idx in selectedIndicesSorted) {
          _currentGridTiles.removeAt(idx);
        }

        //insert merged tile at last merge tile position
        _currentGridTiles.insert(
          lastMergeIdx ,
          GridTileData(
            matchedArticle!.keywords,
            isMerged: true,
            article: matchedArticle,
            isNew: true, // 👈 trigger pop
          ),
        );

        _selectedIndices.clear();
      });
      // reset animation flag + pop flag
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _animateTiles = true;
          for (final tile in _currentGridTiles) {
            tile.isNew = false;
          }
        });
      });
    } else {
      _shakeController.forward(from: 0);
      setState(() => _attempts++);
      _showMessage(oneOff ? "Fast richtig! (3 von 4)" : "Falsche Gruppe");
    }
  }

  void _shuffleTiles() {
    setState(() {
      _animateTiles = true;

      final merged = _currentGridTiles.where((t) => t.isMerged).toList();
      final unmerged = _currentGridTiles.where((t) => !t.isMerged).toList();
      unmerged.shuffle();
      _currentGridTiles = [...merged, ...unmerged];
      _selectedIndices.clear();
    });
  }

  bool get _isGameOver => _currentGridTiles.isNotEmpty && _currentGridTiles.every((tile) => tile.isMerged);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));

    final screenWidth = MediaQuery.of(context).size.width;
    const spacing = 8.0;
    const padding = 16.0;
    final gridWidth = screenWidth - (padding * 2);
    final normalTileWidth = (gridWidth - (spacing * 3)) / 4;
    final rowHeight = 100.0 + spacing;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text("TAGESSCHLAU", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Colors.black)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.calendar_month, color: Colors.black), onPressed: _showDateSelector)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Text("Datum: ${_selectedDate?.day.toString().padLeft(2, '0')}.${_selectedDate?.month.toString().padLeft(2, '0')}.${_selectedDate?.year}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Text("Bilde vier Gruppen aus vier Begriffen!"),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: padding),
            child: SizedBox(
              height: rowHeight * 4,
              child: Stack(
                children: _buildAnimatedTiles(normalTileWidth, spacing, rowHeight),
              ),
            ),
          ),

          const Spacer(),
          _buildBottomSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  List<Widget> _buildAnimatedTiles(double tileWidth, double spacing, double rowHeight) {
    List<Widget> widgets = [];
    int unmergedCounter = 0;
    int mergedCounter = 0;

    for (int i = 0; i < _currentGridTiles.length; i++) {
      final tile = _currentGridTiles[i];
      double top, left, width;

      if (tile.isMerged) {
        top = mergedCounter * rowHeight;
        left = 0;
        width = (tileWidth * 4) + (spacing * 3);
        mergedCounter++;
      } else {
        int row = (unmergedCounter ~/ 4) + mergedCounter;
        int col = unmergedCounter % 4;
        top = row * rowHeight;
        left = col * (tileWidth + spacing);
        width = tileWidth;
        unmergedCounter++;
      }

      final isSelected = _selectedIndices.contains(i);

      widgets.add(
        AnimatedPositioned(
          key: ValueKey(tile.keywords.join() + tile.isMerged.toString()),
          duration: _animateTiles ? const Duration(milliseconds: 500) : Duration.zero,
          curve: Curves.easeInOut,
          top: top,
          left: left,
          width: width,
          height: 100,
          child: _ShakeTransition(
            enabled: isSelected && _shakeController.isAnimating,
            controller: _shakeController,
            child: _buildTile(i, tile, isSelected),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildTile(int index, GridTileData tile, bool isSelected) {
    final scale = tile.isNew ? 0.92 : 1.0;

    return GestureDetector(
      onTap: tile.isMerged ? (tile.article != null ? () => _openArticle(tile.article!.shareURL) : null) : () {
        setState(() {
          if (_selectedIndices.contains(index)) {
            _selectedIndices.remove(index);
          } else if (_selectedIndices.length < 4) {
            _selectedIndices.add(index);
          }
        });
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: scale, end: 1.0),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.scale(scale: value, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: tile.isMerged ? null : (isSelected ? const Color(0xFF5A594E) : const Color(0xFFEFEFE6)),
            image: tile.isMerged && tile.article != null
                ? DecorationImage(image: NetworkImage(tile.article!.imageURL), fit: BoxFit.cover)
                : null,
          ),
          child: tile.isMerged ? _buildMergedContent(tile) : _buildUnmergedContent(tile, isSelected),
        ),
      ),
    );
  }

  Widget _buildMergedContent(GridTileData tile) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.7)]),
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(tile.article?.title.toUpperCase() ?? "", textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(tile.keywords.join(", ").toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildUnmergedContent(GridTileData tile, bool isSelected) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(tile.keywords.isNotEmpty ? tile.keywords.first : "", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(_isGameOver ? "Gelöst in $_attempts Versuchen!" : "Versuche: $_attempts",
              key: ValueKey(_isGameOver.toString() + _attempts.toString()),
              style: TextStyle(color: _isGameOver ? Colors.green : Colors.black54, fontWeight: FontWeight.bold, fontSize: _isGameOver ? 18 : 14)),
        ),
        const SizedBox(height: 16),
        if (!_isGameOver)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: FittedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _nytButton("Mischen", _shuffleTiles),
                  const SizedBox(width: 8),
                  _nytButton("Auswahl aufheben", () => setState(() => _selectedIndices.clear())),
                  const SizedBox(width: 8),
                  _nytButton("Bestätigen", _submitGroup, isFilled: true),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _nytButton(String label, VoidCallback onPressed, {bool isFilled = false}) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: isFilled ? Colors.black : Colors.white,
        foregroundColor: isFilled ? Colors.white : Colors.black,
        side: const BorderSide(color: Colors.black),
        shape: const StadiumBorder(),
      ),
      child: Text(label),
    );
  }

  Future<void> _showDateSelector() async {
    if (_historyData == null) return;
    final List<DateTime> availableDates = _historyData!.keys.toList()..sort();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? availableDates.last,
      firstDate: availableDates.first,
      lastDate: availableDates.last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,      // header + selected date
              onPrimary: Colors.white,    // text on selected
              surface: Colors.white,      // background
              onSurface: Colors.black,    // normal text
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final key = _historyData!.keys.firstWhere((d) => d.year == picked.year && d.month == picked.month && d.day == picked.day);
      _updateActiveDate(key);
    }
  }

  Future<void> _openArticle(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage("Link konnte nicht geöffnet werden");
    }
  }
}

class _ShakeTransition extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final AnimationController controller;

  const _ShakeTransition({required this.child, required this.enabled, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final double sineValue = math.sin(4 * math.pi * controller.value);
        return Transform.translate(
          offset: Offset(sineValue * 8, 0),
          child: child,
        );
      },
      child: child,
    );
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismissed;
  const _ToastWidget({required this.message, required this.onDismissed});

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        _fadeController.reverse().then((_) => widget.onDismissed());
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 150,
      width: MediaQuery.of(context).size.width,
      child: FadeTransition(
        opacity: _fadeController,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(25)),
              child: Text(widget.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}